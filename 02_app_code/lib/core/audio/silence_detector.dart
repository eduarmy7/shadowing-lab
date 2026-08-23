import 'dart:collection';
import 'dart:math' as math;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../../domain/entities/sentence_segment.dart';

/// **실제 오디오 amplitude 분석으로 문장(발화) 경계를 찾는다.**
///
/// 2026-08-05 STT 완전 폐기 결정(00_input.md) 이후, 자막이 없는 오디오/영상 파일의
/// 문장 분리는 이 클래스가 유일한 구현이다 — AI도, 네트워크 호출도 전혀 쓰지 않는다.
/// `audio_waveforms` 패키지(Android MediaExtractor / iOS AVAssetReader를 감싼 네이티브
/// 디코더)로 파형 진폭 샘플을 뽑아낸 뒤, 진폭이 [AppConstants.silenceAmplitudeRatio]
/// 이하로 [AppConstants.minPauseMs] 이상 이어지는 구간을 "무음(문장 경계)"으로 판정하는
/// 순수 신호처리 로직이다.
///
/// **번들 asset(`asset:///...`) 경로는 지원 대상이 아니다** — 네이티브 디코더는 실제
/// 기기 파일시스템 경로만 읽을 수 있다. 앱 데모용 "샘플MP3로 체험하기"는 원래도 45초
/// 무음 PCM 플레이스홀더(pubspec.yaml 참고, 실제 발화가 없음)라 이 클래스로 분석해도
/// 의미 있는 결과가 나오지 않으므로, 호출측(`FakeSegmentationRepository`)이 asset 경로일
/// 때는 이 클래스를 아예 호출하지 않고 기존 시뮬레이션 경로를 그대로 쓴다.
class SilenceDetector {
  const SilenceDetector();

  /// **2026-08-24**: "최근 피크"를 지수감쇠 엔벨로프 대신 슬라이딩 윈도우 최댓값으로
  /// 계산한다 — 실사용 배경음악 파일 진단 결과(로그: ratio<=.35인 샘플이 3889개 중
  /// 454개나 있었는데도 결과는 여전히 1문장), 지수감쇠 방식은 진폭이 한 번 떨어지면
  /// "최근 피크" 자체가 그 낮아진 값 쪽으로 1~2샘플 만에 다시 수렴해버려, 무음
  /// 후보 샘플들이 [AppConstants.minPauseMs](350ms)만큼 **연속으로** 이어지지
  /// 못하고 흩어졌던 게 원인이었다. 슬라이딩 윈도우 최댓값은 이 윈도우(ms) 안에
  /// 조금 전 큰 소리가 남아있는 한 "최근 피크"가 그대로 유지되므로, 윈도우보다
  /// 짧은 쉼 구간이라면 쉼 내내 낮은 비율이 안정적으로 이어진다.
  static const int _recentPeakWindowMs = 2500;

  /// [localFilePath]는 실제 기기 파일 경로여야 한다. 오디오가 전혀 없거나(길이 0)
  /// 파형 전체가 무음이라 문장 경계를 하나도 못 찾으면 빈 세그먼트 리스트를 반환한다 —
  /// 호출측은 이를 `SegmentationFailureReason.noClearSilenceDetected`로 매핑한다.
  ///
  /// **2026-08-06**: 세그먼트뿐 아니라 이때 이미 뽑아둔 원본 진폭 배열([durationMs]
  /// 기준 등간격)도 함께 반환한다 — 편집/학습 화면의 파형 표시가 지금까지는 seed
  /// 기반 가짜 그림이었는데("반쪽만 나온다"는 진행률 계산 버그 포함), 이 배열을
  /// 저장해두면 문장별로 그 구간만 잘라서 **진짜 파형**을 그릴 수 있다 — 파일을 다시
  /// 디코딩할 필요 없이(이미 한 번 계산한 값 재사용).
  /// [knownDurationMs]: 이미 [probeDurationMs]로 길이를 알고 있으면 넘겨서 내부에서
  /// 다시 프로브하지 않게 한다(2026-08-07 추가 — #3 화면이 분석 시작 전에 예상 소요시간을
  /// 보여주려면 길이를 먼저 알아야 해서, 호출측이 미리 한 번 프로브해두고 여기 전달하는
  /// 경로가 생겼다. 안 넘기면(null) 예전처럼 이 안에서 직접 프로브한다).
  Future<SilenceDetectionResult> detect({
    required String mediaId,
    required String localFilePath,
    int? knownDurationMs,
  }) async {
    final totalSw = Stopwatch()..start();
    int durationMs;
    if (knownDurationMs != null) {
      durationMs = knownDurationMs;
    } else {
      final probeSw = Stopwatch()..start();
      durationMs = await probeDurationMs(localFilePath);
      probeSw.stop();
      debugPrint('[SilenceDetector] durationMs=$durationMs for $localFilePath '
          '(probe took ${probeSw.elapsedMilliseconds}ms)');
    }
    if (durationMs <= 0) return const SilenceDetectionResult(segments: [], amplitudes: [], durationMs: 0);

    final extractSw = Stopwatch()..start();
    final rawAmplitudes = await _extractAmplitudes(localFilePath, durationMs);
    extractSw.stop();
    final rawMax = rawAmplitudes.isEmpty ? 0.0 : rawAmplitudes.reduce((a, b) => a > b ? a : b);
    debugPrint('[SilenceDetector] amplitudes.length=${rawAmplitudes.length}'
        '${rawAmplitudes.isNotEmpty ? ' max=$rawMax' : ''}'
        ' (extraction took ${extractSw.elapsedMilliseconds}ms = '
        '${(extractSw.elapsedMilliseconds / 1000 / 60).toStringAsFixed(1)}min)');
    if (rawAmplitudes.isEmpty) {
      return SilenceDetectionResult(segments: const [], amplitudes: const [], durationMs: durationMs);
    }

    // **2026-08-24 버그 수정**: 원본(raw) 진폭을 그대로 [SilenceDetectionResult.amplitudes]로
    // 내보내면, 아주 조용하게 녹음된 파일(실사용 사례 — 파일 전체 최댓값이 0.04밖에 안 됨)은
    // 문장 구간별 파형 표시([WaveformPlayer]의 `_normalizeToFullRange`, 절대값 0.02 이하는
    // "거의 무음"으로 보고 증폭을 안 함)에서 실제 대사가 있는 구간도 납작한 무음처럼
    // 보이는 버그로 이어졌다(사용자 스크린샷으로 확인 — "음성이 있는데 파동이 없다"). 그
    // 0.02 컷오프는 원래 파일마다 절대 음량이 다르다는 걸 감안하지 못했던 것 — 여기서
    // 파일 전체 최댓값 기준 0~1로 미리 정규화해 내보내면, 그 컷오프가 파일이 얼마나
    // 조용하게 녹음됐든 항상 "이 파일 최대 음량 대비 2%"라는 일관된 의미를 갖게 된다.
    // 무음 감지(`_segmentFromAmplitudes`) 자체는 이미 내부에서 파일 자체 최댓값 기준
    // 비율로 계산하므로 이 정규화로 판정 로직이 달라지지는 않는다.
    final amplitudes = rawMax > 0 ? [for (final a in rawAmplitudes) a / rawMax] : rawAmplitudes;

    final result = _segmentFromAmplitudes(
      mediaId: mediaId,
      amplitudes: amplitudes,
      durationMs: durationMs,
    );
    totalSw.stop();
    debugPrint('[SilenceDetector] result: ${result.length} segments in '
        '${(totalSw.elapsedMilliseconds / 1000 / 60).toStringAsFixed(1)}min total '
        '${result.take(20).map((s) => '[${s.startMs}-${s.endMs}]').join(' ')}');
    return SilenceDetectionResult(segments: result, amplitudes: amplitudes, durationMs: durationMs);
  }

  /// `audio_waveforms`는 파형 "모양"만 다루고 재생 길이를 알려주지 않으므로, 표본을
  /// 실제 ms 단위로 환산하려면 파일 길이를 별도로 알아야 한다. 이 프로브 자체는
  /// 빠르다(메타데이터만 읽고 전체 디코드는 하지 않음) — [detect]가 내부에서도 쓰지만,
  /// 호출측이 본 분석을 시작하기 전에 예상 소요시간을 먼저 보여주고 싶을 때도 이 메서드를
  /// 직접 불러 재사용할 수 있게 public으로 둔다.
  ///
  /// **2026-08-08 버그 수정**: 원래는 `just_audio`의 `AudioPlayer`로 잠깐 로드했다 바로
  /// 버리는 방식이었다 — 그런데 `main.dart`의 `JustAudioBackground.init()`이 앱 전역에
  /// 걸려 있어, `just_audio_background`는 프로세스당 **단 하나의** `AudioPlayer` 인스턴스만
  /// 허용한다. 사용자가 쉐도잉 화면에서 문장을 한 번이라도 재생하면(`audioPlayerServiceProvider`,
  /// 의도적으로 앱 전역 싱글톤 — 그 파일의 주석 참고) 그 순간부터 이 프로브가 두 번째
  /// 인스턴스를 만들려다 `PlatformException(just_audio_background supports only a single
  /// player instance)`를 던진다. 실기기에서 재현: 파일을 분석→쉐도잉 화면에서 재생→홈으로
  /// 나와 새 파일을 분석하면 이 프로브가 매번 실패해 분석이 "0%에서 멈춘 것처럼" 보였다
  /// (예외가 이 메서드의 try/catch 바깥의 비동기 경로로 새어나가 상위에서 미처리 예외로
  /// 잡혔다). `audio_waveforms`의 `PlayerController`는 `just_audio`와 완전히 분리된 자체
  /// 네이티브 플레이어(키별로 여러 인스턴스 동시 허용)라 이 제약이 없다 — 이미
  /// `_extractAmplitudes`에서 파형 추출에 쓰고 있으므로 길이 조회에도 그대로 재사용한다.
  Future<int> probeDurationMs(String localFilePath) async {
    final controller = PlayerController();
    try {
      await controller.preparePlayer(path: localFilePath, shouldExtractWaveform: false);
      final duration = await controller.getDuration(DurationType.max);
      return duration > 0 ? duration : 0;
    } catch (e, st) {
      debugPrint('[SilenceDetector] _probeDurationMs failed: $e\n$st');
      return 0;
    } finally {
      controller.dispose();
    }
  }

  Future<List<double>> _extractAmplitudes(String localFilePath, int durationMs) async {
    final controller = PlayerController();
    try {
      final samples = await controller.waveformExtraction.extractWaveformData(
        path: localFilePath,
        noOfSamples: _sampleCountFor(durationMs),
      );
      return samples;
    } catch (e, st) {
      debugPrint('[SilenceDetector] _extractAmplitudes failed: $e\n$st');
      return const [];
    } finally {
      controller.dispose();
    }
  }

  /// 대략 100ms 해상도로 샘플링한다 — [AppConstants.minPauseMs](350ms) 판정에 충분한
  /// 해상도다.
  ///
  /// **2026-08-06 버그 수정**: 예전엔 상한을 6000개로 걸어뒀는데, 118분(7,119,793ms)
  /// 짜리 실제 파일을 돌려보니 6000개로는 샘플당 해상도가 ~1.2초까지 뭉개져서
  /// 실제로는 문장 사이 350ms짜리 쉼을 사실상 감지할 수 없었다 — 그 결과 실제로는
  /// 2071문장이어야 할 파일이 306문장으로 과소 분리됐다(사용자가 다른 쉐도잉 앱과
  /// 비교해 발견). 상한을 앱의 최대 업로드 길이(`AppConstants.maxMediaDurationMinutes`,
  /// 60분)보다 넉넉히 크게 잡아 실제 파일 길이에서도 100ms 해상도가 그대로 유지되게
  /// 한다(120분 파일 기준 72,000개 필요 → 여유를 두고 150,000으로 상한 설정).
  int _sampleCountFor(int durationMs) => (durationMs / 100).round().clamp(50, 150000);

  List<SentenceSegment> _segmentFromAmplitudes({
    required String mediaId,
    required List<double> amplitudes,
    required int durationMs,
  }) {
    final maxAmp = amplitudes.reduce((a, b) => a > b ? a : b);
    if (maxAmp <= 0) return const []; // 파형 전체가 완전 무음 — 발화 자체가 없음

    final msPerSample = durationMs / amplitudes.length;
    final globalThreshold = maxAmp * AppConstants.silenceAmplitudeRatio;
    final minPauseSamples = (AppConstants.minPauseMs / msPerSample).ceil().clamp(1, amplitudes.length);

    // **2026-08-23 추가, 2026-08-24 재작성 — 배경음악이 계속 깔린 영상 대응**:
    // 사용자 실사용 사례 — 배경음악이 있는 6분 반짜리 영상이 무음을 하나도 못
    // 찾고 통째로 문장 1개로 잡혔다. 파일 전체 최대치 대비 고정 비율([globalThreshold])
    // 만으로는, 대사가 쉬는 구간에도 배경음악이 계속 나오면 그 음량이 절대 그
    // 기준 밑으로 안 떨어진다. 그래서 "방금까지 들리던 소리 크기(최근 피크)" 대비
    // 상대적으로 조용해지는 지점도 무음 후보로 함께 인정한다 — 절대적으로
    // 조용하지 않아도(배경음악은 계속 나와도) 직전 대사보다 확실히 작아지면 문장
    // 사이 쉼일 가능성이 높다는 전제. [_recentPeakWindowMs] 주석 참고 — 첫 시도였던
    // 지수감쇠 엔벨로프는 실측 결과 무음 후보 샘플이 있어도(454/3889) 전부
    // `minPauseSamples` 미만의 짧은 조각으로 흩어져 경계를 못 만들었다. 슬라이딩
    // 윈도우 최댓값으로 바꿔 "최근 피크"가 윈도우 동안 안정적으로 유지되게 한다.
    final windowSamples = (_recentPeakWindowMs / msPerSample).round().clamp(1, amplitudes.length);
    final envelope = _slidingWindowMax(amplitudes, windowSamples);

    // 1) 진폭이 (전체 최대치 기준 OR 최근 피크 기준) threshold 이하로 minPauseSamples
    //    이상 이어지는 무음 구간을 찾는다 — 둘 중 하나만 만족해도 무음 후보.
    // **2026-08-24**: 상대 기준(`isRelativelyQuiet`)은 "절대적으로도 어느 정도
    // 조용함"을 AND로 추가 요구한다 — [AppConstants.localSilenceAbsoluteCeiling]
    // 주석 참고. 이게 없으면 그냥 직전 단어보다 조용하게 말한 진짜 단어가 통째로
    // 무음 처리돼 사라지는 실사용 버그가 있었다.
    final silenceRanges = <List<int>>[];
    int? runStart;
    for (var i = 0; i < amplitudes.length; i++) {
      final isGloballyQuiet = amplitudes[i] <= globalThreshold;
      final isRelativelyQuiet = envelope[i] > 0 &&
          amplitudes[i] <= envelope[i] * AppConstants.localSilenceRatio &&
          amplitudes[i] <= maxAmp * AppConstants.localSilenceAbsoluteCeiling;
      if (isGloballyQuiet || isRelativelyQuiet) {
        runStart ??= i;
      } else if (runStart != null) {
        if (i - runStart >= minPauseSamples) silenceRanges.add([runStart, i]);
        runStart = null;
      }
    }
    if (runStart != null && amplitudes.length - runStart >= minPauseSamples) {
      silenceRanges.add([runStart, amplitudes.length]);
    }

    // 2) 무음 구간 사이사이가 발화(문장) 구간이다 — 무음이 하나도 없으면 파일 전체가
    //    문장 1개다.
    final speechRanges = <List<int>>[];
    var cursor = 0;
    for (final silence in silenceRanges) {
      if (silence[0] > cursor) speechRanges.add([cursor, silence[0]]);
      cursor = silence[1];
    }
    if (cursor < amplitudes.length) speechRanges.add([cursor, amplitudes.length]);
    if (speechRanges.isEmpty) return const [];

    // 3) 너무 짧은 발화 구간(순간 잡음 스파이크)은 문장으로 보지 않고 인접 구간과
    //    합친다 — 시간 손실 없이 항상 "이전 구간을 뒤로 늘리는" 방식으로만 병합해
    //    어떤 샘플도 유실되지 않게 한다.
    final minSentenceSamples = (AppConstants.minSentenceMs / msPerSample).ceil();
    final merged = <List<int>>[];
    for (final range in speechRanges) {
      if (merged.isEmpty) {
        merged.add([range[0], range[1]]);
        continue;
      }
      final prevLength = merged.last[1] - merged.last[0];
      if (prevLength < minSentenceSamples) {
        merged.last[1] = range[1]; // 직전 구간이 너무 짧았으면 현재 구간과 합친다.
      } else {
        merged.add([range[0], range[1]]);
      }
    }
    // 마지막 구간이 여전히 너무 짧으면(파일 끝자락 노이즈) 그 앞 문장에 합친다.
    if (merged.length > 1 && (merged.last[1] - merged.last[0]) < minSentenceSamples) {
      final tail = merged.removeLast();
      merged.last[1] = tail[1];
    }

    // 4) 시작/끝에 여유(패딩)를 준다 — [AppConstants.sentenceBoundaryPaddingMs] 주석
    //    참고. 인접 문장 사이 무음 구간이 항상 minPauseMs 이상이라 겹칠 걱정 없다.
    const padding = AppConstants.sentenceBoundaryPaddingMs;
    return [
      for (var i = 0; i < merged.length; i++)
        SentenceSegment(
          id: '$mediaId-seg-$i',
          mediaId: mediaId,
          index: i,
          startMs: math.max(0, (merged[i][0] * msPerSample).round() - padding),
          endMs: i == merged.length - 1
              ? durationMs
              : math.min(durationMs, (merged[i][1] * msPerSample).round() + padding),
        ),
    ];
  }

  /// 각 인덱스 i에 대해 `[i - window + 1, i]`(과거 방향, 미래를 안 보는 causal 창) 안의
  /// 최댓값을 O(n)에 계산한다 — 단조 감소 데크: 큐 뒤쪽부터 자기보다 작은 값을 모두
  /// 버리고 자신을 넣으면, 큐의 맨 앞이 항상 현재 창의 최댓값 인덱스가 된다.
  List<double> _slidingWindowMax(List<double> data, int window) {
    final result = List<double>.filled(data.length, 0);
    final deque = Queue<int>();
    for (var i = 0; i < data.length; i++) {
      while (deque.isNotEmpty && data[deque.last] <= data[i]) {
        deque.removeLast();
      }
      deque.addLast(i);
      if (deque.first <= i - window) {
        deque.removeFirst();
      }
      result[i] = data[deque.first];
    }
    return result;
  }
}

/// [SilenceDetector.detect]의 반환값 — 문장 경계뿐 아니라 그 계산에 이미 쓰인 원본
/// 진폭 배열([amplitudes], [durationMs] 구간에 걸쳐 등간격)도 함께 담는다. 호출측
/// (`FakeSegmentationRepository`)이 이 배열을 저장해두면, 이후 문장별 파형 표시에서
/// 파일을 다시 디코딩하지 않고 저장된 배열의 해당 구간만 잘라 쓸 수 있다.
class SilenceDetectionResult {
  final List<SentenceSegment> segments;
  final List<double> amplitudes;
  final int durationMs;

  const SilenceDetectionResult({
    required this.segments,
    required this.amplitudes,
    required this.durationMs,
  });
}
