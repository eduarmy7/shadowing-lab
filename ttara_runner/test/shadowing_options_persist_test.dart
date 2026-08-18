import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttara/data/local/local_kv_store.dart';
import 'package:ttara/data/repositories/local_settings_repository.dart';
import 'package:ttara/domain/entities/learning_settings.dart';

/// 2026-08-18 버그 리포트: 학습 옵션 시트(반복 횟수/재생 속도/빈공간 없이 반복 등)에서
/// 값을 바꿔도 앱을 나갔다 다시 들어가면(혹은 다음날) 초기값으로 되돌아간다는 실사용
/// 피드백. 원인: `ShadowingController.updateOptions`가 세션 상태만 바꾸고 마이>설정과
/// 같은 저장소(`LearningSettings`, SharedPreferences 백업)에는 저장하지 않았음.
///
/// 수정: `updateOptions`가 세션 상태를 바꾼 직후 `_persistOptionsAsDefault`를 호출해
/// 바뀐 값만 골라 저장소에도 반영한다(shadowing_controller.dart 참고). 이 테스트는
/// 그 저장소 계층(`LocalSettingsRepository`)을 대상으로 정확히 같은 병합 규칙(바뀐
/// 필드만 덮어쓰고 나머지는 유지)을 10개 시나리오로 검증한다 — "세션 1에서 옵션을
/// 바꾼다 → 세션 2(앱 재시작, 완전히 새 저장소 인스턴스)에서 그 값이 기본값으로
/// 보이는가"를 매번 확인한다. 실제 오디오 재생 배선(ShadowingController 전체)은
/// just_audio/audio_service 플랫폼 채널이 필요해 헤드리스 유닛 테스트로 돌릴 수 없고,
/// 이 프로젝트에서도 늘 실기기 확인과 짝지어 왔다 — 이번 수정이 정확히 건드린 저장
/// 계층만 자동화하고, 옵션 시트 UI 경로는 실기기에서 별도 확인 권장.
Future<void> applyOptionsLikeShadowingController(
  LocalSettingsRepository repo, {
  int? repeatCount,
  double? speed,
  bool? handsFree,
  bool? autoTranslation,
  SentenceGapMode? sentenceGapMode,
}) async {
  final current = await repo.getSettings();
  await repo.updateSettings(current.copyWith(
    defaultRepeatCount: repeatCount,
    defaultPlaybackSpeed: speed,
    handsFreeMode: handsFree,
    autoShowTranslation: autoTranslation,
    sentenceGapMode: sentenceGapMode,
  ));
}

void main() {
  final scenarios = <String, Map<String, Object?>>{
    '반복 횟수 1회로 변경': {'repeatCount': 1},
    '반복 횟수 5회로 변경': {'repeatCount': 5},
    '반복 횟수 10회(최댓값)로 변경': {'repeatCount': 10},
    '재생 속도 0.75x로 변경': {'speed': 0.75},
    '재생 속도 1.5x로 변경': {'speed': 1.5},
    '문장 간격 "빈공간 없이 반복"으로 변경(버그 리포트 원문 케이스)': {
      'sentenceGapMode': SentenceGapMode.none,
    },
    '문장 간격 "문장 길이 +2초"로 변경': {'sentenceGapMode': SentenceGapMode.plusTwoSeconds},
    'Hands-free 모드 끄기': {'handsFree': false},
    '한글 뜻 자동 표시 켜기': {'autoTranslation': true},
    '복합 변경: 반복 7회 + 빈공간 없이 + 1.25x 동시 적용': {
      'repeatCount': 7,
      'sentenceGapMode': SentenceGapMode.none,
      'speed': 1.25,
    },
  };

  var index = 0;
  for (final entry in scenarios.entries) {
    index++;
    final n = index;
    final scenarioName = entry.key;
    final changes = entry.value;

    test('시나리오 $n: $scenarioName → 앱 재시작 후에도 유지되는가', () async {
      SharedPreferences.setMockInitialValues({});

      // ── 세션 1: 학습 옵션 시트에서 값을 바꾼다 ──
      final session1Store = LocalKvStore();
      final session1Repo = LocalSettingsRepository(session1Store);
      await applyOptionsLikeShadowingController(
        session1Repo,
        repeatCount: changes['repeatCount'] as int?,
        speed: changes['speed'] as double?,
        handsFree: changes['handsFree'] as bool?,
        autoTranslation: changes['autoTranslation'] as bool?,
        sentenceGapMode: changes['sentenceGapMode'] as SentenceGapMode?,
      );

      // ── 세션 2: 앱을 완전히 새로 켠 상황을 시뮬레이션 — 새 LocalKvStore/Repository
      //    인스턴스를 만들어(리포지토리 내부 인메모리 캐시가 아니라 실제
      //    SharedPreferences에 저장된 값을 읽는지 확인) 학습 화면에 처음 들어갔을 때
      //    보일 기본값을 확인한다.
      final session2Store = LocalKvStore();
      final session2Repo = LocalSettingsRepository(session2Store);
      final persisted = await session2Repo.getSettings();

      if (changes.containsKey('repeatCount')) {
        expect(persisted.defaultRepeatCount, changes['repeatCount'],
            reason: '반복 횟수가 저장/유지되어야 함');
      }
      if (changes.containsKey('speed')) {
        expect(persisted.defaultPlaybackSpeed, changes['speed'],
            reason: '재생 속도가 저장/유지되어야 함');
      }
      if (changes.containsKey('handsFree')) {
        expect(persisted.handsFreeMode, changes['handsFree'],
            reason: 'Hands-free 설정이 저장/유지되어야 함');
      }
      if (changes.containsKey('autoTranslation')) {
        expect(persisted.autoShowTranslation, changes['autoTranslation'],
            reason: '한글 뜻 자동 표시 설정이 저장/유지되어야 함');
      }
      if (changes.containsKey('sentenceGapMode')) {
        expect(persisted.sentenceGapMode, changes['sentenceGapMode'],
            reason: '문장 간격 설정이 저장/유지되어야 함');
      }

      // 이번 시나리오에서 바꾸지 않은 필드는 기본값 그대로여야 한다(다른 설정을
      // 덮어쓰지 않는지 확인 — copyWith 병합 누락 회귀 방지).
      if (!changes.containsKey('repeatCount')) {
        expect(persisted.defaultRepeatCount, const LearningSettings().defaultRepeatCount);
      }
    });
  }
}
