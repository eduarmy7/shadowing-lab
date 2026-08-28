import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';

/// 2026-08-28 추가 — 가족 소유 기기(예: 자녀 태블릿)에 스토어 결제 없이 사이드로드할
/// "가족용 광고 없음" 특수 빌드 전용 스위치. 자녀 Google 계정은 Play 결제 자체가
/// 막혀있어 정상적인 "광고 제거" 구매/패밀리 라이브러리 공유가 당장 안 되는 상황이라,
/// 컴파일 시점 플래그로만 켜지는 별도 APK를 만든다 — 일반 빌드(스토어 배포용)는 이
/// 플래그를 안 넘기므로 기본값 false로 항상 실제 구매 여부를 그대로 따른다.
/// 빌드 예: `flutter build apk --release --dart-define=FAMILY_ADS_FREE=true`
const bool _kFamilyAdsFree = bool.fromEnvironment('FAMILY_ADS_FREE');

/// "광고 제거" 구매 상태 스트림 — `settings_screen.dart`의 `learningSettingsProvider`와
/// 동일한 패턴(Repository의 watch* 스트림을 그대로 노출하는 StreamProvider.autoDispose).
/// 배너 게이팅(`tab_scaffold.dart`), 전면 광고 게이팅(`session_summary_screen.dart`),
/// 구매 배너 표시(`my_home_screen.dart`)에서 공통으로 watch한다.
final adsRemovedProvider = StreamProvider.autoDispose<bool>((ref) {
  if (_kFamilyAdsFree) return Stream.value(true);
  return ref.watch(purchaseRepositoryProvider).watchAdsRemoved();
});

/// 구매 완료 시각 — 마이 > 계정 화면 전용.
final purchasedAtProvider = StreamProvider.autoDispose<DateTime?>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchasedAt();
});
