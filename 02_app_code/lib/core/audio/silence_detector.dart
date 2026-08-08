import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as jab;

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
    final amplitudes = await _extractAmplitudes(localFilePath, durationMs);
    extractSw.stop();
    debugPrint('[SilenceDetector] amplitudes.length=${amplitudes.length}'
        '${amplitudes.isNotEmpty ? ' max=${amplitudes.reduce((a, b) => a > b ? a : b)}' : ''}'
        ' (extraction took ${extractSw.elapsedMilliseconds}ms = '
        '${(extractSw.elapsedMilliseconds / 1000 / 60).toStringAsFixed(1)}min)');
    if (amplitudes.isEmpty) {
      return SilenceDetectionResult(segments: const [], amplitudes: const [], durationMs: durationMs);
    }

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
  /// 실제 ms 단위로 환산하려면 파일 길이를 별도로 알아야 한다 — 이미 의존성에 있는
  /// `just_audio`로 잠깐 로드했다 바로 버리는 방식으로 얻는다(재생하지 않음). 이 프로브
  /// 자체는 빠르다(118분짜리 실제 파일 기준 1초 미만) — [detect]가 내부에서도 쓰지만,
  /// 호출측이 본 분석을 시작하기 전에 예상 소요시간을 먼저 보여주고 싶을 때도 이 메서드를
  /// 직접 불러 재사용할 수 있게 public으로 둔다.
  Future<int> probeDurationMs(String localFilePath) async {
    final probe = AudioPlayer();
    try {
      // main.dart의 JustAudioBackground.init()이 앱 전역에 걸려 있어, 모든
      // AudioSource는 MediaItem 태그가 반드시 있어야 한다(없으면 assert 실패) —
      // 이 플레이어는 알림/재생 UI에 노출되지 않는 내부 probe라 최소 태그만 채운다.
      final duration = await probe.setAudioSource(
        AudioSource.uri(
          Uri.file(localFilePath),
          tag: jab.MediaItem(id: localFilePath, title: 'silence-detector-probe'),
        ),
      );
      return duration?.inMilliseconds ?? 0;
    } catch (e, st) {
      debugPrint('[SilenceDetector] _probeDurationMs failed: $e\n$st');
      return 0;
    } finally {
      await probe.dispose();
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
    final threshold = maxAmp * AppConstants.silenceAmplitudeRatio;
    final minPauseSamples = (AppConstants.minPauseMs / msPerSample).ceil().clamp(1, amplitudes.length);

    // 1) 진폭이 threshold 이하로 minPauseSamples 이상 이어지는 무음 구간을 찾는다.
    final silenceRanges = <List<int>>[];
    int? runStart;
    for (var i = 0; i < amplitudes.length; i++) {
      if (amplitudes[i] <= threshold) {
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

    return [
      for (var i = 0; i < merged.length; i++)
        SentenceSegment(
          id: '$mediaId-seg-$i',
          mediaId: mediaId,
          index: i,
          startMs: (merged[i][0] * msPerSample).round(),
          endMs: i == merged.length - 1 ? durationMs : (merged[i][1] * msPerSample).round(),
        ),
    ];
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
