import 'package:go_router/go_router.dart';
import 'package:product_traceability_mobile/features/auth/role_selection_screen.dart';
import 'package:product_traceability_mobile/features/auth/login_screen.dart';
import 'package:product_traceability_mobile/features/auth/register_screen.dart';
import 'package:product_traceability_mobile/features/home/home_screen.dart';
import 'package:product_traceability_mobile/features/manufacturer/mint_product_screen.dart';
import 'package:product_traceability_mobile/features/product/scan_screen.dart';
import 'package:product_traceability_mobile/features/product/product_details_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'customer';
        return HomeScreen(role: role);
      },
    ),
    GoRoute(
      path: '/mint-product',
      builder: (context, state) => const MintProductScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/product-details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProductDetailsScreen(productId: id);
      },
    ),
  ],
);
