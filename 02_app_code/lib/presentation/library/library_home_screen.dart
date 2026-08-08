import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/entities/library_content.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/pro_badge.dart';
import '../common_widgets/skeleton_loader.dart';
import 'library_controller.dart';

/// #7 라이브러리 홈 — 라이브러리 진입 자체는 비구독자에게도 열려 있다(둘러보기 가능).
/// 잠금은 "재생 시작" 시점에만 발생(#8에서 처리).
class LibraryHomeScreen extends ConsumerWidget {
  const LibraryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final subscription = ref.watch(subscriptionStatusProvider);
    final today = ref.watch(libraryTodayProvider);
    final categoriesAsync = ref.watch(libraryCategoriesProvider);
    final isSubscribed = subscription.maybeWhen(data: (s) => s.isActive, orElse: () => false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabLibrary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: ProBadge(variant: isSubscribed ? ProBadgeVariant.unlocked : ProBadgeVariant.locked),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
        children: [
          if (!isSubscribed)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.libraryFreeTrialBanner, style: theme.textTheme.bodyMedium),
                  ),
                  TextButton(onPressed: () => context.push('/my/subscription'), child: Text(l10n.learnMoreButton)),
                ],
              ),
            ),
          Text(l10n.todayNewsTitle, style: AppTypography.title.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          today.when(
            loading: () => const SkeletonCardList(count: 2),
            error: (e, st) => _SectionError(onRetry: () => ref.invalidate(libraryTodayProvider)),
            data: (items) => items.isEmpty
                ? Text(l10n.todayContentLoadError, style: theme.textTheme.bodySmall)
                : Column(children: [for (final c in items) _ContentCard(content: c, isSubscribed: isSubscribed)]),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.byTopicTitle, style: AppTypography.title.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          categoriesAsync.when(
            loading: () => const SizedBox(height: 40),
            error: (e, st) => const SizedBox.shrink(),
            data: (categories) => SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.where((c) => c.id != 'today').length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final category = categories.where((c) => c.id != 'today').toList()[i];
                  return Chip(label: Text(category.label));
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (categories) => Column(
              children: [
                for (final category in categories.where((c) => c.id != 'today'))
                  _CategorySection(category: category, isSubscribed: isSubscribed),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final LibraryCategory category;
  final bool isSubscribed;
  const _CategorySection({required this.category, required this.isSubscribed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contentAsync = ref.watch(libraryCategoryContentProvider(category.id));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.label, style: AppTypography.title.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          contentAsync.when(
            loading: () => const SizedBox(height: 100, child: SkeletonCardList(count: 1)),
            error: (e, st) => const SizedBox.shrink(),
            data: (page) => SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: page.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => SizedBox(
                  width: 160,
                  child: _ContentCard(content: page.items[i], isSubscribed: isSubscribed, compact: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final LibraryContent content;
  final bool isSubscribed;
  final bool compact;
  const _ContentCard({required this.content, required this.isSubscribed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locked = !isSubscribed;
    return Container(
      margin: compact ? null : const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          onTap: () => context.push('/library/content/${content.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(Icons.article_outlined, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.contentCardMeta(content.source, content.durationSec ~/ 60, content.difficultyLabel),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (locked)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SectionError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(l10n.sectionLoadError)),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
