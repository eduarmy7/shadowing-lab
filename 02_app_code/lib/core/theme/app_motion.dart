import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

/// 01_ux_design.md "모션/트랜지션 스펙" 표를 코드 토큰화.
/// `AppMotion.reduceMotion`이 true면 모든 duration을 120ms/Fade로 강제 대체한다
/// (OS 접근성 "모션 감소" 설정 대응 — main.dart에서 MediaQuery.disableAnimations로 갱신).
abstract class AppMotion {
  static bool reduceMotion = false;

  static Duration get stackTransition =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 280);
  static const Curve stackCurve = Curves.easeOutCubic;

  static Duration get sheetTransition =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 220);
  static const Curve sheetCurve = Curves.easeOut;

  static Duration get sentenceCardTransition =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 250);
  static const Curve sentenceCardCurve = Curves.easeInOutCubic;

  static Duration get dotFillTransition =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 150);

  static Duration get mergeSplitTransition =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 300);
  static const Curve mergeSplitCurve = Curves.easeInOutQuart;

  /// 현재 플랫폼의 "모션 감소" 접근성 설정을 읽어와 반영한다. main.dart의
  /// MaterialApp builder에서 최초 1회 + didChangeAccessibilityFeatures에서 호출.
  static void syncWithPlatform() {
    reduceMotion = SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }
}
