import 'package:equatable/equatable.dart';

enum ContentDifficulty { easy, mid, hard }

/// 라이브러리(#7/#8) 카테고리 — "오늘의 뉴스" 섹션은 카테고리 id `today`로 취급.
class LibraryCategory extends Equatable {
  final String id;
  final String label;

  const LibraryCategory({required this.id, required this.label});

  factory LibraryCategory.fromJson(Map<String, dynamic> json) =>
      LibraryCategory(id: json['id'] as String, label: json['label'] as String);

  @override
  List<Object?> get props => [id, label];
}

/// PRO 큐레이션 콘텐츠 1건(뉴스/회화 등). 필드는 01_ux_design.md
/// "API 연동 전달 사항 > #7/#8 라이브러리" 명세와 1:1 대응.
class LibraryContent extends Equatable {
  final String id;
  final String title;
  final String source; // 예: "CNN"
  final String thumbnailUrl;
  final int durationSec;
  final ContentDifficulty difficulty;
  final bool isLocked; // 비구독자 잠금 여부
  final String previewAudioUrl; // 비구독자도 항상 가능한 30초 미리듣기
  /// 전체 재생용 오디오 URL. 03_api_integration.md 5-1절: 서버가 매 요청마다 만료
  /// 15분짜리 서명된 URL을 이 필드로 내려주며, **구독자에게만 값이 채워지고
  /// 비구독자에게는 null**로 응답한다(저작권 보호 목적 짧은 TTL). `previewAudioUrl`은
  /// 잠금 콘텐츠 미리듣기(#8 "30초 미리 듣기") 전용, `audioUrl`은 전체 학습(#5) 전용으로
  /// 반드시 구분해서 사용할 것 — QA 🔴-1: 이 구분이 없어 PRO 학습 시 30초 이후 재생이 깨졌었음.
  final String? audioUrl;
  final DateTime publishedAt;
  final String categoryId;
  final int sentenceCount;

  const LibraryContent({
    required this.id,
    required this.title,
    required this.source,
    required this.thumbnailUrl,
    required this.durationSec,
    required this.difficulty,
    required this.isLocked,
    required this.previewAudioUrl,
    this.audioUrl,
    required this.publishedAt,
    required this.categoryId,
    required this.sentenceCount,
  });

  String get difficultyLabel => switch (difficulty) {
        ContentDifficulty.easy => '초급',
        ContentDifficulty.mid => '중급',
        ContentDifficulty.hard => '고급',
      };

  factory LibraryContent.fromJson(Map<String, dynamic> json) => LibraryContent(
        id: json['id'] as String,
        title: json['title'] as String,
        source: json['source'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        durationSec: json['durationSec'] as int,
        difficulty: ContentDifficulty.values.byName(json['difficulty'] as String),
        isLocked: json['isLocked'] as bool,
        previewAudioUrl: json['previewAudioUrl'] as String,
        audioUrl: json['audioUrl'] as String?,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        categoryId: json['categoryId'] as String,
        sentenceCount: json['sentenceCount'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'thumbnailUrl': thumbnailUrl,
        'durationSec': durationSec,
        'difficulty': difficulty.name,
        'isLocked': isLocked,
        'previewAudioUrl': previewAudioUrl,
        'audioUrl': audioUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'categoryId': categoryId,
        'sentenceCount': sentenceCount,
      };

  @override
  List<Object?> get props => [
        id,
        title,
        source,
        thumbnailUrl,
        durationSec,
        difficulty,
        isLocked,
        previewAudioUrl,
        audioUrl,
        publishedAt,
        categoryId,
        sentenceCount,
      ];
}

/// cursor 기반 페이지네이션 응답 래퍼 (01_ux_design.md 권장).
class Paginated<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const Paginated({required this.items, this.nextCursor, required this.hasMore});
}
