/// 앱 전역 상수. UX 문서의 수치 가정(예: 지원 포맷, 최대 길이)을 한 곳에 모아
/// api-integrator/qa-engineer가 실측 후 값만 바꾸면 되도록 함.
abstract class AppConstants {
  static const String appName = '쉐도잉랩';
  static const String appNameEn = 'ShadowingLab';
  static const String appTagline = '내 파일로, 진짜 쉐도잉';

  /// 지원 미디어 확장자 (00_input.md, 01_ux_design.md #2 화면 기준).
  static const List<String> supportedAudioExtensions = ['mp3', 'm4a', 'wav'];
  static const List<String> supportedVideoExtensions = ['mp4', 'mov'];
  static List<String> get supportedExtensions => [
        ...supportedAudioExtensions,
        ...supportedVideoExtensions,
      ];

  /// 영상과 함께(선택) 첨부하는 자막 파일 확장자 — 있으면 자막 파싱 경로,
  /// 없으면 무음 감지 경로(00_input.md 문장 분리 방식).
  /// 2026-08-10: 'smi' 추가 — 한국 사용자층 자막 파일 다수가 SAMI 포맷이라는
  /// 실사용 피드백으로 지원 추가(core/utils/subtitle_parser.dart의 `_parseSami`).
  static const List<String> supportedSubtitleExtensions = ['srt', 'vtt', 'smi'];

  /// 업로드 가능 최대 길이(분) — #2 화면 안내 문구 "최대 60분".
  static const int maxMediaDurationMinutes = 60;

  /// 2026-08-06: 실기기에서 큰 실제 파일(예: 100분 이상 mp3)을 고를 때 `file_picker`가
  /// content:// URI를 앱 캐시로 실제 복사하는데(느린 저장소/기기에서 수 분 걸릴 수 있음)
  /// 이 복사 도중 화면이 꺼지면(잠금 타임아웃) 일부 안드로이드 기기에서 FlutterEngine이
  /// Activity와의 연결을 끊어버려("FlutterJNI was detached from native C++") 피커의
  /// `Future`가 영원히 응답을 못 받는 버그가 재현됨(에뮬레이터+갤럭시탭 실기기 모두 확인).
  /// 근본 원인은 [FileUploadScreen]에서 픽 도중 화면 꺼짐 방지 wakelock을 켜서 완화하지만,
  /// 그래도 막히는 경우를 위해 이 타임아웃으로 무한 대기 대신 재시도 가능한 에러로
  /// 전환한다.
  static const int filePickTimeoutMinutes = 5;

  /// [SilenceDetector.detect]에 씌우는 안전장치 타임아웃 — 화면 꺼짐/백그라운드 절전으로
  /// isolate 실행이 멈추는 경우([filePickTimeoutMinutes]와 같은 부류의 문제, 위 참고)든
  /// 특정 파일에서 네이티브 디코더 자체가 정말 멈추는 경우든, 무한 대기 대신 재시도
  /// 가능한 실패로 전환한다. 최대 업로드 길이(60분) 기준 실측 없이 넉넉하게 잡은 값 —
  /// 실기기 실측 데이터가 쌓이면 좁혀도 된다.
  ///
  /// 2026-08-06: 갤럭시탭 실기기 실측 — 118분짜리 mp3가 **34분** 걸림(0.29×실시간),
  /// 61분짜리도 20분을 넘김. 10분→20분으로 늘렸다가 그것도 부족해서 다시 60분으로
  /// 올렸다 — `maxMediaDurationMinutes`(60분) 한도 안의 파일이면 0.29×실시간보다
  /// 훨씬 못 미쳐야 정상이니 넉넉한 상한이다. 근본적으로는 디코딩 자체가 느린 게
  /// 문제라 타임아웃을 늘리는 것만으로는 "빠르게" 만들지 못한다 — 진행률 표시를
  /// 30%에서 안 멈추고 서서히 올라가게 만든 것([progressTimeConstantSeconds])과
  /// 별개로, 다음 과제는 (a) 60분 넘는 파일은 애초에 업로드 시점에 거부하거나
  /// (b) 사용자가 제안한 대로 긴 파일을 구간별로 잘라 순차 분석하는 방식으로
  /// 바꾸는 것.
  static const int silenceDetectionTimeoutMinutes = 60;

  /// 무음 감지 진행률 표시용 — 실제 진행률 콜백이 없는 [SilenceDetector.detect] 호출
  /// 동안 30%→95%를 점근적으로(느려지면서) 채워 보여준다: t초 뒤 진행률 ≈
  /// 0.3 + 0.65 × (1 − e^(−t / 이 값)). 이 값(초)마다 "남은 거리"의 63%씩 채워진다.
  ///
  /// **2026-08-08**: `audio_waveforms` O(N²) 성능 버그 패치([estimatedLocalSegmentationSecondsPer10Min]
  /// 주석 참고) 이후 118.5분 파일이 34.88분이 아니라 4.7분에 끝나므로, 300(5분)은 이제
  /// 완료 시점에도 곡선이 겨우 ~66%밖에 안 올라가 "다 됐는데 아직 덜 된 것처럼" 보인다.
  /// 100으로 줄임 — 100초 지점 약 71%, 300초(=이제 대부분의 실제 완료 시점) 지점 약 92%.
  static const double progressTimeConstantSeconds = 100;

  /// 로컬 무음/일시정지 구간 감지 예상 소요시간 안내용 추정치(#3 화면 "영상 10분당 약 X초").
  ///
  /// **2026-08-08**: `audio_waveforms`를 벤더링해 O(N²) 성능 버그를 패치한 뒤
  /// (`vendor/audio_waveforms/PATCH_NOTES.md` 참고 — 포인트마다 누적 파형 전체를
  /// 플랫폼 채널로 재전송하던 걸 추출당 ~200회로 스로틀) 다시 실측: 같은 118.5분짜리
  /// 실제 mp3 파일이 34.88분이 아니라 **4.7분**(10분당 23.8초, ≈4.15×실시간)에 끝난다.
  /// 예전 값(180초/10분)을 그대로 두면 이제 실제보다 7배 넘게 과장된 예상 시간이
  /// 표시된다. 기기/파일 편차에 대한 여유를 조금 두어 30으로 반올림 — 그래도 예전 대비
  /// 6배 개선된 값이다.
  static const double estimatedLocalSegmentationSecondsPer10Min = 30;

  /// 무음 감지(SilenceDetector) 파라미터 — 실측 오디오로 튜닝 전까지의 초기값.
  /// 최대 진폭 대비 이 비율 이하인 구간을 "무음"으로 판정한다.
  static const double silenceAmplitudeRatio = 0.12;
  /// 2026-08-23 추가, 2026-08-24 튜닝 — 배경음악이 계속 깔린 파일 대응. "최근
  /// 피크"(슬라이딩 윈도우 최댓값) 대비 이 비율 이하로 떨어지면, 절대적으로
  /// 조용하지 않아도(배경음악은 계속 나와도) 무음 후보로 인정한다.
  /// `silence_detector.dart`의 `_slidingWindowMax`와 함께 쓰인다. 실사용 배경음악
  /// 파일로 0.35 → 6문장까지는 나왔지만 사용자가 "6문장이네"(더 잘게 나뉘어야
  /// 정상)라고 확인 — 로그상 ratio<=.5인 샘플이 .35보다 78% 더 많아(1373 vs 723)
  /// 여유가 있어 0.5로 완화.
  static const double localSilenceRatio = 0.5;
  /// **2026-08-24 추가 — 실사용 치명적 버그 대응**: 상대 임계값([localSilenceRatio])
  /// 만으로 무음을 판정하면 "완전한 침묵"과 "직전 단어보다 그냥 조용하게 말한 진짜
  /// 단어"를 구분하지 못한다 — 실사용자 제보: "바이 루이스" 다음에 조용히 말한
  /// "세커"가 3.6초 내내 무음으로 오판돼 문장에서 통째로 사라짐(재생 불가능한
  /// 구간이 됨 — 편집 화면에서 합쳐도 복구 안 됨). 그래서 상대 임계값 판정에
  /// "파일 전체 최댓값 대비 이 비율보다는 절대적으로도 작아야 한다"는 조건을
  /// AND로 추가한다 — 진짜 무음(배경음악만 남고 대사가 없는 구간)은 대부분 절대
  /// 음량도 상당히 낮지만, 그냥 조용히 말한 단어는 상대적으로만 작을 뿐 절대
  /// 음량 자체는 이 정도는 넘는 경우가 많다는 전제.
  static const double localSilenceAbsoluteCeiling = 0.3;
  /// 이 길이(ms) 이상 무음이 이어져야 문장 경계(쉼)로 인정한다 — 03_api_integration.md
  /// 구 SentenceSegmenter 설계의 "pause ≥ 350ms" 값을 그대로 승계.
  static const int minPauseMs = 350;
  /// 이보다 짧게 끊기는 발화 구간은 노이즈로 보고 바로 앞 문장에 병합한다.
  ///
  /// **2026-08-24 버그 발견/튜닝**: 이 병합이 "직전 구간을 뒤로 늘리는" 방식이라(
  /// `silence_detector.dart`의 `_segmentFromAmplitudes` 3단계 참고), 700ms보다
  /// 짧은 진짜 발화(감탄사 등)가 있으면 그 뒤에 정상적으로 감지된 무음 구간까지
  /// 통째로 삼켜 다음 문장과 합쳐버린다 — 사용자가 실기기 파형에서 "가운데
  /// 평평한(무음) 구간이 있는데도 안 끊겼다"고 발견. 오늘 쉼 감지가 촘촘해지며
  /// (`localSilenceRatio`) 짧은 발화가 늘어 이 버그가 더 자주 발동했다. 700ms는
  /// 너무 공격적인 필터였다고 보고 300ms로 완화.
  static const int minSentenceMs = 300;
  /// **2026-08-24 추가 — 사용자 제안(처음 50ms → 100ms로 조정)**: 무음 판정
  /// 경계에서 문장을 칼같이 자르면 꼬리 모음(예: "세커"의 "어" 소리)이나 시작
  /// 자음이 살짝 잘려 들리는 문제가 있었다("색까지만 들리고 모음이 사라진 것
  /// 같다"는 실사용 제보). 문장 시작은 이만큼 당기고 끝은 이만큼 늘려서 여유를
  /// 둔다 — 인접 문장 사이 무음 구간이 항상 [minPauseMs](350ms) 이상이라 양쪽에서
  /// 100ms씩(총 200ms) 당겨써도 다음 문장과 겹칠 일은 없다.
  static const int sentenceBoundaryPaddingMs = 100;

  /// 학습 옵션 기본값.
  static const int defaultRepeatCount = 5;
  static const int minRepeatCount = 3;
  static const int maxRepeatCount = 10;
  static const double defaultPlaybackSpeed = 1.0;
  // 2026-08-28: 0.25 단위(7단계)로는 세밀한 조절이 부족하다는 사용자 요청으로
  // 0.5~2.0 사이를 0.1 단위(16단계)로 촘촘하게 바꿨다. 고르는 화면(학습 옵션
  // 드롭다운/학습 기본값 바텀시트) 둘 다 항목 수 증가에 맞춰 확인 완료 —
  // 특히 바텀시트는 스크롤 없이는 아래쪽 항목이 가려질 수 있어 스크롤 가능하게
  // 함께 고쳤다(`learning_defaults_screen.dart`의 `_showSpeedPicker`).
  static const List<double> availablePlaybackSpeeds = [
    0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0,
  ];
}
