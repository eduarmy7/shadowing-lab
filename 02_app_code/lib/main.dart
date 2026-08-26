import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
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

  // 2026-08-26 추가 — 전화 수신 대응: 이전엔 오디오 포커스(AudioSession) 설정 자체가
  // 없어서, 전화가 오면 안드로이드가 우리 앱에 "포커스를 잃었다"고 알려줘도 아무도
  // 안 듣고 있어 재생이 전혀 안 멈췄다(실사용자 제보 — 통화 소리와 쉐도잉 음성이
  // 동시에 재생됨). `audio_session`으로 세션을 구성하고 인터럽션 이벤트를 구독해,
  // 전화 등으로 포커스를 잃는 순간(끊김이 아니라 "일시적으로 뺏김" 타입 포함) 알림의
  // 정지 버튼을 누른 것과 동일한 경로(`audioHandler.pause()` → `StudyAudioHandler.pause()`
  // → `onNotificationPause` 콜백, 학습 화면에 있으면 `stopSingleMode`/`stopListPlayback`로
  // 라우팅됨)로 확실히 멈춘다. 통화가 끝났다고 자동으로 다시 재생하지는 않는다 —
  // 사용자가 다시 눌러서 이어가는 편이 안전하다(예상치 못한 순간에 갑자기 소리가
  // 다시 나오는 게 더 당황스러울 수 있음).
  final audioSession = await AudioSession.instance;
  await audioSession.configure(const AudioSessionConfiguration.music());
  audioSession.interruptionEventStream.listen((event) {
    if (event.begin && event.type != AudioInterruptionType.duck) {
      audioHandler.pause();
    }
  });

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

class TtaraApp extends ConsumerStatefulWidget {
  const TtaraApp({super.key});

  @override
  ConsumerState<TtaraApp> createState() => _TtaraAppState();
}

/// 2026-08-26 추가, 같은 날 두 차례 재설계 — 실사용자 제보: "오늘 학습을 마쳐서"
/// (그 파일 전체를 다 봤다는 뜻이 아니라, 지금 세션을 끝냈다는 뜻 — 다음 학습은
/// 오늘 다른 파일일 수도, 내일일 수도 있다) 미니 플레이어까지 사라진 뒤에 앱을
/// 다시 열어도 마지막 학습 화면이 그대로 다시 떴다. 반대로 학습 세션이 아직
/// 살아있으면(백그라운드 재생/일시정지 포함, 미니 플레이어가 떠 있는 상태) 다시
/// 열었을 때 그 화면 그대로 보이는 게 맞는 동작이다 — 즉 판단 기준은 파일의
/// 학습 완료율이 아니라 **"지금 이 순간 학습 세션이 살아있는가"**다.
///
/// **첫 시도**: `StudyAudioHandler.mediaItem`이 채워져 있는지로 판단했는데, 그때는
/// `ShadowingController.dispose()`가 이 값을 지운 적이 없어 신호 자체가 못 믿을
/// 상태였다(이미 고침, 위 dispose() 참고). **두 번째 시도(실패)**: "파일 전체
/// 문장을 다 완료했는지"로 바꿨는데, 사용자가 "학습을 마쳤다"고 한 건 파일 전체
/// 완료가 아니라 그날의 세션 종료를 뜻했다 — 1000문장짜리 책을 5문장만 보고
/// 오늘 그만둬도 "마친" 것이다. 그래서 원래의 mediaItem 신호로 되돌아가되, 이제는
/// dispose()가 확실히 지워주므로 믿을 수 있다.
class _TtaraAppState extends ConsumerState<TtaraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _returnHomeIfSessionEnded();
  }

  void _returnHomeIfSessionEnded() {
    final router = ref.read(appRouterProvider);
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    if (!location.startsWith('/shadowing/')) return;
    final hasActiveSession = ref.read(audioHandlerProvider).mediaItem.value != null;
    if (!hasActiveSession) router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
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
