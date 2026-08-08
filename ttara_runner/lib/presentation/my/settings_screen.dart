import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/learning_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../providers/repository_providers.dart';

final learningSettingsProvider = StreamProvider.autoDispose<LearningSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

/// #12 설정 — 학습 기본값/알림/화면/계정/지원 그룹핑된 리스트.
/// 마이 홈(#10)의 개별 메뉴 항목들은 모두 이 화면으로 수렴한다(스캐폴드 단순화).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, LearningSettings Function(LearningSettings) updater) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.getSettings();
    await repo.updateSettings(updater(current));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(learningSettingsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.settingsLoadError)),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            _SectionHeader(l10n.sectionLearningDefaults),
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
              onChanged: (v) => _update(ref, (s) => s.copyWith(handsFreeMode: v)),
            ),
            const Divider(),
            _SectionHeader(l10n.sectionNotifications),
            SwitchListTile(
              title: Text(l10n.studyReminder),
              value: settings.reminderEnabled,
              onChanged: (v) => _update(ref, (s) => s.copyWith(reminderEnabled: v)),
            ),
            ListTile(
              title: Text(l10n.reminderTimeLabel),
              trailing: Text(settings.reminderTime, style: theme.textTheme.bodyMedium),
            ),
            const Divider(),
            _SectionHeader(l10n.sectionDisplay),
            ListTile(
              title: Text(l10n.theme),
              trailing: DropdownButton<AppThemeModeOption>(
                value: settings.themeMode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: AppThemeModeOption.system, child: Text(l10n.themeSystem)),
                  DropdownMenuItem(value: AppThemeModeOption.light, child: Text(l10n.themeLight)),
                  DropdownMenuItem(value: AppThemeModeOption.dark, child: Text(l10n.themeDark)),
                ],
                onChanged: (v) => v == null ? null : _update(ref, (s) => s.copyWith(themeMode: v)),
              ),
            ),
            // 2026-08-08 추가: 외국인 사용자 지원 — 앱 표시 언어 선택.
            ListTile(
              title: Text(l10n.language),
              trailing: DropdownButton<AppLanguageOption>(
                value: settings.languageOption,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: AppLanguageOption.system, child: Text(l10n.languageSystem)),
                  DropdownMenuItem(value: AppLanguageOption.korean, child: Text(l10n.languageKorean)),
                  DropdownMenuItem(value: AppLanguageOption.english, child: Text(l10n.languageEnglish)),
                  DropdownMenuItem(value: AppLanguageOption.japanese, child: Text(l10n.languageJapanese)),
                ],
                onChanged: (v) => v == null ? null : _update(ref, (s) => s.copyWith(languageOption: v)),
              ),
            ),
            const Divider(),
            _SectionHeader(l10n.sectionSupport),
            ListTile(title: Text(l10n.faq), trailing: const Icon(Icons.chevron_right, size: 20)),
            ListTile(title: Text(l10n.contactUs), trailing: const Icon(Icons.chevron_right, size: 20)),
            ListTile(title: Text(l10n.termsPrivacy), trailing: const Icon(Icons.chevron_right, size: 20)),
            const Divider(),
            ListTile(title: Text(l10n.versionInfo), trailing: const Text('1.0.0')),
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
                  _update(ref, (s) => s.copyWith(defaultRepeatCount: n));
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
                  _update(ref, (s) => s.copyWith(defaultPlaybackSpeed: speed));
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.md, AppSpacing.screenMargin, AppSpacing.xs),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
