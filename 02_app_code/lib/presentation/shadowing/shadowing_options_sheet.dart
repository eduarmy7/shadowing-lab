import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/learning_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import 'shadowing_controller.dart';

String _gapModeLabel(AppLocalizations l10n, SentenceGapMode mode) => switch (mode) {
      SentenceGapMode.none => l10n.gapNone,
      SentenceGapMode.matchSentence => l10n.gapMatchSentence,
      SentenceGapMode.plusOneSecond => l10n.gapPlusOneSecond,
      SentenceGapMode.plusTwoSeconds => l10n.gapPlusTwoSeconds,
    };

/// 옵션 시트(⋯ 탭 시, Bottom Sheet) — 반복 횟수/재생 속도/한글 뜻/Hands-free/녹음 토글.
class ShadowingOptionsSheet extends ConsumerWidget {
  final String mediaId;
  const ShadowingOptionsSheet({super.key, required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shadowingControllerProvider(mediaId));
    final controller = ref.read(shadowingControllerProvider(mediaId).notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin, AppSpacing.md, AppSpacing.screenMargin, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Text(l10n.studyOptions, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _OptionRow(
              label: l10n.repeatCountLabel,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: state.targetRepeats > AppConstants.minRepeatCount
                        ? () => controller.updateOptions(repeatCount: state.targetRepeats - 1)
                        : null,
                  ),
                  Text('${state.targetRepeats}'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: state.targetRepeats < AppConstants.maxRepeatCount
                        ? () => controller.updateOptions(repeatCount: state.targetRepeats + 1)
                        : null,
                  ),
                ],
              ),
            ),
            _OptionRow(
              label: l10n.playbackSpeedLabel,
              trailing: DropdownButton<double>(
                value: state.playbackSpeed,
                underline: const SizedBox.shrink(),
                items: AppConstants.availablePlaybackSpeeds
                    .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                    .toList(),
                onChanged: (v) => v == null ? null : controller.updateOptions(speed: v),
              ),
            ),
            _OptionRow(
              label: l10n.sentenceGapLabel,
              trailing: DropdownButton<SentenceGapMode>(
                value: state.sentenceGapMode,
                underline: const SizedBox.shrink(),
                items: SentenceGapMode.values
                    .map((mode) => DropdownMenuItem(value: mode, child: Text(_gapModeLabel(l10n, mode))))
                    .toList(),
                onChanged: (v) => v == null ? null : controller.updateOptions(sentenceGapMode: v),
              ),
            ),
            _OptionRow(
              label: l10n.autoShowTranslationLabel,
              trailing: Switch(
                value: state.showTranslation,
                onChanged: (v) => controller.updateOptions(autoTranslation: v),
              ),
            ),
            _OptionRow(
              label: l10n.handsFreeMode,
              trailing: Switch(
                value: state.handsFree,
                onChanged: (v) => controller.updateOptions(handsFree: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _OptionRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          trailing,
        ],
      ),
    );
  }
}
