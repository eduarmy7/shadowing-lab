import 'dart:async';

import '../../domain/repositories/purchase_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.ads_removed.v1';
const _purchasedAtStorageKey = 'ttara.ads_removed_at.v1';

/// [PurchaseRepository]의 Fake 구현체 — 실제 스토어 결제 없이 "광고 제거" 구매 상태를
/// 로컬에 저장해 구매 시트/배너 게이팅 흐름 전체를 데모.
/// api-integrator가 StoreKit/Play Billing + 서버 영수증 검증으로 교체할 대상.
/// (구 `FakeSubscriptionRepository`와 동일한 LocalKvStore 기반 패턴을 그대로 따른다.)
class FakePurchaseRepository implements PurchaseRepository {
  final LocalKvStore _store;
  final _controller = StreamController<bool>.broadcast();
  final _purchasedAtController = StreamController<DateTime?>.broadcast();
  bool? _cache;
  DateTime? _purchasedAtCache;
  bool _purchasedAtLoaded = false;

  FakePurchaseRepository(this._store);

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
    await Future.delayed(const Duration(milliseconds: 900)); // 스토어 결제 시트 시뮬레이션
    await _persist(true, purchasedAt: DateTime.now());
  }

  @override
  Future<void> restorePurchases() async {
    await Future.delayed(const Duration(milliseconds: 500)); // 스토어 복원 흐름 시뮬레이션
    final wasRemoved = await _load();
    // 실제 스토어 복원은 영수증에 찍힌 원 구매 시각을 돌려주지만, Fake 구현체는 로컬에
    // 저장된 값이 없으면(예: 재설치) 알 방법이 없다 — 이미 알고 있으면 그대로 두고,
    // 복원으로 처음 true가 됐는데 시각이 없다면 지금 시각으로 대체 표시한다.
    if (wasRemoved && _purchasedAtCache == null) {
      await _persist(true, purchasedAt: DateTime.now());
    }
  }
}
