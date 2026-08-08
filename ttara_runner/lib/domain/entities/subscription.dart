import 'package:equatable/equatable.dart';

enum SubscriptionPlanType { monthly, yearly }

/// #9 구독 결제/관리 화면 상태. `isActive == false`면 Paywall, true면 관리 화면 분기.
class SubscriptionStatus extends Equatable {
  final bool isActive;
  final SubscriptionPlanType? plan;
  final DateTime? nextBillingDate;
  final bool isTrialEligible;

  const SubscriptionStatus({
    required this.isActive,
    this.plan,
    this.nextBillingDate,
    this.isTrialEligible = true,
  });

  static const SubscriptionStatus free = SubscriptionStatus(isActive: false, isTrialEligible: true);

  SubscriptionStatus copyWith({
    bool? isActive,
    SubscriptionPlanType? plan,
    DateTime? nextBillingDate,
    bool? isTrialEligible,
  }) {
    return SubscriptionStatus(
      isActive: isActive ?? this.isActive,
      plan: plan ?? this.plan,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      isTrialEligible: isTrialEligible ?? this.isTrialEligible,
    );
  }

  @override
  List<Object?> get props => [isActive, plan, nextBillingDate, isTrialEligible];
}

/// 가격 정보는 시장 벤치마크 기반 예시안 — store-manager/비즈니스 의사결정에 따라 조정 필요
/// (01_ux_design.md "가정 사항 명시" 참고). 실제 가격은 스토어(App Store Connect/Play
/// Console)에 등록된 값을 api-integrator가 IAP SDK를 통해 동적으로 가져와야 한다.
class SubscriptionPlanOption extends Equatable {
  final SubscriptionPlanType type;
  final String priceLabel;
  final String? discountLabel;
  final bool isRecommended;

  const SubscriptionPlanOption({
    required this.type,
    required this.priceLabel,
    this.discountLabel,
    this.isRecommended = false,
  });

  static const monthly = SubscriptionPlanOption(
    type: SubscriptionPlanType.monthly,
    priceLabel: '월 4,900원',
  );

  static const yearly = SubscriptionPlanOption(
    type: SubscriptionPlanType.yearly,
    priceLabel: '연 39,000원',
    discountLabel: '33%↓',
    isRecommended: true,
  );

  @override
  List<Object?> get props => [type, priceLabel, discountLabel, isRecommended];
}
