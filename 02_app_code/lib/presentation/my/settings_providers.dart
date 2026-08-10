import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/learning_settings.dart';
import '../providers/repository_providers.dart';

/// 2026-08-10: 마이 탭의 설정 화면이 학습 기본값/알림/화면/계정 4개로 쪼개지면서,
/// 원래 `settings_screen.dart` 하나에 있던 이 provider를 공용 위치로 옮겼다 —
/// `main.dart`(테마/언어 적용)를 포함해 여러 화면이 함께 쓴다.
final learningSettingsProvider = StreamProvider.autoDispose<LearningSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

/// 여러 설정 화면이 공유하는 업데이트 헬퍼 — 현재 설정을 읽어 [updater]로 변형한 뒤 저장한다.
Future<void> updateLearningSettings(
  WidgetRef ref,
  LearningSettings Function(LearningSettings) updater,
) async {
  final repo = ref.read(settingsRepositoryProvider);
  final current = await repo.getSettings();
  await repo.updateSettings(updater(current));
}
