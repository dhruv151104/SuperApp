import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:product_traceability_mobile/core/providers.dart';
import 'package:product_traceability_mobile/core/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String role; // "manufacturer", "retailer", "customer"
  const HomeScreen({super.key, this.role = "customer"});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _email;
  String? _role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    // For simplicity, we decode JWT or just store email/role separate on login.
    // Let's assume we just stored role in storage on login. 
    // Ideally we should decode JWT here or fetch /me.
    // But since ApiService stores 'user_role', lets use that.
    final role = await storage.read(key: 'user_role');
    
    if (mounted) {
      setState(() {
        _role = role;
        _isLoading = false;
      });
    }
  }
  
  void _onScan() {
    context.push('/scanner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              // Show User Card if logged in, else nothing/login prompt
              if (_role != null) _buildUserCard(),
              if (_role == null && widget.role != 'customer') 
                   _buildLoginPrompt(),
              const SizedBox(height: 32),
              Text(
                "Quick Actions",
                style: AppTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildActionGrid(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onScan,
        label: const Text("Scan QR"),
        icon: const Icon(Icons.qr_code_scanner),
        backgroundColor: AppTheme.primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, ${_role?.toUpperCase() ?? widget.role.toUpperCase()}",
              style: AppTheme.textTheme.labelLarge?.copyWith(color: Colors.grey),
            ),
            Text(
              "Welcome Back",
              style: AppTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        CircleAvatar(
          backgroundColor: Colors.white,
          radius: 24,
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await ref.read(apiServiceProvider).logout();
              if (mounted) context.go('/');
            },
          ),
        ),
      ],
    ).animate().fadeIn().slideX(begin: -0.2);
  }

  Widget _buildLoginPrompt() {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(Icons.login, color: Colors.blue),
        title: const Text("Not Logged In"),
        subtitle: const Text("Tap to Login"),
        onTap: () => context.go('/login'),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Logged in as", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(
            _role ?? "User",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildActionGrid() {
    // Prefer _role (from backend) if available, else widget.role
    final currentRole = (_role ?? widget.role).toLowerCase();
    
    final actions = [
      if (currentRole == 'manufacturer')
        _ActionItem(
          title: "Mint Product",
          icon: Icons.add_box_outlined,
          color: Colors.blue,
          onTap: () => context.push('/mint-product'), 
        ),
      if (currentRole == 'retailer')
        _ActionItem(
          title: "Verify Stock",
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
          onTap: () {}, // TODO: Scanner handles this
        ),
      _ActionItem(
        title: "Scan History",
        icon: Icons.history,
        color: Colors.purple,
        onTap: () {},
      ),
      _ActionItem(
        title: "Settings",
        icon: Icons.settings_outlined,
        color: Colors.grey,
        onTap: () {},
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return actions[index].animate().fadeIn(delay: (100 * index).ms).scale();
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
             BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.secondaryColor
              ),
            ),
          ],
        ),
      ),
    );
  }
}
