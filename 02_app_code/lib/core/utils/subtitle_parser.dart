import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:cp949_codec/cp949_codec.dart';

/// SRT/VTT/SMI 자막 파일을 파싱하는 순수 유틸리티 — **AI/네트워크 전혀 사용 안 함**,
/// 텍스트 포맷을 정규식으로 읽어내는 단순 파일 파싱이다(2026-08-05 STT 폐기 결정,
/// 00_input.md "자동 문장 분리" 참고). `SegmentationRepository`가 영상+자막 업로드
/// 경로에서 이 파서를 호출해 자막 큐의 타임스탬프를 그대로 문장 경계로, 자막 텍스트를
/// 그대로 [SentenceSegment.text]로 사용한다.
///
/// **2026-08-22 버그 수정**: 자막 파일을 항상 UTF-8로 가정하고 읽었는데, 사용자가
/// 실사용 중 유튜브 다운로드 SMI 파일이 안 읽힌다고 보고 — 한국어 SMI 자막 파일 다수가
/// (특히 오래되거나 다운로드 툴이 만든 것들) **EUC-KR/CP949**로 인코딩돼 있어
/// UTF-8 디코딩이 깨진 텍스트를 내거나 `FormatException`을 던지고, 그게
/// `unsupportedSubtitleFormat`으로 오인됐다. [readSubtitleFileAsText]가 UTF-8을
/// 먼저 시도하고 실패하면 CP949로 폴백한다.
Future<String> readSubtitleFileAsText(String path) async {
  final bytes = await File(path).readAsBytes();
  try {
    return utf8.decode(bytes).replaceFirst('﻿', ''); // UTF-8 BOM 제거
  } on FormatException {
    return cp949.decode(bytes);
  }
}

class SubtitleCue {
  final int index;
  final int startMs;
  final int endMs;
  final String text;
  // 2026-08-22 추가: 다국어 SMI에서 학습 언어와 별개로 뽑아낸 "한글 뜻" 트랙(있으면).
  final String? translation;

  const SubtitleCue({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.translation,
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
///
/// [preferredLanguageClassId]: SMI 파일이 여러 언어 트랙(`<P Class=...>`)을 함께
/// 담고 있을 때 어느 트랙을 문장 텍스트로 쓸지 지정한다(`detectSamiLanguageTracks`로
/// 미리 고른 값). null이면(SRT/VTT이거나 단일 언어 SMI) 예전처럼 각 구간의 첫 번째
/// `<P>`를 쓴다.
///
/// [translationLanguageClassId]: **2026-08-22 추가** — 다국어 SMI일 때, 학습 언어와
/// 별개로 [SubtitleCue.translation]에 채워 넣을 또 다른 트랙(보통 한국어 —
/// `findKoreanLanguageClassId` 참고). null이면 번역은 항상 채워지지 않는다(단일
/// 언어 자막/무음 감지 경로는 애초에 번역 데이터 자체가 없다).
List<SubtitleCue> parseSubtitleFile(
  String content, {
  required String fileNameOrExt,
  String? preferredLanguageClassId,
  String? translationLanguageClassId,
}) {
  final ext = fileNameOrExt.split('.').last.toLowerCase();
  final isSmi = ext == 'smi' || RegExp(r'<SAMI', caseSensitive: false).hasMatch(content);
  final isVtt = ext == 'vtt' || content.trimLeft().startsWith('WEBVTT');

  final cues = isSmi
      ? _parseSami(
          content,
          preferredClassId: preferredLanguageClassId,
          translationClassId: translationLanguageClassId,
        )
      : (isVtt ? _parseVtt(content) : _parseSrt(content));
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
// 다국어 SMI도 흔해서, 한 SYNC 블록 안에 <P>가 여러 개일 수 있다.
final _samiSyncPattern = RegExp(r'<SYNC[^>]*Start\s*=\s*"?(\d+)"?[^>]*>', caseSensitive: false);
final _samiPTagPattern = RegExp(r'<P\b[^>]*>', caseSensitive: false);
// 2026-08-22 버그 수정: 큰따옴표(Class="en")만 벗겨내고 작은따옴표(Class='en')는 그대로
// 값에 남겨서, 실제 유튜브 다운로드 SMI(작은따옴표 스타일)에서 classId가 "en"이 아니라
// "'en'"(따옴표 포함 5글자)로 저장돼 매칭에 실패하던 버그 — 큰/작은따옴표 둘 다 벗긴다.
final _samiClassAttrPattern = RegExp(r'''Class\s*=\s*['"]?([^'"\s>]+)['"]?''', caseSensitive: false);

String? _classIdOf(String pTag) => _samiClassAttrPattern.firstMatch(pTag)?.group(1);

/// SAMI 언어 트랙 하나 — `<P Class=...>`의 Class 값과, 사용자에게 보여줄 이름.
class SamiLanguageTrack {
  final String classId;
  final String label;
  const SamiLanguageTrack({required this.classId, required this.label});
}

/// **2026-08-22 추가**: SMI 파일이 여러 언어 트랙을 함께 담고 있는지 미리 살펴본다
/// (실제 파싱은 하지 않고 어떤 `Class`들이 쓰였는지만 스캔) — 예전엔 항상 각 SYNC
/// 구간의 "첫 번째" `<P>`만 문장 텍스트로 썼는데, 다운로드한 SMI 파일 중엔 한국어
/// 트랙이 먼저 오는 경우가 흔해서(예: 유튜브 자동자막 SMI) 영어 쉐도잉 앱인데 한국어
/// 문장이 그대로 보이는 문제가 있었다 — 트랙이 여러 개면 사용자가 직접 언어를 고르게
/// 한다(`parseSubtitleFile`의 [preferredLanguageClassId]).
///
/// 트랙 이름은 SAMI `<STYLE>` 블록의 `.클래스 { Name:이름; lang:코드; }` 같은 CSS 형태
/// 규칙(여러 SMI 제작 도구가 실제로 쓰는 관행)에서 우선 가져오고, 없으면 클래스 이름
/// 자체에서 언어를 추측한다(KR/KO→한국어, EN→English 등). 트랙이 1개 이하면 빈
/// 리스트를 반환 — 호출측은 이때 언어 선택 UI를 건너뛰고 예전처럼 동작해야 한다.
List<SamiLanguageTrack> detectSamiLanguageTracks(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // <STYLE>...</STYLE> 안의 `.ClassName { ... Name:표시이름 ... }` 규칙에서 이름을 뽑는다.
  final styleNames = <String, String>{};
  final styleBlock = RegExp(r'<STYLE[^>]*>([\s\S]*?)</STYLE>', caseSensitive: false).firstMatch(normalized);
  if (styleBlock != null) {
    final ruleMatches = RegExp(r'\.([\w-]+)\s*\{([^}]*)\}').allMatches(styleBlock.group(1)!);
    for (final rule in ruleMatches) {
      final className = rule.group(1)!;
      final body = rule.group(2)!;
      final nameMatch = RegExp(r'Name\s*:\s*([^;]+);', caseSensitive: false).firstMatch(body);
      if (nameMatch != null) {
        styleNames[className.toLowerCase()] = nameMatch.group(1)!.trim();
      }
    }
  }

  // 본문에 실제로 쓰인 Class들을 등장 순서대로 수집(중복 제거).
  final seen = <String>{};
  final classIds = <String>[];
  for (final pTag in _samiPTagPattern.allMatches(normalized).map((m) => m.group(0)!)) {
    final classId = _classIdOf(pTag);
    if (classId == null || !seen.add(classId)) continue;
    classIds.add(classId);
  }

  if (classIds.length <= 1) return const [];

  return [
    for (final classId in classIds)
      SamiLanguageTrack(
        classId: classId,
        label: styleNames[classId.toLowerCase()] ?? _guessLanguageLabel(classId),
      ),
  ];
}

/// **2026-08-22 추가**: 다국어 SMI에서 [studyClassId](사용자가 학습 언어로 고른 트랙)와
/// 별개로 "한글 뜻"으로 쓸 한국어 트랙의 classId를 찾는다. 학습 언어 자체가 이미
/// 한국어면(예: 한국어 자막으로 한국어를 공부) 번역이 무의미하므로 null을 반환한다.
///
/// **2026-08-22 버그 수정**: 처음엔 라벨이 정확히 '한국어'인지만 봤는데, 실사용자의
/// 다른 SMI 파일은 STYLE 블록에 `.ko { Name:Korean; ... }`처럼 **영어로** "Korean"이라고
/// 붙여놔서 못 찾았다(번역이 조용히 비어있었음). STYLE Name은 파일마다 어떤 언어로
/// 쓰여있을지 알 수 없으므로, classId 자체(ISO 639 코드 — 'ko', 'kor', 'ko-KR' 등)를
/// 우선 확인하고, 라벨이 '한국어'/'Korean'(대소문자 무관)인 경우도 함께 인정한다.
String? findKoreanLanguageClassId(List<SamiLanguageTrack> tracks, {required String? studyClassId}) {
  for (final t in tracks) {
    if (t.classId == studyClassId) continue;
    final classIdLower = t.classId.toLowerCase();
    final isKoreanClassId =
        classIdLower == 'ko' || classIdLower == 'kor' || classIdLower.startsWith('ko-') || classIdLower.startsWith('kor-');
    final isKoreanLabel = t.label == '한국어' || t.label.toLowerCase() == 'korean';
    if (isKoreanClassId || isKoreanLabel) return t.classId;
  }
  return null;
}

String _guessLanguageLabel(String classId) {
  final upper = classId.toUpperCase();
  if (upper.contains('KR') || upper.contains('KO')) return '한국어';
  if (upper.contains('EN')) return 'English';
  if (upper.contains('JP') || upper.contains('JA')) return '日本語';
  if (upper.contains('CN') || upper.contains('ZH')) return '中文';
  return classId; // 짐작 못하면 원래 Class 이름 그대로 보여준다.
}

class _SamiEntry {
  final String classId;
  final int startMs;
  final String rawText;
  const _SamiEntry({required this.classId, required this.startMs, required this.rawText});
}

/// SMI 파일 전체를 훑어 `<P Class=...>` 하나하나를 (언어, 시작 시각, 원본 텍스트)로
/// 평탄화한다. **2026-08-22 설계 변경**: 처음엔 "한 SYNC 구간 안에 여러 언어의 `<P>`가
/// 나란히 들어있다"고 가정했는데, 실사용자가 가진 실제 SMI 파일은 그 반대 구조였다 —
/// 언어별로 **완전히 분리된 구간**이 순서대로 이어진다(영어 문장 전체 → 한국어 문장
/// 전체, 각자 자기 타임스탬프를 처음부터 다시 가짐). 두 구조 모두 "SYNC 하나 = P
/// 태그 하나 이상"이라는 점은 같아서, 일단 (언어, 시작 시각, 텍스트) 튜플로 전부
/// 뽑아낸 뒤 언어별로 묶으면 두 구조 모두 같은 코드로 처리된다.
List<_SamiEntry> _flattenSamiEntries(String normalized, List<RegExpMatch> syncMatches) {
  final entries = <_SamiEntry>[];
  for (var i = 0; i < syncMatches.length; i++) {
    final sync = syncMatches[i];
    final startMs = int.tryParse(sync.group(1)!);
    if (startMs == null) continue;

    final blockEnd = i + 1 < syncMatches.length ? syncMatches[i + 1].start : normalized.length;
    final block = normalized.substring(sync.end, blockEnd);

    final pMatches = _samiPTagPattern.allMatches(block).toList();
    for (var j = 0; j < pMatches.length; j++) {
      final classId = _classIdOf(pMatches[j].group(0)!);
      if (classId == null) continue;
      final textEnd = j + 1 < pMatches.length ? pMatches[j + 1].start : block.length;
      entries.add(_SamiEntry(classId: classId, startMs: startMs, rawText: block.substring(pMatches[j].end, textEnd)));
    }
  }
  return entries;
}

List<SubtitleCue> _parseSami(String content, {String? preferredClassId, String? translationClassId}) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final syncMatches = _samiSyncPattern.allMatches(normalized).toList();
  if (syncMatches.isEmpty) return [];

  const fallbackLastCueDurationMs = 3000;
  final allEntries = _flattenSamiEntries(normalized, syncMatches);
  if (allEntries.isEmpty) return [];

  // 언어별로 묶는다 — 등장 순서를 그대로 유지해야 각 언어 자신의 시간순 트랙이 된다
  // (같은 언어의 항목이 파일 안에서 서로 떨어져 있어도 상관없다, groupBy는 안정 정렬).
  //
  // **실제 유튜브 다운로드 SMI로 검증하며 발견한 두 번째 문제**: 이 파일은 같은
  // 언어+같은 시작 시각의 <P>가 파일 안에 두 번씩 들어있었다(다운로드 과정에서 생긴
  // 중복으로 보임 — 원인은 확실치 않지만 결과는 명확했다). 그냥 첫 번째를 남기면 실제로는
  // **첫 번째가 빈 자리표시자(placeholder)고 실제 텍스트는 두 번째 중복에 들어있는
  // 경우가 대부분**이라(직접 확인함), 오히려 문장이 거의 다 빈 텍스트로 잡혀 버려지는
  // 정반대 문제가 생겼다. 그래서 같은 (언어, 시작 시각) 조합이 여러 번 나오면 그중
  // **텍스트가 실제로 있는 쪽**을 남긴다(위치 순서와 무관하게) — 순서(첫 등장 위치)는
  // Map 삽입 순서로 그대로 유지된다.
  final byClass = <String, List<_SamiEntry>>{};
  for (final entries in allEntries.groupListsBy((e) => e.classId).entries) {
    final byStart = <int, _SamiEntry>{};
    for (final e in entries.value) {
      final existing = byStart[e.startMs];
      if (existing == null || _decodeSamiText(existing.rawText).isEmpty) {
        byStart[e.startMs] = e;
      }
    }
    byClass[entries.key] = byStart.values.toList();
  }

  // preferredClassId가 없으면(SRT/VTT이거나 단일 언어 SMI) 처음 등장한 언어를 그대로 쓴다
  // — 언어가 하나뿐이면 고를 필요가 없으므로 예전과 동일하게 동작한다.
  final textClassId = preferredClassId ?? allEntries.first.classId;
  final textTrack = byClass[textClassId];
  if (textTrack == null || textTrack.isEmpty) return [];

  final translationTrack = translationClassId != null ? byClass[translationClassId] : null;

  final cues = <SubtitleCue>[];
  for (var idx = 0; idx < textTrack.length; idx++) {
    final entry = textTrack[idx];
    final text = _decodeSamiText(entry.rawText);
    if (text.isEmpty) continue; // "&nbsp;"만 있는 무음 구간 표시 — 건너뜀

    final endMs =
        idx + 1 < textTrack.length ? textTrack[idx + 1].startMs : entry.startMs + fallbackLastCueDurationMs;
    if (endMs <= entry.startMs) continue;

    // 2026-08-22 추가: 번역 트랙("한글 뜻") — 같은 시작 시각을 가진 항목을 찾는다(두
    // 언어 트랙이 서로 다른 구조로 저장돼 있어도, 같은 문장이면 시작 시각은 같다는
    // 사용자 확인 기반). 없으면 이 구간만 번역 없음으로 둔다.
    String? translation;
    if (translationTrack != null) {
      final match = translationTrack.firstWhereOrNull((e) => e.startMs == entry.startMs);
      if (match != null) {
        final decoded = _decodeSamiText(match.rawText);
        if (decoded.isNotEmpty) translation = decoded;
      }
    }

    cues.add(SubtitleCue(
      index: cues.length,
      startMs: entry.startMs,
      endMs: endMs,
      text: text,
      translation: translation,
    ));
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
