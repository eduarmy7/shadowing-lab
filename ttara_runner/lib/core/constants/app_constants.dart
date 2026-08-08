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
  static const List<String> supportedSubtitleExtensions = ['srt', 'vtt'];

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
  /// 300(5분)으로 잡으면 5분 지점에서 약 71%, 10분 지점에서 약 86%, 15분 지점에서
  /// 약 92%를 보여준다 — [silenceDetectionTimeoutMinutes](20분)에 가까워질 때까지도
  /// 계속(아주 조금씩) 올라가서 "멈춘 것처럼" 보이지 않는다.
  static const double progressTimeConstantSeconds = 300;

  /// 로컬 무음/일시정지 구간 감지 예상 소요시간 안내용 추정치(#3 화면 "영상 10분당 약 X초").
  /// 2026-08-07: 118.5분짜리 실제 파일을 갤럭시탭 실기기에서 끝까지 돌려 정확히 측정한
  /// 값으로 다시 교체 — 34.88분 걸림 = 10분당 176.6초(≈0.294×실시간). 예전 값(60초/10분)은
  /// "10분 넘게 걸림" 정도의 대략적 관찰만으로 잡은 값이라 실측보다 3배 가까이 낙관적이었고,
  /// 그래서 #3 화면 예상 소요시간 안내가 실제보다 한참 짧게 표시되고 있었다. 소폭의 여유를
  /// 둬서 180으로 반올림.
  static const double estimatedLocalSegmentationSecondsPer10Min = 180;

  /// 무음 감지(SilenceDetector) 파라미터 — 실측 오디오로 튜닝 전까지의 초기값.
  /// 최대 진폭 대비 이 비율 이하인 구간을 "무음"으로 판정한다.
  static const double silenceAmplitudeRatio = 0.12;
  /// 이 길이(ms) 이상 무음이 이어져야 문장 경계(쉼)로 인정한다 — 03_api_integration.md
  /// 구 SentenceSegmenter 설계의 "pause ≥ 350ms" 값을 그대로 승계.
  static const int minPauseMs = 350;
  /// 이보다 짧게 끊기는 발화 구간은 노이즈로 보고 바로 앞 문장에 병합한다.
  static const int minSentenceMs = 700;

  /// 학습 옵션 기본값.
  static const int defaultRepeatCount = 5;
  static const int minRepeatCount = 3;
  static const int maxRepeatCount = 10;
  static const double defaultPlaybackSpeed = 1.0;
  static const List<double> availablePlaybackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// 몇 문장마다 전면 광고 자연 전환 지점을 둘지 (#5 화면 설계 원칙).
  static const int interstitialAdEverySentences = 5;

  /// 라이브러리 페이지네이션 최초 프리페치 개수.
  static const int libraryPagePrefetchCount = 10;

  /// 라이브러리 오프라인 캐시 상한(최근 열람 콘텐츠 수).
  static const int libraryOfflineCacheLimit = 5;
}
