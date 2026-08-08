import 'package:equatable/equatable.dart';

/// 문장(구간) 하나. #4 문장 분리 결과 확인/편집, #5 쉐도잉 학습 화면에서 공통으로
/// 사용되는 핵심 엔티티.
///
/// **2026-08-05 아키텍처 결정으로 STT(AssemblyAI 등) 완전 폐기 — 100% 로컬/무비용 처리로
/// 전환**(00_input.md 참고). 문장 경계와 텍스트의 출처는 두 갈래뿐이다:
/// 1) 음성만 업로드: 로컬 무음/일시정지 구간 감지로 `startMs`/`endMs`만 산출 — [text]는
///    `null`(전사 자체가 없음). STT 신뢰도 개념이 없으므로 `confidence` 필드는 완전히
///    제거했다(무음 감지 결과에 가짜 신뢰도 값을 붙이지 않는다).
/// 2) 영상+자막(SRT/VTT) 업로드: 자막 파일을 그대로 파싱 — 자막 큐의 타임스탬프가
///    `startMs`/`endMs`, 자막 텍스트가 [text]가 된다(순수 파일 파싱, AI 아님).
class SentenceSegment extends Equatable {
  final String id;
  final String mediaId;
  final int index; // 0-based 문장 순서
  final String? text; // 자막에서 파싱된 텍스트. 음성만 업로드한 경우 null(텍스트 없음).
  final String? translation; // 한글 번역(옵션, text가 있을 때만 의미 있음) — #5 "한글 뜻 보기" 접힘 콘텐츠
  final int startMs;
  final int endMs;
  final bool edited; // 사용자가 경계/텍스트를 수동 조정했는지 (#4 편집 이력)
  final int? repeatCountOverride; // 문장별 반복횟수를 기본값과 다르게 지정한 경우
  final bool flaggedByUser; // 사용자가 "잘 안되는 문장"으로 직접 표시했는지 (#5 학습 화면 체크)

  const SentenceSegment({
    required this.id,
    required this.mediaId,
    required this.index,
    this.text,
    this.translation,
    required this.startMs,
    required this.endMs,
    this.edited = false,
    this.repeatCountOverride,
    this.flaggedByUser = false,
  });

  int get durationMs => endMs - startMs;

  /// 텍스트 없이(무음 감지만으로) 만들어진 구간인지 — UI에서 "텍스트 없이 듣고 따라
  /// 말하기" 표시 분기에 사용.
  bool get hasText => text != null && text!.trim().isNotEmpty;

  SentenceSegment copyWith({
    String? id,
    String? mediaId,
    int? index,
    String? text,
    bool clearText = false,
    String? translation,
    int? startMs,
    int? endMs,
    bool? edited,
    int? repeatCountOverride,
    bool? flaggedByUser,
  }) {
    return SentenceSegment(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      index: index ?? this.index,
      text: clearText ? null : (text ?? this.text),
      translation: translation ?? this.translation,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      edited: edited ?? this.edited,
      repeatCountOverride: repeatCountOverride ?? this.repeatCountOverride,
      flaggedByUser: flaggedByUser ?? this.flaggedByUser,
    );
  }

  factory SentenceSegment.fromJson(Map<String, dynamic> json) => SentenceSegment(
        id: json['id'] as String,
        mediaId: json['mediaId'] as String,
        index: json['index'] as int,
        text: json['text'] as String?,
        translation: json['translation'] as String?,
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
        edited: json['edited'] as bool? ?? false,
        repeatCountOverride: json['repeatCountOverride'] as int?,
        flaggedByUser: json['flaggedByUser'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'index': index,
        'text': text,
        'translation': translation,
        'startMs': startMs,
        'endMs': endMs,
        'edited': edited,
        'repeatCountOverride': repeatCountOverride,
        'flaggedByUser': flaggedByUser,
      };

  @override
  List<Object?> get props => [
        id,
        mediaId,
        index,
        text,
        translation,
        startMs,
        endMs,
        edited,
        repeatCountOverride,
        flaggedByUser,
      ];
}
