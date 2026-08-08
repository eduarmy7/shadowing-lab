import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';
import '../../l10n/gen/app_localizations.dart';

/// 쉐도잉 학습 화면(#5) "반복 횟수 도트" 컴포넌트. 3~10개 가변, 완료된 도트는
/// 스케일 팝(1→1.15→1) 애니메이션과 함께 채워진다.
/// 접근성: 개별 도트를 순회하지 않고 "N회 중 M회 완료"로 요약 발화(semantics label).
class RepeatDotIndicator extends StatelessWidget {
  final int total;
  final int completed;
  final bool allDone;

  const RepeatDotIndicator({
    super.key,
    required this.total,
    required this.completed,
    this.allDone = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context)!.repeatDotsCompletedLabel(total, completed),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final filled = i < completed;
          final isCurrent = i == completed && !allDone;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('dot-$i-$filled'),
              tween: Tween(begin: filled ? 0.85 : 1.0, end: 1.0),
              duration: AppMotion.dotFillTransition,
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: allDone && filled
                  ? Icon(Icons.check_circle, size: 14, color: scheme.primary)
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? scheme.primary : scheme.outline.withValues(alpha: 0.4),
                        border: isCurrent ? Border.all(color: scheme.primary, width: 1.5) : null,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}
