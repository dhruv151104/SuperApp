import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

class MintProductScreen extends ConsumerStatefulWidget {
  const MintProductScreen({super.key});

  @override
  ConsumerState<MintProductScreen> createState() => _MintProductScreenState();
}

class _MintProductScreenState extends ConsumerState<MintProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productIdController = TextEditingController();
  final _productNameController = TextEditingController();
  final _locationController = TextEditingController(); // Manual or Auto
  bool _isLoading = false;
  String? _txHash;
  File? _imageFile;

  bool _locationFetched = false;

  @override
  void initState() {
     super.initState();
     // Auto-generate a UUID for convenience
     _productIdController.text = const Uuid().v4();
     _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationFetched = false);
    _locationController.clear();
    
    // Check service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
         _showLocationDialog(
            "Location Services Disabled", 
            "Please enable location services to mint a product.",
            () async {
               await Geolocator.openLocationSettings();
               _getCurrentLocation(); // Retry
            }
         );
      }
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Location permissions are required."),
               action: SnackBarAction(label: "Retry", onPressed: _getCurrentLocation),
             )
           );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
       if (mounted) {
         _showLocationDialog(
            "Permission Denied", 
            "Location permission is permanently denied. Please enable it in settings.",
            () async {
               await Geolocator.openAppSettings();
               _getCurrentLocation();
            }
         );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if(mounted) {
        setState(() {
           _locationController.text = "${position.latitude}, ${position.longitude}";
           _locationFetched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
      }
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

  Future<void> _pickImage() async {
     try {
       final picker = ImagePicker();
       final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
       if (photo != null) {
          setState(() {
            _imageFile = File(photo.path);
          });
       }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera Error: $e")));
     }
  }


  Future<void> _checkGeofenceAndMint() async {
     // Fetch registered location
     final api = ref.read(apiServiceProvider);
     final profile = await api.getUserProfile();
     final regLoc = profile['registeredLocation'];
     
     if (regLoc != null && _locationController.text.isNotEmpty) {
        try {
          final currentParts = _locationController.text.split(',').map((e) => double.parse(e.trim())).toList();
          final regParts = regLoc.split(',').map((e) => double.parse(e.trim())).toList();
          
          final distance = Geolocator.distanceBetween(
             currentParts[0], currentParts[1], 
             regParts[0], regParts[1]
          ); // in meters

          if (distance > 2) { // 2m threshold (Testing)
             bool proceed = await showDialog(
               context: context, 
               builder: (ctx) => AlertDialog(
                 title: const Text("Geofence Warning"),
                 content: Text("You are ${(distance).toStringAsFixed(1)}m away from your registered factory location.\n\nThis action will be flagged as 'Off-site Minting'."),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                   TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Proceed Anyway", style: TextStyle(color: Colors.red))),
                 ],
               )
             ) ?? false;

             if (!proceed) return;
             // User chose to proceed, so we flag it
             _mintProduct(flags: ["Off-site Minting"]);
             return;
          }
        } catch (e) {
          // Parse error or something, ignore geofence
        }
     }
     _mintProduct();
  }

  Future<void> _mintProduct({List<String>? flags}) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationFetched) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not fetched yet.")));
       return; 
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      // NOTE: Backend generates the ID. We send location.
      final result = await api.createProduct(
          _locationController.text, 
          _productNameController.text, 
          flags: flags,
          imagePath: _imageFile?.path
      );
      
      setState(() {
         _txHash = result['txHash'];
         _productIdController.text = result['productId']; // Backend generated ID
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Minted Successfully!")));
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareQrCode() async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: _productIdController.text,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/product_qr.png';
        final file = File(path);
        
        final picData = await painter.toImageData(875); // 875px size
        await file.writeAsBytes(picData!.buffer.asUint8List());

        await Share.shareXFiles([XFile(path)], text: 'Product ID: ${_productIdController.text}');
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sharing QR: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mint New Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Product Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _productIdController,
                readOnly: true, // ID is auto-generated mostly
                decoration: InputDecoration(
                  labelText: "Product ID (Unique)",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _productIdController.text = const Uuid().v4()),
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: "Product Name (e.g. Nike Air)",
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) => v!.isEmpty ? "Name required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                readOnly: true, // Disable editing
                decoration: InputDecoration(
                  labelText: "Manufacturing Location",
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _locationFetched 
                    ? const Icon(Icons.check, color: Colors.green) 
                    : IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.orange),
                        onPressed: _isLoading ? null : _getCurrentLocation,
                      ),
                ),
                validator: (v) => v!.isEmpty ? "Location required" : null,
              ),
              const SizedBox(height: 16),
              
              // Preview QR
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text("Product QR Code", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: _productIdController.text,
                        version: QrVersions.auto,
                        size: 200.0,
                         // foregroundColor: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _shareQrCode, 
                        icon: const Icon(Icons.share), 
                        label: const Text("Share QR Image")
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text("Visual Condition Reference", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_imageFile == null)
                 InkWell(
                   onTap: _pickImage,
                   child: Container(
                     height: 150,
                     decoration: BoxDecoration(
                       color: Colors.grey[200],
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid)
                     ),
                     child: const Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                           Text("Take Photo of Product", style: TextStyle(color: Colors.grey))
                         ],
                       ),
                     ),
                   ),
                 )
              else 
                 Stack(
                   children: [
                     ClipRRect(
                       borderRadius: BorderRadius.circular(12),
                       child: Image.file(_imageFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
                     ),
                     Positioned(
                       top: 8, right: 8,
                       child: CircleAvatar(
                         backgroundColor: Colors.white,
                         child: IconButton(
                           icon: const Icon(Icons.close, color: Colors.red),
                           onPressed: () => setState(() => _imageFile = null),
                         ),
                       )
                     )
                   ],
                 ),


              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: (_isLoading || !_locationFetched) ? null : _checkGeofenceAndMint,
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check),
                label: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Mint on Blockchain"),
                   style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _locationFetched ? AppTheme.successColor : Colors.grey
                  ),
              ),

              if (_txHash != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 8),
                      const Text("Transaction Confirmed!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      SelectableText("Hash: $_txHash", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.pop(), 
                        child: const Text("Done")
                      )
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
