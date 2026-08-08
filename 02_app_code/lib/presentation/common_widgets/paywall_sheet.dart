import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/entities/subscription.dart';
import '../providers/repository_providers.dart';
import 'app_toast.dart';
import 'primary_button.dart';

/// 공통 위젯화 최우선 순위 컴포넌트 — #8 잠금 콘텐츠 접근 시 / #9 구독 화면 재사용.
/// Bottom Sheet로 노출해 "홈으로 돌아가는 탈출구가 항상 보이는" 압박감 낮은 결제 유도.
///
/// 사용: `showModalBottomSheet(context: context, isScrollControlled: true,
///   builder: (_) => const PaywallSheet());`
class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  SubscriptionPlanType _selected = SubscriptionPlanType.yearly;
  bool _isPurchasing = false;
  String? _error;

  Future<void> _purchase() async {
    setState(() {
      _isPurchasing = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionRepositoryProvider).purchase(_selected);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppToast.show(context, 'PRO 구독이 시작됐어요', type: AppToastType.success);
    } catch (_) {
      // 결제 실패 시 인라인 에러 + 재시도 (#8/#9 상태 처리 명세).
      setState(() => _error = '결제 처리에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenMargin,
          right: AppSpacing.screenMargin,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.workspace_premium, color: semantic.proGold),
                const SizedBox(width: AppSpacing.xs),
                Text('쉐도잉랩 프리미엄', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '매일 갱신되는 뉴스·회화로 끊임없이 쉐도잉하세요',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 18, color: semantic.success),
                    const SizedBox(width: AppSpacing.sm),
                    Text(b, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlanCard(
              option: SubscriptionPlanOption.monthly,
              selected: _selected == SubscriptionPlanType.monthly,
              onTap: () => setState(() => _selected = SubscriptionPlanType.monthly),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PlanCard(
              option: SubscriptionPlanOption.yearly,
              selected: _selected == SubscriptionPlanType.yearly,
              onTap: () => setState(() => _selected = SubscriptionPlanType.yearly),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: AppSpacing.sm),
            ],
            PrimaryButton(
              label: '시작하기 (7일 무료)',
              isLoading: _isPurchasing,
              onPressed: _purchase,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                '구독 취소는 언제든 가능',
                style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _benefits = ['매일 새 콘텐츠', '광고 없이 학습', '무제한 반복/속도조절'];
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(option.priceLabel, style: theme.textTheme.bodyMedium)),
            if (option.discountLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  option.discountLabel!,
                  style: AppTypography.caption.copyWith(color: theme.colorScheme.secondary),
                ),
              ),
            if (option.isRecommended) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '인기',
                  style: AppTypography.caption.copyWith(color: theme.colorScheme.onPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
