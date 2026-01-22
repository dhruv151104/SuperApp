import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_animate/flutter_animate.dart';

class ScanItem {
  final String id;
  final String? imagePath;
  ScanItem(this.id, [this.imagePath]);
}

class BatchScanScreen extends ConsumerStatefulWidget {
  const BatchScanScreen({super.key});

  @override
  ConsumerState<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends ConsumerState<BatchScanScreen> {
  final List<ScanItem> _scannedItems = [];
  final Set<String> _processedIds = {}; // IDs already handled by this user
  bool _isLoadingHistory = true;
  bool _isSubmitting = false;
  String? _currentLocation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Visual Audit
  bool _auditMode = false;
  bool _isPausingForImage = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _fetchLocation(),
      _fetchHistory(),
    ]);
  }

  Future<void> _fetchHistory() async {
    try {
      final api = ref.read(apiServiceProvider);
      final history = await api.getUserHistory();
      if (mounted) {
        setState(() {
          _processedIds.addAll(history.map((e) => e['productId'].toString()));
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if(mounted) setState(() => _currentLocation = "${position.latitude}, ${position.longitude}");
    } catch (e) {
      // Handle location error or default
    }
  }

  DateTime? _lastScanTime;
  String? _lastScannedCode;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isSubmitting || _isLoadingHistory || _isPausingForImage) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code == null || !code.startsWith("PROD-")) continue;

      // Debounce
      if (code == _lastScannedCode && 
          _lastScanTime != null && 
          DateTime.now().difference(_lastScanTime!) < const Duration(seconds: 2)) {
        return;
      }

      _lastScannedCode = code;
      _lastScanTime = DateTime.now();

      if (_scannedItems.any((i) => i.id == code)) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
            content: Text("Item is already in pending list!", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      } else if (_processedIds.contains(code)) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text("Item '$code' verified before!", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        // Valid Scan
        _audioPlayer.play(AssetSource('sounds/beep.mp3')).catchError((_) {});
        
        if (_auditMode) {
           setState(() => _isPausingForImage = true);
           //_scannerController.stop(); // Optional, but prevents background scans
           
           // Prompt for image
           final picker = ImagePicker();
           try {
              // Ask user effectively
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Takes photo for analysis..."), duration: Duration(seconds: 1)));
              final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
              String? path = photo?.path;
              
              if (mounted) {
                 setState(() {
                   _scannedItems.add(ScanItem(code, path));
                   _isPausingForImage = false;
                 });
                 //_scannerController.start();
              }
           } catch(e) {
              if (mounted) setState(() => _isPausingForImage = false);
           }
        } else {
           setState(() {
             _scannedItems.add(ScanItem(code));
           });
        }
      }
      break; // Process one code at a time per frame
    }
  }

  Future<void> _submitBatch() async {
    if (_scannedItems.isEmpty) return;
    if (_currentLocation == null) {
       await _fetchLocation();
       if (_currentLocation == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location required for submission")));
         return;
       }
    }

    setState(() => _isSubmitting = true);
    final api = ref.read(apiServiceProvider);
    
    int successCount = 0;
    int failCount = 0;
    final List<ScanItem> succeeded = [];

    // Process sequentially
    for (final item in List.from(_scannedItems)) {
       try {
         await api.addRetailerHop(item.id, _currentLocation!, imagePath: item.imagePath);
         succeeded.add(item);
         successCount++;
       } catch (e) {
         failCount++;
       }
    }

    setState(() {
      _isSubmitting = false;
      _scannedItems.removeWhere((i) => succeeded.contains(i));
      _processedIds.addAll(succeeded.map((i) => i.id));
    });
    
    if (mounted) {
       if (failCount == 0 && _scannedItems.isEmpty) {
         _showResultDialog(true, "Successfully processed $successCount items!");
       } else {
         _showResultDialog(false, "Processed $successCount. Failed $failCount.\nPlease retry failed items.");
       }
    }
  }

  void _showResultDialog(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? Colors.green : Colors.red,
              size: 64,
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              success ? "Success!" : "Issues Found",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (success && !_auditMode) Navigator.pop(context); // Exit screen if done
                },
                child: const Text("OK", style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Batch Scan (${_scannedItems.length})"),
        actions: [
          // Audit Mode Toggle
          Row(
            children: [
               const Text("Visual Check", style: TextStyle(fontSize: 12)),
               Switch(
                 value: _auditMode, 
                 onChanged: (v) => setState(() => _auditMode = v),
                 activeColor: Colors.purpleAccent,
               )
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _scannedItems.isEmpty ? null : () => setState(() => _scannedItems.clear()),
          )
        ],
      ),
      body: _isLoadingHistory 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _auditMode ? Colors.purpleAccent : Colors.blue, width: 3),
                boxShadow: [BoxShadow(blurRadius: 10, color: _auditMode ? Colors.purple.withOpacity(0.5) : Colors.blueAccent)]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          
          if (_auditMode) 
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text("🔎 Compliance Mode: You will be prompted to photo every item.", style: TextStyle(color: Colors.purple, fontSize: 12)),
            ),

          const Divider(),
          
          // List
          Expanded(
            flex: 3,
            child: _scannedItems.isEmpty 
              ? const Center(child: Text("Scan product QR codes..."))
              : ListView.builder(
                  itemCount: _scannedItems.length,
                  itemBuilder: (context, index) {
                    final item = _scannedItems[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.qr_code),
                      title: Text(item.id),
                      subtitle: item.imagePath != null 
                          ? Row(children: [Icon(Icons.image, size: 14, color: Colors.green), SizedBox(width: 4), Text("Image Attached", style: TextStyle(color: Colors.green, fontSize: 12))])
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _scannedItems.removeAt(index)),
                      ),
                    );
                  },
                ),
          ),
          
          // Button
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_scannedItems.isEmpty || _isSubmitting) ? null : _submitBatch,
              icon: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload),
              label: Text(_isSubmitting ? "Processing..." : "Submit Batch"),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _auditMode ? Colors.purple : null
              ),
            ),
          )
        ],
      ),
    );
  }
}
