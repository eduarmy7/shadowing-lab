import 'dart:async';
import '../../domain/entities/learning_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.learning_settings.v1';

class LocalSettingsRepository implements SettingsRepository {
  final LocalKvStore _store;
  final _controller = StreamController<LearningSettings>.broadcast();
  LearningSettings? _cache;

  LocalSettingsRepository(this._store);

  Future<LearningSettings> _load() async {
    if (_cache != null) return _cache!;
    final loaded = await _store.getJson<LearningSettings>(
      _storageKey,
      (decoded) => LearningSettings.fromJson(decoded as Map<String, dynamic>),
    );
    _cache = loaded ?? const LearningSettings();
    return _cache!;
  }

  @override
  Future<LearningSettings> getSettings() => _load();

  @override
  Stream<LearningSettings> watchSettings() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Future<void> updateSettings(LearningSettings settings) async {
    _cache = settings;
    await _store.setJson(_storageKey, settings.toJson());
    _controller.add(settings);
  }
}
