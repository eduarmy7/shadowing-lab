import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum WaveformVariant { compact, expanded }

/// 디자인 시스템 "Waveform Player" 컴포넌트. Compact(카드 내 미리듣기) / Expanded
/// (쉐도잉 학습 화면, 전체 타임라인) 두 변형을 지원한다.
///
/// 실제 오디오 진폭(waveform) 분석은 온디바이스 오디오 디코딩/분석이 필요한 영역이라
/// 이번 스캐폴드에서는 [seed] 기반 결정적 pseudo-waveform을 그린다(2026-08-05 STT 폐기
/// 결정 이후 이 앱에 서버 오디오 분석 응답이라는 개념 자체가 없다 — 무음 감지도 100%
/// 온디바이스). 실 amplitude 분석(로컬 오디오 디코딩 패키지 연동)이 준비되면
/// [amplitudes] 파라미터로 교체하면 된다.
class WaveformPlayer extends StatelessWidget {
  final String seed;
  final WaveformVariant variant;
  final double progressRatio; // 0.0~1.0, 재생 위치
  final bool isPlaying;
  final bool isBuffering;
  final List<double>? amplitudes;
  final ValueChanged<double>? onScrub; // Expanded 모드 스크럽(0.0~1.0)

  const WaveformPlayer({
    super.key,
    required this.seed,
    this.variant = WaveformVariant.compact,
    this.progressRatio = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.amplitudes,
    this.onScrub,
  });

  /// 2026-08-07 추가: 실측 진폭은 이 문장 구간만의 상대적 크기가 아니라 원본 오디오
  /// 파일 전체 기준 절대값이라(예: 조용히 녹음된 오디오북은 파일 전체 최댓값 자체가
  /// 0.29 정도밖에 안 됨 — 118분 실제 파일에서 확인됨), 문장이 길든 짧든 그 구간의
  /// 최댓값이 파일의 절대 최댓값에 못 미치면 막대가 다 낮고 밋밋해 보여 "소리가 있는
  /// 부분과 없는 부분 구분이 잘 안 간다"는 피드백으로 이어졌다. 화면에 그릴 때마다 그
  /// 구간(지금 보이는 창) 안에서의 최댓값 기준으로 다시 0~1로 늘려 그리면, 그 문장이
  /// 원래 얼마나 크게 녹음됐는지와 무관하게 항상 트랙 높이를 최대한 활용해 발화/무음
  /// 대비가 뚜렷하게 보인다. 거의 완전한 무음 구간(마이크가 거의 안 잡힌 매우 조용한
  /// 부분)까지 증폭해버리면 노이즈를 진짜 소리처럼 보이게 할 수 있어 그런 경우만 원본
  /// 그대로 둔다.
  List<double> _normalizeToFullRange(List<double> values) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0.02) return values;
    return [for (final v in values) (v / maxVal).clamp(0.0, 1.0)];
  }

  List<double> _generateBars() {
    final random = Random(seed.hashCode);
    final count = variant == WaveformVariant.expanded ? 64 : 28;
    return List.generate(count, (i) {
      // 문장 중간부는 진폭이 크고 끝부분은 잦아드는 자연스러운 곡선 가중치.
      final t = i / count;
      final envelope = sin(t * pi).clamp(0.25, 1.0);
      return (0.25 + random.nextDouble() * 0.75) * envelope;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 2026-08-08: 메인 브랜드색을 터콰이즈로 바꾸면서 파형 색만은 예전 인디고
    // 블루를 유지해달라는 요청 — colorScheme.secondary(이제 터콰이즈)가 아니라
    // 전용 토큰(AppSemanticColors.waveform)을 쓴다.
    final semantic = Theme.of(context).extension<AppSemanticColors>()!.waveform;
    // 2026-08-06: 실측 데이터가 없을 때(getWaveformForSegment가 빈 리스트를 반환하는
    // 경우 — 자막 파싱 경로/라이브러리 콘텐츠 등) 빈 리스트는 null과 똑같이 "장식용
    // 표시로 폴백"으로 취급해야 한다 — 빈 리스트 그대로 두면 막대가 하나도 안 그려진다.
    // (인스턴스 필드는 타입 프로모션이 안 되므로 로컬 변수로 한 번 받는다.)
    final providedAmplitudes = amplitudes;
    final bars = (providedAmplitudes != null && providedAmplitudes.isNotEmpty)
        ? _normalizeToFullRange(providedAmplitudes)
        : _generateBars();
    final height = variant == WaveformVariant.expanded ? 64.0 : 32.0;

    Widget bar(int i, double amp) {
      final playedUpTo = (bars.length * progressRatio).floor();
      final played = i <= playedUpTo;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: (amp * height).clamp(3, height),
            decoration: BoxDecoration(
              color: played ? semantic : scheme.outline.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final waveform = Semantics(
      // 파형은 장식용 — 재생 위치는 별도 진행률 텍스트로 제공(접근성 요구사항).
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [for (var i = 0; i < bars.length; i++) bar(i, bars[i])],
            ),
            if (isBuffering)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );

    if (onScrub == null) return waveform;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
        onScrub!(ratio);
      },
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
        onScrub!(ratio);
      },
      child: waveform,
    );
  }
}
