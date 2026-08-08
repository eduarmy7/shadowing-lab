// 스모크 테스트: 앱이 크래시 없이 첫 프레임을 그리는지만 확인한다.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ttara/main.dart';

void main() {
  testWidgets('TtaraApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TtaraApp()));
    await tester.pump();

    expect(find.byType(TtaraApp), findsOneWidget);
  });
}
