import '../../domain/entities/sentence_segment.dart';

/// [FakeSegmentationRepository]가 반환하는 데모용 문장(구간) 데이터.
///
/// 2026-08-05 STT 폐기 결정 이후에는 실제 STT 결과를 시뮬레이션하는 게 아니라, 두 로컬
/// 처리 경로의 결과 형태를 각각 데모한다:
/// - [buildMockSubtitleSentences]: 영상+자막(SRT/VTT) 경로. 실제로는
///   `core/utils/subtitle_parser.dart`가 사용자가 첨부한 자막 파일을 파싱해 이 형태의
///   데이터를 만든다 — 여기 있는 문장 텍스트는 자막 파일이 아직 없는 상태(예: "샘플로
///   체험하기")를 위한 데모용 값일 뿐, 어떤 AI로도 생성되지 않았다(01_ux_design.md
///   "Lorem ipsum류 금지" 지침 반영해 자연스러운 문장으로 구성).
/// - [buildMockSilenceSegments]: 음성만 업로드 경로. 텍스트가 전혀 없다 — 실제 무음/
///   일시정지 구간 감지 결과를 흉내내 타이밍(구간 길이·간격)만 제공한다. **STT 신뢰도
///   개념이 없으므로 confidence 값은 만들어내지 않는다.**
const _rawSubtitleLines = <(String text, String translation, int durMs)>[
  ('I think this is the best way to understand it.', '제 생각엔 이게 이해하는 가장 좋은 방법인 것 같아요.', 3800),
  ("We've been working on this project for almost two years now.", '저희는 거의 2년째 이 프로젝트를 진행해 왔어요.', 4200),
  ('The results were better than anyone expected.', '결과는 모두의 예상보다 좋았습니다.', 2900),
  ("It's kind of hard to explain in just a few words.", '몇 마디로 설명하기가 좀 어렵네요.', 3400),
  ('But basically, we wanted to make the process simpler.', '하지만 기본적으로 저희는 그 과정을 더 간단하게 만들고 싶었어요.', 3600),
  ("A lot of people don't realize how much work goes into this.", '많은 사람들이 여기에 얼마나 많은 노력이 들어가는지 잘 몰라요.', 4100),
  ("So that's really what motivated the whole team.", '그게 바로 팀 전체에게 동기부여가 된 부분이에요.', 3000),
  ("Looking back, I'm proud of what we've built.", '돌이켜보면, 저희가 만든 것이 자랑스러워요.', 2800),
  ("Um, well, it's a bit complicated, honestly.", '음, 그게, 솔직히 좀 복잡해요.', 2600),
  ('The next step is to bring this to more people.', '다음 단계는 이걸 더 많은 사람들에게 전하는 거예요.', 3300),
  ("And I think that's when things really started to change.", '그리고 그때부터 상황이 정말 바뀌기 시작한 것 같아요.', 3500),
  ('Thanks so much for having me today.', '오늘 초대해 주셔서 정말 감사합니다.', 2400),
];

/// 자막 파싱 경로 데모 데이터(텍스트 있음).
List<SentenceSegment> buildMockSubtitleSentences(String mediaId) {
  var cursor = 0;
  final segments = <SentenceSegment>[];
  for (var i = 0; i < _rawSubtitleLines.length; i++) {
    final (text, translation, durMs) = _rawSubtitleLines[i];
    final start = cursor;
    final end = start + durMs;
    segments.add(SentenceSegment(
      id: '$mediaId-seg-$i',
      mediaId: mediaId,
      index: i,
      text: text,
      translation: translation,
      startMs: start,
      endMs: end,
    ));
    cursor = end + 400; // 문장 사이 간격(자막 큐 사이 여백 데모용)
  }
  return segments;
}

/// 무음/일시정지 구간 감지 경로 데모 데이터(텍스트 없음, confidence 없음).
/// 같은 타이밍 패턴을 재사용해 길이감만 사실적으로 유지한다.
List<SentenceSegment> buildMockSilenceSegments(String mediaId) {
  var cursor = 0;
  final segments = <SentenceSegment>[];
  for (var i = 0; i < _rawSubtitleLines.length; i++) {
    final (_, __, durMs) = _rawSubtitleLines[i];
    final start = cursor;
    final end = start + durMs;
    segments.add(SentenceSegment(
      id: '$mediaId-seg-$i',
      mediaId: mediaId,
      index: i,
      startMs: start,
      endMs: end,
    ));
    cursor = end + 400;
  }
  return segments;
}
