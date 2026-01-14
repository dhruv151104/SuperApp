import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.verified_user_outlined, size: 64, color: AppTheme.primaryColor)
                  .animate().fadeIn(duration: 600.ms).scale(),
              const SizedBox(height: 24),
              Text(
                "Supply Chain Trust",
                textAlign: TextAlign.center,
                style: AppTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ).animate().fadeIn(delay: 200.ms).moveY(begin: 20, end: 0),
              const SizedBox(height: 12),
              Text(
                "Verify authenticity and track product journey on the blockchain.",
                textAlign: TextAlign.center,
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
              const Spacer(),
              
              _RoleCard(
                title: "Manufacturer",
                subtitle: "Create & Mint Products",
                icon: Icons.factory_outlined,
                color: Colors.blueAccent,
                onTap: () => context.push('/login'),
                delay: 600.ms,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: "Retailer",
                subtitle: "Verify & Add Hops",
                icon: Icons.store_mall_directory_outlined,
                color: Colors.orangeAccent,
                onTap: () => context.push('/login'),
                delay: 700.ms,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: "Customer",
                subtitle: "Scan & Verify History",
                icon: Icons.qr_code_scanner_rounded,
                color: Colors.green,
                onTap: () => context.push('/home?role=customer'),
                delay: 800.ms,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Duration delay;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).moveX(begin: 20, end: 0);
  }
}
