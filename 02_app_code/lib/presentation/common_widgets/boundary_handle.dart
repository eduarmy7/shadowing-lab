import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';

enum HandleSide { left, right }

/// 디자인 시스템 "Boundary Handle" 컴포넌트 — #4 문장 분리 결과 편집 화면의
/// 경계(▮) 드래그 핸들. Default / Dragging / Snapped 상태를 색상으로 표현한다.
///
/// 접근성: 드래그 제스처를 쓸 수 없는 스크린리더 사용자를 위해 SemanticsAction
/// increase/decrease를 노출 — VoiceOver/TalkBack에서 위/아래 스와이프(로터 조정)로
/// "+0.1초/-0.1초" 미세조정이 가능하다(01_ux_design.md 접근성 요구사항).
class BoundaryHandle extends StatelessWidget {
  final HandleSide side;
  final bool isDragging;
  final bool isSnapped;
  final ValueChanged<double> onDragDelta; // 누적 아님, 프레임당 delta(px)
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const BoundaryHandle({
    super.key,
    required this.side,
    this.isDragging = false,
    this.isSnapped = false,
    required this.onDragDelta,
    this.onDragStart,
    this.onDragEnd,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final color = isSnapped
        ? Theme.of(context).colorScheme.secondary
        : (isDragging ? scheme.primary : scheme.primary.withValues(alpha: 0.6));

    return Semantics(
      label: side == HandleSide.left ? l10n.boundaryHandleStartLabel : l10n.boundaryHandleEndLabel,
      increasedValue: l10n.incrementPoint1Sec,
      decreasedValue: l10n.decrementPoint1Sec,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => onDragStart?.call(),
        onHorizontalDragUpdate: (details) => onDragDelta(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: 20,
          height: 44,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: isDragging ? 6 : 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isDragging
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
