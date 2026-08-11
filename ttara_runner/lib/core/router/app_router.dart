import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/user_stats.dart';
import '../../presentation/common_widgets/tab_scaffold.dart';
import '../../presentation/home/ai_analyzing_screen.dart';
import '../../presentation/home/file_upload_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/sentence_edit_screen.dart';
import '../../presentation/my/account_screen.dart';
import '../../presentation/my/customer_support_screen.dart';
import '../../presentation/my/display_settings_screen.dart';
import '../../presentation/my/language_settings_screen.dart';
import '../../presentation/my/learning_defaults_screen.dart';
import '../../presentation/my/learning_history_screen.dart';
import '../../presentation/my/my_home_screen.dart';
import '../../presentation/my/notification_settings_screen.dart';
import '../../presentation/my/privacy_policy_screen.dart';
import '../../presentation/my/terms_of_service_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/shadowing/session_summary_screen.dart';
import '../../presentation/shadowing/shadowing_screen.dart';

/// 앱 라우팅 테이블 — 01_ux_design.md "정보구조(IA) 및 네비게이션 구조"를 그대로 반영.
///
/// - `/onboarding`: 최초 1회, 탭 바 밖 풀스크린 스택.
/// - `StatefulShellRoute.indexedStack`: 2탭(홈/마이) 독립 스택 유지 —
///   탭 재진입 시 마지막 위치를 기억한다(요구사항: "탭 전환은 항상 1탭으로 즉시 가능").
///   2026-08-08: 라이브러리(PRO 구독 뉴스) 탭은 별도 앱으로 분리되며 이 앱에서 제거됨.
/// - `/shadowing/:mediaId`: 쉐도잉 학습 화면은 셸 바깥의 풀스크린 라우트로 분리해
///   탭바가 노출되지 않게 한다(#5 "이 화면에 들어오면 오직 학습만 보이게"). 이 앱은
///   이제 내 파일(로컬 미디어)만 다루므로 소스 구분 쿼리 파라미터는 없다.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    // 2026-08-11 버그 수정: 예전엔 온보딩을 이미 마친 사용자도 '/onboarding' 화면이
    // 한 프레임 그려진 뒤에야(OnboardingScreen.initState의 postFrameCallback) 완료
    // 여부를 비동기로 확인해 '/home'으로 돌려보냈다 — 그 사이 온보딩 1페이지가
    // 눈에 아주 짧게 보였다 사라지는 깜빡임으로 나타났다. 목적지 화면을 짓기 전에
    // 먼저 판단하는 라우터 레벨 redirect로 옮기면 온보딩 화면 자체가 아예 빌드되지
    // 않는다.
    redirect: (context, state) async {
      if (state.matchedLocation != '/onboarding') return null;
      final done = await ref.read(onboardingCompletedProvider.future);
      return done ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => TabScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(path: 'upload', builder: (context, state) => const FileUploadScreen()),
                GoRoute(
                  path: 'analyzing/:mediaId',
                  builder: (context, state) =>
                      AiAnalyzingScreen(mediaId: state.pathParameters['mediaId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my',
              builder: (context, state) => const MyHomeScreen(),
              routes: [
                GoRoute(path: 'history', builder: (context, state) => const LearningHistoryScreen()),
                GoRoute(
                  path: 'settings/learning-defaults',
                  builder: (context, state) => const LearningDefaultsScreen(),
                ),
                GoRoute(
                  path: 'settings/notifications',
                  builder: (context, state) => const NotificationSettingsScreen(),
                ),
                GoRoute(
                  path: 'settings/display',
                  builder: (context, state) => const DisplaySettingsScreen(),
                ),
                GoRoute(
                  path: 'settings/language',
                  builder: (context, state) => const LanguageSettingsScreen(),
                ),
                GoRoute(path: 'settings/account', builder: (context, state) => const AccountScreen()),
                GoRoute(path: 'support', builder: (context, state) => const CustomerSupportScreen()),
                GoRoute(path: 'support/terms', builder: (context, state) => const TermsOfServiceScreen()),
                GoRoute(path: 'support/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/shadowing/:mediaId',
        builder: (context, state) => ShadowingScreen(mediaId: state.pathParameters['mediaId']!),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) => SessionSummaryScreen(result: state.extra as LearningSessionResult),
          ),
          // 2026-08-06: 구 #4 목록 확인 화면(전체 문장 확정 후 학습 시작) 폐기 이후,
          // 문장 편집(병합/분리/길이조정)은 학습 화면에서 지금 보고 있는 문장을 바로
          // 편집 화면으로 넘겨 처리한다 — 수천 문장짜리 콘텐츠를 학습 시작 전에
          // 전부 확정하라고 요구하지 않는다.
          GoRoute(
            path: 'edit/:index',
            builder: (context, state) => SentenceEditScreen(
              mediaId: state.pathParameters['mediaId']!,
              initialIndex: int.parse(state.pathParameters['index']!),
            ),
          ),
        ],
      ),
    ],
  );
});
