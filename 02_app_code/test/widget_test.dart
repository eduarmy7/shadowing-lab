import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttara/main.dart';

/// 스모크 테스트 — 앱이 크래시 없이 첫 프레임(온보딩 화면)을 그리는지 확인한다.
/// QA 엔지니어 전달 사항: 화면별 상세 위젯/골든 테스트는 각 컨트롤러 단위테스트와
/// 함께 추가 예정(우선순위: ShadowingController 상태 전이, SegmentationReviewController
/// 경계 조정/병합/분리 로직).
void main() {
  testWidgets('앱 최초 실행 시 온보딩 화면이 표시된다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: TtaraApp()));
    await tester.pump();

    expect(find.text('건너뛰기'), findsOneWidget);
  });
}
