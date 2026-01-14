import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';

class WalletSetupScreen extends ConsumerStatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  ConsumerState<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends ConsumerState<WalletSetupScreen> {
  bool _isLoading = false;
  final TextEditingController _privateKeyController = TextEditingController();

  Future<void> _createWallet() async {
    setState(() => _isLoading = true);
    try {
      final web3 = ref.read(web3ServiceProvider);
      final pk = await web3.createWallet();
      if (mounted) {
        _showSuccessDialog(pk);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String pk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Wallet Created"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Save your private key safely! You won't see it again."),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                pk,
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pk));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
            },
            child: const Text("Copy"),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.pop(); // Close dialog
              final role = GoRouterState.of(context).uri.queryParameters['role'] ?? 'customer';
              context.go('/home?role=$role'); // Go to dashboard
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  Future<void> _importWallet() async {
    final pk = _privateKeyController.text.trim();
    if (pk.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final web3 = ref.read(web3ServiceProvider);
      await web3.importWallet(pk);
      final role = GoRouterState.of(context).uri.queryParameters['role'] ?? 'customer';
      if (mounted) {
        context.go('/home?role=$role');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid Key: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Wallet")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "To interact with the blockchain, you need a wallet.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createWallet,
              icon: const Icon(Icons.add_circle_outline),
              label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Create New Wallet"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR", style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _privateKeyController,
              decoration: const InputDecoration(
                labelText: "Private Key",
                hintText: "Enter existing private key (0x...)",
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
               onPressed: _isLoading ? null : _importWallet,
               child: const Text("Import Wallet"),
               style: OutlinedButton.styleFrom(
                 padding: const EdgeInsets.all(16),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
            ),
          ],
        ),
      ),
    );
  }
}
