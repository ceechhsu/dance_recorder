import 'package:flutter_test/flutter_test.dart';
import 'package:dance_recorder/main.dart';

void main() {
  testWidgets('Smoke test for DanceRecorderApp', (WidgetTester tester) async {
    // Pump the DanceRecorderApp widget into the widget tree.
    await tester.pumpWidget(const DanceRecorderApp());

    // Look for the "Select Videos" text that appears in the VideoSelectionPage AppBar.
    expect(find.text('Select Videos'), findsOneWidget);
  });
}
