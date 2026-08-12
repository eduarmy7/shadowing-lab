import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import 'legal_content.dart';

/// 마이 > 고객지원 > 이용약관. 본문은 [legal_content.dart] 참고.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final sections = termsOfService(languageCode);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsOfServiceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
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
