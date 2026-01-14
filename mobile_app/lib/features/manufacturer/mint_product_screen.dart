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

class MintProductScreen extends ConsumerStatefulWidget {
  const MintProductScreen({super.key});

  @override
  ConsumerState<MintProductScreen> createState() => _MintProductScreenState();
}

class _MintProductScreenState extends ConsumerState<MintProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productIdController = TextEditingController();
  final _locationController = TextEditingController(); // Manual or Auto
  bool _isLoading = false;
  String? _txHash;

  @override
  void initState() {
     super.initState();
     // Auto-generate a UUID for convenience
     _productIdController.text = const Uuid().v4();
     _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // Basic Permissions Check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if(mounted) {
        _locationController.text = "${position.latitude}, ${position.longitude}";
      }
    } catch (e) {
      // debugPrint("Error getting location: $e");
    }
  }

  Future<void> _mintProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      // NOTE: Backend generates the ID. We send location.
      final result = await api.createProduct(_locationController.text);
      
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
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Manufacturing Location",
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
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
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _mintProduct,
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check),
                label: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Mint on Blockchain"),
                   style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.successColor
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
