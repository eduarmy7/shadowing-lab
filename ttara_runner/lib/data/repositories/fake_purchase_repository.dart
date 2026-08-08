import 'dart:async';

import '../../domain/repositories/purchase_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.ads_removed.v1';

/// [PurchaseRepository]의 Fake 구현체 — 실제 스토어 결제 없이 "광고 제거" 구매 상태를
/// 로컬에 저장해 구매 시트/배너 게이팅 흐름 전체를 데모.
/// api-integrator가 StoreKit/Play Billing + 서버 영수증 검증으로 교체할 대상.
/// (구 `FakeSubscriptionRepository`와 동일한 LocalKvStore 기반 패턴을 그대로 따른다.)
class FakePurchaseRepository implements PurchaseRepository {
  final LocalKvStore _store;
  final _controller = StreamController<bool>.broadcast();
  bool? _cache;

  FakePurchaseRepository(this._store);

  Future<bool> _load() async {
    if (_cache != null) return _cache!;
    final loaded = await _store.getJson<bool>(_storageKey, (decoded) => decoded as bool);
    _cache = loaded ?? false;
    return _cache!;
  }

  Future<void> _persist(bool adsRemoved) async {
    _cache = adsRemoved;
    await _store.setJson(_storageKey, adsRemoved);
    _controller.add(adsRemoved);
  }

  @override
  Stream<bool> watchAdsRemoved() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Future<void> purchaseRemoveAds() async {
    await Future.delayed(const Duration(milliseconds: 900)); // 스토어 결제 시트 시뮬레이션
    await _persist(true);
  }

  @override
  Future<void> restorePurchases() async {
    await Future.delayed(const Duration(milliseconds: 500)); // 스토어 복원 흐름 시뮬레이션
    await _load();
  }
}
