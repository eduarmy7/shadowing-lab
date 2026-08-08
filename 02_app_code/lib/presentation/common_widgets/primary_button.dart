import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// 디자인 시스템 "Button > Primary(Filled)" 컴포넌트. 화면마다 반복되는 하단 고정
/// CTA(예: #4 "24개 문장으로 시작", #2 "취소")를 표준화한다.
/// Default / Pressed(플랫폼 기본 InkWell) / Disabled / Loading 4개 상태 지원.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final button = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary(Tonal) 버튼 — #6 학습 완료 요약의 "홈으로" 등 보조 액션.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  const SecondaryButton({super.key, required this.label, required this.onPressed, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
      ),
      child: Text(label),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
