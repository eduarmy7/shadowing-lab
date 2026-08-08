import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/user_stats.dart';
import '../../presentation/common_widgets/tab_scaffold.dart';
import '../../presentation/home/ai_analyzing_screen.dart';
import '../../presentation/home/file_upload_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/sentence_edit_screen.dart';
import '../../presentation/library/content_detail_screen.dart';
import '../../presentation/library/library_home_screen.dart';
import '../../presentation/my/learning_history_screen.dart';
import '../../presentation/my/my_home_screen.dart';
import '../../presentation/my/settings_screen.dart';
import '../../presentation/my/subscription_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/shadowing/session_summary_screen.dart';
import '../../presentation/shadowing/shadowing_screen.dart';

/// 앱 라우팅 테이블 — 01_ux_design.md "정보구조(IA) 및 네비게이션 구조"를 그대로 반영.
///
/// - `/onboarding`: 최초 1회, 탭 바 밖 풀스크린 스택.
/// - `StatefulShellRoute.indexedStack`: 3탭(홈/라이브러리/마이) 독립 스택 유지 —
///   탭 재진입 시 마지막 위치를 기억한다(요구사항: "탭 전환은 항상 1탭으로 즉시 가능").
/// - `/shadowing/:mediaId`: 쉐도잉 학습 화면은 셸 바깥의 풀스크린 라우트로 분리해
///   탭바가 노출되지 않게 하고(#5 "이 화면에 들어오면 오직 학습만 보이게"),
///   Tab1(내 파일)과 Tab2(라이브러리) 양쪽에서 `source` 쿼리 파라미터만 바꿔 동일 위젯을
///   재사용한다(app-developer 전달 사항 그대로 구현).
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
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
              path: '/library',
              builder: (context, state) => const LibraryHomeScreen(),
              routes: [
                GoRoute(
                  path: 'content/:contentId',
                  builder: (context, state) =>
                      ContentDetailScreen(contentId: state.pathParameters['contentId']!),
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
                GoRoute(path: 'settings', builder: (context, state) => const SettingsScreen()),
                GoRoute(path: 'subscription', builder: (context, state) => const SubscriptionScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/shadowing/:mediaId',
        builder: (context, state) => ShadowingScreen(
          mediaId: state.pathParameters['mediaId']!,
          source: state.uri.queryParameters['source'] ?? 'local',
        ),
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
