import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/learning_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import 'settings_providers.dart';

/// 마이 > 학습 기본값 — 2026-08-10부터 예전 하나였던 설정 화면에서 분리됨(사용자
/// 요청: "학습 기본값에 학습기본값만"). 반복 횟수/재생 속도/Hands-free만 다룬다.
class LearningDefaultsScreen extends ConsumerWidget {
  const LearningDefaultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(learningSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionLearningDefaults)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.settingsLoadError)),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            ListTile(
              title: Text(l10n.defaultRepeatCount),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.timesUnit(settings.defaultRepeatCount)),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () => _showRepeatCountPicker(context, ref, settings),
            ),
            ListTile(
              title: Text(l10n.defaultPlaybackSpeed),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.speedUnit(settings.defaultPlaybackSpeed.toString())),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: () => _showSpeedPicker(context, ref, settings),
            ),
            SwitchListTile(
              title: Text(l10n.handsFreeMode),
              value: settings.handsFreeMode,
              onChanged: (v) => updateLearningSettings(ref, (s) => s.copyWith(handsFreeMode: v)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepeatCountPicker(BuildContext context, WidgetRef ref, LearningSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (var n = AppConstants.minRepeatCount; n <= AppConstants.maxRepeatCount; n++)
              ListTile(
                title: Text(l10n.timesUnit(n)),
                trailing: settings.defaultRepeatCount == n ? const Icon(Icons.check) : null,
                onTap: () {
                  updateLearningSettings(ref, (s) => s.copyWith(defaultRepeatCount: n));
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, WidgetRef ref, LearningSettings settings) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (final speed in AppConstants.availablePlaybackSpeeds)
              ListTile(
                title: Text(l10n.speedUnit(speed.toString())),
                trailing: settings.defaultPlaybackSpeed == speed ? const Icon(Icons.check) : null,
                onTap: () {
                  updateLearningSettings(ref, (s) => s.copyWith(defaultPlaybackSpeed: speed));
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
