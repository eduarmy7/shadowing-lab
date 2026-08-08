import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failure.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../providers/repository_providers.dart';
import 'app_toast.dart';
import 'primary_button.dart';

/// 광고 제거 단발성 구매 Bottom Sheet — 2026-08-08 PRO 구독/라이브러리 Paywall
/// (`paywall_sheet.dart`) 제거 후 이를 대체하는, 훨씬 단순한 단일 SKU 구매 시트.
/// 월간/연간 플랜 선택 없이 "구매" 하나, "복원" 링크 하나뿐이다.
class AdRemovalSheet extends ConsumerStatefulWidget {
  const AdRemovalSheet({super.key});

  @override
  ConsumerState<AdRemovalSheet> createState() => _AdRemovalSheetState();
}

class _AdRemovalSheetState extends ConsumerState<AdRemovalSheet> {
  bool _isPurchasing = false;
  bool _isRestoring = false;

  Future<void> _purchase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPurchasing = true);
    try {
      await ref.read(purchaseRepositoryProvider).purchaseRemoveAds();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PurchaseFailure catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message, type: AppToastType.error);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, l10n.adRemovalPurchaseFailed, type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isRestoring = true);
    try {
      await ref.read(purchaseRepositoryProvider).restorePurchases();
      if (!mounted) return;
      final restored = await ref.read(purchaseRepositoryProvider).watchAdsRemoved().first;
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pop();
      } else {
        AppToast.show(context, l10n.adRemovalRestoreNotFound, type: AppToastType.info);
      }
    } on PurchaseFailure catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message, type: AppToastType.error);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, l10n.adRemovalPurchaseFailed, type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final busy = _isPurchasing || _isRestoring;

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
            Text(l10n.adRemovalSheetTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.adRemovalPrice,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: AppSpacing.md),
            _BenefitRow(text: l10n.adRemovalBenefitBanner),
            const SizedBox(height: AppSpacing.xs),
            _BenefitRow(text: l10n.adRemovalBenefitInterstitial),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.adRemovalPurchaseCta,
              isLoading: _isPurchasing,
              onPressed: busy ? null : _purchase,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: busy ? null : _restore,
                child: _isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.adRemovalRestoreLink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>();
    return Row(
      children: [
        Icon(Icons.check_circle, size: 18, color: semantic?.success ?? theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
