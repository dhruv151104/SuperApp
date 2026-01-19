import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

class BatchScanScreen extends ConsumerStatefulWidget {
  const BatchScanScreen({super.key});

  @override
  ConsumerState<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends ConsumerState<BatchScanScreen> {
  final List<String> _scannedCodes = [];
  final Set<String> _processedIds = {}; // IDs already handled by this user
  bool _isLoadingHistory = true;
  bool _isSubmitting = false;
  String? _currentLocation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initData();
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

  void _onDetect(BarcodeCapture capture) {
    if (_isSubmitting || _isLoadingHistory) return;
    
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

      if (_scannedCodes.contains(code)) {
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
        // Optional: Error sound?
      } else {
        setState(() {
          _scannedCodes.add(code);
        });
        _audioPlayer.play(AssetSource('sounds/beep.mp3')).catchError((_) {});
      }
    }
  }

  Future<void> _submitBatch() async {
    if (_scannedCodes.isEmpty) return;
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
    final List<String> succeeded = [];

    // Process sequentially
    for (final productId in List.from(_scannedCodes)) {
       try {
         await api.addRetailerHop(productId, _currentLocation!);
         succeeded.add(productId);
         successCount++;
       } catch (e) {
         failCount++;
       }
    }

    setState(() {
      _isSubmitting = false;
      _scannedCodes.removeWhere((id) => succeeded.contains(id));
      _processedIds.addAll(succeeded); // Add to local processed list so we don't rescan immediately
    });
    
    if (mounted) {
       if (failCount == 0 && _scannedCodes.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully processed $successCount items!")));
         Navigator.pop(context);
       } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processed $successCount. Failed $failCount. Please retry failed items.")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Batch Scan (${_scannedCodes.length})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _scannedCodes.isEmpty ? null : () => setState(() => _scannedCodes.clear()),
          )
        ],
      ),
      body: _isLoadingHistory 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          // Camera Preview (Half Screen)
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue, width: 2),
                boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.blueAccent)]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MobileScanner(
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          
          const Divider(),
          
          // List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Pending Submission", style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          
          Expanded(
            flex: 3,
            child: _scannedCodes.isEmpty 
              ? const Center(child: Text("Scan product QR codes..."))
              : ListView.builder(
                  itemCount: _scannedCodes.length,
                  itemBuilder: (context, index) {
                    final code = _scannedCodes[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.qr_code),
                      title: Text(code),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _scannedCodes.removeAt(index)),
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
              onPressed: (_scannedCodes.isEmpty || _isSubmitting) ? null : _submitBatch,
              icon: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload),
              label: Text(_isSubmitting ? "Processing..." : "Submit Batch"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          )
        ],
      ),
    );
  }
}
