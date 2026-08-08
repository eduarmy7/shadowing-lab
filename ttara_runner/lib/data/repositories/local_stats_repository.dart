import 'dart:async';
import 'package:intl/intl.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.user_stats.v1';
final _dateFmt = DateFormat('yyyy-MM-dd');

/// [StatsRepository]의 로컬 구현체. 마이 홈(#10)/학습 기록(#11)은 로컬 데이터로 즉시
/// 계산 가능해야 하므로(Empty/Loading만 존재, Error 없음) 서버 없이도 완결된다.
class LocalStatsRepository implements StatsRepository {
  final LocalKvStore _store;
  final _controller = StreamController<UserStats>.broadcast();
  UserStats? _cache;

  LocalStatsRepository(this._store);

  Future<UserStats> _load() async {
    if (_cache != null) return _cache!;
    final loaded = await _store.getJson<UserStats>(
      _storageKey,
      (decoded) => UserStats.fromJson(decoded as Map<String, dynamic>),
    );
    _cache = loaded ?? const UserStats();
    return _cache!;
  }

  @override
  Future<UserStats> getStats() => _load();

  @override
  Stream<UserStats> watchStats() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Future<void> recordSession(LearningSessionResult result) async {
    final current = await _load();
    final todayKey = _dateFmt.format(result.completedAt);
    final heatmap = Map<String, int>.from(current.dailyHeatmap);
    final wasNewDay = !heatmap.containsKey(todayKey);
    heatmap[todayKey] = (heatmap[todayKey] ?? 0) + result.sentencesCompleted;

    final updated = current.copyWith(
      totalSentences: current.totalSentences + result.sentencesCompleted,
      totalStudyTimeMs: current.totalStudyTimeMs + result.durationMs,
      totalStudyDays: current.totalStudyDays + (wasNewDay ? 1 : 0),
      currentStreakDays: _computeStreak(heatmap, result.completedAt, current.currentStreakDays, wasNewDay),
      dailyHeatmap: heatmap,
    );

    _cache = updated;
    await _store.setJson(_storageKey, updated.toJson());
    _controller.add(updated);
  }

  int _computeStreak(Map<String, int> heatmap, DateTime today, int previousStreak, bool wasNewDay) {
    if (!wasNewDay) return previousStreak == 0 ? 1 : previousStreak;
    final yesterdayKey = _dateFmt.format(today.subtract(const Duration(days: 1)));
    final continuedStreak = heatmap.containsKey(yesterdayKey);
    return continuedStreak ? previousStreak + 1 : 1;
  }
}
