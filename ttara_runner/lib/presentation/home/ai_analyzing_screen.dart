import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/primary_button.dart';
import '../providers/repository_providers.dart';
import 'analyzing_controller.dart';

/// #3 문장 분리 중 — 진행률 %, 예상 소요시간, 실패 시 재시도/수동 분리 대체 경로.
/// 2026-08-05 STT 폐기 이후 이 화면이 관찰하는 진행률은 로컬 연산(자막 파싱/무음 감지)
/// 진행률이지 네트워크 업로드/서버 처리 진행률이 아니다.
///
/// 2026-08-06: 실기기(+에뮬레이터)에서 큰 실제 파일의 무음 감지가 "분석 중 30%"에서
/// 화면이 멈춰버리는 문제가 재현됐다 — 이 화면을 보고 있는 동안 화면이 꺼지면(자동
/// 잠금 타임아웃) 일부 안드로이드 기기가 백그라운드 프로세스를 절전 처리하면서
/// `SilenceDetector`가 돌고 있는 isolate 실행이 멈춰버리는 것으로 보인다
/// (`ShadowingScreen`이 학습 중 화면 꺼짐을 막는 것과 같은 문제) — 그래서 이 화면을
/// 보고 있는 동안에는 wakelock으로 화면이 꺼지지 않게 한다.
///
/// 2026-08-13: wakelock은 앱 자체가 포그라운드일 때만 유효하다 — 다른 앱으로
/// 전환하거나 화면을 꺼서 쉐도잉랩 전체가 백그라운드로 밀려나면 즉시 무력화되고
/// 안드로이드가 백그라운드 프로세스를 절전 처리해 분석이 멈추는 게 실사용에서
/// 확인됐다(예전엔 "백그라운드에서 계속" 버튼으로 의도적으로 나갈 수 있었는데,
/// 그 버튼이 있다고 안전한 게 아니었다). **이 화면 자체를 벗어나는 것과는 다르다**
/// — 이 라우트는 `StatefulShellRoute`의 홈 탭 브랜치에 속해서, 마이 탭 등 앱 안의
/// 다른 메뉴로 이동해도 `IndexedStack`이 이 위젯을 계속 마운트된 채로 들고 있어
/// dispose가 안 되고 wakelock도 안 풀린다 — 실제로 위험한 건 앱을 통째로 벗어나는
/// 것뿐이다. 근본 해결(포그라운드 서비스로 감싸기)은 하지 않기로 하고, 대신
/// "백그라운드에서 계속" 버튼을 없애고 앱을 나가면 멈출 수 있다는 경고 문구만
/// 상시 노출한다 — 뒤로가기/홈으로 앱을 나가는 것 자체는 막지 않는다.
class AiAnalyzingScreen extends ConsumerStatefulWidget {
  final String mediaId;
  const AiAnalyzingScreen({super.key, required this.mediaId});

  @override
  ConsumerState<AiAnalyzingScreen> createState() => _AiAnalyzingScreenState();
}

/// 초 단위 예상시간을 "약 N분"(1분 미만이면 "1분 미만")으로 표시한다.
String _formatMinutes(AppLocalizations l10n, double seconds) {
  final minutes = (seconds / 60).round();
  return minutes < 1 ? l10n.lessThanOneMinute : l10n.minutesCount(minutes);
}

class _AiAnalyzingScreenState extends ConsumerState<AiAnalyzingScreen> {
  // 2026-08-26 추가: 자막에 언어 트랙이 한국어(등 영어가 아닌 언어) 하나뿐인 파일은,
  // 분석이 자막 파싱이라 순식간에 끝나버려서 안내 토스트를 띄워봐야 읽을 시간도 없이
  // 넘어갔다("안내문구 읽을 시간이 없이 지나가버리네" — 사용자 피드백). 그래서 토스트
  // 대신, 분석이 끝나도 곧장 넘어가지 않고 이 화면에 큼직하게 안내를 [_noticeDuration]
  // 만큼 보여준 뒤에 학습 화면으로 넘어간다.
  static const _noticeDuration = Duration(seconds: 5);
  String? _nonEnglishNoticeLabel;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _handleSucceeded(String mediaId) async {
    final item = await ref.read(mediaRepositoryProvider).getById(mediaId);
    final label = item?.nonEnglishSingleTrackLabel;
    if (label != null && mounted) {
      setState(() => _nonEnglishNoticeLabel = label);
      await Future.delayed(_noticeDuration);
    }
    if (mounted) context.pushReplacement('/shadowing/$mediaId');
  }

  @override
  Widget build(BuildContext context) {
    final mediaId = widget.mediaId;
    final state = ref.watch(analyzingControllerProvider(mediaId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    ref.listen(analyzingControllerProvider(mediaId), (prev, next) {
      if (next.phase == AnalyzingPhase.succeeded) {
        _handleSucceeded(mediaId);
      }
    });

    final noticeLabel = _nonEnglishNoticeLabel;
    if (noticeLabel != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_outlined, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.nonEnglishSubtitleNotice(noticeLabel),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  state.phase == AnalyzingPhase.failed ? l10n.analyzingFailedTitle : l10n.analyzingTitle,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.phase != AnalyzingPhase.failed) ...[
                  Text(l10n.analyzingProgress((state.progress * 100).round()), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: state.progress, minHeight: 6),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    // 2026-08-07: 이 파일 길이를 프로브해서 예상 소요시간을 알 수 있게 되면
                    // ("이 파일은 약 N분 정도 걸려요") 일반론 문구 대신 구체적으로 안내한다 —
                    // "보통 10분당 약 X초" 식 문구는 사용자가 자기 파일 기준으로 환산해야
                    // 해서 감이 잘 안 온다는 점을 개선.
                    state.estimatedTotalSeconds != null
                        ? l10n.estimatedTimeSpecific(_formatMinutes(l10n, state.estimatedTotalSeconds!))
                        : l10n.estimatedTimeGeneric(AppConstants.estimatedLocalSegmentationSecondsPer10Min.round()),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // 2026-08-13: "백그라운드에서 계속" 버튼 삭제 — wakelock은 이 화면이
                  // 실제로 보이고 있을 때만 유효해서, 눌러서 나가는 순간 보호가
                  // 사라지고 안드로이드가 백그라운드 프로세스를 절전 처리해 분석이
                  // 멈추는 게 실사용에서 확인됐다(사용자가 늘 화면을 지켜봐서 이제야
                  // 드러남). 대신 벗어나면 멈출 수 있다는 걸 명확히 경고만 한다 —
                  // 뒤로가기/홈 버튼으로 나가는 것 자체는 막지 않는다.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          l10n.analyzingStayWarning,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    state.errorMessage ?? l10n.analyzingErrorGeneric,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l10n.retry,
                    onPressed: () => ref.read(analyzingControllerProvider(mediaId).notifier).retry(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.pushReplacement('/shadowing/$mediaId'),
                    child: Text(l10n.manualSplit),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
