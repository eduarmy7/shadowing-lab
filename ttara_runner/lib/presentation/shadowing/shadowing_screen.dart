import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../common_widgets/circle_icon_button.dart';
import '../common_widgets/repeat_dot_indicator.dart';
import '../common_widgets/sentence_card.dart';
import '../common_widgets/waveform_player.dart';
import '../providers/repository_providers.dart';
import 'shadowing_controller.dart';
import 'shadowing_options_sheet.dart';

/// #5 쉐도잉 학습 화면 — 앱의 심장. 화면에는 딱 4가지만: 문장 카드, 반복 진행 상태,
/// 재생/말하기 전환 원형 트리거(녹음은 하지 않음 — 재생↔말하기 단계 표시용), 최소
/// 보조 컨트롤. 광고·알림 절대 없음(01_ux_design.md).
class ShadowingScreen extends ConsumerStatefulWidget {
  final String mediaId;

  const ShadowingScreen({super.key, required this.mediaId});

  @override
  ConsumerState<ShadowingScreen> createState() => _ShadowingScreenState();
}

class _ShadowingScreenState extends ConsumerState<ShadowingScreen> {
  bool _navigatedToSummary = false;

  @override
  void initState() {
    super.initState();
    // Hands-free 모드의 핵심 전제조건 — 학습 중 화면 꺼짐 방지.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _openEditor(BuildContext context, ShadowingController controller, int index) async {
    await controller.pauseForEditing();
    if (!context.mounted) return;
    await context.push('/shadowing/${widget.mediaId}/edit/$index');
    if (!context.mounted) return;
    await controller.reloadSegments();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shadowingControllerProvider(widget.mediaId));
    final controller = ref.read(shadowingControllerProvider(widget.mediaId).notifier);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context)!;

    ref.listen(shadowingControllerProvider(widget.mediaId), (prev, next) async {
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, next.error!, type: AppToastType.error);
      }
      if (!_navigatedToSummary && next.isSessionFullyDone && (prev?.isSessionFullyDone ?? false) == false) {
        _navigatedToSummary = true;
        final result = await controller.buildSessionResult();
        await ref.read(statsRepositoryProvider).recordSession(result);
        if (context.mounted) {
          context.pushReplacement('/shadowing/${widget.mediaId}/summary', extra: result);
        }
      }
    });

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.segments.isEmpty) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/home'))),
        body: Center(child: Text(l10n.noSentencesToStudy)),
      );
    }

    final segment = state.currentSegment!;
    final isListMode = state.viewMode == ShadowingViewMode.list;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.studyEnd,
                    onPressed: () => context.go('/home'),
                  ),
                  Expanded(
                    child: Text(
                      '${state.currentIndex + 1} / ${state.segments.length}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isListMode ? Icons.view_carousel_outlined : Icons.view_agenda_outlined),
                    tooltip: isListMode ? l10n.viewSingle : l10n.viewList,
                    onPressed: controller.toggleViewMode,
                  ),
                  // 2026-08-06: 학습 시작 전 전체 문장을 확정하는 화면이 없어졌으니,
                  // 이상한 문장을 만나면 학습 도중 바로 편집할 수 있어야 한다 — 한
                  // 문장씩 보기에서는 지금 보고 있는 문장을 편집 화면으로 바로 연다
                  // (한꺼번에 보기는 문장이 많아 행마다 편집 아이콘을 따로 둔다).
                  if (!isListMode)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editThisSentence,
                      onPressed: () => _openEditor(context, controller, state.currentIndex),
                    ),
                  if (isListMode)
                    IconButton(
                      icon: Icon(
                        state.filterFlaggedOnly ? Icons.flag : Icons.outlined_flag,
                        color: state.filterFlaggedOnly ? theme.colorScheme.error : null,
                      ),
                      tooltip: state.filterFlaggedOnly ? l10n.viewAllSentences : l10n.viewFlaggedOnly,
                      onPressed: controller.toggleFlaggedFilter,
                    )
                  else
                    IconButton(
                      icon: Icon(
                        segment.flaggedByUser ? Icons.flag : Icons.outlined_flag,
                        color: segment.flaggedByUser ? theme.colorScheme.error : null,
                      ),
                      tooltip: segment.flaggedByUser ? l10n.unflagSentence : l10n.flagAsDifficult,
                      onPressed: controller.toggleFlag,
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    tooltip: l10n.studyOptions,
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ShadowingOptionsSheet(mediaId: widget.mediaId),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (state.currentIndex + 1) / state.segments.length,
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            Expanded(
              child: isListMode
                  ? Column(
                      children: [
                        Expanded(
                          child: _SentenceListView(
                            segments: state.segments,
                            currentIndex: state.currentIndex,
                            completedIndices: state.fullyCompletedIndices,
                            filterFlaggedOnly: state.filterFlaggedOnly,
                            onTapSentence: controller.selectSentence,
                            onEditSentence: (i) => _openEditor(context, controller, i),
                          ),
                        ),
                        _ListModePlayBar(
                          mediaId: widget.mediaId,
                          segment: segment,
                          isPlaying: state.phase == ShadowingPhase.listening,
                          isBuffering: state.isBuffering,
                          progressRatio: state.playbackProgressRatio,
                          completedRepeats: state.completedRepeats,
                          targetRepeats: state.targetRepeats,
                          onPlay: controller.playListFromCurrent,
                          onStop: controller.stopListPlayback,
                        ),
                      ],
                    )
                  : GestureDetector(
                      onVerticalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v < -200) {
                          controller.skipToNext();
                        } else if (v > 200) {
                          controller.skipToPrevious();
                        }
                      },
                      onLongPress: controller.previewAtHalfSpeed,
                      behavior: HitTestBehavior.translucent,
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                                child: SentenceCard(
                                  key: ValueKey(segment.id),
                                  variant: SentenceCardVariant.learning,
                                  segment: segment,
                                  showTranslation: state.showTranslation,
                                  onToggleTranslation: controller.toggleTranslation,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            // 2026-08-06: 무음 감지 때 이미 뽑아둔 실측 진폭이 저장돼 있으면
                            // (로컬 업로드 파일만 — 자막 파싱/라이브러리 콘텐츠는 없음) 그걸
                            // 잘라서 진짜 파형을 그린다. 없으면 WaveformPlayer가 알아서
                            // 장식용 표시로 폴백한다.
                            child: Consumer(
                              builder: (context, ref, _) {
                                final waveform = ref.watch(segmentWaveformProvider(
                                  (mediaId: widget.mediaId, startMs: segment.startMs, endMs: segment.endMs),
                                ));
                                return WaveformPlayer(
                                  seed: segment.id,
                                  variant: WaveformVariant.expanded,
                                  isPlaying: state.phase == ShadowingPhase.listening,
                                  progressRatio:
                                      state.phase == ShadowingPhase.listening ? state.playbackProgressRatio : 0,
                                  amplitudes: waveform.valueOrNull,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          RepeatDotIndicator(
                            total: state.targetRepeats,
                            completed: state.completedRepeats,
                            allDone: state.phase == ShadowingPhase.sentenceComplete,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 2026-08-06: 재생 시작을 기다리는 동안 스피너로 아이콘을 통째로
                              // 갈아치우던 걸 없앴다 — 사용자가 "버튼이 계속 바뀌면서 렉
                              // 걸린 것처럼 보인다"고 피드백해서, 로딩 중에도 버튼 모양은
                              // 고정하고 그대로 둔다. 대신 `CircleIconButton`의 InkWell
                              // 리플로 "눌렀다"는 피드백은 확실히 준다.
                              CircleIconButton(
                                icon: state.phase == ShadowingPhase.speaking ? Icons.mic : Icons.volume_up,
                                backgroundColor:
                                    state.phase == ShadowingPhase.speaking ? semantic.success : theme.colorScheme.primary,
                                size: AppSpacing.primaryCtaSize,
                                iconSize: 32,
                                onTap: controller.restartCurrentStep,
                                semanticLabel:
                                    state.phase == ShadowingPhase.speaking ? l10n.speakingInProgress : l10n.playListenLabel,
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              // 2026-08-06: 한 문장씩 보기에도 "한꺼번에 보기"와 마찬가지로
                              // 자동 듣기↔말하기 루프를 즉시 멈출 수 있는 정지 버튼을 뒀다.
                              CircleIconButton(
                                icon: Icons.stop_rounded,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                iconColor: theme.colorScheme.onSurface,
                                onTap: controller.stopSingleMode,
                                semanticLabel: l10n.stopLabel,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            state.awaitingManualAdvance
                                ? l10n.swipeUpNext
                                : (state.phase == ShadowingPhase.speaking ? l10n.repeatAfterMe : l10n.listenAndRepeat),
                            style: AppTypography.label.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous), onPressed: controller.skipToPrevious),
                                const SizedBox(width: AppSpacing.lg),
                                IconButton(icon: const Icon(Icons.replay), onPressed: controller.restartCurrentStep),
                                const SizedBox(width: AppSpacing.lg),
                                IconButton(icon: const Icon(Icons.skip_next), onPressed: controller.skipToNext),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "한꺼번에 보기" — 책 한 권/영화 한 편처럼 문장이 아주 많은 콘텐츠를 한 화면에
/// 6~8문장 정도씩 훑어보며 손으로 스크롤, 원하는 문장을 탭하면 선택 + 미리듣기.
/// [filterFlaggedOnly]가 켜지면 표시(🚩)해둔 문장만 걸러 보여준다 — 이때도 리스트에
/// 노출되는 인덱스는 원본 [segments] 기준 절대 인덱스를 그대로 쓴다(선택/하이라이트/
/// 이어서 한 문장씩 보기로 전환 시 정확한 위치를 가리켜야 하기 때문).
class _SentenceListView extends StatefulWidget {
  final List<SentenceSegment> segments;
  final int currentIndex;
  final Set<int> completedIndices;
  final bool filterFlaggedOnly;
  final ValueChanged<int> onTapSentence;
  final ValueChanged<int> onEditSentence;

  const _SentenceListView({
    required this.segments,
    required this.currentIndex,
    required this.completedIndices,
    required this.filterFlaggedOnly,
    required this.onTapSentence,
    required this.onEditSentence,
  });

  @override
  State<_SentenceListView> createState() => _SentenceListViewState();
}

/// 2026-08-07: 한 문장씩 보기(문장 200번을 보고 있다고 치자)에서 한꺼번에 보기로
/// 전환하면, 예전엔 이 위젯이 매번 새로 만들어지는 평범한 `ListView`라 스크롤 위치가
/// 항상 맨 위(1번)로 초기화됐다 — 200번짜리 긴 문장 목록에서 지금 듣던 문장을 다시
/// 찾으려면 수백 개를 손으로 스크롤해야 했다. `ListView.builder`는 지금 화면에 없는
/// 항목(예: 200번째)의 실제 위치를 즉시 알 수 없으므로(지연 빌드), 행 높이를
/// 대략치로 추정해 그 근처로 먼저 점프한 뒤(요청한 대로 "근처"면 충분) 사용자가
/// 손으로 미세 조정하게 한다 — 스크롤 가능한 위치 지정 패키지 없이 표준적으로 쓰는
/// 방식이다.
class _SentenceListViewState extends State<_SentenceListView> {
  final _scrollController = ScrollController();
  // 행 내용(패딩 포함) + separator 간격의 대략적인 합 — 자막 없는 문장(번호만, 고정
  // 높이)과 자막 있는 문장(1~2줄 텍스트)의 평균적인 실측 높이에 맞춘 추정치다.
  // 목표가 "정확히 그 문장 위"가 아니라 "그 근처로 이동"이라 오차는 감수한다.
  static const _estimatedItemExtent = 72.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<int> get _visibleIndices => [
        for (var i = 0; i < widget.segments.length; i++)
          if (!widget.filterFlaggedOnly || widget.segments[i].flaggedByUser) i,
      ];

  void _jumpToCurrent() {
    if (!_scrollController.hasClients) return;
    final listPos = _visibleIndices.indexOf(widget.currentIndex);
    if (listPos <= 0) return; // 목록 맨 앞 근처거나(0) 필터링으로 안 보이면 그대로 둔다.
    final viewport = _scrollController.position.viewportDimension;
    // 화면 맨 위 끝에 걸치지 않고 뷰포트 안쪽 1/3 지점쯤에 오도록 살짝 위로 당긴다.
    final target =
        (listPos * _estimatedItemExtent - viewport / 3).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final visibleIndices = _visibleIndices;

    if (visibleIndices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            l10n.noFlaggedSentences,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: visibleIndices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, listPos) {
        final i = visibleIndices[listPos];
        final segment = widget.segments[i];
        final isCurrent = i == widget.currentIndex;
        final isDone = widget.completedIndices.contains(i);
        return Material(
          color: isCurrent ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: InkWell(
            onTap: () => widget.onTapSentence(i),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: isCurrent ? theme.colorScheme.primary : theme.dividerColor,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 자막 없음(무음 감지 전용)인 문장은 대신 보여줄 텍스트가 없으므로,
                  // 안내 문구를 매 행마다 반복하는 대신 번호 자체를 크게 키워 왼쪽에
                  // 강조 노출한다 — 자막모드(hasText)는 기존처럼 번호는 작게 유지.
                  Text(
                    '${i + 1}',
                    style: segment.hasText
                        ? AppTypography.caption.copyWith(
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          )
                        : AppTypography.title.copyWith(
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (segment.hasText)
                    Expanded(
                      child: Text(
                        segment.text!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: AppSpacing.sm),
                  if (segment.flaggedByUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.flag, size: 16, color: theme.colorScheme.error),
                    ),
                  if (isDone)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.check_circle,
                          size: 16, color: theme.extension<AppSemanticColors>()!.success),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: l10n.editThisSentence,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onEditSentence(i),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 한꺼번에 보기 하단 재생바 — 한 문장씩 보기의 원형 재생 버튼과 같은 자리, 같은 역할.
/// 목록에서 탭해 선택한 문장을 다시 듣고 싶을 때 목록을 벗어나지 않고 바로 재생한다.
///
/// 2026-08-06: 설정된 반복 횟수만큼 자동으로 반복하고 다음 문장으로 이어지도록
/// 바뀌면서(`playListFromCurrent`), 한번 누르면 목록 끝까지 계속 재생될 수 있으니
/// 원할 때 멈출 수 있는 정지 버튼을 재생 버튼 옆에 나란히 추가했다.
class _ListModePlayBar extends StatelessWidget {
  final String mediaId;
  final SentenceSegment segment;
  final bool isPlaying;
  final bool isBuffering;
  final double progressRatio;
  final int completedRepeats;
  final int targetRepeats;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const _ListModePlayBar({
    required this.mediaId,
    required this.segment,
    required this.isPlaying,
    required this.isBuffering,
    required this.progressRatio,
    required this.completedRepeats,
    required this.targetRepeats,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = isPlaying || isBuffering;
    return Padding(
      // 2026-08-07: 재생/정지 버튼 위 공간을 넓히고(md→lg) 지금 선택된 문장의 파형을
      // 보여달라는 요청 — 한 문장씩 보기에는 이미 있던 파형 표시를 한꺼번에 보기의
      // 재생바에도 동일하게 넣었다.
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Consumer(
              builder: (context, ref, _) {
                final waveform = ref.watch(segmentWaveformProvider(
                  (mediaId: mediaId, startMs: segment.startMs, endMs: segment.endMs),
                ));
                return WaveformPlayer(
                  seed: segment.id,
                  variant: WaveformVariant.expanded,
                  isPlaying: isPlaying,
                  progressRatio: isPlaying ? progressRatio : 0,
                  amplitudes: waveform.valueOrNull,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2026-08-06: 재생 시작을 기다리는 동안 스피너로 아이콘을 통째로 갈아치우던
              // 걸 없앴다 — 버튼 모양을 고정해서 렉처럼 보이지 않게 한다. `CircleIconButton`
              // 의 InkWell 리플이 "눌렀다"는 피드백을 대신 준다.
              CircleIconButton(
                icon: isPlaying ? Icons.volume_up : Icons.play_arrow,
                backgroundColor: theme.colorScheme.primary,
                onTap: onPlay,
                semanticLabel: l10n.repeatPlaySelected,
              ),
              const SizedBox(width: AppSpacing.lg),
              CircleIconButton(
                icon: Icons.stop_rounded,
                backgroundColor: isActive
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                iconColor: isActive
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                onTap: isActive ? onStop : null,
                semanticLabel: l10n.stopPlayback,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.repeatPlaySelectedStatus(completedRepeats, targetRepeats),
            style: AppTypography.label.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
