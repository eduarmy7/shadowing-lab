import 'dart:ui' show Locale;
import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

enum AppThemeModeOption { system, light, dark }

/// 2026-08-08: 외국인 사용자 지원 — 마이 > 설정에서 앱 표시 언어를 고를 수 있게 한다.
/// `system`은 기기 언어를 따라가고(지원 언어 밖이면 한국어로 폴백), 나머지는 기기
/// 언어와 무관하게 항상 그 언어로 고정 표시한다.
enum AppLanguageOption { system, korean, english, japanese }

extension AppLanguageOptionX on AppLanguageOption {
  /// null이면 시스템 언어를 따라간다는 뜻 — `main.dart`에서 `MaterialApp.locale`을
  /// null로 두면 Flutter가 기기 언어 중 `supportedLocales`와 가장 잘 맞는 걸 고른다.
  Locale? get locale => switch (this) {
        AppLanguageOption.system => null,
        AppLanguageOption.korean => const Locale('ko'),
        AppLanguageOption.english => const Locale('en'),
        AppLanguageOption.japanese => const Locale('ja'),
      };
}

/// 2026-08-06: 원어민 음성을 들은 뒤 "따라 말하기" 단계에 얼마나 시간을 줄지 —
/// 사용자가 직접 고를 수 있게 한 옵션(학습 옵션 시트). 문장 길이에 비례한 배수 대신
/// 명시적인 4가지 선택지로 바꿨다 — 사용자가 "이만큼이면 충분하다/부족하다"를 직관적
/// 으로 가늠하기 쉽다.
enum SentenceGapMode { none, matchSentence, plusOneSecond, plusTwoSeconds }

extension SentenceGapModeX on SentenceGapMode {
  String get label => switch (this) {
        SentenceGapMode.none => '공간 없이 반복',
        SentenceGapMode.matchSentence => '문장 길이만큼 띄우기',
        SentenceGapMode.plusOneSecond => '문장 길이 +1초',
        SentenceGapMode.plusTwoSeconds => '문장 길이 +2초',
      };

  /// [segmentDurationMs]: 지금 문장의 원어민 음성 길이. 이 값을 기준으로 "따라
  /// 말하기" 단계에 줄 시간(ms)을 계산한다.
  int gapMsFor(int segmentDurationMs) => switch (this) {
        SentenceGapMode.none => 0,
        SentenceGapMode.matchSentence => segmentDurationMs,
        SentenceGapMode.plusOneSecond => segmentDurationMs + 1000,
        SentenceGapMode.plusTwoSeconds => segmentDurationMs + 2000,
      };
}

/// 마이 > 설정(#12) + 학습 옵션 시트(#5) 공용 설정 엔티티.
class LearningSettings extends Equatable {
  final int defaultRepeatCount;
  final double defaultPlaybackSpeed;
  final bool autoShowTranslation;
  final bool handsFreeMode;
  final bool voiceRecordingEnabled;
  final AppThemeModeOption themeMode;
  final double fontScale; // 1.0 = 보통, 접근성 "글자 크기" 설정
  final bool reminderEnabled;
  final String reminderTime; // "HH:mm"
  final SentenceGapMode sentenceGapMode;
  final AppLanguageOption languageOption;

  const LearningSettings({
    this.defaultRepeatCount = AppConstants.defaultRepeatCount,
    this.defaultPlaybackSpeed = AppConstants.defaultPlaybackSpeed,
    this.autoShowTranslation = false,
    this.handsFreeMode = true,
    this.voiceRecordingEnabled = false,
    this.themeMode = AppThemeModeOption.system,
    this.fontScale = 1.0,
    this.reminderEnabled = false,
    this.reminderTime = '20:00',
    this.sentenceGapMode = SentenceGapMode.matchSentence,
    // 기본값은 'system'이 아니라 'korean' — 이 앱은 원래 기기 언어와 무관하게 항상
    // 한국어로 고정 표시됐으므로(main.dart의 예전 Locale('ko','KR') 하드코딩과 동일한
    // 동작), 다국어 지원을 켜면서 기존 사용자에게 갑자기 다른 언어가 보이는 일이
    // 없게 한다. 새 사용자가 원하면 설정에서 '시스템 설정'이나 다른 언어로 바꾸면 된다.
    this.languageOption = AppLanguageOption.korean,
  });

  LearningSettings copyWith({
    int? defaultRepeatCount,
    double? defaultPlaybackSpeed,
    bool? autoShowTranslation,
    bool? handsFreeMode,
    bool? voiceRecordingEnabled,
    AppThemeModeOption? themeMode,
    double? fontScale,
    bool? reminderEnabled,
    String? reminderTime,
    SentenceGapMode? sentenceGapMode,
    AppLanguageOption? languageOption,
  }) {
    return LearningSettings(
      defaultRepeatCount: defaultRepeatCount ?? this.defaultRepeatCount,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      autoShowTranslation: autoShowTranslation ?? this.autoShowTranslation,
      handsFreeMode: handsFreeMode ?? this.handsFreeMode,
      voiceRecordingEnabled: voiceRecordingEnabled ?? this.voiceRecordingEnabled,
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      sentenceGapMode: sentenceGapMode ?? this.sentenceGapMode,
      languageOption: languageOption ?? this.languageOption,
    );
  }

  factory LearningSettings.fromJson(Map<String, dynamic> json) => LearningSettings(
        defaultRepeatCount: json['defaultRepeatCount'] as int? ?? AppConstants.defaultRepeatCount,
        defaultPlaybackSpeed:
            (json['defaultPlaybackSpeed'] as num?)?.toDouble() ?? AppConstants.defaultPlaybackSpeed,
        autoShowTranslation: json['autoShowTranslation'] as bool? ?? false,
        handsFreeMode: json['handsFreeMode'] as bool? ?? true,
        voiceRecordingEnabled: json['voiceRecordingEnabled'] as bool? ?? false,
        themeMode: AppThemeModeOption.values.byName(json['themeMode'] as String? ?? 'system'),
        fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderTime: json['reminderTime'] as String? ?? '20:00',
        sentenceGapMode:
            SentenceGapMode.values.byName(json['sentenceGapMode'] as String? ?? 'matchSentence'),
        languageOption:
            AppLanguageOption.values.byName(json['languageOption'] as String? ?? 'korean'),
      );

  Map<String, dynamic> toJson() => {
        'defaultRepeatCount': defaultRepeatCount,
        'defaultPlaybackSpeed': defaultPlaybackSpeed,
        'autoShowTranslation': autoShowTranslation,
        'handsFreeMode': handsFreeMode,
        'voiceRecordingEnabled': voiceRecordingEnabled,
        'themeMode': themeMode.name,
        'fontScale': fontScale,
        'reminderEnabled': reminderEnabled,
        'reminderTime': reminderTime,
        'sentenceGapMode': sentenceGapMode.name,
        'languageOption': languageOption.name,
      };

  @override
  List<Object?> get props => [
        defaultRepeatCount,
        defaultPlaybackSpeed,
        autoShowTranslation,
        handsFreeMode,
        voiceRecordingEnabled,
        themeMode,
        languageOption,
        fontScale,
        reminderEnabled,
        reminderTime,
        sentenceGapMode,
      ];
}
