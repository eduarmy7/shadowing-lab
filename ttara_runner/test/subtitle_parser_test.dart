import 'dart:convert';
import 'dart:io';

import 'package:cp949_codec/cp949_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttara/core/utils/subtitle_parser.dart';

/// 2026-08-22 실사용 버그: 유튜브에서 다운로드한 SMI 자막이 EUC-KR(CP949)로
/// 인코딩돼 있어 UTF-8 전제였던 파일 읽기가 깨지던 문제 + 다국어 SMI에서 항상
/// 첫 언어 트랙만 쓰던 문제. 이 두 가지를 검증한다.
void main() {
  group('readSubtitleFileAsText — 인코딩 자동 판별', () {
    test('UTF-8 SMI 파일은 그대로 읽힌다', () async {
      final file = await _writeTemp('utf8.smi', utf8.encode(_sampleSmiKoEn));
      final text = await readSubtitleFileAsText(file.path);
      expect(text, contains('안녕하세요'));
      expect(text, contains('Hello'));
      await file.parent.delete(recursive: true);
    });

    test('EUC-KR(CP949) SMI 파일도 깨지지 않고 읽힌다', () async {
      final cp949Bytes = cp949.encode(_sampleSmiKoEn);
      final file = await _writeTemp('cp949.smi', cp949Bytes);
      final text = await readSubtitleFileAsText(file.path);
      expect(text, contains('안녕하세요'));
      expect(text, contains('Hello'));
      await file.parent.delete(recursive: true);
    });
  });

  group('detectSamiLanguageTracks', () {
    test('단일 언어 SMI는 빈 리스트(선택 UI 불필요)', () {
      const singleLang = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class=KRCC>안녕하세요
<SYNC Start=1000><P Class=KRCC>반갑습니다
</BODY>
</SAMI>
''';
      expect(detectSamiLanguageTracks(singleLang), isEmpty);
    });

    test('다국어 SMI는 STYLE의 Name으로 라벨을 붙인 트랙 목록을 반환', () {
      final tracks = detectSamiLanguageTracks(_sampleSmiKoEn);
      expect(tracks.map((t) => t.classId), containsAll(['KRCC1', 'ENUSCC1']));
      final ko = tracks.firstWhere((t) => t.classId == 'KRCC1');
      final en = tracks.firstWhere((t) => t.classId == 'ENUSCC1');
      expect(ko.label, '한국어');
      expect(en.label, 'English');
    });

    test('STYLE 블록이 없으면 Class 이름에서 언어를 추측한다', () {
      const noStyle = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class=KRCC1>안녕<P Class=ENCC1>Hi
<SYNC Start=1000><P Class=KRCC1>반가워<P Class=ENCC1>Nice
</BODY>
</SAMI>
''';
      final tracks = detectSamiLanguageTracks(noStyle);
      expect(tracks.firstWhere((t) => t.classId == 'KRCC1').label, '한국어');
      expect(tracks.firstWhere((t) => t.classId == 'ENCC1').label, 'English');
    });
  });

  group('detectSingleSamiLanguageTrack/isEnglishSamiTrack — 2026-08-26 추가', () {
    test('한국어 자막만 있는 SMI는 그 한국어 트랙을 돌려주고, 영어가 아니라고 판단한다', () {
      const koOnly = '''
<sami>
<head>
<style type='text/css'><!--
.ko { Name:한국어; lang:ko; SAMIType:CC; }
--></style>
</head>
<body>
<SYNC Start=0><P class='ko'>혹시 그 에피소드 기억나세요?
<SYNC Start=1000><P class='ko'>&nbsp;
</body>
</sami>
''';
      final track = detectSingleSamiLanguageTrack(koOnly);
      expect(track, isNotNull);
      expect(track!.classId, 'ko');
      expect(track.label, '한국어');
      expect(isEnglishSamiTrack(track), isFalse);
    });

    test('영어 자막만 있는 SMI는 영어라고 판단한다', () {
      const enOnly = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class=ENUSCC1>Hello there
<SYNC Start=1000><P Class=ENUSCC1>Nice to meet you
</BODY>
</SAMI>
''';
      final track = detectSingleSamiLanguageTrack(enOnly);
      expect(track, isNotNull);
      expect(isEnglishSamiTrack(track!), isTrue);
    });

    test('다국어 SMI(트랙 2개 이상)는 null — 언어 선택 UI가 대신 처리한다', () {
      expect(detectSingleSamiLanguageTrack(_sampleSmiKoEn), isNull);
    });
  });

  group('parseSubtitleFile — preferredLanguageClassId', () {
    test('지정 안 하면 예전처럼 각 구간 첫 번째 <P>(한국어)를 쓴다', () {
      final cues = parseSubtitleFile(_sampleSmiKoEn, fileNameOrExt: 'x.smi');
      expect(cues.map((c) => c.text), ['안녕하세요', '반갑습니다']);
    });

    test('영어 트랙을 고르면 영어 문장이 나온다 — 버그 리포트의 핵심 케이스', () {
      final cues = parseSubtitleFile(
        _sampleSmiKoEn,
        fileNameOrExt: 'x.smi',
        preferredLanguageClassId: 'ENUSCC1',
      );
      expect(cues.map((c) => c.text), ['Hello', 'Nice to meet you']);
    });

    test('타임스탬프는 어느 언어를 고르든 동일하게 유지된다', () {
      final ko = parseSubtitleFile(_sampleSmiKoEn, fileNameOrExt: 'x.smi', preferredLanguageClassId: 'KRCC1');
      final en =
          parseSubtitleFile(_sampleSmiKoEn, fileNameOrExt: 'x.smi', preferredLanguageClassId: 'ENUSCC1');
      expect(ko.map((c) => c.startMs), en.map((c) => c.startMs));
      expect(ko.map((c) => c.endMs), en.map((c) => c.endMs));
    });
  });

  group('작은따옴표 Class 속성 — 2026-08-22 실기기 버그(Class=\'en\' 스타일)', () {
    const singleQuoteSmi = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class='ko'>안녕하세요<P Class='en'>Hello
<SYNC Start=1500><P Class='ko'>반갑습니다<P Class='en'>Nice to meet you
</BODY>
</SAMI>
''';

    test('detectSamiLanguageTracks가 따옴표 없는 순수 classId를 돌려준다', () {
      final tracks = detectSamiLanguageTracks(singleQuoteSmi);
      expect(tracks.map((t) => t.classId), containsAll(['ko', 'en']));
      expect(tracks.every((t) => !t.classId.contains("'")), isTrue,
          reason: 'classId에 따옴표 문자가 남아있으면 안 됨 — 실기기에서 확인된 버그');
    });

    test('작은따옴표 스타일 파일에서도 영어 트랙 선택이 정확히 동작한다', () {
      final cues = parseSubtitleFile(singleQuoteSmi, fileNameOrExt: 'x.smi', preferredLanguageClassId: 'en');
      expect(cues.map((c) => c.text), ['Hello', 'Nice to meet you']);
    });
  });

  group('언어별로 완전히 분리된 SMI 구조 — 2026-08-22 실사용자 제보', () {
    // 사용자 제보: 실제로 가진 SMI 파일은 한 SYNC 안에 여러 언어가 나란히 있는 게
    // 아니라, "영어 문장 전체 묶음 → 한국어 문장 전체 묶음"처럼 언어별로 완전히
    // 분리된 구간이 순서대로 이어지고, 각 언어가 처음부터 자기 타임스탬프를 다시
    // 갖는다(둘 다 같은 시각 값을 씀). 이 구조에서도 정상 동작해야 한다.
    const groupedSmi = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class=en>Hello
<SYNC Start=1500><P Class=en>Nice to meet you
<SYNC Start=0><P Class=kr>안녕하세요
<SYNC Start=1500><P Class=kr>반갑습니다
</BODY>
</SAMI>
''';

    test('영어 트랙만 골라도 정확한 문장과 시간이 나온다', () {
      final cues = parseSubtitleFile(groupedSmi, fileNameOrExt: 'x.smi', preferredLanguageClassId: 'en');
      expect(cues.map((c) => c.text), ['Hello', 'Nice to meet you']);
      expect(cues.map((c) => c.startMs), [0, 1500]);
    });

    test('영어를 학습 언어로, 한국어를 번역으로 — 같은 시작 시각끼리 정확히 짝지어진다', () {
      final cues = parseSubtitleFile(
        groupedSmi,
        fileNameOrExt: 'x.smi',
        preferredLanguageClassId: 'en',
        translationLanguageClassId: 'kr',
      );
      expect(cues.map((c) => c.text), ['Hello', 'Nice to meet you']);
      expect(cues.map((c) => c.translation), ['안녕하세요', '반갑습니다']);
    });

    test('일부 시각에만 번역이 있으면 그 구간만 번역이 채워진다', () {
      const partial = '''
<SAMI>
<BODY>
<SYNC Start=0><P Class=en>Hello
<SYNC Start=1500><P Class=en>Nice to meet you
<SYNC Start=0><P Class=kr>안녕하세요
</BODY>
</SAMI>
''';
      final cues = parseSubtitleFile(
        partial,
        fileNameOrExt: 'x.smi',
        preferredLanguageClassId: 'en',
        translationLanguageClassId: 'kr',
      );
      expect(cues[0].translation, '안녕하세요');
      expect(cues[1].translation, isNull);
    });
  });

  group('한글 뜻(번역) 자동 추출 — 2026-08-22 추가', () {
    test('findKoreanLanguageClassId가 학습 언어와 다른 한국어 트랙을 찾는다', () {
      final tracks = detectSamiLanguageTracks(_sampleSmiKoEn);
      final translationId = findKoreanLanguageClassId(tracks, studyClassId: 'ENUSCC1');
      expect(translationId, 'KRCC1');
    });

    test('STYLE Name이 "Korean"(영어)이어도 classId로 한국어 트랙을 찾는다 — 실사용자 제보', () {
      // 실제 파일의 STYLE 블록: .ko { Name:Korean; lang:ko; SAMIType:CC; } — 라벨이
      // '한국어'가 아니라 영어 "Korean"이라 못 찾던 버그.
      const smi = '''
<sami>
<head>
<style type='text/css'><!--
.ko { Name:Korean; lang:ko; SAMIType:CC; }
.en-US { Name:English; lang:en-US; SAMIType:CC; }
-->
</style>
</head>
<body>
<sync Start=0><p Class=ko>안녕<p Class=en-US>Hi
<sync Start=1000><p Class=ko>반가워<p Class=en-US>Nice
</body>
</sami>
''';
      final tracks = detectSamiLanguageTracks(smi);
      expect(tracks.firstWhere((t) => t.classId == 'ko').label, 'Korean');
      final translationId = findKoreanLanguageClassId(tracks, studyClassId: 'en-US');
      expect(translationId, 'ko');
    });

    test('학습 언어 자체가 한국어면 번역 트랙을 찾지 않는다(null)', () {
      final tracks = detectSamiLanguageTracks(_sampleSmiKoEn);
      final translationId = findKoreanLanguageClassId(tracks, studyClassId: 'KRCC1');
      expect(translationId, isNull);
    });

    test('translationLanguageClassId를 주면 영어 문장 + 한국어 번역이 함께 채워진다', () {
      final cues = parseSubtitleFile(
        _sampleSmiKoEn,
        fileNameOrExt: 'x.smi',
        preferredLanguageClassId: 'ENUSCC1',
        translationLanguageClassId: 'KRCC1',
      );
      expect(cues.map((c) => c.text), ['Hello', 'Nice to meet you']);
      expect(cues.map((c) => c.translation), ['안녕하세요', '반갑습니다']);
    });

    test('translationLanguageClassId를 안 주면 translation은 항상 null', () {
      final cues = parseSubtitleFile(_sampleSmiKoEn, fileNameOrExt: 'x.smi', preferredLanguageClassId: 'ENUSCC1');
      expect(cues.every((c) => c.translation == null), isTrue);
    });
  });
}

Future<File> _writeTemp(String name, List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('subtitle_parser_test_');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

const _sampleSmiKoEn = '''
<SAMI>
<HEAD>
<STYLE TYPE="text/css">
<!--
.KRCC1 { Name:한국어; lang:ko-KR; SAMIType:CC; }
.ENUSCC1 { Name:English; lang:en-US; SAMIType:CC; }
-->
</STYLE>
</HEAD>
<BODY>
<SYNC Start=0><P Class=KRCC1>안녕하세요<P Class=ENUSCC1>Hello
<SYNC Start=1500><P Class=KRCC1>반갑습니다<P Class=ENUSCC1>Nice to meet you
<SYNC Start=3000><P Class=KRCC1>&nbsp;<P Class=ENUSCC1>&nbsp;
</BODY>
</SAMI>
''';
