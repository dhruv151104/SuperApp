import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanned = false; // Prevent multiple scans
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isScanned || _isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isScanned = true;
          _isProcessing = true;
        });
        
        final productId = barcode.rawValue!;
        
        // check role
        const storage = FlutterSecureStorage();
        final role = await storage.read(key: 'user_role');
        
        if (role == 'retailer') {
           // We need to fetch location before submitting
           try {
             await _fetchLocationAndSubmit(productId);
           } catch(e) {
             if(mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
               setState(() => _isProcessing = false); // Allow retry? or manual entry
             }
           }
        } else {
           if(mounted) context.pushReplacement('/product-details/$productId');
        }
        return;
      }
    }
  }

  Future<void> _fetchLocationAndSubmit(String productId) async {
    // Check service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
         _showLocationDialog(
            "Location Services Disabled", 
            "Please enable location services to verify this product.",
            () async {
               await Geolocator.openLocationSettings();
               // User needs to rescan or we could retry, but rescan is safer flow
               setState(() => _isProcessing = false); 
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
         throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
       if (mounted) {
         _showLocationDialog(
            "Permission Denied", 
            "Location permission is permanently denied. Please enable it in settings.",
            () async {
               await Geolocator.openAppSettings();
               setState(() => _isProcessing = false);
            }
         );
      }
      return;
    }

    // Get Location
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    final locationString = "${position.latitude}, ${position.longitude}";

    // Geofence Check
    final api = ref.read(apiServiceProvider);
    final profile = await api.getUserProfile();
    final regLoc = profile['registeredLocation'];

    if (regLoc != null) {
       try {
          final regParts = regLoc.split(',').map((e) => double.parse(e.trim())).toList();
          final distance = Geolocator.distanceBetween(
             position.latitude, position.longitude, 
             regParts[0], regParts[1]
          ); // in meters
          
          if (distance > 2) { // 2m threshold (Testing)
             if (mounted) {
               bool proceed = await showDialog(
                 context: context, 
                 builder: (ctx) => AlertDialog(
                   title: const Text("Geofence Warning"),
                   content: Text("You are ${(distance).toStringAsFixed(1)}m away from your registered store location."),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                     TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Proceed", style: TextStyle(color: Colors.red))),
                   ],
                 )
               ) ?? false;
               if (!proceed) {
                 setState(() => _isProcessing = false);
                 return;
               }
               // Proceed with flag
               await api.addRetailerHop(productId, locationString, flags: ["Off-site Scan"]);
               _onSuccess(locationString);
               return;
             }
          }
       } catch (e) {
         // ignore
       }
    }

    // Call API (clean)
    await api.addRetailerHop(productId, locationString);
    _onSuccess(locationString);
  }

  void _onSuccess(String loc) {
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text("Retailer Hop Added at $loc"),
           backgroundColor: Colors.green,
         )
       );
       context.pop(); // Return to home
    }
  }

  void _showLocationDialog(String title, String message, VoidCallback onAction) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () { 
            Navigator.pop(ctx);
            setState(() => _isProcessing = false); // Reset processing on cancel
          }, child: const Text("Cancel")),
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
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Product QR")),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (_isProcessing)
             Container(
               color: Colors.black54,
               child: const Center(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     CircularProgressIndicator(),
                     SizedBox(height: 16),
                     Text("Processing Location...", style: TextStyle(color: Colors.white))
                   ],
                 )
               ),
             ),
             
          if (!_isProcessing)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Align QR code within the frame",
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                ),
              ),
            )
        ],
      ),
    );
  }
}
