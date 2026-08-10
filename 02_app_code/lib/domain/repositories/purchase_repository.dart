import 'dart:async';

/// **api-integrator에게 전달되는 인터페이스.** 광고 제거 단발성 구매(인앱 결제) +
/// 스토어 영수증 검증.
///
/// 실제 구현은 클라이언트 스토어 SDK(StoreKit/Play Billing, 또는 `in_app_purchase`
/// 패키지)로 구매를 시작하고, 영수증을 서버로 보내 검증하는 흐름이 된다. 기존
/// `SubscriptionRepository`(2026-08-08 제거 — PRO 구독/라이브러리는 별도 앱으로
/// 분리됨)와 동일한 구매/복원 분리 원칙을 그대로 따른다 — [purchaseRemoveAds]와
/// [restorePurchases]를 하나로 합치지 않는다. 실제 StoreKit/Play Billing에서도
/// "새로 구매"와 "이미 구매한 내역 복원"은 서로 다른 API 호출이기 때문이다.
abstract class PurchaseRepository {
  /// 광고 제거 단발성 상품 ID. 실제 App Store Connect/Play Console 등록 시
  /// 이 상수를 그대로 상품 ID로 사용한다.
  static const adRemovalProductId = 'com.shadowinglab.remove_ads';

  Stream<bool> watchAdsRemoved();

  /// 구매 완료 시각 — 마이 > 계정(#12-계정) 화면에서 "2026년 8월 10일에 구매" 같은
  /// 표시에 쓰인다. 구매 전이거나 복원 이력이 없으면 null.
  Stream<DateTime?> watchPurchasedAt();

  /// 구매 흐름 시작(스토어 결제 UI 표시 → 영수증 서버 검증까지 포함).
  /// 실패 시 [PurchaseFailure]를 던진다(구매 시트 인라인 에러 + 재시도).
  Future<void> purchaseRemoveAds();

  /// 이미 구매한 내역을 복원한다(기기 변경/재설치 시나리오). [purchaseRemoveAds]와
  /// 별개의 스토어 API를 호출하는 실제 흐름을 그대로 반영한다.
  Future<void> restorePurchases();
}
