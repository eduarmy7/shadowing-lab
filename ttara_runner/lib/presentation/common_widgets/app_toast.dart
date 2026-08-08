import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppToastType { success, error, info }

/// 디자인 시스템 "Toast/Snackbar" — Success/Error/Info, 자동 1.5초 소멸.
///
/// **2026-08-07**: 원래 3초였는데, 학습/편집 화면 하단의 재생·정지 버튼과 겹치는
/// 자리에 떠서 "문장이 저장되었습니다" 같은 토스트가 오래 떠있는 동안 그 버튼들을
/// 누르는 데 방해가 된다는 피드백으로 절반(1.5초)으로 줄였다.
abstract class AppToast {
  static void show(BuildContext context, String message, {AppToastType type = AppToastType.info}) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final color = switch (type) {
      AppToastType.success => semantic.success,
      AppToastType.error => Theme.of(context).colorScheme.error,
      AppToastType.info => Theme.of(context).colorScheme.primary,
    };
    final icon = switch (type) {
      AppToastType.success => Icons.check_circle_outline,
      AppToastType.error => Icons.error_outline,
      AppToastType.info => Icons.info_outline,
    };

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
