import 'package:flutter_test/flutter_test.dart';
import 'package:signature_addon/main.dart';

void main() {
  testWidgets('Dashboard renders app title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the dashboard title is rendered.
    expect(find.text('פשוט לחתום'), findsOneWidget);
  });
}
