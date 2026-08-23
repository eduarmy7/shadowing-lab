import 'package:auto_size_text/auto_size_text.dart';
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

    // 문장마다 고유 번호 표시 — 긴 콘텐츠(예: 책 한 권 1000문장 이상)에서 몇 번째
    // 문장인지 문장 카드 자체에서 바로 확인 가능하게 한다(상단 "N / 전체" 진행률과 별개로,
    // 스와이프로 오갈 때도 항상 문장 옆에 붙어있어야 하는 정보라 카드 안에 둔다).
    final header = Row(
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
    );

    final noTextPlaceholder = Column(
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
    );

    // **2026-08-22 여러 차례 수정 끝에 확정된 형태**: 처음엔 문장 아래 작은 접힌 줄로
    // 번역을 보여줬는데 공간이 부족했고, 그다음엔 화면을 절반씩 나눠 영어+한글을
    // 동시에 보여줬는데 그마저도 한 줄에 욱여넣느라 글자가 작았다(사용자 피드백:
    // "글자가 너무 작아서 안 보여"). 최종적으로는 **영어/한글을 동시에 보여주지
    // 않고, 버튼으로 완전히 전환**하기로 했다 — "한글 뜻 보기"를 누르면 화면 전체를
    // 한글이 차지하고, "영어 자막 보기"를 누르면 다시 영어로 돌아간다. 어느 쪽이든
    // `AutoSizeText`로 화면 전체 높이/너비를 활용해 여러 줄로 줄바꿈하며 가능한 한
    // 크게 표시한다. 목록형(list) 화면엔 이 토글 자체가 없으므로("한 문장 보기에서만")
    // 번역은 여전히 학습형(learning)에만 나온다.
    final showingTranslation = showTranslation && segment.translation != null;
    final mainText = !segment.hasText
        ? noTextPlaceholder
        : AutoSizeText(
            showingTranslation ? segment.translation! : segment.text!,
            textAlign: TextAlign.center,
            maxLines: 8,
            minFontSize: showingTranslation ? 14 : 16,
            style: AppTypography.sentence.copyWith(
              color: showingTranslation ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
              // 최소 20sp ~ 최대 56sp: 짧은 문장은 크게, 긴 문장은 AutoSizeText가 줄바꿈하며 줄인다.
              fontSize: (30 * fontScale).clamp(20.0, 56.0),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        header,
        const SizedBox(height: AppSpacing.xs),
        Expanded(child: Center(child: mainText)),
        if (segment.translation != null) ...[
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onToggleTranslation,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showingTranslation ? l10n.showOriginalTextLabel : l10n.showTranslationLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Icon(Icons.swap_vert, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
