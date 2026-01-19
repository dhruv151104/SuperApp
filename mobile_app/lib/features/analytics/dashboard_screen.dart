import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getAnalyticsDashboard();
      if (mounted) setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return const Center(child: Text("Failed to load analytics"));

    final total = _stats!['totalProducts'] as int? ?? 0;
    final inTransit = _stats!['productsInTransit'] as int? ?? 0;
    final retailers = _stats!['retailersReached'] as int? ?? 0;
    final recent = _stats!['recentActivity'] as List<dynamic>? ?? [];

    // Simple Distribution Logic
    final unknown = total - inTransit; // Assuming "At Factory" if not transit

    return Scaffold(
      appBar: AppBar(title: const Text("Manufacturer Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(title: "Total Minted", value: "$total", icon: Icons.inventory_2, color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(
                  title: "In Transit", 
                  value: "$inTransit", 
                  icon: Icons.local_shipping, 
                  color: Colors.orange,
                  onTap: () => context.push('/history'),
                )),
              ],
            ),
            const SizedBox(height: 8),
            _StatCard(
              title: "Retailers Reached", 
              value: "$retailers", 
              icon: Icons.store, 
              color: Colors.green,
              onTap: () => context.push('/dashboard/partners'),
            ),
            
            const SizedBox(height: 32),
            Text("Distribution Status", style: AppTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (total > 0)
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: inTransit.toDouble(),
                        color: Colors.orange,
                        title: '$inTransit',
                        radius: 50,
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: unknown.toDouble(),
                        color: Colors.blue.shade300,
                        title: '$unknown',
                        radius: 50,
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(child: Text("No data to chart")),

             if (total > 0)
              Center(
                 child: Wrap(
                   spacing: 16,
                   children: [
                     _Legend(color: Colors.blue.shade300, text: "At Factory"),
                     _Legend(color: Colors.orange, text: "Distributed"),
                   ],
                 )
              ),

            const SizedBox(height: 32),
            Text("Recent Activity", style: AppTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              itemBuilder: (context, index) {
                final item = recent[index];
                final id = item['productId'];
                final hops = item['hops'] as List;
                final lastHop = hops.isNotEmpty ? hops.last : null;
                final status = lastHop != null && lastHop['role'] == "Manufacturer" ? "Minted" : "Moved";
                
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: status == "Minted" ? Colors.blue.shade100 : Colors.orange.shade100,
                      child: Icon(status == "Minted" ? Icons.add : Icons.arrow_forward, size: 16, color: Colors.black87),
                    ),
                    title: Text(item['productName'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("$id • $status", style: const TextStyle(fontSize: 12, fontFamily: 'Courier')),
                    onTap: () => context.push('/product-details/$id'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ).animate().fadeIn(delay: (100 * index).ms);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, color: color),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(fontSize: 12))
  ]);
}
