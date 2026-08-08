import 'dart:async';

import '../entities/user_stats.dart';

/// 마이 홈(#10)/학습 기록(#11) 통계. 로컬 우선 계산이 기본이며, 로그인 사용자에 한해
/// `GET /user/stats` 서버 동기화를 추가하는 것을 권장(01_ux_design.md).
/// 로컬 구현은 [LocalStatsRepository], 서버 동기화가 필요해지면 이 인터페이스를
/// 유지한 채 데코레이터(로컬 우선 + 백그라운드 서버 sync)로 확장한다.
abstract class StatsRepository {
  Future<UserStats> getStats();
  Stream<UserStats> watchStats();
  Future<void> recordSession(LearningSessionResult result);
}
