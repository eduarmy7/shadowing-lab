import 'package:flutter/material.dart';

/// 원형 아이콘 버튼(재생/정지 등 학습 화면 공용 컨트롤) — [Material]+[InkWell]로 감싸서
/// 탭할 때 리플(물결) 피드백이 뜨게 한다.
///
/// **2026-08-06 추가**: 예전엔 이 자리들을 전부 맨 `GestureDetector`+`Container`로
/// 직접 그렸는데, `GestureDetector`는 기본적으로 아무 시각 피드백이 없다 — 사용자가
/// "눌렀는지 안 눌렀는지 티가 안 난다"고 피드백해서, 학습 화면의 모든 원형 재생/정지
/// 버튼(한 문장씩 보기의 재생·정지, 한꺼번에 보기의 재생·정지, 편집 화면의 재생·정지)을
/// 이 공용 위젯으로 통일했다.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.size = 56,
    this.iconSize = 26,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
    if (semanticLabel == null) return button;
    return Semantics(button: true, label: semanticLabel, child: ExcludeSemantics(child: button));
  }
}
