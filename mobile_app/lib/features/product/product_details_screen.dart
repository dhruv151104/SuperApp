import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:product_traceability_mobile/features/product/widgets/product_map.dart';
import 'package:product_traceability_mobile/features/product/widgets/product_map.dart';
import 'package:product_traceability_mobile/services/pdf_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:product_traceability_mobile/services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _productData; // JSON from API

  bool _isRetailer = false;
  bool _isManufacturer = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _checkRole();
  }

  Future<void> _fetchDetails() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getProduct(widget.productId);
      if (mounted) {
        setState(() {
          _productData = data; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String? _currentWalletAddress;

  Future<void> _checkRole() async {
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role');
    final wallet = await storage.read(key: 'wallet_address');
    if (mounted) setState(() {
      _isRetailer = role == 'Retailer';
      _isManufacturer = role == 'Manufacturer';
      _currentWalletAddress = wallet;
    });
  }



// ... (imports)

  Future<void> _verifyProduct() async {
    setState(() => _isVerifying = true);
    try {
      // 1. Check Location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
          if (mounted) _showLocationDialog("Location Disabled", "Enable location?", () async => await Geolocator.openLocationSettings());
          return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
          if (mounted) _showLocationDialog("Permission Denied", "Enable permission in settings?", () async => await Geolocator.openAppSettings());
          return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final location = "${position.latitude}, ${position.longitude}";

      // 2. Ask for Visual Evidence (Retailer Flow)
      bool? includePhoto;
      if (mounted) {
         includePhoto = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Visual Verification?"),
              content: const Text("Do you want to document the condition of this product with a photo?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No, just verify")),
                ElevatedButton.icon(
                   onPressed: () => Navigator.pop(ctx, true), 
                   icon: const Icon(Icons.camera_alt), 
                   label: const Text("Yes, Check Quality")
                )
              ],
            )
         );
      }
      if (includePhoto == null) return; // Cancelled

      String? imagePath;
      if (includePhoto) {
          final picker = ImagePicker();
          final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
          if (photo == null) return; // Cancelled photo
          imagePath = photo.path;
      }
      
      final api = ref.read(apiServiceProvider);
      await api.addRetailerHop(widget.productId, location, imagePath: imagePath);
      
      if (mounted) {
        showDialog(
           context: context,
           builder: (_) => AlertDialog(
             title: const Text("Verified!"),
             content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 8),
                Text("Product verified at $location"),
                if (includePhoto == true) ...[
                   const SizedBox(height: 8),
                   const Text("Visual Evidence Recorded", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
                ]
             ]),
             actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
           )
        );
      }
      _fetchDetails(); 
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _performConsumerCheck() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo == null) return;

    if(mounted) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (_) => const Center(child: CircularProgressIndicator())
       );
    }

    try {
       final api = ref.read(apiServiceProvider);
       // Passing productId enables Backend to fetch Manufacturer's Reference Image
       // for "Spot the Difference" / Comparative Analysis
       final result = await api.analyzeImage(photo.path, productId: widget.productId);
       final analysis = result['result'];
       
       if(mounted) {
          Navigator.pop(context); // Close loader
          
          bool isDamaged = analysis['isDamaged'] == true;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
               title: Text(isDamaged ? "Analysis Result" : "Analysis Result"), 
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDamaged ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDamaged ? Colors.red : Colors.green, width: 2)
                      ),
                      child: Column(
                        children: [
                           Icon(
                             isDamaged ? Icons.gpp_bad : Icons.verified_user, 
                             color: isDamaged ? Colors.red : Colors.green, 
                             size: 48
                           ),
                           const SizedBox(height: 12),
                           Text(
                             isDamaged ? "AI Detected Damage" : "Verified Intact",
                             style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDamaged ? Colors.red : Colors.green
                             ),
                           ),
                           const SizedBox(height: 8),
                           Divider(color: isDamaged ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                           const SizedBox(height: 8),
                           Text(
                             analysis['reason'] ?? "No reason provided", 
                             textAlign: TextAlign.center,
                             style: TextStyle(
                               fontSize: 14, 
                               color: Colors.black87,
                               fontWeight: FontWeight.w500
                             )
                           ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                       "Private Analysis: This result is for your reference only and is not recorded on the blockchain.", 
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 11, color: Colors.grey)
                    )
                 ],
               ),
               actions: [
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: ()=>Navigator.pop(context), 
                     style: ElevatedButton.styleFrom(backgroundColor: isDamaged ? Colors.red : Colors.green, foregroundColor: Colors.white),
                     child: const Text("OK")
                   ),
                 )
               ],
            )
          );
       }
    } catch(e) {
       if(mounted) Navigator.pop(context);
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analysis failed"))); 
    }
  }

  void _showLocationDialog(String title, String message, VoidCallback onAction) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            }, 
            child: const Text("Settings")
          ),
        ],
      )
    );
  }

  Future<void> _exportPdf() async {
    if (_productData == null) return;
    try {
      await PdfService().generateProductCertificate(_productData!);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e")));
    }
  }

  Future<void> _showQrCode() async {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Product QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: widget.productId,
                  version: QrVersions.auto,
                  // size: 200.0, // Removed to avoid conflict with SizedBox
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                 // Share Logic (Simplified for brevity, similar to mint screen)
                 // Ideally extract this to a helper if reusing vastly
                 final painter = QrPainter.withQr(
                    qr: QrValidator.validate(data: widget.productId, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.L).qrCode!,
                    color: const Color(0xFF000000),
                    emptyColor: const Color(0xFFFFFFFF),
                    gapless: true,
                  );
                  final directory = await getTemporaryDirectory();
                  final path = '${directory.path}/share_qr.png';
                  final file = File(path);
                  final picData = await painter.toImageData(875);
                  await file.writeAsBytes(picData!.buffer.asUint8List());
                  await Share.shareXFiles([XFile(path)], text: 'Product ID: ${widget.productId}');
              },
              icon: const Icon(Icons.share),
              label: const Text("Share")
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text("Error: $_error")),
      );
    }
    
    if (_isLoading) {
       return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Parsing Data: { productId, manufacturer, hops: [{role, actor, location, timestamp}] }
    final history = _productData!['hops'] as List<dynamic>;
    final locations = history.map((e) => e['location'].toString()).toList();

    // Check if already verified by this user
    bool alreadyVerified = false;
    if (_currentWalletAddress != null) {
      // Case-insensitive comparison of wallet addresses
      alreadyVerified = history.any((h) => h['actor'].toString().toLowerCase() == _currentWalletAddress!.toLowerCase());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Traceability"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Export Passport",
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: "Show QR",
            onPressed: _showQrCode,
          )
        ],
      ),
      floatingActionButton: (_isManufacturer || (_isRetailer && alreadyVerified)) 
        ? null 
        : FloatingActionButton.extended(
            onPressed: (_isVerifying) 
                ? null 
                // Logic: If we are here, it's either Unverified Retailer OR Consumer
                : (_isRetailer) ? _verifyProduct : _performConsumerCheck,
            
            label: (_isRetailer)
                ? (_isVerifying ? const Text("Verifying...") : const Text("Verify & Receive"))
                : const Text("✨ AI Quality Check"),
            
            icon: Icon((_isRetailer) ? Icons.check_circle_outline : Icons.camera_enhance),
            
            backgroundColor: (_isRetailer) ? Colors.orange : Colors.deepPurpleAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(),
            const SizedBox(height: 24),
            ProductMap(locations: locations),
            const SizedBox(height: 32),
            Text(
              "Journey Timeline",
              style: AppTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final hop = history[index]; // Map
                
                final roleStr = hop['role'];
                final actor = hop['actor'];
                final location = hop['location'];
                // Timestamp from backend is typically seconds or millis check backend.
                // Backend: timestamp: Number(h[3].toString()) from solidity timestamp (seconds)
                final timestamp = DateTime.fromMillisecondsSinceEpoch(hop['timestamp'] * 1000);
                
                final isManufacturer = roleStr == "Manufacturer";
                final dateStr = DateFormat('MMM d, y • h:mm a').format(timestamp);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isManufacturer ? AppTheme.primaryColor : Colors.orange,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                               BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5)
                            ]
                          ),
                        ),
                        if (index != history.length - 1)
                          Container(
                            width: 2,
                            height: 80,
                            color: Colors.grey[300],
                          )
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                             BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isManufacturer ? "Manufactured" : "Retailer Scan",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Icon(
                                  isManufacturer ? Icons.factory : Icons.store,
                                  size: 16,
                                  color: Colors.grey,
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(icon: Icons.calendar_today, text: dateStr),
                            const SizedBox(height: 4),
                            _InfoRow(icon: Icons.location_on, text: location),
                             const SizedBox(height: 4),
                            _InfoRow(
                              icon: Icons.business, 
                              text: hop['actorName'] != null && hop['actorName'] != 'Unknown' 
                                  ? hop['actorName'] 
                                  : "Unregistered Entity",
                              color: Colors.black87,
                              fontWeight: FontWeight.w600
                            ),
                            _InfoRow(
                              icon: Icons.person_outline, 
                              text: "${actor.substring(0, 6)}...${actor.substring(38)}",
                              fontSize: 11
                            ),
                            
                             // Flags
                             if(hop['flags'] != null && (hop['flags'] as List).isNotEmpty) ...[
                               const SizedBox(height: 8),
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                   color: Colors.red.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(8),
                                   border: Border.all(color: Colors.red.withOpacity(0.3))
                                 ),
                                 child: Row(
                                   children: [
                                     const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                     const SizedBox(width: 8),
                                     Expanded(child: Text(
                                       (hop['flags'] as List).join(", "),
                                       style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)
                                     ))
                                   ],
                                 ),
                               )
                             ],
                             
                             // Visual Evidence & AI Analysis
                             if (hop['imageUrl'] != null) ...[
                                const SizedBox(height: 12),
                                const Text("Visual Evidence:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          insetPadding: EdgeInsets.zero,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              InteractiveViewer(
                                                child: Image.network(
                                                  "${ApiService.baseUrl}/${hop['imageUrl']}",
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Positioned(
                                                top: 40,
                                                right: 20,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                  onPressed: () => Navigator.pop(ctx),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.network(
                                          "${ApiService.baseUrl}/${hop['imageUrl']}",
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_,__,___) => const Text("Image Load Error", style: TextStyle(fontSize: 10, color: Colors.red)),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.3),
                                            shape: BoxShape.circle
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                             ],

                             if (hop['visionResult'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (hop['visionResult']['isDamaged'] == true) ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: (hop['visionResult']['isDamaged'] == true) ? Colors.red : Colors.green)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Row(
                                         children: [
                                           Icon(
                                             (hop['visionResult']['isDamaged'] == true) 
                                                ? Icons.gpp_bad 
                                                : (hop['visionResult']['reason'].toString().contains("Failed") ? Icons.error_outline : Icons.verified_user),
                                             size: 16,
                                             color: (hop['visionResult']['isDamaged'] == true) 
                                                ? Colors.red 
                                                : (hop['visionResult']['reason'].toString().contains("Failed") ? Colors.grey : Colors.green)
                                           ),
                                           const SizedBox(width: 6),
                                           Text(
                                             (hop['visionResult']['isDamaged'] == true) 
                                                ? "AI Detected Damage" 
                                                : (hop['visionResult']['reason'].toString().contains("Failed") ? "AI Analysis Unavailable" : "Verified Intact"),
                                             style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: (hop['visionResult']['isDamaged'] == true) 
                                                    ? Colors.red 
                                                    : (hop['visionResult']['reason'].toString().contains("Failed") ? Colors.grey : Colors.green)
                                             ),
                                           )
                                         ],
                                       ),
                                       if(hop['visionResult']['reason'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            hop['visionResult']['reason'],
                                            style: TextStyle(fontSize: 11, color: Colors.grey[800])
                                          )
                                       ]
                                    ],
                                  ),
                                )
                             ]
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: (200 * index).ms).slideX();
              },
            ),
            // Add extra space at bottom for FAB
            if(_isRetailer) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified, color: AppTheme.successColor, size: 48),
          const SizedBox(height: 16),
          Text(
            _productData?['productName'] ?? "Authentic Product",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          
          if (_productData != null && _productData!['manufacturerName'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "by ${_productData!['manufacturerName']}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),

          const SizedBox(height: 8),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               borderRadius: BorderRadius.circular(20)
             ),
             child: Text(
               widget.productId,
               style: const TextStyle(color: Colors.white70, fontFamily: 'Courier'),
             ),
          ),
        ],
      ),
    ).animate().scale();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;

  const _InfoRow({
    required this.icon, 
    required this.text,
    this.color,
    this.fontWeight,
    this.fontSize
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(
          text, 
          style: TextStyle(
            color: color ?? Colors.grey[600], 
            fontSize: fontSize ?? 13,
            fontWeight: fontWeight ?? FontWeight.normal
          )
        )),
      ],
    );
  }
}
