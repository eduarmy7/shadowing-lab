import 'package:equatable/equatable.dart';

/// 마이 홈(#10)/학습 기록 상세(#11)의 로컬 우선 통계. 로그인 사용자는 서버 동기화
/// 후순위 지원(01_ux_design.md API 전달 사항 `GET /user/stats`).
class UserStats extends Equatable {
  final int currentStreakDays;
  final int totalSentences;
  final int totalStudyTimeMs;
  final int totalStudyDays;

  /// 날짜(yyyy-MM-dd 키) → 그날 학습한 문장 수. 캘린더 히트맵(#11) 렌더링에 사용.
  final Map<String, int> dailyHeatmap;

  const UserStats({
    this.currentStreakDays = 0,
    this.totalSentences = 0,
    this.totalStudyTimeMs = 0,
    this.totalStudyDays = 0,
    this.dailyHeatmap = const {},
  });

  bool get hasAnyRecord => totalSentences > 0;

  UserStats copyWith({
    int? currentStreakDays,
    int? totalSentences,
    int? totalStudyTimeMs,
    int? totalStudyDays,
    Map<String, int>? dailyHeatmap,
  }) {
    return UserStats(
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      totalSentences: totalSentences ?? this.totalSentences,
      totalStudyTimeMs: totalStudyTimeMs ?? this.totalStudyTimeMs,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      dailyHeatmap: dailyHeatmap ?? this.dailyHeatmap,
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        currentStreakDays: json['currentStreakDays'] as int? ?? 0,
        totalSentences: json['totalSentences'] as int? ?? 0,
        totalStudyTimeMs: json['totalStudyTimeMs'] as int? ?? 0,
        totalStudyDays: json['totalStudyDays'] as int? ?? 0,
        dailyHeatmap: (json['dailyHeatmap'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, value as int)),
      );

  Map<String, dynamic> toJson() => {
        'currentStreakDays': currentStreakDays,
        'totalSentences': totalSentences,
        'totalStudyTimeMs': totalStudyTimeMs,
        'totalStudyDays': totalStudyDays,
        'dailyHeatmap': dailyHeatmap,
      };

  @override
  List<Object?> get props =>
      [currentStreakDays, totalSentences, totalStudyTimeMs, totalStudyDays, dailyHeatmap];
}

/// 세션 1회(문장 시작~종료) 결과 — #6 학습 완료 요약 화면(책을 끝까지 다 마쳤을 때만
/// 뜨는 축하 화면)의 표시용 입력값. 2026-08-10부터 통계 누적 자체는 이 결과가 아니라
/// [StatsRepository.recordProgress]가 문장 단위로 실시간 처리한다.
class LearningSessionResult extends Equatable {
  final String mediaId;
  final int sentencesCompleted;
  final int totalSentencesInMedia;
  final int durationMs;
  final DateTime completedAt;

  const LearningSessionResult({
    required this.mediaId,
    required this.sentencesCompleted,
    required this.totalSentencesInMedia,
    required this.durationMs,
    required this.completedAt,
  });

  bool get isFullyCompleted => sentencesCompleted >= totalSentencesInMedia;

  @override
  List<Object?> get props => [mediaId, sentencesCompleted, totalSentencesInMedia, durationMs, completedAt];
}
