import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';

/// 마이 > 고객지원 — 2026-08-10부터 분리(사용자 요청: "고객지원에는 고객지원만"),
/// 자주 묻는 질문 + 문의하기(플레이스토어 평점/리뷰 안내) + 이용약관/개인정보처리방침
/// 링크만 다룬다.
///
/// **문의하기 목적지**: 사용자가 "플레이스토어 쉐도잉랩 평점 및 리뷰 코너로 안내"를
/// 명시적으로 지정했다(전용 지원 이메일 개설은 추후 검토 사항으로 보류) — 실제 앱
/// 심사 통과 후 Play 콘솔에 등록되는 진짜 URL로 아래 상수를 교체해야 한다.
class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

  // TODO(store-manager): 실제 Play Console 등록 후 진짜 스토어 URL로 교체.
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.ttara.ttara';

  Future<void> _openPlayStore(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(_playStoreUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.show(context, l10n.openPlayStoreFailed, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final faqs = [
      (l10n.faqQ1, l10n.faqA1),
      (l10n.faqQ2, l10n.faqA2),
      (l10n.faqQ3, l10n.faqA3),
      (l10n.faqQ4, l10n.faqA4),
      (l10n.faqQ5, l10n.faqA5),
      (l10n.faqQ6, l10n.faqA6),
      (l10n.faqQ7, l10n.faqA7),
      (l10n.faqQ8, l10n.faqA8),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.customerSupport)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.sm, AppSpacing.screenMargin, AppSpacing.xs),
            child: Text(l10n.faqTitle, style: theme.textTheme.titleMedium),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (final (q, a) in faqs)
                  ExpansionTile(
                    title: Text(q, style: theme.textTheme.bodyMedium),
                    childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenMargin, 0, AppSpacing.screenMargin, AppSpacing.md),
                    expandedAlignment: Alignment.centerLeft,
                    children: [
                      Text(a, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.contactUs),
            subtitle: Text(l10n.contactUsDescription),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _openPlayStore(context),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.termsOfServiceTitle),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/my/support/terms'),
          ),
          ListTile(
            title: Text(l10n.privacyPolicyTitle),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/my/support/privacy'),
          ),
        ],
      ),
    );
  }
}
