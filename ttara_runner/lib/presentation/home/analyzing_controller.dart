import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/segmentation_job.dart';
import '../providers/repository_providers.dart';

enum AnalyzingPhase { processing, succeeded, failed }

class AnalyzingState {
  final AnalyzingPhase phase;
  final double progress;
  final String? errorMessage;
  // 2026-08-07: 이 파일 길이에 맞는 예상 총 소요시간(초) — 알려지면 채워진다.
  final double? estimatedTotalSeconds;

  const AnalyzingState({
    this.phase = AnalyzingPhase.processing,
    this.progress = 0,
    this.errorMessage,
    this.estimatedTotalSeconds,
  });

  AnalyzingState copyWith({
    AnalyzingPhase? phase,
    double? progress,
    String? errorMessage,
    double? estimatedTotalSeconds,
  }) {
    return AnalyzingState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      estimatedTotalSeconds: estimatedTotalSeconds ?? this.estimatedTotalSeconds,
    );
  }
}

/// mediaId별 컨트롤러. **의도적으로 autoDispose를 쓰지 않는다** — #3 화면 설계 원칙
/// "화면을 벗어나도 홈에 진행 중 카드로 표시되어 처리 계속됨(비차단형 대기)"을 만족하려면
/// 사용자가 뒤로 가거나 "백그라운드에서 계속"을 눌러도 처리가 이어져야 하기 때문.
final analyzingControllerProvider =
    StateNotifierProvider.family<AnalyzingController, AnalyzingState, String>(
        (ref, mediaId) => AnalyzingController(ref, mediaId));

/// #3 문장 분리 중 화면 뷰모델. 로컬 분리 요청(자막 파싱 또는 무음 감지) → 진행률
/// 관찰 → 완료 시 로컬 [MediaItem]을 ready로 갱신. 실패 시 "다시 시도" 경로를
/// 위해 [retry] 노출. 2026-08-05 STT 폐기 이후 이 흐름은 네트워크를 전혀 타지 않는다.
class AnalyzingController extends StateNotifier<AnalyzingState> {
  final Ref ref;
  final String mediaId;

  AnalyzingController(this.ref, this.mediaId) : super(const AnalyzingState()) {
    _start();
  }

  Future<void> _start() async {
    state = const AnalyzingState(phase: AnalyzingPhase.processing);
    try {
      final segRepo = ref.read(segmentationRepositoryProvider);
      final jobId = await segRepo.requestSegmentation(mediaId);

      await for (final status in segRepo.watchJobStatus(jobId)) {
        state = state.copyWith(progress: status.progress, estimatedTotalSeconds: status.estimatedTotalSeconds);
        await _updateMediaProgress(status.progress);

        if (status.state == SegmentationJobState.succeeded) {
          final segments = await segRepo.getSegments(mediaId);
          final current = await ref.read(mediaRepositoryProvider).getById(mediaId);
          if (current != null) {
            await ref.read(mediaRepositoryProvider).save(current.copyWith(
                  status: MediaStatus.ready,
                  sentenceCount: segments.length,
                  analysisProgress: 1,
                ));
          }
          state = state.copyWith(phase: AnalyzingPhase.succeeded, progress: 1);
          return;
        }
        if (status.state == SegmentationJobState.failed) {
          await _markFailed(status.errorMessage);
          return;
        }
      }
    } catch (_) {
      await _markFailed(null);
    }
  }

  Future<void> _updateMediaProgress(double progress) async {
    final current = await ref.read(mediaRepositoryProvider).getById(mediaId);
    if (current != null) {
      await ref.read(mediaRepositoryProvider).save(current.copyWith(analysisProgress: progress));
    }
  }

  Future<void> _markFailed(String? message) async {
    final current = await ref.read(mediaRepositoryProvider).getById(mediaId);
    if (current != null) {
      await ref.read(mediaRepositoryProvider).save(current.copyWith(status: MediaStatus.failed));
    }
    state = state.copyWith(phase: AnalyzingPhase.failed, errorMessage: message ?? '문장을 나누는 중 문제가 발생했어요');
  }

  void retry() => _start();
}
