import 'package:flutter_test/flutter_test.dart';

import 'package:adola/app/adola_app.dart';

void main() {
  testWidgets('渲染 iOS 主标签栏', (WidgetTester tester) async {
    await tester.pumpWidget(const AdolaApp());
    await tester.pumpAndSettle();

    expect(find.text('书架'), findsNWidgets(2));
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('书源'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
