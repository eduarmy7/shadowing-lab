import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../common_widgets/paywall_sheet.dart';
import '../common_widgets/primary_button.dart';
import '../library/library_controller.dart';
import '../providers/repository_providers.dart';

/// #9 구독 결제/관리 — 마이 탭 "구독 관리" 진입 경로.
/// 비구독자: [PaywallSheet]와 동일 컴포넌트를 페이지 형태로 재사용.
/// 구독자: 결제 수단 변경/해지 관리 화면으로 전환.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionManageTitle)),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.subscriptionLoadError)),
        data: (status) => status.isActive ? const _ManageView() : const PaywallSheet(),
      ),
    );
  }
}

class _ManageView extends ConsumerStatefulWidget {
  const _ManageView();

  @override
  ConsumerState<_ManageView> createState() => _ManageViewState();
}

class _ManageViewState extends ConsumerState<_ManageView> {
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final subscription = ref.watch(subscriptionStatusProvider).valueOrNull;
    if (subscription == null) return const SizedBox.shrink();

    final planLabel = subscription.plan?.name == 'yearly' ? l10n.planYearlyLabel : l10n.planMonthlyLabel;
    final nextBilling =
        subscription.nextBillingDate != null ? DateFormat('yyyy.MM.dd').format(subscription.nextBillingDate!) : '-';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(l10n.proPlanActiveLabel(planLabel), style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.nextBillingDateLabel(nextBilling), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: l10n.changePaymentMethod,
            onPressed: () => AppToast.show(context, l10n.goToStorePaymentManagement, type: AppToastType.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          // QA 🔴-4: 앱은 스토어 구독을 직접 취소할 수 없다(03_api_integration.md 6-3절) —
          // 버튼 라벨/후속 안내를 "즉시 해지 완료"가 아니라 "스토어로 이동"으로 맞춘다.
          PrimaryButton(
            label: l10n.manageSubscriptionStoreButton,
            isLoading: _isCancelling,
            onPressed: () async {
              setState(() => _isCancelling = true);
              try {
                await ref.read(subscriptionRepositoryProvider).cancel();
                if (context.mounted) {
                  AppToast.show(
                    context,
                    l10n.cancelViaStoreNotice,
                    type: AppToastType.info,
                  );
                }
              } catch (_) {
                if (context.mounted) AppToast.show(context, l10n.cannotOpenStorePage, type: AppToastType.error);
              } finally {
                if (mounted) setState(() => _isCancelling = false);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.cancelExplanationNotice,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
