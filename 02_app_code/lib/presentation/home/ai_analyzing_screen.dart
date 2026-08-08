import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/primary_button.dart';
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
/// 보고 있는 동안에는 wakelock으로 화면이 꺼지지 않게 한다. "백그라운드에서 계속"을
/// 눌러 이 화면을 실제로 벗어나면 wakelock도 해제된다(그건 사용자가 의도적으로 다른
/// 일을 하러 가는 것이므로 화면을 계속 켜둘 이유가 없다 — 다만 그 경우 안드로이드의
/// 백그라운드 프로세스 절전 자체를 막지는 못한다는 한계는 남아있다).
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

  @override
  Widget build(BuildContext context) {
    final mediaId = widget.mediaId;
    final state = ref.watch(analyzingControllerProvider(mediaId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    ref.listen(analyzingControllerProvider(mediaId), (prev, next) {
      if (next.phase == AnalyzingPhase.succeeded) {
        context.pushReplacement('/shadowing/$mediaId?source=local');
      }
    });

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
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(l10n.continueInBackground),
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
                    onPressed: () => context.pushReplacement('/shadowing/$mediaId?source=local'),
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
