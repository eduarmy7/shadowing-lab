import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ads/ad_mob_ad_service.dart';
import 'core/audio/audio_player_service.dart';
import 'core/audio/study_audio_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/learning_settings.dart';
import 'l10n/gen/app_localizations.dart';
import 'presentation/my/settings_providers.dart';
import 'presentation/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppMotion.syncWithPlatform();

  // 2026-08-09: `just_audio_background`의 단순 미러링 대신 커스텀
  // `StudyAudioHandler`를 직접 등록한다 — 잠금화면/알림의 재생·정지·이전·다음 버튼이
  // 재생기를 직접 만지지 않고 학습 컨트롤러를 거치게 하기 위해서다
  // (`core/audio/study_audio_handler.dart` 문서 참고). Hands-free 학습 중 화면
  // 잠금에도 학습 루프가 끊기지 않아야 한다는 원 요구사항(01_ux_design.md)은 그대로
  // 유지된다 — MainActivity가 여전히 audio_service의 AudioServiceFragmentActivity를
  // 베이스로 쓴다.
  // 2026-08-11: AdMob은 첫 배너/전면 광고 요청 전에 MobileAds.instance.initialize()가
  // 완료돼 있어야 한다 — 홈 화면 배너가 앱 시작 직후 바로 로드를 시도하므로 runApp
  // 이전에 await한다(audio_service 초기화와 동일한 부트스트랩 패턴).
  final adService = AdMobAdService();
  await adService.initialize();

  final audioPlayerService = AudioPlayerService();
  final audioHandler = await AudioService.init(
    builder: () => StudyAudioHandler(audioPlayerService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ttara.app.audio',
      androidNotificationChannelName: '쉐도잉랩 쉐도잉 재생',
      androidNotificationOngoing: true,
    ),
  );

  // 2026-08-10: 학습 리마인더가 켜져 있으면 앱을 열 때마다 다시 예약한다 — Android는
  // 기기가 완전히 재부팅되면 예약된 알람이 초기화되는데(별도 네이티브 BootReceiver는
  // 이번 범위 밖), 최소한 앱을 한 번이라도 열면 여기서 되살아나게 한다. 임시
  // ProviderContainer로 부팅 시점 1회성 부수효과만 처리하고 바로 버린다 — runApp의
  // 진짜 ProviderScope와는 독립적이어도 문제없다(둘 다 같은 영구 저장소/OS API를
  // 다루는 얇은 서비스일 뿐, 상태를 컨테이너 자체에 들고 있지 않는다).
  final bootstrapContainer = ProviderContainer();
  try {
    final settings = await bootstrapContainer.read(settingsRepositoryProvider).getSettings();
    if (settings.reminderEnabled) {
      final reminderService = bootstrapContainer.read(reminderNotificationServiceProvider);
      final granted = await reminderService.requestPermission();
      if (granted) {
        await reminderService.scheduleDaily(settings.reminderTime);
      }
    }
  } catch (_) {
    // 리마인더 재예약 실패는 앱 시작을 막을 이유가 아니다.
  } finally {
    bootstrapContainer.dispose();
  }

  runApp(ProviderScope(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(audioPlayerService),
      audioHandlerProvider.overrideWithValue(audioHandler),
      adServiceProvider.overrideWithValue(adService),
    ],
    child: const TtaraApp(),
  ));
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
