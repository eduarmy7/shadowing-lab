import 'dart:async';

import '../entities/learning_settings.dart';

/// 마이 > 설정(#12) + 학습 옵션 시트(#5). 완전히 로컬 전용(기기별 설정).
abstract class SettingsRepository {
  Future<LearningSettings> getSettings();
  Stream<LearningSettings> watchSettings();
  Future<void> updateSettings(LearningSettings settings);
}
