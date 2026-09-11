import 'package:flutter_test/flutter_test.dart';
import 'package:huawei_health_export/main.dart';

void main() {
  testWidgets('App renders Home Screen with import UI', (WidgetTester tester) async {
    await tester.pumpWidget(const HuaweiHealthExportApp());
    await tester.pumpAndSettle();

    expect(find.text('Huawei Exporter'), findsOneWidget);
    expect(find.text('Import Huawei Data'), findsOneWidget);
    expect(find.text('Select Huawei Data ZIP'), findsOneWidget);
  });
}
