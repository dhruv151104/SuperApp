import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, String?>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final api = ref.read(apiServiceProvider);
    final profile = await api.getUserProfile();
    if(mounted) setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile & Settings")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompanyCard(),
                const SizedBox(height: 32),
                const Text("Contact Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildInfoTile(Icons.person, "Contact Person", _profile?['contactPerson']),
                _buildInfoTile(Icons.phone, "Phone", _profile?['contactPhone']),
                _buildInfoTile(Icons.store, "Registered Location", _profile?['registeredLocation']),
                _buildInfoTile(Icons.badge, "License ID", _profile?['licenseId']),
              ],
            ),
          ),
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               CircleAvatar(
                 backgroundColor: Colors.white24,
                 child: Icon(Icons.business, color: Colors.white),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       _profile?['companyName'] ?? "Company Name",
                       style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                     ),
                     Text(
                       _profile?['role'] ?? "Role",
                       style: const TextStyle(color: Colors.white70),
                     ),
                   ],
                 ),
               )
             ],
           ),
           const SizedBox(height: 24),
           const Text("Wallet Address (Digital ID)", style: TextStyle(color: Colors.white60, fontSize: 12)),
           const SizedBox(height: 4),
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: Colors.black12,
               borderRadius: BorderRadius.circular(8)
             ),
             child: Row(
               children: [
                 const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     _profile?['walletAddress'] ?? "Unknown",
                     style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 12),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ],
             ),
           )
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10)
            ),
            child: Icon(icon, color: Colors.grey.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(value ?? "Not set", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
