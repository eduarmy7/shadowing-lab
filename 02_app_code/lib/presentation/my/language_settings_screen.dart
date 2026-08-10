import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/learning_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import 'settings_providers.dart';

/// 마이 > 언어 — 2026-08-11부터 [DisplaySettingsScreen](화면)에서 분리된 별도 화면
/// (사용자 요청: 마이 탭 메뉴 목록에 "언어"를 화면(라이트/다크)과 나란히 독립 항목으로
/// 노출). 앱 표시 언어만 다룬다.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(learningSettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.settingsLoadError)),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
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
