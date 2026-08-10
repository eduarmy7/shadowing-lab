/// SRT/VTT/SMI 자막 파일을 파싱하는 순수 유틸리티 — **AI/네트워크 전혀 사용 안 함**,
/// 텍스트 포맷을 정규식으로 읽어내는 단순 파일 파싱이다(2026-08-05 STT 폐기 결정,
/// 00_input.md "자동 문장 분리" 참고). `SegmentationRepository`가 영상+자막 업로드
/// 경로에서 이 파서를 호출해 자막 큐의 타임스탬프를 그대로 문장 경계로, 자막 텍스트를
/// 그대로 [SentenceSegment.text]로 사용한다.
class SubtitleCue {
  final int index;
  final int startMs;
  final int endMs;
  final String text;

  const SubtitleCue({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

class SubtitleParseException implements Exception {
  final String message;
  const SubtitleParseException(this.message);
  @override
  String toString() => 'SubtitleParseException: $message';
}

/// 확장자(.srt/.vtt/.smi) 또는 내용으로 포맷을 판별해 파싱한다.
/// 큐를 하나도 뽑아내지 못하면 [SubtitleParseException]을 던진다 —
/// 호출측(`SegmentationRepository`)은 이를 `SegmentationFailureReason.unsupportedSubtitleFormat`로
/// 매핑해 사용자에게 "지원하지 않는 자막 형식이에요" 같은 안내를 보여준다.
List<SubtitleCue> parseSubtitleFile(String content, {required String fileNameOrExt}) {
  final ext = fileNameOrExt.split('.').last.toLowerCase();
  final isSmi = ext == 'smi' || RegExp(r'<SAMI', caseSensitive: false).hasMatch(content);
  final isVtt = ext == 'vtt' || content.trimLeft().startsWith('WEBVTT');

  final cues = isSmi ? _parseSami(content) : (isVtt ? _parseVtt(content) : _parseSrt(content));
  if (cues.isEmpty) {
    throw const SubtitleParseException('자막 큐를 하나도 찾지 못했어요');
  }
  return cues;
}

// "00:00:01,240" (SRT, 콤마) 또는 "00:00:01.240" (VTT, 마침표) 모두 대응.
final _timeLinePattern = RegExp(
  r'(\d{2,}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{2,}):(\d{2}):(\d{2})[,.](\d{1,3})',
);

int? _parseTimestamp(RegExpMatch m, int groupOffset) {
  final h = int.tryParse(m.group(groupOffset)!);
  final min = int.tryParse(m.group(groupOffset + 1)!);
  final s = int.tryParse(m.group(groupOffset + 2)!);
  final msRaw = m.group(groupOffset + 3)!;
  final ms = int.tryParse(msRaw.padRight(3, '0'));
  if (h == null || min == null || s == null || ms == null) return null;
  return ((h * 60 + min) * 60 + s) * 1000 + ms;
}

List<SubtitleCue> _parseSrt(String content) => _parseCueBlocks(content);

List<SubtitleCue> _parseVtt(String content) => _parseCueBlocks(content);

/// SRT/VTT 둘 다 "빈 줄로 구분된 블록, 그 안에 타임코드 줄 + 텍스트 줄들" 구조가
/// 동일해 공통 로직으로 처리한다. 블록 안에서 타임코드 줄을 찾아 그 앞뒤를 각각
/// 순번 줄(SRT 등)/텍스트 줄로 다뤄서, 순번 줄 유무와 무관하게 방어적으로 파싱한다.
List<SubtitleCue> _parseCueBlocks(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  final cues = <SubtitleCue>[];
  var autoIndex = 0;

  for (final block in blocks) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) continue;

    var timeLineIdx = lines.indexWhere((l) => _timeLinePattern.hasMatch(l));
    if (timeLineIdx < 0) continue; // 타임코드가 없는 블록(예: VTT 헤더/NOTE)은 건너뜀

    final match = _timeLinePattern.firstMatch(lines[timeLineIdx])!;
    final startMs = _parseTimestamp(match, 1);
    final endMs = _parseTimestamp(match, 5);
    if (startMs == null || endMs == null || endMs <= startMs) continue;

    final textLines = lines.sublist(timeLineIdx + 1);
    // 잔여 VTT 큐 세팅(예: "align:middle")이 텍스트 줄에 섞여 들어오는 경우는
    // 이 스캐폴드 범위 밖 — 텍스트 줄을 그대로 이어붙인다.
    final text = textLines.join(' ').replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (text.isEmpty) continue;

    autoIndex++;
    cues.add(SubtitleCue(index: autoIndex - 1, startMs: startMs, endMs: endMs, text: text));
  }
  return cues;
}

// SAMI(.smi)는 SRT/VTT와 달리 큐마다 명시적 종료 시각이 없다 — 대신
// `<SYNC Start=밀리초>`로 각 자막의 "시작" 지점만 표시하고, 그 자막의 실제 끝은
// 다음 <SYNC>가 시작되는 시점으로 암묵적으로 정의된다(한국 자막 커뮤니티의
// 사실상 표준 포맷). `<P Class=...>텍스트` 형태로 언어별 트랙을 나란히 넣는
// 다국어 SMI도 흔해서, 한 SYNC 블록 안에 <P>가 여러 개면 그중 첫 번째 것만
// 문장 텍스트로 쓴다(두 번째 <P>부터는 다른 언어 트랙일 가능성이 높다 — 전부
// 이어붙이면 두 언어가 한 문장에 섞여버린다).
final _samiSyncPattern = RegExp(r'<SYNC[^>]*Start\s*=\s*"?(\d+)"?[^>]*>', caseSensitive: false);
final _samiPTagPattern = RegExp(r'<P\b[^>]*>', caseSensitive: false);

List<SubtitleCue> _parseSami(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final syncMatches = _samiSyncPattern.allMatches(normalized).toList();
  if (syncMatches.isEmpty) return [];

  const fallbackLastCueDurationMs = 3000;
  final cues = <SubtitleCue>[];
  var autoIndex = 0;

  for (var i = 0; i < syncMatches.length; i++) {
    final sync = syncMatches[i];
    final startMs = int.tryParse(sync.group(1)!);
    if (startMs == null) continue;

    final blockEnd = i + 1 < syncMatches.length ? syncMatches[i + 1].start : normalized.length;
    final block = normalized.substring(sync.end, blockEnd);

    final pMatches = _samiPTagPattern.allMatches(block).toList();
    if (pMatches.isEmpty) continue; // 자막 텍스트가 없는 SYNC(스타일/메타 전용) — 건너뜀

    // SAMI는 </P> 닫는 태그를 흔히 생략한다 — 같은 블록 안 다음 <P>(다국어 트랙)나
    // 블록 끝(다음 SYNC 직전)까지를 이 언어 트랙의 텍스트로 본다.
    final textEnd = pMatches.length > 1 ? pMatches[1].start : block.length;
    final rawText = block.substring(pMatches.first.end, textEnd);
    final text = _decodeSamiText(rawText);
    if (text.isEmpty) continue; // "&nbsp;"만 있는 무음 구간 표시 — 건너뜀

    final endMs = i + 1 < syncMatches.length
        ? (int.tryParse(syncMatches[i + 1].group(1)!) ?? startMs + fallbackLastCueDurationMs)
        : startMs + fallbackLastCueDurationMs;
    if (endMs <= startMs) continue;

    autoIndex++;
    cues.add(SubtitleCue(index: autoIndex - 1, startMs: startMs, endMs: endMs, text: text));
  }
  return cues;
}

String _decodeSamiText(String raw) {
  final stripped = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
  final decoded = stripped
      .replaceAll(RegExp('&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp('&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp('&lt;', caseSensitive: false), '<')
      .replaceAll(RegExp('&gt;', caseSensitive: false), '>')
      .replaceAll(RegExp('&quot;', caseSensitive: false), '"')
      .replaceAll(RegExp('&(#39;|apos;)', caseSensitive: false), "'");
  return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
}
