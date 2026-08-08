import 'dart:async';
import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';
import '../../core/error/failure.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../local/local_kv_store.dart';

/// 03_api_integration.md 6-3절에 명시된 실제 스토어 구독관리 URL. `{productId}`/
/// `{packageName}`은 실제 IAP 상품 ID/패키지명 확정 후 api-integrator가 채워야 한다.
const _iosSubscriptionManagementUrl = 'https://apps.apple.com/account/subscriptions';
const _androidSubscriptionManagementUrl =
    'https://play.google.com/store/account/subscriptions?sku=ttara_pro&package=com.ttara.app';

const _storageKey = 'ttara.subscription_status.v1';

/// [SubscriptionRepository]의 Fake 구현체 — 실제 스토어 결제 없이 구독 상태를
/// 로컬에 저장해 Paywall(#8)/구독관리(#9) UI 흐름 전체를 데모.
/// api-integrator가 StoreKit/Play Billing + 서버 영수증 검증으로 교체할 대상.
class FakeSubscriptionRepository implements SubscriptionRepository {
  final LocalKvStore _store;
  final _controller = StreamController<SubscriptionStatus>.broadcast();
  SubscriptionStatus? _cache;

  FakeSubscriptionRepository(this._store);

  Future<SubscriptionStatus> _load() async {
    if (_cache != null) return _cache!;
    final loaded = await _store.getJson<SubscriptionStatus>(_storageKey, (decoded) {
      final map = decoded as Map<String, dynamic>;
      return SubscriptionStatus(
        isActive: map['isActive'] as bool,
        plan: map['plan'] == null ? null : SubscriptionPlanType.values.byName(map['plan'] as String),
        nextBillingDate: map['nextBillingDate'] == null ? null : DateTime.parse(map['nextBillingDate'] as String),
        isTrialEligible: map['isTrialEligible'] as bool? ?? true,
      );
    });
    _cache = loaded ?? SubscriptionStatus.free;
    return _cache!;
  }

  Future<void> _persist(SubscriptionStatus status) async {
    _cache = status;
    await _store.setJson(_storageKey, {
      'isActive': status.isActive,
      'plan': status.plan?.name,
      'nextBillingDate': status.nextBillingDate?.toIso8601String(),
      'isTrialEligible': status.isTrialEligible,
    });
    _controller.add(status);
  }

  @override
  Future<SubscriptionStatus> getStatus() => _load();

  @override
  Stream<SubscriptionStatus> watchStatus() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Future<SubscriptionStatus> purchase(SubscriptionPlanType plan) async {
    await Future.delayed(const Duration(milliseconds: 900)); // 스토어 결제 시트 시뮬레이션
    final status = SubscriptionStatus(
      isActive: true,
      plan: plan,
      nextBillingDate: DateTime.now().add(plan == SubscriptionPlanType.monthly
          ? const Duration(days: 30)
          : const Duration(days: 365)),
      isTrialEligible: false,
    );
    await _persist(status);
    return status;
  }

  @override
  Future<SubscriptionStatus> restorePurchases() => _load();

  @override
  Future<void> cancel() async {
    // QA 🔴-4: 앱은 스토어 구독을 직접 취소할 수 없다 — 네이티브 구독 관리 화면으로
    // 딥링크만 시도하고 로컬 isActive는 절대 바꾸지 않는다. 실제 해지 여부는
    // Apple/Google 웹훅을 서버가 받은 뒤에야 알 수 있으며(이 Fake 구현체에는 웹훅이
    // 없으므로), watchStatus()로 관찰되는 상태가 이 호출만으로 바뀌지 않는 것이 정상이다.
    final uri = Uri.parse(Platform.isIOS ? _iosSubscriptionManagementUrl : _androidSubscriptionManagementUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const PurchaseFailure('스토어 구독 관리 화면을 열 수 없어요');
    }
  }
}
