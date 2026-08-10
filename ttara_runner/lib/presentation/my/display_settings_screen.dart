import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/learning_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import 'settings_providers.dart';

/// 마이 > 화면 — 2026-08-10부터 분리(사용자 요청: "화면에 화면만"). 테마/언어만 다룬다.
class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(learningSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionDisplay)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.settingsLoadError)),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
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
                onChanged: (v) => v == null ? null : updateLearningSettings(ref, (s) => s.copyWith(themeMode: v)),
              ),
            ),
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
                onChanged: (v) => v == null ? null : updateLearningSettings(ref, (s) => s.copyWith(languageOption: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
