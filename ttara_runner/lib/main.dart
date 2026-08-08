import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/learning_settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'presentation/my/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppMotion.syncWithPlatform();

  // 영상 파일도 오디오만 추출해 백그라운드 재생 — Hands-free 학습 중 화면 잠금에도
  // 학습 루프가 끊기지 않게 한다(01_ux_design.md 앱 개발자 전달 사항).
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ttara.app.audio',
    androidNotificationChannelName: '쉐도잉랩 쉐도잉 재생',
    androidNotificationOngoing: true,
  );

  runApp(const ProviderScope(child: TtaraApp()));
}

class TtaraApp extends ConsumerWidget {
  const TtaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsAsync = ref.watch(learningSettingsProvider);

    final themeMode = settingsAsync.maybeWhen(
      data: (s) => switch (s.themeMode) {
        AppThemeModeOption.system => ThemeMode.system,
        AppThemeModeOption.light => ThemeMode.light,
        AppThemeModeOption.dark => ThemeMode.dark,
      },
      orElse: () => ThemeMode.system,
    );

    // 2026-08-08: 외국인 사용자 지원 — 마이 > 설정의 언어 선택을 실제 앱 표시 언어에
    // 반영한다. 'system'(locale이 null)이면 Flutter가 기기 언어 중 supportedLocales와
    // 가장 잘 맞는 걸 자동으로 고른다.
    final locale = settingsAsync.maybeWhen(
      data: (s) => s.languageOption.locale,
      orElse: () => const Locale('ko'),
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // OS "모션 감소" 접근성 설정을 실시간 반영 — 모든 트랜지션이 즉시 Fade 120ms로 전환.
        AppMotion.reduceMotion = MediaQuery.of(context).disableAnimations;
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
