import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import 'legal_content.dart';

/// 마이 > 고객지원 > 개인정보처리방침. 본문은 [legal_content.dart] 참고 — 초안이며
/// 실제 출시 전 변호사 검토가 필요하다는 문구를 화면 상단에 항상 노출한다.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final sections = privacyPolicy(languageCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Text(
              l10n.legalDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (heading, body) in sections) ...[
            Text(heading, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
