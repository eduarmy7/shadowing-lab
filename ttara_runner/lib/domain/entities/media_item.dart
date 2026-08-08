import 'package:equatable/equatable.dart';

enum MediaSourceType { audio, video }

/// 미디어 처리 파이프라인 상태 — #2(업로드) → #3(분석) → #5(학습) 흐름과 대응.
///
/// 2026-08-06: 분석 완료→학습 사이에 있던 "전체 문장 확인 후 확정" 게이트(구
/// readyForReview → #4 목록 확인 화면 → "N개 문장으로 시작")를 없앴다 — 문장이 수백~
/// 수천 개인 콘텐츠(책 한 권 등)에서는 학습 시작 전에 전부 훑어보고 확정하는 게
/// 애초에 불가능하고, 실제로도 필요 없다. 이제 분석이 끝나면 곧장 [ready]가 되어
/// 학습 화면(#5)으로 들어가고, 편집(병합/분리/길이조정)은 학습 화면에서 그때그때
/// 필요한 문장만 편집 화면으로 들어가 처리한다.
enum MediaStatus {
  uploading,
  analyzing,
  ready, // 분석 완료, 학습 가능(편집은 학습 화면에서 문장별로 그때그때)
  failed, // 로컬 문장분리 실패(무음 미검출/자막 파싱 실패) — "재분석 필요" 배지(#1) / 재시도 경로(#3)
}

/// 홈 탭(#1)의 "내 파일" 한 건. 사용자가 업로드한 로컬 음성/영상 + 처리 상태 + 학습 진행률.
class MediaItem extends Equatable {
  final String id;
  final String fileName;
  final String localPath;
  final MediaSourceType sourceType;
  final int durationMs;
  final MediaStatus status;
  final double uploadProgress; // 0.0~1.0, status == uploading일 때만 의미 있음
  final double analysisProgress; // 0.0~1.0, status == analyzing일 때만 의미 있음
  final int sentenceCount;
  final int completedSentenceCount; // 학습 완료(반복 도달)한 문장 수 — 홈 카드 진행률 바
  final int lastPlayedSentenceIndex; // "이어서 학습" 진입점
  final DateTime createdAt;
  final DateTime? lastStudiedAt;

  const MediaItem({
    required this.id,
    required this.fileName,
    required this.localPath,
    required this.sourceType,
    required this.durationMs,
    required this.status,
    this.uploadProgress = 0,
    this.analysisProgress = 0,
    this.sentenceCount = 0,
    this.completedSentenceCount = 0,
    this.lastPlayedSentenceIndex = 0,
    required this.createdAt,
    this.lastStudiedAt,
  });

  double get completionRatio => sentenceCount == 0 ? 0 : completedSentenceCount / sentenceCount;
  bool get isCompleted => sentenceCount > 0 && completedSentenceCount >= sentenceCount;

  MediaItem copyWith({
    String? id,
    String? fileName,
    String? localPath,
    MediaSourceType? sourceType,
    int? durationMs,
    MediaStatus? status,
    double? uploadProgress,
    double? analysisProgress,
    int? sentenceCount,
    int? completedSentenceCount,
    int? lastPlayedSentenceIndex,
    DateTime? createdAt,
    DateTime? lastStudiedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      sourceType: sourceType ?? this.sourceType,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      analysisProgress: analysisProgress ?? this.analysisProgress,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      completedSentenceCount: completedSentenceCount ?? this.completedSentenceCount,
      lastPlayedSentenceIndex: lastPlayedSentenceIndex ?? this.lastPlayedSentenceIndex,
      createdAt: createdAt ?? this.createdAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        localPath: json['localPath'] as String,
        sourceType: MediaSourceType.values.byName(json['sourceType'] as String),
        durationMs: json['durationMs'] as int,
        status: MediaStatus.values.byName(json['status'] as String),
        uploadProgress: (json['uploadProgress'] as num?)?.toDouble() ?? 0,
        analysisProgress: (json['analysisProgress'] as num?)?.toDouble() ?? 0,
        sentenceCount: json['sentenceCount'] as int? ?? 0,
        completedSentenceCount: json['completedSentenceCount'] as int? ?? 0,
        lastPlayedSentenceIndex: json['lastPlayedSentenceIndex'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastStudiedAt: json['lastStudiedAt'] == null ? null : DateTime.parse(json['lastStudiedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'localPath': localPath,
        'sourceType': sourceType.name,
        'durationMs': durationMs,
        'status': status.name,
        'uploadProgress': uploadProgress,
        'analysisProgress': analysisProgress,
        'sentenceCount': sentenceCount,
        'completedSentenceCount': completedSentenceCount,
        'lastPlayedSentenceIndex': lastPlayedSentenceIndex,
        'createdAt': createdAt.toIso8601String(),
        'lastStudiedAt': lastStudiedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        fileName,
        localPath,
        sourceType,
        durationMs,
        status,
        uploadProgress,
        analysisProgress,
        sentenceCount,
        completedSentenceCount,
        lastPlayedSentenceIndex,
        createdAt,
        lastStudiedAt,
      ];
}
