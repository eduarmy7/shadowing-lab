import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../l10n/gen/app_localizations.dart';

enum SentenceCardVariant { list, learning }
enum SentenceCardState { idle, playing, recording, completed, warning }

/// 공통 위젯화 최우선 순위 컴포넌트. 목록형(#4 문장 분리 편집 화면)과 학습형(#5 쉐도잉
/// 학습 화면)에서 텍스트 표시 규칙(가변 폰트, Dynamic Type)을 공유한다.
///
/// [SentenceSegment.text]가 null인 경우(음성만 업로드 → 무음 감지 결과, STT가 없어
/// 텍스트 자체가 없음)를 목록형/학습형 모두에서 별도 플레이스홀더로 표시한다 — 없는
/// 텍스트를 지어내지 않는다.
/// - 목록형: 인덱스·타임스탬프 노출, [footer]에 파형+경계핸들+병합/분리 버튼을 끼워넣는다.
/// - 학습형: 대형 가변 텍스트만 노출(최대 200% 확대까지 레이아웃 유지), 번역 접기/펼치기 지원.
class SentenceCard extends StatelessWidget {
  final SentenceCardVariant variant;
  final SentenceSegment segment;
  final SentenceCardState state;
  final bool showTranslation;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleTranslation;
  final double fontScale;
  final Widget? footer;

  const SentenceCard({
    super.key,
    required this.variant,
    required this.segment,
    this.state = SentenceCardState.idle,
    this.showTranslation = false,
    this.onTap,
    this.onDoubleTap,
    this.onToggleTranslation,
    this.fontScale = 1.0,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return variant == SentenceCardVariant.learning ? _buildLearning(context) : _buildList(context);
  }

  Widget _buildLearning(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 문장마다 고유 번호 표시 — 긴 콘텐츠(예: 책 한 권 1000문장 이상)에서 몇 번째
        // 문장인지 문장 카드 자체에서 바로 확인 가능하게 한다(상단 "N / 전체" 진행률과 별개로,
        // 스와이프로 오갈 때도 항상 문장 옆에 붙어있어야 하는 정보라 카드 안에 둔다).
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${segment.index + 1}',
              style: AppTypography.caption.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (segment.flaggedByUser) ...[
              const SizedBox(width: 6),
              Icon(Icons.flag, size: 14, color: theme.colorScheme.error),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        segment.hasText
            ? Text(
                segment.text!,
                textAlign: TextAlign.center,
                style: AppTypography.sentence.copyWith(
                  color: theme.colorScheme.onSurface,
                  // 최소 18sp ~ 최대 200%(48sp)까지 레이아웃 깨짐 없이 확대(Dynamic Type 대응).
                  fontSize: (24 * fontScale).clamp(18.0, 48.0),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hearing, size: 32, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.noSubtitleListenPrompt,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
        if (segment.translation != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onToggleTranslation,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showTranslation ? segment.translation! : l10n.showTranslationLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Icon(
                    showTranslation ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final semantic = theme.extension<AppSemanticColors>()!;
    final isWarning = state == SentenceCardState.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isWarning ? semantic.warning : theme.dividerColor,
          width: isWarning ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${segment.index + 1}',
                      style: AppTypography.caption.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    state == SentenceCardState.playing ? Icons.volume_up : Icons.play_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const Spacer(),
                  if (segment.flaggedByUser)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.flag, size: 14, color: theme.colorScheme.error),
                    ),
                  if (segment.edited)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.edit, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (isWarning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: semantic.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: semantic.warning),
                          const SizedBox(width: 3),
                          Text(l10n.needsReviewBadge,
                              style: AppTypography.caption.copyWith(color: semantic.warning, fontSize: 11)),
                        ],
                      ),
                    )
                  else
                    Icon(Icons.check_circle, size: 16, color: semantic.success),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                segment.text ?? l10n.noSubtitleSegmentLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: segment.hasText ? FontStyle.normal : FontStyle.italic,
                  color: segment.hasText ? null : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Formatters.msToClock(segment.startMs)} – ${Formatters.msToClock(segment.endMs)}',
                style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
