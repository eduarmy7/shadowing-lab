import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../common_widgets/boundary_handle.dart';
import '../common_widgets/primary_button.dart';
import '../common_widgets/sentence_card.dart';
import '../common_widgets/waveform_player.dart';
import '../providers/repository_providers.dart';
import 'segmentation_review_controller.dart';

/// **단일 문장 편집 화면.**
///
/// 원래는 #4 목록형 확인 화면(전체 문장을 한꺼번에 보여주고 "N개 문장으로 시작"을
/// 눌러야 학습이 시작되는 화면)의 카드에서 진입했으나, 문장이 수백~수천 개인
/// 콘텐츠는 학습 시작 전에 전부 확인/확정하는 게 불가능해서 그 화면 자체를 없앴다
/// (2026-08-06). 지금은 #5 학습 화면(단일/목록 보기 모두)에서 지금 보고 있는 문장을
/// 바로 이 화면으로 넘겨 편집한다 — 학습하다가 이상한 문장을 만나면 그 자리에서
/// 고치고 저장한 뒤 계속 이어서 학습하는 흐름.
///
/// **분리 UX가 기존과 다르다**: 예전엔 "분리" 버튼을 누르면 무조건 정확히 반으로
/// 잘렸다. 이제는 "분리" 버튼을 누르면 파형 위에 (경계 핸들과 다른 색의) 분리 마커가
/// 나타나고, 사용자가 원하는 위치로 드래그한 뒤 "이 위치에서 분리"를 눌러야 실제로
/// 나뉜다 — 마커 앞은 그대로 현재 번호, 마커 뒤는 새 문장으로 삽입되고 이후 문장
/// 번호가 전부 하나씩 밀린다(`SegmentationReviewController._reindex`가 이미 처리).
class SentenceEditScreen extends ConsumerStatefulWidget {
  final String mediaId;
  final int initialIndex;
  const SentenceEditScreen({super.key, required this.mediaId, required this.initialIndex});

  @override
  ConsumerState<SentenceEditScreen> createState() => _SentenceEditScreenState();
}

class _SentenceEditScreenState extends ConsumerState<SentenceEditScreen> {
  late int _index;
  bool _isPlaying = false;
  bool _isSplitMode = false;
  double _splitFraction = 0.5;
  // 2026-08-06: 한 문장씩 보기와 동일하게, 파형 위 재생 위치를 고정값(0.4) 대신
  // 실제 재생 진행률로 보여준다.
  double _playbackProgress = 0;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  /// 2026-08-06 추가 — 미리듣기 중 바로 멈출 수 있는 정지 버튼용.
  Future<void> _stop() async {
    await _positionSub?.cancel();
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _preview(SentenceSegment segment) async {
    setState(() {
      _isPlaying = true;
      _playbackProgress = 0;
    });
    final media = await ref.read(mediaRepositoryProvider).getById(widget.mediaId);
    if (media == null) return;
    final player = ref.read(audioPlayerServiceProvider);
    final segmentDurationMs = segment.durationMs.clamp(1, 1 << 31);
    try {
      await player.setSource(media.localPath, isLocal: true);
      await _positionSub?.cancel();
      _positionSub = player.positionStream.listen((pos) {
        if (!mounted) return;
        final ratio = ((pos.inMilliseconds - segment.startMs) / segmentDurationMs).clamp(0.0, 1.0);
        setState(() => _playbackProgress = ratio);
      });
      await player.playSegmentOnce(startMs: segment.startMs, endMs: segment.endMs);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, AppLocalizations.of(context)!.previewPlaybackError, type: AppToastType.error);
      }
    } finally {
      await _positionSub?.cancel();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  /// 2026-08-07: 정지 버튼으로 원하는 지점에서 멈춘 뒤 "분리"를 누르면, 그 지점을
  /// 다시 눈대중으로 찾아 드래그할 필요 없이 분리 마커(빨간선)가 곧바로 그 위치에서
  /// 시작하게 한다 — "재생을 듣다가 정지한 바로 그 지점에서 나누고 싶다"는 요청의
  /// 핵심(빨간선을 정지 지점에 맞추는 수고를 없애는 것)이라 기본값을 여기서 정한다.
  /// 아직 한 번도 재생 안 했거나(0) 끝까지 다 들은 경우(1)는 의미 있는 지점이
  /// 아니므로 기존처럼 중앙(0.5)에서 시작한다.
  void _startSplitMode() => setState(() {
        _isSplitMode = true;
        _splitFraction =
            (_playbackProgress > 0 && _playbackProgress < 1) ? _playbackProgress.clamp(0.03, 0.97) : 0.5;
      });

  void _cancelSplitMode() => setState(() => _isSplitMode = false);

  Future<void> _confirmSplit(SegmentationReviewController controller, SentenceSegment segment) async {
    final splitMs = segment.startMs + (segment.durationMs * _splitFraction).round();
    debugPrint('[_confirmSplit] segmentId=${segment.id} startMs=${segment.startMs} endMs=${segment.endMs} '
        'splitFraction=$_splitFraction splitMs=$splitMs');
    // 2026-08-07: splitSegmentAt이 실패(너무 짧은 문장/단어 1개)하면 이제 false를
    // 반환한다 — 예전엔 반환값 자체가 없어서 실패해도 "문장을 나눴어요" 성공 토스트가
    // 그대로 떴다(실제로는 예외로 죽어서 그마저도 안 뜨는 경우도 있었다). 실패 시엔
    // 분리 모드를 유지해서 사용자가 다른 위치를 다시 골라볼 수 있게 한다.
    final success = controller.splitSegmentAt(segment.id, splitMs);
    if (!success) {
      if (mounted) {
        AppToast.show(context, AppLocalizations.of(context)!.sentenceTooShortToSplit, type: AppToastType.error);
      }
      return;
    }
    setState(() => _isSplitMode = false);
    if (mounted) AppToast.show(context, AppLocalizations.of(context)!.sentenceSplitSuccess, type: AppToastType.success);
  }

  Future<void> _merge(SegmentationReviewController controller, SentenceSegment segment) async {
    controller.mergeWithNext(segment.id);
    if (mounted) {
      AppToast.show(context, AppLocalizations.of(context)!.sentenceMergedSuccess, type: AppToastType.success);
    }
  }

  /// 2026-08-06: 경계 드래그/스테퍼는 더 이상 자동저장되지 않는다 — 사용자가 길이를
  /// 몇 번이고 조정해본 뒤, 마음에 들 때 이 버튼을 눌러야 실제로 저장된다.
  Future<void> _save(SegmentationReviewController controller) async {
    await controller.commitBoundaryEdit();
    if (mounted) {
      AppToast.show(context, AppLocalizations.of(context)!.sentenceLengthSaved, type: AppToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(segmentationReviewProvider(widget.mediaId));
    final controller = ref.read(segmentationReviewProvider(widget.mediaId).notifier);
    final l10n = AppLocalizations.of(context)!;

    if (state.isLoading || state.segments.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index = _index.clamp(0, state.segments.length - 1);
    final segment = state.segments[index];
    final hasNext = index < state.segments.length - 1;
    final hasPrev = index > 0;

    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(icon: const Icon(Icons.close), tooltip: l10n.finishEditingTooltip, onPressed: () => context.pop()),
        title: Text(l10n.sentenceEditTitle(index + 1, state.segments.length)),
        actions: [
          // 2026-08-06: 경계 드래그/스테퍼는 자동저장되지 않으므로, 길이 조정을 다 마친
          // 뒤 이 버튼을 눌러야 저장된다 — 항상 보이는 별도 버튼으로 명확하게 노출.
          TextButton.icon(
            onPressed: () => _save(controller),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.saveButton),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SentenceCard(
                    key: ValueKey(segment.id),
                    variant: SentenceCardVariant.learning,
                    segment: segment,
                  ),
                ),
              ),
              // 2026-08-06: 경계를 드래그해도 화면 어디에도 바뀐 시간이 안 보인다는
              // 피드백 — 학습형 SentenceCard(#4-상세용)는 원래 타임스탬프를 표시하지
              // 않고(목록형에만 있음), 초 단위 반올림([Formatters.msToClock])도 1~2초짜리
              // 문장에서는 드래그 결과가 거의 안 바뀐 것처럼 보이므로, 0.1초 단위로
              // 여기에만 별도 표시한다.
              Text(
                l10n.durationRangePrecise(
                  Formatters.msToClockPrecise(segment.startMs),
                  Formatters.msToClockPrecise(segment.endMs),
                  (segment.durationMs / 1000).toStringAsFixed(1),
                ),
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 2026-08-06: 좌우 경계 핸들이 화면 가장자리에 너무 가까이 있으면
              // (screenMargin 20dp만으로는 부족) 안드로이드 제스처 내비게이션의
              // "가장자리에서 스와이프 = 뒤로가기" 인식 영역과 겹친다 — 실제로 에뮬레이터에서
              // 왼쪽 핸들을 드래그하려다 화면이 통째로 닫히는 현상으로 재현됨. 핸들이 항상
              // 화면 진짜 가장자리에서 충분히(즉 뒤로가기 인식 영역 밖으로) 떨어져 있도록
              // 이 위젯에만 추가 여백을 둔다.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _EditWaveform(
                  key: ValueKey(segment.id),
                  mediaId: widget.mediaId,
                  segment: segment,
                  isPlaying: _isPlaying,
                  playbackProgress: _playbackProgress,
                  isSplitMode: _isSplitMode,
                  splitFraction: _splitFraction,
                  onDragLeft: (deltaMs) => controller.adjustBoundary(segment.id, HandleSide.left, deltaMs),
                  onDragRight: (deltaMs) => controller.adjustBoundary(segment.id, HandleSide.right, deltaMs),
                  onBoundaryDragEnd: (side) => controller.finalizeBoundaryDrag(segment.id, side),
                  onNudgeLeft: (inc) => controller.nudgeBoundary(segment.id, HandleSide.left, increase: inc),
                  onNudgeRight: (inc) => controller.nudgeBoundary(segment.id, HandleSide.right, increase: inc),
                  onSplitFractionChanged: (f) => setState(() => _splitFraction = f),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isSplitMode)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _cancelSplitMode, child: Text(l10n.cancel)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: l10n.splitAtThisPosition,
                        onPressed: () => _confirmSplit(controller, segment),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasNext ? () => _merge(controller, segment) : null,
                        icon: const Icon(Icons.call_merge, size: 18),
                        label: Text(l10n.mergeWithNextSentence),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startSplitMode,
                        icon: const Icon(Icons.call_split, size: 18),
                        label: Text(l10n.splitButton),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    tooltip: l10n.previousSentenceTooltip,
                    onPressed: hasPrev ? () => setState(() { _index--; _isSplitMode = false; }) : null,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: l10n.playListenLabel,
                        child: IconButton.filled(
                          icon: Icon(_isPlaying ? Icons.volume_up : Icons.play_arrow),
                          iconSize: 28,
                          onPressed: () => _preview(segment),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // 2026-08-06 추가: 편집 화면에도 미리듣기를 바로 멈출 수 있는 정지
                      // 버튼을 뒀다(학습 화면들과 동일한 패턴).
                      Semantics(
                        button: true,
                        label: l10n.stopLabel,
                        child: IconButton.filled(
                          icon: const Icon(Icons.stop_rounded),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: _isPlaying ? _stop : null,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    tooltip: l10n.nextSentenceTooltip,
                    onPressed: hasNext ? () => setState(() { _index++; _isSplitMode = false; }) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2026-08-06 재작성: 예전 구현은 좌우 핸들을 `Row`의 양 끝 칸에 고정 배치했다 —
/// 드래그해도 핸들 자체는 화면 위에서 단 1px도 움직이지 않고(내부적으로 ms는
/// 바뀌지만 위치·색상 어느 것도 반영 안 됨), `SentenceCard`(learning variant)에는
/// 애초에 타임스탬프 표시가 없어서 사용자 입장에서는 "드래그가 안 먹는다"로 보일
/// 수밖에 없었다(실제 버그 리포트: "경계 드래그가 안됨").
///
/// 지금은 문장 앞뒤로 여백([_pad])을 둔 고정 시간창(`_windowStartMs~_windowEndMs`)을
/// 하나의 트랙으로 놓고, 그 트랙 위에서 좌우 핸들을 실제 비율 위치에 `Positioned`로
/// 배치한다 — 드래그하면 핸들이 트랙 위에서 실제로 슬라이드하고, 선택 밖 영역은
/// 어둡게 처리해 "지금 문장으로 잡힌 범위"가 눈에 보인다. 창은 문장이 바뀔 때만
/// (`didUpdateWidget`) 다시 계산하고 드래그 중에는 고정해서, 트랙이 드래그 도중
/// 다시 가운데 정렬되며 튀는 것을 막는다.
class _EditWaveform extends StatefulWidget {
  final String mediaId;
  final SentenceSegment segment;
  final bool isPlaying;
  final double playbackProgress; // 0.0~1.0, 문장 구간 안에서의 실제 재생 위치
  final bool isSplitMode;
  final double splitFraction;
  final ValueChanged<int> onDragLeft; // ms 델타(누적 아님, 프레임당)
  final ValueChanged<int> onDragRight;
  // 2026-08-07 추가: 드래그를 놓았을 때 이웃 문장과의 간격이 가까우면 붙이는
  // "무음구간 자동 스냅"을 여기서 트리거한다 — 드래그 도중에는 더 이상 스냅하지
  // 않는다(계속 원위치로 튕겨나가 전혀 못 움직이던 버그의 원인이었다).
  final ValueChanged<HandleSide> onBoundaryDragEnd;
  final ValueChanged<bool> onNudgeLeft;
  final ValueChanged<bool> onNudgeRight;
  final ValueChanged<double> onSplitFractionChanged;

  const _EditWaveform({
    super.key,
    required this.mediaId,
    required this.segment,
    required this.isPlaying,
    required this.playbackProgress,
    required this.isSplitMode,
    required this.splitFraction,
    required this.onDragLeft,
    required this.onDragRight,
    required this.onBoundaryDragEnd,
    required this.onNudgeLeft,
    required this.onNudgeRight,
    required this.onSplitFractionChanged,
  });

  @override
  State<_EditWaveform> createState() => _EditWaveformState();
}

class _EditWaveformState extends State<_EditWaveform> {
  static const _handleWidth = 28.0;

  late int _windowStartMs;
  late int _windowEndMs;
  HandleSide? _draggingSide;
  double? _splitDragAccumFraction; // 분리 마커 드래그 중 로컬 누적값 — 위 _buildSplitMarker 참고.

  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  @override
  void didUpdateWidget(covariant _EditWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 같은 문장을 계속 드래그하는 동안에는 창을 고정한다 — segment.id가 바뀔 때(이전/다음
    // 문장으로 이동)만 새 문장 기준으로 창을 다시 잡는다.
    if (oldWidget.segment.id != widget.segment.id) _initWindow();
  }

  /// 2026-08-06: 예전엔 여백(pad)이 문장 길이의 60%(최대 4초)나 돼서, 경계 막대가
  /// 트랙 양 끝이 아니라 트랙의 27~73% 지점(사실상 가운데 근처)에 찍혔다 —
  /// "문장 앞뒤를 나타내는 막대가 맨 앞/맨 뒤에 있어야 하는데 중간에 있다"는 피드백의
  /// 원인. 이제 여백을 훨씬 작게(문장 길이의 8%, 최대 400ms) 줄여서 막대가 트랙
  /// 거의 맨 끝에 붙어 보이게 하면서도, 바깥으로 살짝 드래그해 늘릴 여지는 남겨둔다.
  void _initWindow() {
    final pad = (widget.segment.durationMs * 0.08).round().clamp(80, 400);
    _windowStartMs = (widget.segment.startMs - pad).clamp(0, 1 << 31);
    _windowEndMs = widget.segment.endMs + pad;
  }

  double _ratioOf(int ms) {
    final windowMs = _windowEndMs - _windowStartMs;
    if (windowMs <= 0) return 0;
    return ((ms - _windowStartMs) / windowMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final windowMs = (_windowEndMs - _windowStartMs).toDouble();
              final leftX = _ratioOf(widget.segment.startMs) * width;
              final rightX = _ratioOf(widget.segment.endMs) * width;
              int pxToMs(double px) => (px / width * windowMs).round();

              return Stack(
                children: [
                  Positioned.fill(
                    // 2026-08-06: 무음 감지 때 이미 뽑아둔 실측 진폭이 있으면(로컬 업로드
                    // 파일만) 트랙 창(_windowStartMs~_windowEndMs) 전체 구간을 잘라와
                    // 진짜 파형을 그린다 — 자막 파싱 경로처럼 실측 데이터가 없으면
                    // WaveformPlayer가 알아서 장식용 표시로 폴백한다.
                    child: Consumer(
                      builder: (context, ref, _) {
                        final waveform = ref.watch(segmentWaveformProvider(
                          (mediaId: widget.mediaId, startMs: _windowStartMs, endMs: _windowEndMs),
                        ));
                        return WaveformPlayer(
                          seed: widget.segment.id,
                          variant: WaveformVariant.expanded,
                          isPlaying: widget.isPlaying,
                          // 2026-08-07: 예전엔 재생 중이 아니면(정지 버튼을 누른 직후 포함)
                          // 무조건 0으로 되돌려서, 정지한 지점의 파형 표시가 사라지고 맨
                          // 처음으로 튀어버렸다 — "정지를 누르면 그 지점에서 파형이 멈춰
                          // 있어야 위치를 보고 분리선을 맞출 수 있다"는 요청과 정반대였다.
                          // `_playbackProgress`는 정지해도 마지막 값을 그대로 들고 있으니
                          // (재생 시작 시에만 0으로 리셋됨) 그냥 그 값을 쓰면 정지 지점에
                          // 그대로 멈춰 보인다.
                          progressRatio: widget.playbackProgress,
                          amplitudes: waveform.valueOrNull,
                        );
                      },
                    ),
                  ),
                  // 선택 밖(문장 시작 이전 / 끝 이후) 구간을 어둡게 표시해 지금 문장
                  // 범위가 트랙 위에서 눈에 보이게 한다.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: leftX,
                    child: IgnorePointer(child: Container(color: scheme.surface.withValues(alpha: 0.65))),
                  ),
                  Positioned(
                    left: rightX,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(child: Container(color: scheme.surface.withValues(alpha: 0.65))),
                  ),
                  if (widget.isSplitMode)
                    _buildSplitMarker(context, width)
                  else ...[
                    _buildBoundaryHandle(
                      side: HandleSide.left,
                      x: leftX,
                      width: width,
                      onDragDelta: (dxPx) => widget.onDragLeft(pxToMs(dxPx)),
                      onNudge: widget.onNudgeLeft,
                    ),
                    _buildBoundaryHandle(
                      side: HandleSide.right,
                      x: rightX,
                      width: width,
                      onDragDelta: (dxPx) => widget.onDragRight(pxToMs(dxPx)),
                      onNudge: widget.onNudgeRight,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.isSplitMode
              ? AppLocalizations.of(context)!.splitDragInstruction
              : AppLocalizations.of(context)!.boundaryDragInstruction,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBoundaryHandle({
    required HandleSide side,
    required double x,
    required double width,
    required ValueChanged<double> onDragDelta,
    required ValueChanged<bool> onNudge,
  }) {
    return Positioned(
      left: (x - _handleWidth / 2).clamp(0, (width - _handleWidth).clamp(0, double.infinity)),
      top: 0,
      bottom: 0,
      width: _handleWidth,
      child: BoundaryHandle(
        side: side,
        isDragging: _draggingSide == side,
        onDragStart: () => setState(() => _draggingSide = side),
        onDragDelta: onDragDelta,
        onDragEnd: () {
          setState(() => _draggingSide = null);
          widget.onBoundaryDragEnd(side);
        },
        onIncrease: () => onNudge(true),
        onDecrease: () => onNudge(false),
      ),
    );
  }

  Widget _buildSplitMarker(BuildContext context, double width) {
    final markerLeft = width * widget.splitFraction;
    return Positioned(
      left: (markerLeft - 12).clamp(0, width - 24),
      top: 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // 2026-08-07 버그 수정: 예전엔 매 드래그 이벤트마다 "빌드 시점에 캡처해둔
        // markerLeft(=widget.splitFraction*width)에 이번 delta만 더하기"를 했는데,
        // 빠르게 연속으로 손가락을 움직이면 부모의 setState→리빌드가 그 속도를 못
        // 따라가서, 리빌드 전에 여러 드래그 이벤트가 도착하면 매번 "같은" 오래된
        // markerLeft에서 다시 계산해 앞선 이벤트들의 이동분이 사라졌다 — 그 결과
        // 빨간 막대가 손가락보다 느리게(끊기듯) 따라왔다. 리빌드 타이밍과 무관하게
        // 이 위젯 자신의 로컬 상태([_splitDragAccumFraction])에 계속 누적해서, 매
        // 이벤트가 항상 "방금 직전 이벤트"를 기준으로 이어지게 한다.
        onHorizontalDragStart: (_) => _splitDragAccumFraction = widget.splitFraction,
        onHorizontalDragUpdate: (details) {
          final base = _splitDragAccumFraction ?? widget.splitFraction;
          final next = (base + details.delta.dx / width).clamp(0.03, 0.97);
          _splitDragAccumFraction = next;
          widget.onSplitFractionChanged(next);
        },
        onHorizontalDragEnd: (_) => _splitDragAccumFraction = null,
        child: SizedBox(
          width: 24,
          child: Center(
            child: Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                // 시작/끝 경계 핸들(primary색)과 구분되도록 강조색 사용.
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
