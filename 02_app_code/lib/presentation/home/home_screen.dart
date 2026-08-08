import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/media_item.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/empty_state.dart';
import '../common_widgets/primary_button.dart';
import '../common_widgets/skeleton_loader.dart';
import 'analyzing_controller.dart';
import 'home_controller.dart';

/// #1 홈 — 내 콘텐츠(무료). Empty / Populated 두 레이아웃을 한 화면에서 상태로 분기.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(homeMediaListProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/my/settings'),
            tooltip: l10n.settingsTooltip,
          ),
        ],
      ),
      body: RefreshIndicator(
        // 로컬 데이터라 pull-to-refresh는 필수는 아니지만, 스트림 재구독 트리거로 유지.
        onRefresh: () async => ref.invalidate(homeMediaListProvider),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
          children: [
            statsAsync.maybeWhen(
              data: (stats) => stats.currentStreakDays > 0
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        l10n.streakLabel(stats.currentStreakDays),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            PrimaryButton(
              label: l10n.newFileButton,
              onPressed: () => context.push('/home/upload'),
            ),
            const SizedBox(height: AppSpacing.lg),
            mediaAsync.when(
              loading: () => const SkeletonCardList(),
              error: (err, st) => _ErrorRetry(onRetry: () => ref.invalidate(homeMediaListProvider)),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: Column(
                      children: [
                        EmptyState(
                          icon: Icons.headphones_outlined,
                          title: l10n.emptyStateTitle,
                          description: l10n.emptyStateDescription,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // QA 🔴-3: 자기 소유 파일이 없어도(App Review 심사자 포함) 핵심
                        // 기능(자동분리→쉐도잉)을 바로 체험할 수 있는 보조 진입점.
                        // 샘플영상/샘플MP3 두 갈래 선택은 업로드 화면(#2)에 있으므로
                        // 여기서는 그 화면으로 안내만 한다(선택 UI 중복 방지).
                        TextButton.icon(
                          onPressed: () => context.push('/home/upload'),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(l10n.trySampleButton),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.recentlyStudied, style: AppTypography.title.copyWith(color: theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final item in items) _MediaCard(item: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCard extends ConsumerWidget {
  final MediaItem item;
  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // 2026-08-08: 홈 카드의 "분석 중 · N%"는 마지막으로 저장된 스냅샷일 뿐 실시간
    // 상태가 아니다 — 실제 분석은 AnalyzingController(비-autoDispose)가 살아있는
    // 동안에만 진행되는데, 앱이 백그라운드에 있는 동안 OS(특히 삼성 기기의 공격적인
    // 백그라운드 프로세스 정지 정책)가 프로세스를 통째로 죽이면 그 컨트롤러도 같이
    // 사라진다 — 남은 건 죽기 직전 값이 영원히 박제된 카드뿐이고, 사용자는 "그냥
    // 느린 것"과 "완전히 멈춘 것"을 구분할 방법이 없었다(실사용 중 발견, 1시간+
    // 0%로 방치된 사례). 이 프로세스에서 해당 mediaId의 컨트롤러가 실제로
    // 존재하는지(=지금 이 순간 진짜로 진행 중인지) 확인해 구분한다 — 존재하지 않으면
    // "멈춤" 상태로 표시하고, 탭하면 [navigateForMediaStatus]가 분석 화면으로
    // 들여보내 새 컨트롤러 인스턴스를 만들면서 자동으로 재시작된다(직접 확인됨).
    final isOrphanedAnalyzing =
        item.status == MediaStatus.analyzing && !ref.exists(analyzingControllerProvider(item.id));
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => ref.read(homeControllerProvider).deleteMedia(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            onTap: () => navigateForMediaStatus(context, item),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _CoverThumbnail(item: item),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.fileName, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          isOrphanedAnalyzing ? l10n.analyzingOrphanedStatus : _subtitle(l10n, item),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOrphanedAnalyzing ? theme.colorScheme.error : null,
                          ),
                        ),
                        if (item.status == MediaStatus.ready && item.sentenceCount > 0) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: item.completionRatio,
                              minHeight: 4,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.status == MediaStatus.failed || isOrphanedAnalyzing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOrphanedAnalyzing ? l10n.resumeAnalysisNeeded : l10n.reanalyzeNeeded,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  // 좌우 스와이프(Dismissible)만으로는 삭제 기능이 눈에 안 띄어서, 항상
                  // 보이는 삭제 버튼도 함께 제공한다 — 실수 방지를 위해 확인 다이얼로그를 거친다.
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    tooltip: l10n.deleteTooltip,
                    onPressed: () => _confirmDelete(context, ref, item),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, MediaItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody(item.fileName)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(homeControllerProvider).deleteMedia(item.id);
    }
  }

  String _subtitle(AppLocalizations l10n, MediaItem item) {
    switch (item.status) {
      case MediaStatus.uploading:
        return l10n.uploadingStatus(Formatters.percent(item.uploadProgress));
      case MediaStatus.analyzing:
        return l10n.analyzingStatus(Formatters.percent(item.analysisProgress));
      case MediaStatus.ready:
        return item.isCompleted
            ? l10n.sentencesCompleted(item.sentenceCount)
            : l10n.sentencesProgress(item.sentenceCount, Formatters.percent(item.completionRatio));
      case MediaStatus.failed:
        return l10n.analysisFailedStatus;
    }
  }
}

/// 2026-08-09: 파일에 임베딩된 표지(오디오북 커버 등)가 있으면 보여주고, 없으면(대부분의
/// 경우) 기존 마이크/영상 아이콘으로 폴백한다. `errorBuilder`도 함께 두는 이유: 캐시
/// 파일이 삭제됐거나 손상된 경우에도 목록 자체가 깨지면 안 되기 때문.
class _CoverThumbnail extends StatelessWidget {
  final MediaItem item;
  const _CoverThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverArtPath = item.coverArtPath;
    final fallbackIcon = Icon(
      item.sourceType == MediaSourceType.video ? Icons.videocam_outlined : Icons.mic_none,
      color: theme.colorScheme.primary,
    );
    if (coverArtPath == null) return fallbackIcon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(coverArtPath),
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackIcon,
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Text(l10n.loadFailedList),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
