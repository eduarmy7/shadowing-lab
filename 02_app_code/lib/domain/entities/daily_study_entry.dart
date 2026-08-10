import 'package:equatable/equatable.dart';

/// 하루 동안 특정 콘텐츠(책/영상)에서 실제로 완료 처리된 문장들의 범위 요약 —
/// 전체 학습기록(#11) 화면에서 "8월 10일 · Diary of a Wimpy Kid 71~127번" 같은
/// 표시에 쓰인다. [minIndex]/[maxIndex]는 0-based, 화면에는 +1해서 보여준다.
///
/// [StatsRepository.recordProgress]가 문장 하나가 새로 완료 처리될 때마다 호출돼
/// 이 범위를 갱신한다 — 중간에 건너뛴 문장이 있을 수 있어 [sentencesStudied]
/// (실제로 완료된 문장 수)가 `maxIndex - minIndex + 1`(범위 폭)보다 작을 수 있다.
class DailyStudyEntry extends Equatable {
  final String mediaId;
  final String fileName;
  final int minIndex;
  final int maxIndex;
  final int sentencesStudied;
  final int durationMs;

  const DailyStudyEntry({
    required this.mediaId,
    required this.fileName,
    required this.minIndex,
    required this.maxIndex,
    required this.sentencesStudied,
    required this.durationMs,
  });

  DailyStudyEntry copyWith({
    int? minIndex,
    int? maxIndex,
    int? sentencesStudied,
    int? durationMs,
  }) =>
      DailyStudyEntry(
        mediaId: mediaId,
        fileName: fileName,
        minIndex: minIndex ?? this.minIndex,
        maxIndex: maxIndex ?? this.maxIndex,
        sentencesStudied: sentencesStudied ?? this.sentencesStudied,
        durationMs: durationMs ?? this.durationMs,
      );

  factory DailyStudyEntry.fromJson(Map<String, dynamic> json) => DailyStudyEntry(
        mediaId: json['mediaId'] as String,
        fileName: json['fileName'] as String,
        minIndex: json['minIndex'] as int,
        maxIndex: json['maxIndex'] as int,
        sentencesStudied: json['sentencesStudied'] as int,
        durationMs: json['durationMs'] as int,
      );

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'fileName': fileName,
        'minIndex': minIndex,
        'maxIndex': maxIndex,
        'sentencesStudied': sentencesStudied,
        'durationMs': durationMs,
      };

  @override
  List<Object?> get props => [mediaId, fileName, minIndex, maxIndex, sentencesStudied, durationMs];
}
