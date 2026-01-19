import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/features/home/home_screen.dart';

void main() {
  // Helper to pump widget with size and wait for animations
  Future<void> pumpHome(WidgetTester tester, String role) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeScreen(role: role),
        ),
      ),
    );
    await tester.pumpAndSettle(); // Wait for entry animations
  }

  testWidgets('Manufacturer sees Mint Product', (WidgetTester tester) async {
    await pumpHome(tester, 'manufacturer');

    expect(find.text('Mint Product'), findsOneWidget);
    expect(find.text('Verify Stock'), findsNothing);
  });

  testWidgets('Retailer sees Verify Stock', (WidgetTester tester) async {
    await pumpHome(tester, 'retailer');

    expect(find.text('Verify Stock'), findsOneWidget);
    expect(find.text('Mint Product'), findsNothing);
  });

  testWidgets('Settings tap shows SnackBar', (WidgetTester tester) async {
    await pumpHome(tester, 'customer');

    await tester.tap(find.text('Settings'));
    await tester.pump(); // Start snackbar animation
    await tester.pump(const Duration(milliseconds: 500)); // Wait for it to appear

    expect(find.text('Settings coming soon!'), findsOneWidget);
    
    // Wait for snackbar to disappear or test to end cleanly
    await tester.pumpAndSettle(); 
  });

  testWidgets('Scan History tap shows SnackBar', (WidgetTester tester) async {
    await pumpHome(tester, 'customer');

    await tester.tap(find.text('Scan History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scan History coming soon!'), findsOneWidget);
    
    await tester.pumpAndSettle();
  });
}
