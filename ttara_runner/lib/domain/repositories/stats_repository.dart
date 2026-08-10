import 'dart:async';

import '../entities/daily_study_entry.dart';
import '../entities/user_stats.dart';

/// 마이 홈(#10)/학습 기록(#11) 통계. 로컬 우선 계산이 기본이며, 로그인 사용자에 한해
/// `GET /user/stats` 서버 동기화를 추가하는 것을 권장(01_ux_design.md).
/// 로컬 구현은 [LocalStatsRepository], 서버 동기화가 필요해지면 이 인터페이스를
/// 유지한 채 데코레이터(로컬 우선 + 백그라운드 서버 sync)로 확장한다.
///
/// **2026-08-10 버그 수정**: 예전엔 `recordSession()`이 책 전체(수백~수천 문장)를
/// 100% 다 끝내야만 호출돼서, 실제 장문 콘텐츠 사용 패턴에서는 거의 발동하지 않았다
/// (마이 홈 요약 카드/스트릭/전체 학습기록이 사실상 갱신 안 됨). [recordProgress]로
/// 교체 — 문장 하나가 완료 처리될 때마다(`ShadowingController._markSegmentCompleted`)
/// 호출해 실시간으로 누적한다.
abstract class StatsRepository {
  Future<UserStats> getStats();
  Stream<UserStats> watchStats();

  /// 문장 하나가 새로 완료 처리될 때마다 호출한다(문장당 정확히 한 번 — 재학습은
  /// 카운트하지 않음). 마이 홈 요약(스트릭/총 문장/총 시간)과 아래 [watchDailyLog]를
  /// 함께 갱신한다.
  Future<void> recordProgress({
    required String mediaId,
    required String fileName,
    required int sentenceIndex,
    required int deltaDurationMs,
    DateTime? at,
  });

  /// 날짜(yyyy-MM-dd 키) → 그날 학습한 콘텐츠별 요약. 전체 학습기록(#11) 화면 전용.
  Stream<Map<String, List<DailyStudyEntry>>> watchDailyLog();
}
