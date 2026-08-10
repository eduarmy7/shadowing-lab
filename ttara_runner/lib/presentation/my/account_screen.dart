import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/ad_removal_sheet.dart';
import '../common_widgets/app_toast.dart';
import '../providers/purchase_providers.dart';
import '../providers/repository_providers.dart';

/// 마이 > 계정 — 2026-08-10부터 분리(사용자 요청: "계정에 유료 무료 등록정보, 유료
/// 구매날짜 등만"). 이 앱은 로그인 계정 개념이 없으므로(익명/기기 기반), 계정
/// 화면의 실질 내용은 "광고 제거" 구매 상태뿐이다.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(purchaseRepositoryProvider).restorePurchases();
      final restored = await ref.read(purchaseRepositoryProvider).watchAdsRemoved().first;
      if (!mounted) return;
      if (!restored) {
        AppToast.show(context, l10n.adRemovalRestoreNotFound, type: AppToastType.info);
      }
    } catch (_) {
      if (mounted) AppToast.show(context, l10n.adRemovalPurchaseFailed, type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context)!;
    final adsRemovedAsync = ref.watch(adsRemovedProvider);
    final purchasedAtAsync = ref.watch(purchasedAtProvider);
    final adsRemoved = adsRemovedAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final purchasedAt = purchasedAtAsync.maybeWhen(data: (v) => v, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountLabel)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Text(l10n.accountStatusSectionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      adsRemoved ? Icons.check_circle : Icons.info_outline,
                      color: adsRemoved ? semantic.success : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        adsRemoved ? l10n.adRemovalPurchasedLabel : l10n.accountStatusFree,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (adsRemoved && purchasedAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      l10n.accountPurchasedOnLabel(Formatters.date(l10n, purchasedAt)),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
                if (!adsRemoved) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const AdRemovalSheet(),
                      ),
                      child: Text('${l10n.adRemovalPurchaseCta} · ${l10n.adRemovalPrice}'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: TextButton(
                      onPressed: _restoring ? null : _restore,
                      child: _restoring
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.adRemovalRestoreLink),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
