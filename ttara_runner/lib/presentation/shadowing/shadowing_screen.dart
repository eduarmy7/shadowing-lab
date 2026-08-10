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
import '../providers/purchase_providers.dart';
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
    // 2026-08-10: 사용자 요청으로 학습 화면(#5)의 재생 버튼 바로 위에도 배너를
    // 넣는다 — 예전엔 "Hands-free 루프를 끊는다"는 이유로 이 화면 안에서는 광고를
    // 아예 안 넣기로 했었지만(재생 버튼 자체를 가리지 않는 위치라 그 우려는 적용되지
    // 않는다는 판단), 이번 결정으로 대체한다. "광고 제거" 구매 사용자에게는 다른
    // 화면과 동일하게 숨긴다.
    final adService = ref.watch(adServiceProvider);
    final adsRemoved = ref.watch(adsRemovedProvider).maybeWhen(data: (v) => v, orElse: () => false);

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
                        if (!adsRemoved) adService.bannerAdWidget(context),
                        _ListModePlayBar(
                          mediaId: widget.mediaId,
                          segment: segment,
                          isPlaying: state.phase == ShadowingPhase.listening,
                          isBuffering: state.isBuffering,
                          progressRatio: state.playbackProgressRatio,
                          completedRepeats: state.completedRepeats,
                          targetRepeats: state.targetRepeats,
                          canGoPrevious: state.currentIndex > 0,
                          canGoNext: state.currentIndex < state.segments.length - 1,
                          onPlay: controller.playListFromCurrent,
                          onStop: controller.stopListPlayback,
                          onPrevious: controller.previousInList,
                          onNext: controller.nextInList,
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
                          if (!adsRemoved) adService.bannerAdWidget(context),
                          const SizedBox(height: AppSpacing.md),
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
                                // 2026-08-09: 정지 직후엔 처음부터가 아니라 멈춘 지점부터
                                // 이어서 재생한다 — 항상 처음부터 다시 듣고 싶을 땐 아래
                                // "다시 듣기"(Icons.replay) 버튼을 쓴다.
                                onTap: controller.resumeOrRestart,
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
  // 행 내용(패딩 포함) + separator 간격의 대략적인 합 — 자막 없는 문장(번호만, 고정
  // 높이)과 자막 있는 문장(1~2줄 텍스트)의 평균적인 실측 높이에 맞춘 추정치다.
  // 목표가 "정확히 그 문장 위"가 아니라 "그 근처로 이동"이라 오차는 감수한다 —
  // 그 오차는 아래 [_scrollToCurrentIfOffscreen]의 GlobalKey 기반 정밀 보정으로 메운다.
  static const _estimatedItemExtent = 72.0;

  // 2026-08-10 버그 수정: `ScrollController()`를 오프셋 0으로 만든 뒤 postFrame에서
  // 점프하면, 그 사이 첫 프레임이 무조건 맨 위(1번 문장)로 한 번 그려진다 — 사용자가
  // 직접 지적함("1번으로 갔다가 246으로 오네, 불필요한 경로"). 대신 스크롤 컨트롤러
  // 생성 시점에 이미 추정 위치로 `initialScrollOffset`을 지정해, 1번 문장이 화면에
  // 단 한 프레임도 그려지지 않고 바로 목표 근처에서 시작하게 한다. 여전히 추정치라
  // 정확하지 않을 수 있으니, 마운트 후 [_scrollToCurrentIfOffscreen]으로 한 번 더
  // 정밀 보정한다 — 이번엔 시작점이 이미 목표 근처라 보정 폭이 작고 훨씬 빠르다.
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: () {
      final listPos = _visibleIndices.indexOf(widget.currentIndex);
      return listPos > 0 ? listPos * _estimatedItemExtent : 0.0;
    }(),
  );

  // 2026-08-10: 각 행의 실제 렌더 위치를 알아내기 위한 키 — [_scrollToCurrentIfOffscreen]
  // 참고. 절대 인덱스([SentenceSegment.index])로 관리해 깃발 필터로 화면상 위치(listPos)가
  // 바뀌어도 키가 안정적으로 유지된다.
  final Map<int, GlobalKey> _rowKeys = {};

  GlobalKey _keyFor(int absoluteIndex) => _rowKeys.putIfAbsent(absoluteIndex, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    // initialScrollOffset은 뷰포트 크기를 몰라 "1/3 지점" 보정 없이 대략치로만
    // 시작하므로, 마운트 후 한 번 더 정밀 보정한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentIfOffscreen());
  }

  @override
  void didUpdateWidget(covariant _SentenceListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 2026-08-10: 한꺼번에 보기 재생([ShadowingController.playListFromCurrent])이
    // 문장을 자동으로 넘기다가 지금 화면에 보이는 범위를 벗어나면, 재생 중인 문장이
    // 화면 밖으로 사라져 사용자가 어디를 듣고 있는지 놓쳤다(사용자 보고: "화면에
    // 보이는 문장보다 더 많이 학습하면 학습하고 있는 문장이 안 보이네"). currentIndex가
    // 바뀔 때마다 이미 화면 안이면 그대로 두고, 화면 밖으로 나갔을 때만 스크롤한다 —
    // 사용자가 다른 문장을 손으로 보고 있는데 매번 강제로 튕기면 오히려 방해된다.
    if (widget.currentIndex != oldWidget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentIfOffscreen());
    }
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

  /// [attempt]는 무한 루프 방지용 상한 — 실제로는 보통 1~2번 안에 수렴한다.
  void _scrollToCurrentIfOffscreen({int attempt = 0}) {
    if (!_scrollController.hasClients) return;
    final listPos = _visibleIndices.indexOf(widget.currentIndex);
    if (listPos < 0) return; // 깃발 필터링으로 지금 화면에 아예 없음 — 스크롤할 대상이 없다.

    // 목표 행이 이미 빌드돼 있으면(화면 안이거나 뷰포트 바로 밖 캐시 범위) 실제
    // 렌더된 위치로 정확히 스크롤한다 — `_estimatedItemExtent` 추정치를 아예
    // 쓰지 않으므로 오차가 없다. 재생 자동진행처럼 한 번에 한 문장씩만 움직이는
    // 경우 거의 항상 이 경로를 탄다.
    final key = _rowKeys[widget.currentIndex];
    final rowContext = key?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.3, // 화면 위쪽에서 1/3 지점.
      );
      return;
    }

    // 2026-08-10 추가 수정: 재시도마다 `animateTo`(250ms 애니메이션)를 쓰면, 이
    // 앵커 보정이 여러 번 필요한 먼 거리(예: 목록 맨 위 근처에서 500번대로 점프)일 때
    // 실사용 테스트에서 완전히 정확한 위치로 자리잡기까지 체감상 4~6초나 걸렸다 —
    // 사용자가 "안 됐다"고 오해할 만큼 느렸다. 탐색 단계에서는 애니메이션 없이
    // 즉시(`jumpTo`) 이동해 한 프레임 만에 다음 보정으로 넘어가고, 재시도 횟수도
    // 늘린다 — 마지막으로 실제 행을 찾았을 때(위 `ensureVisible`)만 부드럽게 움직인다.
    if (attempt >= 8) return; // 그래도 못 찾으면 마지막 추정 위치에 만족하고 멈춘다.

    // 2026-08-10 버그 수정: 목표 행이 아직 안 빌드된 먼 위치로 건너뛴 경우(예: 한
    // 문장씩 보기에서 한꺼번에 보기로 전환하며 목록 깊숙한 위치로 들어갈 때) —
    // 사용자 실측 재현: 242번 문장이 현재인데 목록은 206~218번을 보여주는 등, 아예
    // 엉뚱한 위치로 스크롤됐다. `_estimatedItemExtent`(72dp)가 이 콘텐츠(짧은 한 줄
    // 자막)의 실제 행 높이보다 커서, 인덱스 0부터 그 오차를 누적시키면 먼 인덱스일수록
    // 목표를 훨씬 지나쳐버렸던 것이 원인 — 최초 진입(initialScrollOffset)도 같은 함정이라
    // 2차 보정이 애초에 크게 어긋난 위치에서 시작해 GlobalKey를 못 찾았다.
    // 고침: 인덱스 0부터 추정하는 대신, **지금 실제로 빌드된 행 중 목표에 가장 가까운
    // 것**을 기준점 삼아 그로부터의 짧은 거리만 추정한다 — 기준점의 실제 렌더 위치는
    // 100% 정확하므로, 남은 오차는 기준점~목표 사이 거리에 비례해 훨씬 작다. 이 보정
    // 후에도 못 찾으면(기준점이 너무 멀었다면) 한 번 더 재귀적으로 다시 시도한다.
    final scrollableBox = context.findRenderObject() as RenderBox?;
    int? anchorIndex;
    double? anchorAbsoluteOffset; // 스크롤 오프셋 0 기준, 그 행의 top 위치.
    if (scrollableBox != null && scrollableBox.attached) {
      for (final entry in _rowKeys.entries) {
        final ctx = entry.value.currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final dy = box.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
        if (anchorIndex == null || (entry.key - widget.currentIndex).abs() < (anchorIndex - widget.currentIndex).abs()) {
          anchorIndex = entry.key;
          anchorAbsoluteOffset = dy + _scrollController.offset;
        }
      }
    }

    final viewport = _scrollController.position.viewportDimension;
    double target;
    if (anchorIndex != null && anchorAbsoluteOffset != null) {
      final anchorListPos = _visibleIndices.indexOf(anchorIndex);
      target = anchorAbsoluteOffset + (listPos - anchorListPos) * _estimatedItemExtent - viewport / 3;
    } else {
      // 화면에 빌드된 행이 하나도 없는 극단적 상황(있을 수 없지만 방어적으로) — 옛 방식.
      target = listPos * _estimatedItemExtent - viewport / 3;
    }
    target = target.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrentIfOffscreen(attempt: attempt + 1);
    });
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
          key: _keyFor(i),
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
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ListModePlayBar({
    required this.mediaId,
    required this.segment,
    required this.isPlaying,
    required this.isBuffering,
    required this.progressRatio,
    required this.completedRepeats,
    required this.targetRepeats,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPlay,
    required this.onStop,
    required this.onPrevious,
    required this.onNext,
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
              // 2026-08-09: 한 문장씩 보기와 마찬가지로 재생바 양옆에 이전/다음 문장
              // 버튼을 뒀다 — 목록을 계속 스크롤하지 않고도 죽 이어 들을 수 있게.
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: canGoPrevious ? onPrevious : null,
              ),
              const SizedBox(width: AppSpacing.md),
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
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: canGoNext ? onNext : null,
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
