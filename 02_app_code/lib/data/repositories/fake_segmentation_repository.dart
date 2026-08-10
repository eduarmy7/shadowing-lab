import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/audio/silence_detector.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/subtitle_parser.dart';
import '../../domain/entities/segmentation_job.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../domain/repositories/segmentation_repository.dart';
import '../local/local_kv_store.dart';
import '../mock/mock_sentences.dart';

/// **[SegmentationRepository]의 로컬 구현체(더 이상 "Fake"라고 부르기 애매할 만큼 두
/// 경로 모두 실제 로직으로 동작한다).**
///
/// 2026-08-05 STT 완전 폐기 결정(00_input.md) 이후 이 클래스는 네트워크를 전혀 쓰지
/// 않는다:
/// - **자막(SRT/VTT/SMI) 첨부됨**: `core/utils/subtitle_parser.dart`로 실제 파일을 파싱한다.
/// - **자막 없음(음성만)**: 2026-08-05(3차)부터 `core/audio/silence_detector.dart`가
///   실제 오디오 파형(진폭)을 분석해 무음 구간으로 문장 경계를 찾는다(진짜 로직) — 단,
///   `localFilePath`가 번들 asset(`asset:///`) 경로인 경우(=샘플MP3 체험하기, 원래도
///   발화가 없는 45초 무음 PCM 플레이스홀더)는 네이티브 디코더가 asset을 직접 읽을 수
///   없고 분석해도 의미가 없어 기존 [buildMockSilenceSegments] 시뮬레이션을 그대로 쓴다.
///
/// api-integrator가 참고할 점: 이 클래스는 원격 API 클라이언트로 교체할 대상이 **아니다**
/// — 문장 분리 자체가 로컬 전용 기능이 되었기 때문에, 실 프로덕션에서도 이 계열
/// (Local*SegmentationRepository)이 남아야 한다. 유일하게 서버와 관련될 수 있는 지점은
/// (향후 검토사항) 완성된 세그먼트를 사용자 계정에 동기화하는 것 정도.
class FakeSegmentationRepository implements SegmentationRepository {
  final LocalKvStore _store;
  final _uuid = const Uuid();

  FakeSegmentationRepository(this._store);

  String _mediaMetaKey(String mediaId) => 'ttara.local_media_meta.$mediaId';
  String _jobMediaKey(String jobId) => 'ttara.local_job_media.$jobId';
  String _segmentsKey(String mediaId) => 'ttara.local_segments.$mediaId';
  String _waveformKey(String mediaId) => 'ttara.local_waveform.$mediaId';

  /// 저장할 진폭 배열의 상한.
  ///
  /// **2026-08-07 수정**: 원래 20,000이었는데, 이건 훨씬 짧은 파일 기준으로 잡은
  /// 가정이었다 — 118분 실제 파일로 확인해보니 샘플당 간격이 20000/7,111,000ms ≈
  /// **356ms**까지 벌어져서, 보통 1~4초인 문장 하나가 겨우 3~11개 원본 포인트만
  /// 갖게 됐다(그걸 64개 막대로 늘려 그리니 뭉텅뭉텅 계단식으로 뭉개짐). 그 결과
  /// "발화가 있는데 막대가 낮고, 조용한데 막대가 높은" 것처럼 보였다 — 실제로는
  /// 파형과 소리가 밀린 게 아니라(인덱스 계산 자체는 맞음), 그 문장 안에서 조용한
  /// 부분과 시끄러운 부분이 356ms 블록 단위로 뭉뚱그려져 word 단위 디테일이 사라진
  /// 것이었다. 앱이 실제로 지원하는 최대 길이([AppConstants.maxMediaDurationMinutes],
  /// 60분) 기준으로 원본 추출 해상도(100ms/샘플)를 그대로 유지하려면 36,000개가
  /// 필요하다 — 여유를 둬서 60,000으로 올린다(60분 파일까지는 정확히 100ms 해상도,
  /// 118분 같은 스펙 밖 파일도 356ms→~119ms로 3배 개선).
  static const _maxStoredWaveformPoints = 60000;

  @override
  Future<String> registerLocalMedia({
    required String localFilePath,
    required String fileName,
    String? subtitleFilePath,
    String? mediaId,
    required void Function(double progress) onProgress,
  }) async {
    // 순수 로컬 I/O(파일 등록) 진행률 시뮬레이션 — 네트워크 업로드가 아니므로 실제로는
    // 거의 즉시 끝나지만, #2 화면의 진행 인디케이터가 뚝뚝 끊기지 않도록 짧게 유지한다.
    debugPrint('[registerLocalMedia] start file=$fileName path=$localFilePath');
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      onProgress(i / steps);
    }
    debugPrint('[registerLocalMedia] progress loop done, about to setJson');

    final resolvedMediaId = mediaId ?? 'local-${_uuid.v4()}';
    await _store.setJson(_mediaMetaKey(resolvedMediaId), {
      'localFilePath': localFilePath,
      'fileName': fileName,
      'subtitleFilePath': subtitleFilePath,
    });
    debugPrint('[registerLocalMedia] setJson done, mediaId=$resolvedMediaId');
    return resolvedMediaId;
  }

  @override
  Future<String> requestSegmentation(String mediaId) async {
    final jobId = 'job-${_uuid.v4()}';
    await _store.setJson(_jobMediaKey(jobId), {'mediaId': mediaId});
    return jobId;
  }

  @override
  Stream<SegmentationJobStatus> watchJobStatus(String jobId) async* {
    final jobMeta = await _store.getJson<Map<String, dynamic>>(
      _jobMediaKey(jobId),
      (decoded) => decoded as Map<String, dynamic>,
    );
    final mediaId = jobMeta?['mediaId'] as String? ?? '';

    final mediaMeta = await _store.getJson<Map<String, dynamic>>(
      _mediaMetaKey(mediaId),
      (decoded) => decoded as Map<String, dynamic>,
    );
    final subtitleFilePath = mediaMeta?['subtitleFilePath'] as String?;
    final localFilePath = mediaMeta?['localFilePath'] as String?;

    yield SegmentationJobStatus(
      jobId: jobId,
      mediaId: mediaId,
      state: SegmentationJobState.processing,
      progress: 0,
    );

    List<SentenceSegment> segments;
    SegmentationFailureReason? failureReason;

    if (subtitleFilePath != null) {
      // ── 영상 + 자막 경로: 파일 파싱은 사실상 즉시 끝나지만, 진행 중임을 보여줄
      // 최소한의 지연만 둔다.
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final content = await File(subtitleFilePath).readAsString();
        final cues = parseSubtitleFile(content, fileNameOrExt: subtitleFilePath);
        segments = [
          for (final cue in cues)
            SentenceSegment(
              id: '$mediaId-seg-${cue.index}',
              mediaId: mediaId,
              index: cue.index,
              text: cue.text,
              startMs: cue.startMs,
              endMs: cue.endMs,
            ),
        ];
      } catch (_) {
        failureReason = SegmentationFailureReason.unsupportedSubtitleFormat;
        segments = const [];
      }
    } else if (localFilePath == null || localFilePath.startsWith('asset:///')) {
      // ── 음성만 경로, 번들 asset(샘플MP3 체험하기): 네이티브 디코더가 asset을 직접
      // 읽을 수 없고, 이 플레이스홀더 자체가 발화 없는 무음 PCM이라 분석 의미도 없다 —
      // 기존 타이밍 시뮬레이션을 그대로 쓴다.
      const steps = 10;
      for (var i = 1; i <= steps; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        yield SegmentationJobStatus(
          jobId: jobId,
          mediaId: mediaId,
          state: SegmentationJobState.processing,
          progress: i / steps,
        );
      }
      segments = buildMockSilenceSegments(mediaId);
      if (segments.isEmpty) {
        failureReason = SegmentationFailureReason.noClearSilenceDetected;
      }
    } else {
      // ── 음성만 경로, 실제 기기 파일: 진짜 amplitude 분석(SilenceDetector).
      //
      // 2026-08-06: 예전엔 여기서 30% → (detect() 끝날 때까지 그대로 멈춤) → 90%로
      // 딱 두 번만 진행률을 찍었다. 긴 실제 파일(118분짜리)은 이 "멈춤" 구간이 실제로
      // 10분 넘게 걸릴 수 있는데, 화면은 30%에서 그대로 굳어있으니 사용자가 "멈췄다"고
      // 오해하고 이탈했다. `SilenceDetector.detect()`는 진행률 콜백이 없는 단발성
      // Future라 진짜 진행률은 알 수 없지만, "천천히라도 계속 올라가는" 진행률 표시가
      // 사용자에게 "죽지 않고 일하고 있다"는 신호를 주므로, 실제 작업(`detect()`)과
      // 별도로 30%→95% 사이를 점근적으로(시간이 지날수록 점점 느리게) 채워주는 가짜
      // 진행률 타이머를 함께 돌린다. `detect()`가 끝나면 즉시 90%로 스냅한다 — 95%에서
      // 멈춰있다가 갑자기 100%로 뛰는 것보다 자연스럽다.
      //
      // 2026-08-07: 본 분석(`detect()`)을 시작하기 전에 길이만 먼저 빠르게 프로브해서
      // (118분 파일 기준 1초 미만) 이 파일에 맞는 예상 소요시간을 계산해 첫 상태부터
      // 실어 보낸다 — #3 화면이 "보통 10분당 약 X초"라는 두루뭉술한 문구 대신 "약 N분
      // 정도 걸려요"처럼 구체적으로 안내할 수 있다. 프로브한 길이는 `detect()`에도
      // 그대로 넘겨 다시 프로브하지 않게 한다.
      const detector = SilenceDetector();
      final probedDurationMs = await detector.probeDurationMs(localFilePath);
      final estimatedTotalSeconds = probedDurationMs > 0
          ? (probedDurationMs / 1000 / 600) * AppConstants.estimatedLocalSegmentationSecondsPer10Min
          : null;
      if (estimatedTotalSeconds != null) {
        yield SegmentationJobStatus(
          jobId: jobId,
          mediaId: mediaId,
          state: SegmentationJobState.processing,
          progress: 0.3,
          estimatedTotalSeconds: estimatedTotalSeconds,
        );
      }

      final detectFuture = detector
          .detect(
            mediaId: mediaId,
            localFilePath: localFilePath,
            knownDurationMs: probedDurationMs > 0 ? probedDurationMs : null,
          )
          .timeout(const Duration(minutes: AppConstants.silenceDetectionTimeoutMinutes));
      var detectDone = false;
      var timedOut = false;
      SilenceDetectionResult? detectionResult;
      unawaited(detectFuture.then((r) {
        detectionResult = r;
        detectDone = true;
      }).catchError((_) {
        detectDone = true;
        timedOut = true;
      }));

      final sw = Stopwatch()..start();
      while (!detectDone) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (detectDone) break;
        final elapsedSec = sw.elapsedMilliseconds / 1000;
        // 점근 곡선: AppConstants.progressTimeConstantSeconds 지날 때마다 남은 거리의
        // 63%씩 채워나가다가 0.95에서 사실상 멈춘다(완료 전엔 100%를 절대 보여주지 않음).
        final t = elapsedSec / AppConstants.progressTimeConstantSeconds;
        final fakeProgress = 0.3 + 0.65 * (1 - math.exp(-t));
        yield SegmentationJobStatus(
          jobId: jobId,
          mediaId: mediaId,
          state: SegmentationJobState.processing,
          progress: fakeProgress.clamp(0.3, 0.95),
          estimatedTotalSeconds: estimatedTotalSeconds,
        );
      }

      if (!timedOut) {
        try {
          detectionResult ??= await detectFuture;
        } catch (_) {
          timedOut = true;
        }
      }
      if (timedOut || detectionResult == null) {
        // 화면 꺼짐/백그라운드 절전으로 멈췄든 디코더 자체가 정말 오래 걸리든, 사용자
        // 입장에서는 똑같이 "재시도 가능한 실패"로 보여주는 게 무한 로딩보다 낫다.
        segments = const [];
        failureReason = SegmentationFailureReason.unknown;
      } else {
        segments = detectionResult!.segments;
        if (segments.isNotEmpty) {
          // 문장별 파형 표시(#4/#5 화면)가 이미 계산해둔 이 진폭 배열을 재사용할 수
          // 있도록 저장해둔다 — 파일을 다시 디코딩하지 않는다.
          await _storeWaveform(mediaId, detectionResult!.amplitudes, detectionResult!.durationMs);
        }
      }
      yield SegmentationJobStatus(
        jobId: jobId,
        mediaId: mediaId,
        state: SegmentationJobState.processing,
        progress: 0.9,
      );
      if (segments.isEmpty && failureReason == null) {
        failureReason = SegmentationFailureReason.noClearSilenceDetected;
      }
    }

    if (failureReason != null) {
      yield SegmentationJobStatus(
        jobId: jobId,
        mediaId: mediaId,
        state: SegmentationJobState.failed,
        progress: 1,
        failureReason: failureReason,
        errorMessage: switch (failureReason) {
          SegmentationFailureReason.unsupportedSubtitleFormat => '지원하지 않는 자막 형식이에요 (SRT/VTT/SMI만 가능해요)',
          SegmentationFailureReason.noClearSilenceDetected => '뚜렷한 무음 구간을 찾지 못했어요',
          SegmentationFailureReason.unknown => '문장을 나누는 중 문제가 발생했어요',
        },
      );
      return;
    }

    await _store.setJson(_segmentsKey(mediaId), segments.map((e) => e.toJson()).toList());
    yield SegmentationJobStatus(
      jobId: jobId,
      mediaId: mediaId,
      state: SegmentationJobState.succeeded,
      progress: 1,
    );
  }

  @override
  Future<List<SentenceSegment>> getSegments(String mediaId) async {
    final cached = await _store.getJson<List<SentenceSegment>>(
      _segmentsKey(mediaId),
      (decoded) =>
          (decoded as List).map((e) => SentenceSegment.fromJson(e as Map<String, dynamic>)).toList(),
    );
    if (cached != null) return cached;

    // 캐시가 아직 없는 경우(예: "샘플로 체험하기"처럼 registerLocalMedia를 거치지 않고
    // 곧바로 requestSegmentation부터 시작하는 데모 경로) — 등록된 자막 여부로 폴백을 고른다.
    final mediaMeta = await _store.getJson<Map<String, dynamic>>(
      _mediaMetaKey(mediaId),
      (decoded) => decoded as Map<String, dynamic>,
    );
    final hasSubtitle = mediaMeta?['subtitleFilePath'] != null;
    return hasSubtitle ? buildMockSubtitleSentences(mediaId) : buildMockSilenceSegments(mediaId);
  }

  @override
  Future<void> saveEditedSegments(String mediaId, List<SentenceSegment> segments) async {
    await Future.delayed(const Duration(milliseconds: 150));
    await _store.setJson(_segmentsKey(mediaId), segments.map((e) => e.toJson()).toList());
  }

  Future<void> _storeWaveform(String mediaId, List<double> amplitudes, int durationMs) async {
    final downsampled = _resample(amplitudes, _maxStoredWaveformPoints.clamp(1, amplitudes.length));
    await _store.setJson(_waveformKey(mediaId), {
      'durationMs': durationMs,
      'amplitudes': downsampled,
    });
  }

  @override
  Future<List<double>> getWaveformForSegment(
    String mediaId, {
    required int startMs,
    required int endMs,
    int barCount = 64,
  }) async {
    final stored = await _store.getJson<Map<String, dynamic>>(
      _waveformKey(mediaId),
      (decoded) => decoded as Map<String, dynamic>,
    );
    if (stored == null) return const []; // 저장된 실측 파형이 없음 — 호출측이 장식용으로 폴백.

    final durationMs = stored['durationMs'] as int;
    final amplitudes = (stored['amplitudes'] as List).cast<num>().map((e) => e.toDouble()).toList();
    if (durationMs <= 0 || amplitudes.isEmpty) return const [];

    final msPerSample = durationMs / amplitudes.length;
    final startIdx = (startMs / msPerSample).floor().clamp(0, amplitudes.length - 1);
    final endIdx = (endMs / msPerSample).ceil().clamp(startIdx + 1, amplitudes.length);
    final slice = amplitudes.sublist(startIdx, endIdx);
    return _resample(slice, barCount);
  }

  /// [values]를 정확히 [targetCount]개로 리샘플링한다 — 줄일 때는 구간별 최댓값을
  /// 남긴다(발화 피크가 뭉개지지 않게), 늘릴 때는 가장 가까운 원본 값을 그대로 반복.
  List<double> _resample(List<double> values, int targetCount) {
    if (values.isEmpty || targetCount <= 0) return const [];
    if (values.length == targetCount) return values;

    final result = <double>[];
    for (var i = 0; i < targetCount; i++) {
      if (values.length > targetCount) {
        final start = (i * values.length / targetCount).floor();
        final end = ((i + 1) * values.length / targetCount).ceil().clamp(start + 1, values.length);
        result.add(values.sublist(start, end).reduce((a, b) => a > b ? a : b));
      } else {
        result.add(values[(i * values.length / targetCount).floor().clamp(0, values.length - 1)]);
      }
    }
    return result;
  }
}
