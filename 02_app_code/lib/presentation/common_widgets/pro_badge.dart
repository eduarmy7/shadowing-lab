import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

enum ProBadgeVariant { locked, unlocked }

/// "PRO 잠금은 색상뿐 아니라 🔒 아이콘+텍스트 병기" 접근성 원칙을 항상 지키는 배지.
class ProBadge extends StatelessWidget {
  final ProBadgeVariant variant;

  const ProBadge({super.key, this.variant = ProBadgeVariant.locked});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<AppSemanticColors>()!.proGold;
    final isLocked = variant == ProBadgeVariant.locked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLocked ? Icons.lock_outline : Icons.workspace_premium, size: 14, color: gold),
          const SizedBox(width: 4),
          Text('PRO', style: AppTypography.label.copyWith(color: gold, fontSize: 12)),
        ],
      ),
    );
  }
}
