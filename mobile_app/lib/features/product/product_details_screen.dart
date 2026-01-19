import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:product_traceability_mobile/features/product/widgets/product_map.dart';

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

  Future<void> _checkRole() async {
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role');
    if (mounted) setState(() => _isRetailer = role == 'Retailer');
  }

  Future<void> _verifyProduct() async {
    setState(() => _isVerifying = true);
    try {
      // Check service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
           _showLocationDialog(
              "Location Services Disabled", 
              "Please enable location services to verify this product.",
              () async {
                 await Geolocator.openLocationSettings();
                 // User can try again manually
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
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
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
              }
           );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final location = "${position.latitude}, ${position.longitude}";
      
      final api = ref.read(apiServiceProvider);
      await api.addRetailerHop(widget.productId, location);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Product Verified at $location!")));
      }
      _fetchDetails(); // Refresh
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
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

    return Scaffold(
      appBar: AppBar(title: const Text("Product Traceability")),
      floatingActionButton: _isRetailer 
        ? FloatingActionButton.extended(
            onPressed: _isVerifying ? null : _verifyProduct,
            label: _isVerifying ? const Text("Verifying...") : const Text("Verify & Receive"),
            icon: const Icon(Icons.check_circle_outline),
            backgroundColor: Colors.orange,
          )
        : null,
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
          const Text(
            "Authentic Product",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
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
