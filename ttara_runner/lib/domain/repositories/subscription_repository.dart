import 'dart:async';

import '../entities/subscription.dart';

/// **api-integrator에게 전달되는 인터페이스.** 인앱 구독(PRO) + 스토어 영수증 검증.
///
/// 실제 구현은 클라이언트 스토어 SDK(StoreKit/Play Billing, 또는 `in_app_purchase`
/// 패키지)로 구매를 시작하고, 영수증을 서버로 보내 `POST /subscription/verify`로
/// 검증하는 2단계 흐름이 된다. 이 인터페이스는 그 전체 흐름을 하나의 메서드로
/// 추상화해 UI(#8 Paywall, #9 구독관리)가 구현 세부사항을 몰라도 되게 한다.
abstract class SubscriptionRepository {
  Future<SubscriptionStatus> getStatus();
  Stream<SubscriptionStatus> watchStatus();

  /// 구매 흐름 시작(스토어 결제 UI 표시 → 영수증 서버 검증까지 포함).
  /// 실패 시 [PurchaseFailure]를 던진다(#9 화면 인라인 에러 + 재시도).
  Future<SubscriptionStatus> purchase(SubscriptionPlanType plan);

  Future<SubscriptionStatus> restorePurchases();

  /// **주의 — 즉시 해지가 아니다.** iOS/Android 모두 서드파티 앱이 스토어 구독을
  /// 프로그래밍적으로 취소하는 API를 제공하지 않는다(03_api_integration.md 6-3절).
  /// 이 메서드는 네이티브 구독 관리 화면으로 **딥링크**만 시도한다:
  /// iOS `https://apps.apple.com/account/subscriptions`,
  /// Android `https://play.google.com/store/account/subscriptions?sku={productId}&package={packageName}`.
  /// 호출 후에도 [SubscriptionStatus.isActive]는 바뀌지 않는다 — 실제 해지 완료 여부는
  /// 이후 Apple/Google 웹훅을 서버가 수신해 반영하고, 클라이언트는 [watchStatus] 폴링으로
  /// 뒤늦게 알게 된다. 딥링크 자체를 열지 못한 경우에만 [PurchaseFailure]를 던진다.
  /// UI(#9)는 "해지 완료"가 아니라 "스토어 화면으로 이동합니다"로 문구를 맞춰야 한다.
  Future<void> cancel();
}
