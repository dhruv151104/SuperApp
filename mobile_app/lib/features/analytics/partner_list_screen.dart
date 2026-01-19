import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class PartnerListScreen extends ConsumerStatefulWidget {
  const PartnerListScreen({super.key});

  @override
  ConsumerState<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends ConsumerState<PartnerListScreen> {
  bool _isLoading = true;
  List<dynamic> _partners = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPartners();
  }

  Future<void> _fetchPartners() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getAnalyticsPartners();
      if (mounted) {
        setState(() {
          _partners = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Retailer Partners")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text("Error: $_error"));

    if (_partners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No retailer partners found yet.",
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _partners.length,
      itemBuilder: (context, index) {
        final retailer = _partners[index];
        final name = retailer['companyName'] ?? 'Unknown Retailer';
        final volume = retailer['volume'] ?? 0;
        final location = retailer['registeredLocation'] ?? 'Unknown Location';
        final person = retailer['contactPerson'];
        final phone = retailer['contactPhone'];
        final lastActive = retailer['lastActive'] != null
            ? DateTime.fromMillisecondsSinceEpoch(retailer['lastActive'] * 1000)
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.store, color: AppTheme.primaryColor),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              "$volume Products Handled", 
              style: TextStyle(color: Colors.grey[600])
            ),
            trailing: const Icon(Icons.arrow_drop_down),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.location_on, location),
                    if (person != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.person, person),
                    ],
                    if (phone != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.phone, phone),
                    ],
                    if (lastActive != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.history, "Last Active: ${DateFormat('MMM d, y • h:mm a').format(lastActive)}"),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideX();
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
