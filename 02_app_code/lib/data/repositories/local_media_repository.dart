import 'dart:async';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.media_items.v1';

/// [MediaRepository]의 로컬 구현체. 홈 탭(#1) "내 파일" 데이터는 100% 기기 로컬이라
/// (오프라인 지원 범위: 이미 분석 완료된 내 파일은 완전 오프라인 학습 가능) 이 구현으로 충분.
class LocalMediaRepository implements MediaRepository {
  final LocalKvStore _store;
  final _controller = StreamController<List<MediaItem>>.broadcast();
  List<MediaItem>? _cache;

  LocalMediaRepository(this._store);

  Future<List<MediaItem>> _load() async {
    if (_cache != null) return _cache!;
    final list = await _store.getJson<List<MediaItem>>(
      _storageKey,
      (decoded) =>
          (decoded as List).map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
    _cache = list ?? [];
    return _cache!;
  }

  Future<void> _persist() async {
    await _store.setJson(_storageKey, _cache!.map((e) => e.toJson()).toList());
    _controller.add(List.unmodifiable(_cache!));
  }

  @override
  Future<List<MediaItem>> getAll() async {
    final items = await _load();
    final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<MediaItem?> getById(String id) async {
    final items = await _load();
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(MediaItem item) async {
    final items = await _load();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    final items = await _load();
    items.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> rename(String id, String newFileName) async {
    final items = await _load();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(fileName: newFileName);
      await _persist();
    }
  }

  @override
  Stream<List<MediaItem>> watchAll() async* {
    yield await getAll();
    yield* _controller.stream.map((items) => [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }
}
