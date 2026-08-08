import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeMode 3단(라이트/다크/시스템) 지원. 마이 탭 > 설정 > 화면 에서 토글.
abstract class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.primaryDark,
            onPrimary: AppColors.onPrimaryDark,
            primaryContainer: AppColors.primaryContainerDark,
            secondary: AppColors.secondaryDark,
            surface: AppColors.surfaceDark,
            error: AppColors.errorDark,
            outline: AppColors.outlineDark,
          )
        : const ColorScheme.light(
            primary: AppColors.primaryLight,
            onPrimary: AppColors.onPrimaryLight,
            primaryContainer: AppColors.primaryContainerLight,
            secondary: AppColors.secondaryLight,
            surface: AppColors.surfaceLight,
            error: AppColors.errorLight,
            outline: AppColors.outlineLight,
          );

    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceVariant = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(color: textPrimary),
        headlineMedium: AppTypography.headline.copyWith(color: textPrimary),
        titleMedium: AppTypography.title.copyWith(color: textPrimary),
        bodyLarge: AppTypography.sentence.copyWith(color: textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: textPrimary),
        labelLarge: AppTypography.label.copyWith(color: textPrimary),
        bodySmall: AppTypography.caption.copyWith(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headline.copyWith(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: AppTypography.label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.label.copyWith(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? colorScheme.primary : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colorScheme.primary : textSecondary,
          ),
        ),
      ),
      dividerColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      splashFactory: InkRipple.splashFactory,
      extensions: [
        AppSemanticColors(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          surfaceVariant: surfaceVariant,
          success: isDark ? AppColors.successDark : AppColors.successLight,
          warning: AppColors.warning,
          proGold: isDark ? AppColors.proGoldDark : AppColors.proGoldLight,
          waveform: isDark ? AppColors.waveformDark : AppColors.waveformLight,
        ),
      ],
    );
  }
}

/// TextTheme/ColorScheme에 없는 디자인 토큰(성공/경고/PRO 골드 등)을 ThemeExtension으로 노출.
/// 사용: `Theme.of(context).extension<AppSemanticColors>()!.warning`
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color textPrimary;
  final Color textSecondary;
  final Color surfaceVariant;
  final Color success;
  final Color warning;
  final Color proGold;
  final Color waveform;

  const AppSemanticColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.surfaceVariant,
    required this.success,
    required this.warning,
    required this.proGold,
    required this.waveform,
  });

  @override
  AppSemanticColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? surfaceVariant,
    Color? success,
    Color? warning,
    Color? proGold,
    Color? waveform,
  }) {
    return AppSemanticColors(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      proGold: proGold ?? this.proGold,
      waveform: waveform ?? this.waveform,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      proGold: Color.lerp(proGold, other.proGold, t)!,
      waveform: Color.lerp(waveform, other.waveform, t)!,
    );
  }
}
