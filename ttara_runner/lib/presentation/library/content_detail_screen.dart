import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../common_widgets/paywall_sheet.dart';
import '../common_widgets/primary_button.dart';
import '../providers/repository_providers.dart';
import 'library_controller.dart';

/// #8 콘텐츠 상세 / 잠금(Paywall) 시트 진입점.
/// 비구독자도 30초 미리듣기는 항상 가능 — "무엇을 얻는지" 먼저 체감시킨 후 Paywall 노출.
class ContentDetailScreen extends ConsumerWidget {
  final String contentId;
  const ContentDetailScreen({super.key, required this.contentId});

  Future<void> _preview(BuildContext context, WidgetRef ref, String previewUrl) async {
    final player = ref.read(audioPlayerServiceProvider);
    try {
      await player.setSource(previewUrl, isLocal: false);
      await player.play();
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, AppLocalizations.of(context)!.previewPlaybackError, type: AppToastType.error);
      }
    }
  }

  Future<void> _startLearning(BuildContext context, WidgetRef ref, bool isSubscribed) async {
    if (isSubscribed) {
      context.push('/shadowing/$contentId?source=library');
      return;
    }
    final purchased = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaywallSheet(),
    );
    if (purchased == true && context.mounted) {
      context.push('/shadowing/$contentId?source=library');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(libraryContentDetailProvider(contentId));
    final subscription = ref.watch(subscriptionStatusProvider);
    final isSubscribed = subscription.maybeWhen(data: (s) => s.isActive, orElse: () => false);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(libraryContentDetailProvider(contentId)),
            child: Text(l10n.retry),
          ),
        ),
        data: (content) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Icon(Icons.article_outlined, size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(content.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.contentDetailMeta(
                  content.source,
                  '${content.durationSec ~/ 60}:${(content.durationSec % 60).toString().padLeft(2, '0')}',
                  content.difficultyLabel,
                  content.sentenceCount,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: l10n.preview30SecButton,
                onPressed: () => _preview(context, ref, content.previewAudioUrl),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: isSubscribed ? l10n.studyAllButton : l10n.studyAllProButton,
                onPressed: () => _startLearning(context, ref, isSubscribed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
