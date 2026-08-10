import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';

/// "광고 제거" 구매 상태 스트림 — `settings_screen.dart`의 `learningSettingsProvider`와
/// 동일한 패턴(Repository의 watch* 스트림을 그대로 노출하는 StreamProvider.autoDispose).
/// 배너 게이팅(`tab_scaffold.dart`), 전면 광고 게이팅(`session_summary_screen.dart`),
/// 구매 배너 표시(`my_home_screen.dart`)에서 공통으로 watch한다.
final adsRemovedProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchAdsRemoved();
});

/// 구매 완료 시각 — 마이 > 계정 화면 전용.
final purchasedAtProvider = StreamProvider.autoDispose<DateTime?>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchasedAt();
});
