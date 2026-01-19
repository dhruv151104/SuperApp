import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_traceability_mobile/main.dart';
import 'package:product_traceability_mobile/features/auth/role_selection_screen.dart';

void main() {
  testWidgets('App starts and shows RoleSelectionScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Verify that RoleSelectionScreen is shown
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
  });
}
