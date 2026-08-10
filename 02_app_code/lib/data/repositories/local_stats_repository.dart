import 'dart:async';
import 'package:intl/intl.dart';
import '../../domain/entities/daily_study_entry.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../local/local_kv_store.dart';

const _storageKey = 'ttara.user_stats.v1';
const _dailyLogStorageKey = 'ttara.daily_study_log.v1';
final _dateFmt = DateFormat('yyyy-MM-dd');

/// [StatsRepository]의 로컬 구현체. 마이 홈(#10)/학습 기록(#11)은 로컬 데이터로 즉시
/// 계산 가능해야 하므로(Empty/Loading만 존재, Error 없음) 서버 없이도 완결된다.
class LocalStatsRepository implements StatsRepository {
  final LocalKvStore _store;
  final _controller = StreamController<UserStats>.broadcast();
  final _dailyLogController = StreamController<Map<String, List<DailyStudyEntry>>>.broadcast();
  UserStats? _cache;
  Map<String, List<DailyStudyEntry>>? _dailyLogCache;

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

  Future<Map<String, List<DailyStudyEntry>>> _loadDailyLog() async {
    if (_dailyLogCache != null) return _dailyLogCache!;
    final loaded = await _store.getJson<Map<String, List<DailyStudyEntry>>>(
      _dailyLogStorageKey,
      (decoded) => (decoded as Map<String, dynamic>).map(
        (date, list) => MapEntry(
          date,
          (list as List).map((e) => DailyStudyEntry.fromJson(e as Map<String, dynamic>)).toList(),
        ),
      ),
    );
    _dailyLogCache = loaded ?? {};
    return _dailyLogCache!;
  }

  @override
  Future<UserStats> getStats() => _load();

  @override
  Stream<UserStats> watchStats() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Stream<Map<String, List<DailyStudyEntry>>> watchDailyLog() async* {
    yield await _loadDailyLog();
    yield* _dailyLogController.stream;
  }

  @override
  Future<void> recordProgress({
    required String mediaId,
    required String fileName,
    required int sentenceIndex,
    required int deltaDurationMs,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final dateKey = _dateFmt.format(now);

    // --- 일자별 콘텐츠 로그(전체 학습기록 화면 전용) ---
    final log = Map<String, List<DailyStudyEntry>>.from(await _loadDailyLog());
    final dayEntries = [...(log[dateKey] ?? const <DailyStudyEntry>[])];
    final idx = dayEntries.indexWhere((e) => e.mediaId == mediaId);
    if (idx < 0) {
      dayEntries.add(DailyStudyEntry(
        mediaId: mediaId,
        fileName: fileName,
        minIndex: sentenceIndex,
        maxIndex: sentenceIndex,
        sentencesStudied: 1,
        durationMs: deltaDurationMs,
      ));
    } else {
      final e = dayEntries[idx];
      dayEntries[idx] = e.copyWith(
        minIndex: sentenceIndex < e.minIndex ? sentenceIndex : e.minIndex,
        maxIndex: sentenceIndex > e.maxIndex ? sentenceIndex : e.maxIndex,
        sentencesStudied: e.sentencesStudied + 1,
        durationMs: e.durationMs + deltaDurationMs,
      );
    }
    log[dateKey] = dayEntries;
    _dailyLogCache = log;
    await _store.setJson(
      _dailyLogStorageKey,
      log.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
    );
    _dailyLogController.add(log);

    // --- 집계 통계(마이 홈 요약 카드/스트릭) ---
    final current = await _load();
    final heatmap = Map<String, int>.from(current.dailyHeatmap);
    final wasNewDay = !heatmap.containsKey(dateKey);
    heatmap[dateKey] = (heatmap[dateKey] ?? 0) + 1;

    final updated = current.copyWith(
      totalSentences: current.totalSentences + 1,
      totalStudyTimeMs: current.totalStudyTimeMs + deltaDurationMs,
      totalStudyDays: current.totalStudyDays + (wasNewDay ? 1 : 0),
      currentStreakDays: _computeStreak(heatmap, now, current.currentStreakDays, wasNewDay),
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
