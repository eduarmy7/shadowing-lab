import '../../l10n/gen/app_localizations.dart';

/// 화면 곳곳(파일 카드 진행률, 타임스탬프, 학습 요약)에서 반복되는 포맷팅 유틸.
abstract class Formatters {
  /// 밀리초 → "00:07" (mm:ss). 문장 분리 결과 화면(#4)의 타임스탬프 표기용.
  static String msToClock(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 밀리초 → "0:00.5" (m:ss.d, 0.1초 단위). 문장 하나가 1~2초 안팎인 경우가 많은
  /// 단일 문장 편집 화면(#4-상세)에서 [msToClock]의 초 단위 반올림으로는 경계 드래그
  /// 결과가 화면에 거의 안 바뀐 것처럼 보여서(예: 500ms↔1500ms가 둘 다 "00:01") 별도로
  /// 0.1초 단위 표기를 쓴다.
  static String msToClockPrecise(int ms) {
    final totalDeciseconds = (ms / 100).round();
    final minutes = totalDeciseconds ~/ 600;
    final secondsWithDecimal = (totalDeciseconds % 600) / 10;
    return '$minutes:${secondsWithDecimal.toStringAsFixed(1).padLeft(4, '0')}';
  }

  /// 밀리초 → "8분 12초" / "8m 12s" / "8分12秒" (#6 학습 완료 요약, 마이 탭 학습 기록).
  static String duration(AppLocalizations l10n, int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return l10n.durationSecOnly(seconds);
    return l10n.durationMinSec(minutes, seconds);
  }

  static String percent(double ratio) => '${(ratio * 100).clamp(0, 100).round()}%';

  /// 날짜 → "2026년 8월 10일" / "8/10/2026" / "2026年8月10日" (마이 > 계정, 이용약관 등).
  static String date(AppLocalizations l10n, DateTime d) => l10n.fullDateLabel(d.year, d.month, d.day);
}
