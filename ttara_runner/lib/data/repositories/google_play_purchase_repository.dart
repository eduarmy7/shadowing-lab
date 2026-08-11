import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/error/failure.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.ads_removed.v1';
const _purchasedAtStorageKey = 'ttara.ads_removed_at.v1';

/// [PurchaseRepository]의 실제 Google Play Billing 구현체 — 2026-08-11부터
/// `FakePurchaseRepository`(로컬 시뮬레이션)를 대체한다.
///
/// **알려진 한계**: 이 앱은 서버가 없는 로컬 우선 구조라 영수증의 서버측 재검증을
/// 하지 않는다. `PurchaseDetails.verificationData`는 받아두지만, 스토어가 돌려준
/// `purchased`/`restored` 상태를 그대로 신뢰한다 — 광고 제거 1개 상품(저가, 비소모성)
/// 규모에는 합리적인 트레이드오프이나 결제 부정사용에 완전히 안전하지는 않다. 서버가
/// 생기면 `verificationData.serverVerificationData`를 서버로 보내 Google Play
/// Developer API로 재검증하는 절차를 추가해야 한다.
class GooglePlayPurchaseRepository implements PurchaseRepository {
  final LocalKvStore _store;
  final InAppPurchase _iap = InAppPurchase.instance;
  final _controller = StreamController<bool>.broadcast();
  final _purchasedAtController = StreamController<DateTime?>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  bool? _cache;
  DateTime? _purchasedAtCache;
  bool _purchasedAtLoaded = false;

  // purchaseRemoveAds()/restorePurchases() 호출이 실제로 끝나는 시점은
  // buyNonConsumable()의 반환값(구매 "시작" 성공 여부)이 아니라, 나중에 비동기로
  // 도착하는 purchaseStream 이벤트다 — 이 Completer로 그 간극을 잇는다.
  Completer<void>? _pendingPurchase;

  GooglePlayPurchaseRepository(this._store) {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object _) {
        _pendingPurchase?.completeError(const PurchaseFailure());
        _pendingPurchase = null;
      },
    );
  }

  void dispose() => _subscription.cancel();

  Future<bool> _load() async {
    if (_cache != null) return _cache!;
    final loaded = await _store.getJson<bool>(_storageKey, (decoded) => decoded as bool);
    _cache = loaded ?? false;
    return _cache!;
  }

  Future<DateTime?> _loadPurchasedAt() async {
    if (_purchasedAtLoaded) return _purchasedAtCache;
    final loaded = await _store.getJson<String>(_purchasedAtStorageKey, (decoded) => decoded as String);
    _purchasedAtCache = loaded == null ? null : DateTime.tryParse(loaded);
    _purchasedAtLoaded = true;
    return _purchasedAtCache;
  }

  Future<void> _persist(bool adsRemoved, {DateTime? purchasedAt}) async {
    _cache = adsRemoved;
    await _store.setJson(_storageKey, adsRemoved);
    _controller.add(adsRemoved);

    if (purchasedAt != null) {
      _purchasedAtCache = purchasedAt;
      _purchasedAtLoaded = true;
      await _store.setJson(_purchasedAtStorageKey, purchasedAt.toIso8601String());
      _purchasedAtController.add(purchasedAt);
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != PurchaseRepository.adRemovalProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _persist(true, purchasedAt: DateTime.now());
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _pendingPurchase?.complete();
          _pendingPurchase = null;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _pendingPurchase?.completeError(PurchaseFailure(purchase.error?.message ?? '결제 처리에 실패했어요'));
          _pendingPurchase = null;
        case PurchaseStatus.canceled:
          _pendingPurchase?.completeError(const PurchaseFailure('결제를 취소했어요'));
          _pendingPurchase = null;
      }
    }
  }

  @override
  Stream<bool> watchAdsRemoved() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Stream<DateTime?> watchPurchasedAt() async* {
    yield await _loadPurchasedAt();
    yield* _purchasedAtController.stream;
  }

  @override
  Future<void> purchaseRemoveAds() async {
    final available = await _iap.isAvailable();
    if (!available) throw const PurchaseFailure('스토어에 연결할 수 없어요. 잠시 후 다시 시도해주세요');

    final response = await _iap.queryProductDetails({PurchaseRepository.adRemovalProductId});
    if (response.error != null || response.productDetails.isEmpty) {
      throw const PurchaseFailure('상품 정보를 불러오지 못했어요');
    }

    final completer = Completer<void>();
    _pendingPurchase = completer;
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
    if (!started) {
      _pendingPurchase = null;
      throw const PurchaseFailure();
    }
    return completer.future;
  }

  @override
  Future<void> restorePurchases() async {
    final completer = Completer<void>();
    _pendingPurchase = completer;
    await _iap.restorePurchases();
    // 복원할 구매 이력이 없으면 스토어가 아무 이벤트도 보내지 않을 수 있다 — 무한
    // 대기를 막기 위해 짧은 타임아웃 후 조용히 끝낸다. 호출부(`ad_removal_sheet.dart`)는
    // 이후 watchAdsRemoved()로 실제 복원 여부를 다시 확인해서 "복원할 구매가 없어요"를
    // 보여주므로, 타임아웃 자체를 에러로 취급할 필요는 없다.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => _pendingPurchase = null,
    );
  }
}
