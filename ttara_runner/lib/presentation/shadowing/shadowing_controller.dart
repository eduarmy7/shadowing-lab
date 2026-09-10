import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/study_audio_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/learning_settings.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../domain/entities/user_stats.dart';
import '../providers/repository_providers.dart';

enum ShadowingPhase { idle, listening, speaking, sentenceComplete }

/// 책 한 권/영화 한 편처럼 문장 수가 아주 많은 콘텐츠 대응 — 한 문장씩 몰입 연습(single)과
/// 여러 문장을 한 화면에서 훑어보며 원하는 곳으로 바로 이동(list) 사이를 전환한다.
enum ShadowingViewMode { single, list }

class ShadowingSessionState {
  final List<SentenceSegment> segments;
  final int currentIndex;
  final ShadowingPhase phase;
  final int completedRepeats;
  final int targetRepeats;
  final bool handsFree;
  final double playbackSpeed;
  final bool showTranslation;
  final bool isLoading;
  final bool isBuffering;
  final String? error;
  final Set<int> fullyCompletedIndices;
  final bool awaitingManualAdvance; // handsFree OFF: 완료 후 스와이프 대기
  // 2026-08-09: 정지 버튼으로 멈춘 뒤 아직 재생을 재개하지 않은 상태 — true면 원형 CTA를
  // 다시 눌렀을 때 문장 처음이 아니라 멈춘 지점부터 이어서 재생한다([resumeOrRestart]).
  final bool awaitingResume;
  final DateTime sessionStartedAt;
  final ShadowingViewMode viewMode;
  final bool filterFlaggedOnly; // 한꺼번에 보기에서 표시(🚩)한 문장만 걸러 보기
  final SentenceGapMode sentenceGapMode; // "따라 말하기" 단계 길이 — 학습 옵션에서 설정
  // 2026-08-06: 파형 위 "재생 위치" 표시용 — 예전엔 재생 중이면 무조건 0.5(파형의
  // 정확히 절반)로 고정해뒀었다("파형이 반쪽만 나온다"는 피드백의 원인). 이제
  // positionStream을 실시간으로 반영한다.
  final double playbackProgressRatio;
  // 2026-09-01 추가 — 영상 파일이면 "한 문장씩 보기"에서 무음 비디오를 겹쳐 보여주기
  // 위해 화면(위젯)에서 알아야 하는 정보. 실제 오디오 재생과는 무관(AudioPlayerService가
  // 그대로 전담) — 표시 여부 판단과 파일 경로 전달용이다.
  final MediaSourceType mediaSourceType;
  final String mediaPath;
  // 2026-09-01 추가 — "듣기" 단계가 새로 시작될 때마다(같은 문장 반복 포함) 증가하는
  // 값. "공간없이" 설정처럼 듣기→말하기→듣기 전환이 한 프레임 안에서 벌어지면,
  // [phase]의 listening→speaking→listening 전환 중간값이 위젯 리빌드에 아예 반영되지
  // 않고 건너뛰어질 수 있다(Flutter가 짧게 스쳐가는 상태를 별도 프레임으로 그리지
  // 않음) — 그러면 SentenceVideoPlayer가 "isPlaying이 false였다가 true로 바뀜"이라는
  // 신호를 영영 못 받아 반복 2회차부터 재생을 다시 시작하지 못했다(실기기 확인: 5번
  // 반복 중 1회차만 영상이 움직이고 2~5회차는 정지). true/false 에지 감지 대신, 매
  // 반복 시작마다 이 값 자체가 달라지므로 놓칠 수가 없다.
  final int playAttempt;

  ShadowingSessionState({
    this.segments = const [],
    this.currentIndex = 0,
    this.phase = ShadowingPhase.idle,
    this.completedRepeats = 0,
    this.targetRepeats = AppConstants.defaultRepeatCount,
    this.handsFree = true,
    this.playbackSpeed = AppConstants.defaultPlaybackSpeed,
    this.showTranslation = false,
    this.isLoading = true,
    this.isBuffering = false,
    this.error,
    this.fullyCompletedIndices = const {},
    this.awaitingManualAdvance = false,
    this.awaitingResume = false,
    DateTime? sessionStartedAt,
    this.viewMode = ShadowingViewMode.single,
    this.filterFlaggedOnly = false,
    this.sentenceGapMode = SentenceGapMode.matchSentence,
    this.playbackProgressRatio = 0,
    this.mediaSourceType = MediaSourceType.audio,
    this.mediaPath = '',
    this.playAttempt = 0,
  }) : sessionStartedAt = sessionStartedAt ?? DateTime.now();

  SentenceSegment? get currentSegment => currentIndex < segments.length ? segments[currentIndex] : null;
  bool get isLastSentence => currentIndex >= segments.length - 1;
  bool get isSessionFullyDone => segments.isNotEmpty && fullyCompletedIndices.length >= segments.length;

  ShadowingSessionState copyWith({
    List<SentenceSegment>? segments,
    int? currentIndex,
    ShadowingPhase? phase,
    int? completedRepeats,
    int? targetRepeats,
    bool? handsFree,
    double? playbackSpeed,
    bool? showTranslation,
    bool? isLoading,
    bool? isBuffering,
    String? error,
    bool clearError = false,
    Set<int>? fullyCompletedIndices,
    bool? awaitingManualAdvance,
    bool? awaitingResume,
    DateTime? sessionStartedAt,
    ShadowingViewMode? viewMode,
    bool? filterFlaggedOnly,
    SentenceGapMode? sentenceGapMode,
    double? playbackProgressRatio,
    MediaSourceType? mediaSourceType,
    String? mediaPath,
    int? playAttempt,
  }) {
    return ShadowingSessionState(
      segments: segments ?? this.segments,
      currentIndex: currentIndex ?? this.currentIndex,
      phase: phase ?? this.phase,
      completedRepeats: completedRepeats ?? this.completedRepeats,
      targetRepeats: targetRepeats ?? this.targetRepeats,
      handsFree: handsFree ?? this.handsFree,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      showTranslation: showTranslation ?? this.showTranslation,
      isLoading: isLoading ?? this.isLoading,
      isBuffering: isBuffering ?? this.isBuffering,
      error: clearError ? null : (error ?? this.error),
      fullyCompletedIndices: fullyCompletedIndices ?? this.fullyCompletedIndices,
      awaitingManualAdvance: awaitingManualAdvance ?? this.awaitingManualAdvance,
      awaitingResume: awaitingResume ?? this.awaitingResume,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      viewMode: viewMode ?? this.viewMode,
      filterFlaggedOnly: filterFlaggedOnly ?? this.filterFlaggedOnly,
      sentenceGapMode: sentenceGapMode ?? this.sentenceGapMode,
      playbackProgressRatio: playbackProgressRatio ?? this.playbackProgressRatio,
      mediaSourceType: mediaSourceType ?? this.mediaSourceType,
      mediaPath: mediaPath ?? this.mediaPath,
      playAttempt: playAttempt ?? this.playAttempt,
    );
  }
}

/// 2026-08-28 추가 — 앱을 백그라운드에서 재개할 때 "학습 화면이 지금 떠 있었는지"를
/// 판단하기 위한 신호. 원래는 `router.routerDelegate.currentConfiguration.uri`(현재
/// 라우터 위치 문자열)로 판단했는데, 실기기 로그로 확인해보니 `/shadowing/:id`가
/// `StatefulShellRoute` 바깥에 push되는 라우트라 그런지, 학습 화면이 실제로 화면에
/// 떠 있는 도중에도 이 값이 계속 '/home'으로 잘못 읽히는 현상이 있었다(정확한 GoRouter
/// 내부 원인은 특정 못함) — 그래서 `main.dart`의 "세션 끝났으면 홈으로" 체크가 항상
/// "이미 홈이네, 할 일 없음"으로 오판하고 아무 것도 안 했다. 대신 이 화면의 State가
/// 실제로 마운트돼 있는지를 직접 추적하는 훨씬 신뢰할 수 있는 신호로 대체한다
/// (`shadowing_screen.dart`의 `initState`/`dispose`에서 갱신).
final isShadowingScreenMountedProvider = StateProvider<bool>((ref) => false);

/// 2026-09-10 추가 — 근본 원인: `AudioPlayerService`는 앱 전체 공유 싱글톤인데,
/// `ShadowingController`는 라우터가 예전 화면을 제대로 dispose하지 않는 경우가 실제로
/// 있어(로그로 확인됨 — `go('/home')`를 호출해도 `dispose()`가 안 찍히는 사례) 여러
/// 인스턴스가 동시에 살아있을 수 있다. "다른 파일을 열면 이전 재생은 반드시 멈춰야
/// 한다"를 라우터/위젯 생명주기에 기대지 않고 **재생 로직 자체에서 강제**하기 위한
/// 장치 — 지금 어떤 mediaId가 "현재 활성 세션"인지 담아두고, 모든 컨트롤러는 실제로
/// 재생을 진행하기 전에 매번 "내가 아직 활성 세션이 맞는가"를 확인한다. 아니라면
/// (더 최근에 다른 파일이 열렸다는 뜻) 조용히 스스로 멈춘다 — dispose가 안 됐어도
/// 안전하다.
final activeMediaSessionProvider = StateProvider<String?>((ref) => null);

final shadowingControllerProvider = StateNotifierProvider.autoDispose
    .family<ShadowingController, ShadowingSessionState, String>(
  (ref, mediaId) => ShadowingController(ref, mediaId),
);

/// #5 쉐도잉 학습 화면 뷰모델 — 앱의 심장. 원버튼(듣기↔말하기) 자동 루프를 상태머신으로 구현.
///
/// 광고 SDK 배치 원칙(01_ux_design.md): 이 컨트롤러는 **의도적으로 AdService를 참조하지
/// 않는다** — 학습 루프 몰입 보호를 위해 광고 관련 호출 자체를 이 레이어에 두지 않는 것이
/// 설계 요구사항이다. "문장 5개마다 자연스러운 전환 지점" 광고 훅이 필요해지면, 이 화면을
/// 벗어나는 전면 라우트(예: 별도 인터스티셜 라우트)로 구현할 것을 권장한다.
class ShadowingController extends StateNotifier<ShadowingSessionState> {
  final Ref ref;
  final String mediaId;

  int _gen = 0;
  int _playAttempt = 0; // ShadowingSessionState.playAttempt 문서 참고.
  String _audioSource = '';
  String _fileName = '';
  Uri? _coverArtUri;
  StreamSubscription<Duration>? _overrunWatchdogSub;
  bool _resyncingFromOverrun = false;
  StudyAudioHandler? _audioHandler;

  /// activeMediaSessionProvider 문서 참고 — 더 최근에 열린 다른 파일이 있으면 false.
  bool get _isActiveSession => ref.read(activeMediaSessionProvider) == mediaId;

  // 2026-08-10: 전체 학습기록(#11) 실시간 집계용 — 문장이 완료 처리될 때마다
  // "마지막 기록 이후 흐른 시간"을 그 문장(오늘 날짜+이 콘텐츠)에 귀속시킨다.
  // 정확한 스톱워치는 아니지만(따라 말하기 대기시간 등도 포함), 실제 학습에 쓴
  // 시간의 합리적 근사치다.
  DateTime _lastProgressFlushAt = DateTime.now();

  ShadowingController(this.ref, this.mediaId) : super(ShadowingSessionState()) {
    debugPrint('[ShadowingController] CREATED mediaId=$mediaId');
    // 2026-09-10 버그 수정 — 사용자 재현: "공부하다가 정지 안 누르고 다른 음성/영상을
    // 클릭하면 이중으로 재생됨". 새 컨트롤러가 만들어지는 바로 그 순간, 이전에 누가
    // 활성 세션이었든 상관없이 즉시 이 mediaId가 새 활성 세션임을 선언하고 공유
    // 재생기를 강제로 멈춘다 — 사용자가 정지 버튼을 누를 필요 없이 자동으로 처리된다.
    // **버그 수정(2)**: 이 대입을 생성자에서 바로 동기적으로 실행하면 "다른 프로바이더가
    // 빌드되는 도중에 또 다른 프로바이더 상태를 바꿨다"는 Riverpod의 재진입 방지
    // assertion(`_debugCurrentlyBuildingElement == null`)에 걸려 실기기에서 즉시
    // 빨간 에러 화면으로 이어졌다(실측 확인) — 이 컨트롤러 자체가 지금 막
    // `ref.watch(shadowingControllerProvider(...))` 빌드 도중에 생성되는 중이기
    // 때문. 같은 프레임 안에서 상태를 바꾸는 대신 `Future.microtask`로 한 틱 미뤄서
    // 빌드가 끝난 뒤에 안전하게 실행한다.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(activeMediaSessionProvider.notifier).state = mediaId;
      unawaited(ref.read(audioPlayerServiceProvider).stopSegment());
    });
    _init();
  }

  Future<void> _init() async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).getSettings();
      final segments = await ref.read(segmentationRepositoryProvider).getSegments(mediaId);
      final media = await ref.read(mediaRepositoryProvider).getById(mediaId);
      _audioSource = media?.localPath ?? '';
      _fileName = media?.fileName ?? '';
      _coverArtUri = media?.coverArtPath != null ? Uri.file(media!.coverArtPath!) : null;
      final startIndex = media?.lastPlayedSentenceIndex ?? 0;
      // 2026-08-09: 최근학습(홈)에서 이미 진행 중이던 책을 다시 열면(=이어서 학습,
      // lastPlayedSentenceIndex > 0) 곧장 한 문장씩 자동재생으로 들어가는 대신 한꺼번에
      // 보기로 먼저 보여준다 — 어디까지 했는지 맥락을 보고 원하는 문장을 골라 이어갈 수
      // 있게(사용자 피드백: 한 문장 화면으로 바로 떨어지면 맥락 없이 갑자기 시작돼
      // 당황스럽다). 처음 시작하는 콘텐츠(index 0)는 기존처럼 바로 몰입 모드로 들어간다.
      final initialViewMode = startIndex > 0 ? ShadowingViewMode.list : ShadowingViewMode.single;

      state = state.copyWith(
        segments: segments,
        isLoading: false,
        currentIndex: segments.isEmpty ? 0 : startIndex.clamp(0, segments.length - 1),
        targetRepeats: settings.defaultRepeatCount,
        playbackSpeed: settings.defaultPlaybackSpeed,
        handsFree: settings.handsFreeMode,
        showTranslation: settings.autoShowTranslation,
        sentenceGapMode: settings.sentenceGapMode,
        viewMode: initialViewMode,
        mediaSourceType: media?.sourceType ?? MediaSourceType.audio,
        mediaPath: _audioSource,
        // 2026-08-10: 완료 체크는 문장 자체에 영구 저장된 값에서 매번 다시 계산한다
        // (세션 한정 Set이 아니다) — 그래야 화면을 나갔다 들어와도 유지되고,
        // 학습 중 병합/분리를 해도 [reloadSegments]가 최신 인덱스 기준으로
        // 다시 계산해준다.
        fullyCompletedIndices: _completedIndicesOf(segments),
      );

      if (segments.isNotEmpty && _audioSource.isNotEmpty) {
        await ref.read(audioPlayerServiceProvider).setSource(_audioSource, isLocal: true);
      }
      _overrunWatchdogSub =
          ref.read(audioPlayerServiceProvider).positionStream.listen(_watchForExternalOverrun);

      claimNotificationCallbacks();

      if (initialViewMode == ShadowingViewMode.single) {
        _runSentenceLoop();
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '학습 콘텐츠를 불러오지 못했어요');
    }
  }

  /// 잠금화면/알림 미니 플레이어의 이전·재생/정지·다음 버튼을 이 컨트롤러의 메서드로
  /// 직접 연결한다 — 알림이 재생기를 우회해서 만지지 않게 되어, 반복/속도 설정이
  /// 그대로 적용되고 정지도 진짜로 멈춘 채 있는다([StudyAudioHandler] 문서 참고).
  ///
  /// **2026-09-07 버그 수정 — 근본 원인**: `StudyAudioHandler`는 앱 전체 싱글톤인데,
  /// 예전엔 이 등록을 [_init]에서 딱 한 번만 했다. `ShadowingController`는
  /// `autoDispose.family`라 같은 mediaId로 다시 들어오면(예: 다른 영상 봤다가 이
  /// 영상으로 돌아옴) 인스턴스가 재사용되며 [_init]이 다시 실행되지 않는다 — 그
  /// 사이 다른 영상의 컨트롤러가 `_init()`을 돌며 알림 콜백을 자기 걸로 덮어썼다면,
  /// 지금 화면에 보이는 이 컨트롤러로 다시 돌아와도 알림의 정지/재생 버튼은 여전히
  /// "가장 최근에 초기화됐던" 다른(이미 화면에 없는) 컨트롤러를 가리키고 있었다.
  /// 그 결과 사용자가 (실제로 소리를 내고 있는) 이 화면에서 정지를 눌러도 엉뚱한
  /// 컨트롤러가 멈추고, 정작 재생 중이던 이 루프는 멈추라는 신호를 못 받아 자체
  /// 끊김-감지 재시도 로직이 몇 초 뒤 스스로 재생을 재개해버렸다(실사용자 재현:
  /// "정지 누르면 2~3초 뒤 저절로 다시 재생됨"). 화면이 실제로 보일 때마다
  /// ([ShadowingScreen.initState] 참고) 이 메서드를 다시 호출해 콜백을 자기 것으로
  /// 되찾아오게 한다 — 컨트롤러 인스턴스 재사용 여부와 무관하게 항상 "지금 보이는
  /// 화면"이 알림을 소유한다.
  void claimNotificationCallbacks() {
    final handler = ref.read(audioHandlerProvider);
    _audioHandler = handler;
    handler.onNotificationPlay = () {
      if (!mounted) return;
      if (state.viewMode == ShadowingViewMode.single) {
        resumeOrRestart();
      } else {
        playListFromCurrent();
      }
    };
    handler.onNotificationPause = () {
      if (!mounted) return;
      if (state.viewMode == ShadowingViewMode.single) {
        stopSingleMode();
      } else {
        stopListPlayback();
      }
    };
    handler.onNotificationSkipToNext = () {
      if (!mounted) return;
      if (state.viewMode == ShadowingViewMode.single) {
        skipToNext();
      } else {
        nextInList();
      }
    };
    handler.onNotificationSkipToPrevious = () {
      if (!mounted) return;
      if (state.viewMode == ShadowingViewMode.single) {
        skipToPrevious();
      } else {
        previousInList();
      }
    };
    handler.updateNowPlaying(
      fileName: _fileName,
      artUri: _coverArtUri,
      sentenceLabel: _sentenceLabel,
    );
  }

  /// 2026-09-07 추가 — 사용자 요청: 미니 플레이어(알림)를 펼치면 파일명 아래에 지금
  /// 재생 중인 문장 번호도 보여준다. `${currentIndex+1} / ${총 문장 수}` — 화면 맨 위
  /// 진행률 표시와 같은 형식.
  String? get _sentenceLabel =>
      state.segments.isEmpty ? null : '${state.currentIndex + 1} / ${state.segments.length}';

  /// 재생 중인 문장이 바뀔 때마다 [ShadowingScreen]이 호출해 알림의 문장 번호 표시를
  /// 최신 상태로 갱신한다.
  void refreshNowPlayingProgress() {
    if (_audioHandler == null) return;
    _audioHandler!.updateNowPlaying(fileName: _fileName, artUri: _coverArtUri, sentenceLabel: _sentenceLabel);
  }

  /// 2026-08-09 추가 — 잠금화면/알림 미니 플레이어 대응.
  ///
  /// `just_audio_background`의 알림 재생 버튼은 우리 컨트롤러를 거치지 않고 재생기를
  /// 직접 조작한다. 정상적인 경우엔 [_playWithRetry]가 매 재생마다 [endMs]에서 멈추는
  /// 리스너를 걸어두지만, 그 리스너는 "듣기" 단계 동안만 살아있다 — "따라 말하기" 대기
  /// 시간처럼 의도적으로 오디오가 멈춰 있는 순간, 혹은 문장이 끝나 다음 반복을 기다리는
  /// 순간에 알림에서 재생 버튼을 누르면 아무 경계 감시 없이 파일 끝까지 죽 재생돼버린다
  /// (사용자 보고: "화면 끄고 미니 플레이어로 들으면 반복 없이 쭉 재생됨"). 이 컨트롤러가
  /// 살아있는 내내 위치를 감시하다가, 현재 문장 경계를 여유 있게(1.2초) 벗어나면 —
  /// 우리 쪽 재생이라면 절대 벗어날 수 없으므로 외부 개입으로 간주하고 — 재생을 멈추고
  /// 현재 문장을 반복 횟수/속도 설정 그대로 다시 시작한다.
  Future<void> _watchForExternalOverrun(Duration pos) async {
    if (!mounted || _resyncingFromOverrun || !_isActiveSession) return;
    if (state.viewMode != ShadowingViewMode.single) return;
    // 2026-09-07 버그 수정: phase 확인이 빠져있었다 — 사용자가 정지 버튼을 눌러
    // phase가 idle로 바뀐 뒤에도, 이 콜백이 이미 걸어둔 400ms 재확인 타이머(아래
    // Future.delayed)가 살아있으면 그 사이 도착한 다른 위치 이벤트를 보고 "여전히
    // 재생 중"으로 오판해 재동기화(=재생 재시작)를 걸 수 있었다 — 정지 버튼을 눌러도
    // 2~3초 뒤 저절로 다시 재생되는 증상으로 실기기에서 재현됨. 지금 우리 쪽에서
    // 의도적으로 듣기 단계가 아니라면(정지/말하기 대기 등) 애초에 "외부 개입"으로
    // 볼 이유가 없다 — phase가 listening일 때만 이 감시를 계속한다.
    if (state.phase != ShadowingPhase.listening) return;
    final segment = state.currentSegment;
    if (segment == null) return;
    const overrunMarginMs = 1200;
    if (pos.inMilliseconds <= segment.endMs + overrunMarginMs) return;
    // 2026-08-09 버그 수정 (1): 정지 버튼을 누르면 재생이 멈춘 그 위치가 우연히 문장
    // 경계를 넘어 있을 수 있다(예: 문장이 막 끝나갈 무렵 정지) — 그 자체는 실제 재생이
    // 계속되는 게 아니라 멈춰서 남아있는 값일 뿐이므로 개입하면 안 된다. 실제로 재생
    // 중일 때만(=플레이어가 멈춘 걸 넘어 계속 흘러가는 중일 때만) 외부 개입으로
    // 간주한다.
    if (!ref.read(audioPlayerServiceProvider).isPlaying) return;

    // 2026-08-09 버그 수정 (2): 위 isPlaying 확인만으로는 부족했다 — 잠금화면 알림에서
    // 정지를 누른 "바로 그 순간" 도착한 위치 이벤트는, 아직 pause()가 완전히 반영되기
    // 전이라 isPlaying이 여전히 true로 보일 수 있다. 그 상태에서 바로 재동기화(재생
    // 재시작)하면 사용자가 방금 누른 정지가 무시된 것처럼 보인다(알림이 사라졌다가
    // 다시 뜨는 것으로 관찰됨 — 재생 중 알림만 "ongoing"으로 유지되기 때문). 짧게
    // 한 번 더 확인해서, 그 사이 실제로 멈췄다면(=사용자의 의도적 정지) 아무 것도
    // 안 하고 넘어간다.
    _resyncingFromOverrun = true;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || !ref.read(audioPlayerServiceProvider).isPlaying) {
      _resyncingFromOverrun = false;
      return;
    }

    debugPrint('[ShadowingController] mediaId=$mediaId external playback overran the current sentence boundary '
        '(pos=${pos.inMilliseconds}ms endMs=${segment.endMs}ms) — resyncing to the study loop.');
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    _resyncingFromOverrun = false;
    if (!mounted) return;
    state = state.copyWith(phase: ShadowingPhase.idle, awaitingResume: false);
    _runSentenceLoop();
  }

  @override
  void dispose() {
    debugPrint('[ShadowingController] DISPOSED mediaId=$mediaId');
    _gen++; // 진행 중이던 루프(있다면)가 다음 확인 시점에 스스로 멈추게 한다.
    _overrunWatchdogSub?.cancel();
    // 2026-09-07 버그 수정 — 근본 원인: `AudioPlayerService`는 앱 전체에서 공유되는
    // 싱글톤(provider가 `.family`가 아님)인데, 이 컨트롤러가 사라질 때 실제 재생을
    // 멈추는 코드가 지금까지 어디에도 없었다(화면의 모든 나가기 경로 — X버튼/뒤로가기/
    // 편집/요약화면 이동 — 도 마찬가지). 그래서 한 파일을 학습하다 다른 파일의 학습
    // 화면으로 넘어가면, 이전 컨트롤러는 dispose됐지만 그 오디오는 계속 재생 중이고
    // 새 컨트롤러가 같은 엔진에 새 재생을 걸면서 두 파일의 소리가 겹쳤다(실사용자 보고:
    // "두 개의 영상 음성이 겹쳐 나옴"). `_runSentenceLoop`/`playListFromCurrent`의
    // `await _playWithRetry(...)` 도중에 dispose가 오면, 그 안의 `await
    // playSegmentOnce(...)`가 끝날 때까지는 `mounted` 재확인 시점 자체에 도달하지
    // 못해 계속 재생되는 문제도 함께 있었다 — 여기서 명시적으로 멈춰야 확실하다.
    unawaited(ref.read(audioPlayerServiceProvider).stopSegment());
    // 이 화면을 벗어날 때 알림 콜백을 해제하지 않으면, 학습 화면 밖(예: 홈)에서도
    // 알림 버튼이 이미 dispose된(mounted=false) 이 컨트롤러를 계속 참조하게 된다.
    _audioHandler?.clearCallbacks();
    // 2026-08-26 버그 수정: 알림/잠금화면 미니 플레이어를 한 번도 지운 적이 없어서,
    // 학습을 다 마치고 이 화면을 벗어나도(요약 화면으로 replace 이동 포함) 미니
    // 플레이어가 계속 남아있었다("공부 다 마쳤는데 작은 플레이어가 안 없어짐" 부류의
    // 실사용 문제와 앱 재접속 시 마지막 학습 화면이 잘못 다시 뜨는 문제 둘 다의
    // 원인) — 이 컨트롤러가 사라질 때 지금 재생 정보도 함께 지운다.
    _audioHandler?.clearNowPlaying();
    super.dispose();
  }

  /// [resumeFromPause]가 true면 이 루프의 첫 번째 "듣기" 단계만 문장 처음으로 되감지
  /// 않고 정지된 위치에서 이어서 재생한다([resumeOrRestart] 참고) — 두 번째 문장부터는
  /// (혹은 첫 문장이 끝난 뒤 반복이 더 필요하면) 평소처럼 처음부터 재생한다.
  Future<void> _runSentenceLoop({bool resumeFromPause = false}) async {
    final myGen = ++_gen;
    var isFirstIteration = true;
    while (true) {
      if (myGen != _gen || !mounted || !_isActiveSession) return;
      final segment = state.currentSegment;
      if (segment == null) return;

      // ── 1) 원어민 음성 재생 ──────────────────────────────────
      debugPrint('[ShadowingController] mediaId=$mediaId _runSentenceLoop iteration '
          'gen=$myGen currentIndex=${state.currentIndex}');
      state = state.copyWith(
        phase: ShadowingPhase.listening,
        clearError: true,
        awaitingResume: false,
        playAttempt: ++_playAttempt,
      );
      final shouldResume = isFirstIteration && resumeFromPause;
      isFirstIteration = false;
      final played = await _playWithRetry(segment.startMs, segment.endMs, seek: !shouldResume, myGen: myGen);
      if (myGen != _gen || !mounted || !_isActiveSession) return;
      if (!played) return; // 재시도까지 실패 — 사용자가 원형 버튼으로 수동 재시작

      await Future.delayed(const Duration(milliseconds: 300));
      if (myGen != _gen || !mounted || !_isActiveSession) return;

      // ── 2) 따라 말하기 (앱은 녹음/분석하지 않음 — 사용자가 소리 내어 말할 시간만 확보) ──
      state = state.copyWith(phase: ShadowingPhase.speaking);
      var speakingDurationMs = state.sentenceGapMode.gapMsFor(segment.durationMs);
      // 2026-09-01 추가 — 영상 모드 전용 최소 간격. "공간없이"(0ms)처럼 듣기→말하기
      // 전환이 한 프레임 안에서 벌어질 만큼 짧으면, Flutter가 이 짧은 "말하기" 상태를
      // 별도 프레임으로 그리지 않고 건너뛸 수 있어 SentenceVideoPlayer가 "정지했다가
      // 다시 재생"이라는 신호를 놓칠 수 있다(실기기로 여러 차례 확인된 문제). 오디오
      // 전용 콘텐츠의 "공간없이" 의미(정말 간격 없음)는 그대로 두고, 영상 모드일
      // 때만 최소 500ms를 보장해 화면이 이 전환을 확실히 한 프레임 이상 그리게 한다.
      if (state.mediaSourceType == MediaSourceType.video) {
        speakingDurationMs = speakingDurationMs.clamp(500, 1 << 31);
      }
      await Future.delayed(Duration(milliseconds: speakingDurationMs));
      if (myGen != _gen || !mounted || !_isActiveSession) return;

      HapticFeedback.lightImpact();
      final newCompleted = state.completedRepeats + 1;

      if (newCompleted >= state.targetRepeats) {
        // ── 3) 문장 완료 ──────────────────────────────────────
        HapticFeedback.mediumImpact();
        await _markSegmentCompleted(state.currentIndex);
        final doneSet = {...state.fullyCompletedIndices, state.currentIndex};
        state = state.copyWith(
          phase: ShadowingPhase.sentenceComplete,
          completedRepeats: newCompleted,
          fullyCompletedIndices: doneSet,
        );
        await _persistProgress(doneSet.length);
        await Future.delayed(const Duration(milliseconds: 600));
        if (myGen != _gen || !mounted || !_isActiveSession) return;

        if (state.isLastSentence) {
          return; // 화면에서 세션 완료를 감지해 요약 화면으로 이동시킴
        }
        if (state.handsFree) {
          state = state.copyWith(
            currentIndex: state.currentIndex + 1,
            completedRepeats: 0,
            phase: ShadowingPhase.idle,
          );
          continue; // 다음 문장으로 루프 계속
        } else {
          state = state.copyWith(awaitingManualAdvance: true);
          return; // 사용자의 스와이프 업 대기
        }
      } else {
        state = state.copyWith(completedRepeats: newCompleted);
        // 목표 횟수 미도달 — 다시 원어민 음성 재생으로 복귀.
      }
    }
  }

  Future<bool> _playWithRetry(int startMs, int endMs, {bool isRetry = false, bool seek = true, int? myGen}) async {
    // 2026-09-01 버그 수정: 호출자(_runSentenceLoop/playListFromCurrent)의 세대 번호를
    // 넘겨받아, 그 세대가 이미 낡았으면(사용자가 그 사이 다른 문장을 탭해 새 세대가
    // 시작됐으면) 아래 positionStream 리스너가 더는 state를 건드리지 않게 한다. 예전엔
    // `mounted`(컨트롤러 자체가 dispose됐는지)만 확인했는데, 그거로는 "이 재생 시도
    // 자체는 이미 낡았지만 컨트롤러는 여전히 살아있고 새 재생이 진행 중인" 흔한 경우를
    // 못 걸렀다 — 사용자가 목록에서 문장을 빠르게 연달아 탭하면, 오래된 시도의 리스너가
    // 계속 살아남아 최신 재생과 뒤섞여 state를 계속 덮어쓰면서 화면(재생 중 표시,
    // 진행률)이 실제 재생 위치를 못 따라가는 원인이 됐다(실사용자 보고: 화면엔 30번인데
    // 실제로는 57번이 재생 중).
    final effectiveGen = myGen ?? _gen;
    StreamSubscription<Duration>? positionSub;
    try {
      // 2026-08-09: seek:false(정지 지점에서 이어재생)일 때는 진행률을 0으로 리셋하지
      // 않는다 — 안 그러면 이미 60% 지점에서 멈췄던 파형이 재생 버튼을 누르는 순간
      // 잠깐 0%로 튀었다가 첫 positionStream 이벤트에서야 다시 튀어 오르는 깜빡임이
      // 생긴다.
      state = state.copyWith(isBuffering: true, playbackProgressRatio: seek ? 0 : state.playbackProgressRatio);
      // 2026-08-06: 파형 위 재생 위치 표시용 — 문장 구간 안에서의 실제 진행률(0.0~1.0)을
      // positionStream으로 실시간 반영한다(예전엔 재생 중이면 무조건 0.5 고정값).
      final segmentDurationMs = (endMs - startMs).clamp(1, 1 << 31);
      positionSub = ref.read(audioPlayerServiceProvider).positionStream.listen((pos) {
        // 2026-08-06 버그 수정: 화면을 벗어나 이 컨트롤러가 dispose된 뒤에도
        // positionStream 이벤트가 늦게 하나 더 도착할 수 있다(구독 취소는
        // finally에서 하지만 그 사이 이벤트가 이미 큐에 있었을 수 있음) — mounted
        // 확인 없이 state를 쓰면 "Tried to use ShadowingController after dispose"로
        // 앱이 죽는다(실기기에서 재현: 문장을 몇 개 넘긴 뒤 재생하면 크래시).
        if (!mounted || effectiveGen != _gen || !_isActiveSession) return;
        final ratio = ((pos.inMilliseconds - startMs) / segmentDurationMs).clamp(0.0, 1.0);
        // 2026-09-01 버그 수정: 위 확인들(컨트롤러 dispose 여부 + 세대 번호)을 다 통과해도,
        // 화면 전환 타이밍에 따라 StateNotifier는 살아있지만 그걸 구독하던 위젯 Element가
        // 이미 defunct가 되어 있는 아주 짧은 찰나가 있을 수 있다 — 그 경우 `state = ...`가
        // 리스너에게 알리는 과정에서 "Element.markNeedsBuild: _lifecycleState != defunct"
        // 예외를 던진다. 이 갱신은 진행률 표시용 부가 정보일 뿐이라, 실패해도 학습 흐름
        // 자체에는 영향이 없다 — 조용히 넘어가 다음 정상 이벤트에서 다시 시도한다.
        try {
          state = state.copyWith(playbackProgressRatio: ratio);
        } catch (_) {}
      });
      // 2026-09-07 버그 수정 — 근본 원인: `AudioPlayerService`는 앱 전체에서 공유되는
      // 싱글톤인데, `playSegmentOnce`는 소스를 다시 로드하지 않고 "이미 로드돼 있는
      // 파일"에 대고서만 seek/play한다. 이 컨트롤러가 `_init()`에서 자기 파일을 로드해둔
      // 뒤로 화면을 벗어나 백그라운드에 남아있는 동안, 다른 파일의 학습화면이 같은
      // 싱글톤에 자기 파일을 새로 로드해버리면 — 이 컨트롤러가 나중에(예: 사용자가 다시
      // 이 화면으로 돌아와 재생 버튼을 누르면) 재생을 재개해도 실제로는 "화면은 이
      // 파일인데 소리는 마지막으로 로드됐던 다른 파일"이 재생됐다(실사용자 재현: 영상
      // A 재생 중 앱을 완전히 닫음(백그라운드에 A의 컨트롤러가 남음) → 영상 B를 열어
      // 재생(공유 재생기 소스가 B로 바뀜) → B도 닫고 다시 A를 재생 → 화면은 A인데
      // 소리는 B). 재생 직전에 항상 내 소스가 실제로 로드돼 있는지 다시 확인·복구한다
      // (이미 맞는 소스면 `setSource` 내부에서 조용히 스킵되므로 매번 불러도 무해하다).
      if (_audioSource.isNotEmpty) {
        await ref.read(audioPlayerServiceProvider).setSource(_audioSource, isLocal: true);
      }
      if (!mounted || effectiveGen != _gen || !_isActiveSession) return true;
      await ref.read(audioPlayerServiceProvider).playSegmentOnce(
            startMs: startMs,
            endMs: endMs,
            speed: state.playbackSpeed,
            seek: seek,
          );
      if (!mounted) return true;
      // 2026-08-07: 재시도(hard reset 후)가 성공했는데도 첫 시도 실패 때 띄운 에러
      // 문구가 다음 문장으로 넘어갈 때까지 화면에 그대로 남아있던 버그 — 성공 시
      // clearError를 안 해서였다. 실제로 재생은 계속되고 있는데 "오디오를 재생할 수
      // 없어요"가 몇 초간 떠 있는 것처럼 보였다.
      state = state.copyWith(isBuffering: false, playbackProgressRatio: 1, clearError: true);
      return true;
    } catch (_) {
      if (!mounted) return false;
      // 2026-08-07: 118분 실제 파일 재생 테스트에서 자동 복구(하드 리셋+재시도)가
      // 정상적으로 동작하며 몇 초 안에 스스로 회복하는 경우에도, 그 첫 실패 시점에
      // 매번 "오디오를 재생할 수 없어요"가 화면에 떴다 — 곧 자동으로 풀리는 일시적
      // 상황인데 사용자에게는 고장난 것처럼 보였다. 재시도까지 두 번 다 실패했을
      // 때(=사용자가 직접 원형 버튼으로 재시작해야 하는 진짜 실패)만 에러를 보여준다.
      if (isRetry) {
        state = state.copyWith(isBuffering: false, error: '오디오를 재생할 수 없어요');
      } else {
        state = state.copyWith(isBuffering: false);
      }
      if (!isRetry) {
        await Future.delayed(const Duration(milliseconds: 500));
        // 재시도는 항상 처음(seek:true)부터 — 실패 처리 과정에서 플레이어가 하드
        // 리셋됐을 수 있어(_hardReset) 이어재생 위치를 더는 신뢰할 수 없다.
        return _playWithRetry(startMs, endMs, isRetry: true, myGen: effectiveGen);
      }
      return false;
    } finally {
      await positionSub?.cancel();
    }
  }

  Set<int> _completedIndicesOf(List<SentenceSegment> segments) => {
        for (final s in segments)
          if (s.completed) s.index,
      };

  /// 2026-08-10: 문장이 목표 반복 횟수를 채웠을 때 호출 — 문장 자체(`SentenceSegment.
  /// completed`)에 영구 저장한다. 예전엔 [ShadowingSessionState.fullyCompletedIndices]
  /// (세션 한정 `Set<int>`)만 갱신해서 화면을 나갔다 들어오면 사라졌고, 병합/분리로
  /// 문장이 재인덱싱되면 옛 인덱스가 엉뚱한 문장을 가리켰다(사용자 보고: 병합 후
  /// 학습 안 한 문장까지 초록 체크로 남음).
  Future<void> _markSegmentCompleted(int index) async {
    if (index < 0 || index >= state.segments.length) return;
    final seg = state.segments[index];
    if (seg.completed) return;
    final newSegments = [...state.segments];
    newSegments[index] = seg.copyWith(completed: true);
    state = state.copyWith(segments: newSegments);
    try {
      await ref.read(segmentationRepositoryProvider).saveEditedSegments(mediaId, newSegments);
    } catch (_) {
      // 저장 실패해도 화면 표시(로컬 상태)는 유지 — toggleFlag와 동일한 원칙.
    }

    // 2026-08-10: 전체 학습기록(#11) 실시간 집계 — 문장당 정확히 한 번만 호출되므로
    // (위 `if (seg.completed) return`) 총 문장 수를 이중 집계할 위험이 없다.
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastProgressFlushAt).inMilliseconds.clamp(0, 1000 * 60 * 10);
    _lastProgressFlushAt = now;
    try {
      await ref.read(statsRepositoryProvider).recordProgress(
            mediaId: mediaId,
            fileName: _fileName,
            sentenceIndex: index,
            deltaDurationMs: elapsedMs,
          );
    } catch (_) {
      // 통계 저장 실패는 학습 흐름을 막지 않는다.
    }
  }

  Future<void> _persistProgress(int completedCount) async {
    final repo = ref.read(mediaRepositoryProvider);
    final media = await repo.getById(mediaId);
    if (media == null) return;
    await repo.save(media.copyWith(
      completedSentenceCount: completedCount,
      lastPlayedSentenceIndex: state.currentIndex,
      lastStudiedAt: DateTime.now(),
    ));
  }

  /// 원형 CTA 탭 — 현재 단계 재생을 즉시 재시작.
  ///
  /// **2026-08-06**: `_gen`만 올리고 실제 오디오 쪽([AudioPlayerService.stopSegment])은
  /// 안 건드리면, 방금 진행 중이던 [_playWithRetry]의 `playSegmentOnce` 대기가
  /// 정리되지 않은 채 남는다 — 여러 번 반복하면 정리 안 된 리스너/Future가 쌓여
  /// "몇 번 조작한 뒤부터 재생이 조용히 안 됨"으로 이어진다(에러 없이 방치된 비동기
  /// 상태라 로그도 안 남는다). 재생 흐름을 끊는 모든 동작에서 먼저 확실히 정리한다.
  Future<void> restartCurrentStep() async {
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(phase: ShadowingPhase.idle);
    _runSentenceLoop();
  }

  /// 한 문장씩 보기의 원형 CTA(큰 재생 버튼) 탭 — 2026-08-09에 [restartCurrentStep]에서
  /// 분리했다. [stopSingleMode]로 멈춘 직후([awaitingResume] true)라면 문장 처음으로
  /// 되감지 않고 멈춘 지점부터 이어서 재생하고, 그 외(맨 처음 진입/문장 완료 후 등)에는
  /// 기존과 동일하게 처음부터 재생한다. 하단의 별도 "다시 듣기"(`Icons.replay`) 버튼은
  /// 항상 [restartCurrentStep]을 써서 명시적으로 처음부터 다시 듣는 용도로 남겨둔다.
  Future<void> resumeOrRestart() async {
    if (state.awaitingResume) {
      _runSentenceLoop(resumeFromPause: true);
    } else {
      await restartCurrentStep();
    }
  }

  /// 스와이프 업 — 다음 문장으로 즉시 스킵(Hands-free OFF일 때 수동 진행 포함).
  Future<void> skipToNext() async {
    if (state.isLastSentence) return;
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      completedRepeats: 0,
      phase: ShadowingPhase.idle,
      awaitingManualAdvance: false,
    );
    _runSentenceLoop();
  }

  /// 스와이프 다운 — 이전 문장으로 이동.
  Future<void> skipToPrevious() async {
    if (state.currentIndex == 0) return;
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      completedRepeats: 0,
      phase: ShadowingPhase.idle,
      awaitingManualAdvance: false,
    );
    _runSentenceLoop();
  }

  /// 롱프레스 — 0.5배속으로 현재 문장을 1회 미리듣기(반복 횟수에는 영향 없음).
  Future<void> previewAtHalfSpeed() async {
    final segment = state.currentSegment;
    if (segment == null) return;
    _gen++; // 진행 중이던 루프 중단
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(phase: ShadowingPhase.listening, playAttempt: ++_playAttempt);
    await _playWithRetry(segment.startMs, segment.endMs, myGen: _gen);
    _runSentenceLoop(); // 현재 반복 횟수를 유지한 채 정상 루프 재개
  }

  void toggleTranslation() => state = state.copyWith(showTranslation: !state.showTranslation);

  /// 한 문장씩(single) ↔ 한꺼번에 보기(list) 전환. list로 들어갈 때는 재생 중이던 음성을
  /// 멈추고 자동 루프도 중단한다 — 목록을 훑어보는 동안 배경에서 오디오가 계속 흐르면
  /// 혼란스럽기 때문(01_ux_design.md 학습 화면 몰입 원칙과 동일 맥락).
  Future<void> toggleViewMode() async {
    if (state.viewMode == ShadowingViewMode.single) {
      _gen++;
      await ref.read(audioPlayerServiceProvider).stopSegment();
      if (!mounted) return;
      // 2026-08-09 버그 수정: filterFlaggedOnly를 여기서 초기화하지 않으면, 예전에 한번
      // "깃발만 보기"를 켠 적이 있을 경우 그 상태가 세션 내내 남아 있어서, 이후 한
      // 문장씩 보기에서 한꺼번에 보기로 전환할 때마다 매번 깃발 표시한 문장만 걸러진
      // 목록이 나왔다(사용자 보고: 전체 목록을 기대했는데 필터링된 목록만 보임). 한꺼번에
      // 보기에 새로 들어갈 때는 항상 전체 목록으로 시작하고, 필터는 그 안에서 원할 때
      // 다시 켜도록 한다.
      state = state.copyWith(viewMode: ShadowingViewMode.list, phase: ShadowingPhase.idle, filterFlaggedOnly: false);
    } else {
      state = state.copyWith(viewMode: ShadowingViewMode.single);
      _runSentenceLoop();
    }
  }

  /// 한꺼번에 보기에서 문장을 탭했을 때 — 그 문장을 선택 상태로 만들고 그 문장부터
  /// 반복 재생을 시작한다(목록 화면을 벗어나지 않는다 — 집중 연습(따라 말하기 mic
  /// 단계)은 상단 토글로 한 문장씩 보기에 별도 진입해야 한다).
  Future<void> selectSentence(int index) async {
    if (index < 0 || index >= state.segments.length) return;
    state = state.copyWith(currentIndex: index, completedRepeats: 0);
    await playListFromCurrent();
  }

  /// 2026-08-09 추가 — 한꺼번에 보기 재생바의 이전/다음 문장 버튼. 목록에서 그 문장을
  /// 직접 탭한 것과 동일하게 동작한다([selectSentence] 재사용).
  Future<void> previousInList() => selectSentence(state.currentIndex - 1);
  Future<void> nextInList() => selectSentence(state.currentIndex + 1);

  /// 한꺼번에 보기 하단 재생 버튼 — 2026-08-06: 예전엔 현재 문장을 딱 1회만 미리듣고
  /// 끝났는데(반복 횟수/자동 다음 문장 없음), 사용자가 "한 문장씩 보기"와 마찬가지로
  /// 설정된 반복 횟수([ShadowingSessionState.targetRepeats])만큼 반복해서 듣고, 그
  /// 횟수를 채우면 자동으로 다음 문장으로 넘어가 계속 재생되길 원해서 바꿨다.
  /// 한 문장씩 보기와 달리 "따라 말하기(mic)" 단계는 없다 — 목록은 죽 훑어 들으며
  /// 원하는 곳에서 [stopListPlayback]으로 멈추는 용도다. 마지막 문장까지 다 채우면
  /// 자동으로 멈춘다(요약 화면으로 넘기지 않는다 — 그건 한 문장씩 보기의 몫).
  Future<void> playListFromCurrent() async {
    final myGen = ++_gen;
    // 2026-09-01 버그 수정: 한 문장씩 보기의 skipToNext/skipToPrevious/restartCurrentStep은
    // 전부 새 재생을 걸기 전에 먼저 stopSegment()로 이전 재생을 확실히 정리하는데,
    // 한꺼번에 보기 쪽(이 함수 — selectSentence/previousInList/nextInList가 전부 이걸
    // 거친다)은 그 정리가 빠져 있었다. 사용자가 목록에서 다른 문장을 빠르게 연달아
    // 탭하면, 이전 문장의 오디오가 아직 재생 중인 채로 새 문장의 seek+재생 요청이 같은
    // AudioPlayerService 인스턴스에 겹쳐 들어가 — 실사용자 보고: "앞 문장 나오다가
    // 갑자기 뒤 문장이 나온다"(재생 내용이 뒤섞여 들림). _gen 체크만으로는 오래된
    // 루프가 "다음 확인 시점에" 멈추는 것뿐이라, 이미 걸어둔 재생 자체는 막지 못한다.
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (myGen != _gen || !mounted || !_isActiveSession) return;
    while (true) {
      if (myGen != _gen || !mounted || !_isActiveSession) return;
      final segment = state.currentSegment;
      if (segment == null) return;

      var completed = state.completedRepeats;
      while (completed < state.targetRepeats) {
        if (myGen != _gen || !mounted || !_isActiveSession) return;
        state = state.copyWith(phase: ShadowingPhase.listening, clearError: true);
        final played = await _playWithRetry(segment.startMs, segment.endMs, myGen: myGen);
        if (myGen != _gen || !mounted || !_isActiveSession) return;
        if (!played) {
          state = state.copyWith(phase: ShadowingPhase.idle);
          return; // 재시도까지 실패 — 사용자가 다시 탭해야 재개
        }
        completed++;
        state = state.copyWith(completedRepeats: completed);
        if (completed < state.targetRepeats) {
          // 2026-09-01: 예전엔 문장 간격 설정과 무관하게 항상 고정 400ms만 쉬었다 —
          // 사용자 요청으로 "한 문장씩 보기"와 동일하게 설정된 문장 간격
          // ([SentenceGapMode])을 그대로 따르도록 통일한다. 간격이 실제로 있을 때만
          // (SentenceGapMode.none이 아닐 때) phase를 speaking으로 바꿔 재생바에도
          // 한 문장씩 보기와 동일하게 마이크 아이콘이 뜨게 한다 — "공간없이"는 원래부터
          // 말하기 단계 개념이 없어(간격 0) idle로 남긴다.
          final gapMs = state.sentenceGapMode.gapMsFor(segment.durationMs);
          if (gapMs > 0) state = state.copyWith(phase: ShadowingPhase.speaking);
          await Future.delayed(Duration(milliseconds: gapMs));
          if (myGen != _gen || !mounted || !_isActiveSession) return;
        }
      }

      await _markSegmentCompleted(state.currentIndex);
      final doneSet = {...state.fullyCompletedIndices, state.currentIndex};
      state = state.copyWith(fullyCompletedIndices: doneSet);
      await _persistProgress(doneSet.length);
      if (myGen != _gen || !mounted || !_isActiveSession) return;

      if (state.isLastSentence) {
        state = state.copyWith(phase: ShadowingPhase.idle, completedRepeats: 0);
        return;
      }
      state = state.copyWith(currentIndex: state.currentIndex + 1, completedRepeats: 0);
      await Future.delayed(const Duration(milliseconds: 300));
      // myGen 확인은 루프 맨 위에서 계속 진행 — 다음 문장 반복을 이어서 재생한다.
    }
  }

  /// 목록 재생바의 정지 버튼 — 반복+자동 다음 문장 재생을 즉시 멈춘다. 진행 중이던
  /// 반복 횟수는 유지해서(초기화하지 않음), 같은 문장을 다시 재생하면 이어서 채울 수
  /// 있다.
  Future<void> stopListPlayback() async {
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(phase: ShadowingPhase.idle, isBuffering: false);
  }

  /// 한꺼번에 보기 상단 필터 — 표시(🚩)해둔 문장만 걸러서 본다.
  void toggleFlaggedFilter() => state = state.copyWith(filterFlaggedOnly: !state.filterFlaggedOnly);

  /// 편집 화면(`SentenceEditScreen`)으로 넘어가기 전에 호출 — 재생/자동 루프를
  /// 멈춘다(편집하는 동안 배경에서 오디오가 계속 흐르면 혼란스럽다).
  Future<void> pauseForEditing() async {
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (mounted) state = state.copyWith(phase: ShadowingPhase.idle);
  }

  /// 2026-08-06: 편집 화면에서 돌아왔을 때 호출 — 학습 화면은 세그먼트를 한 번 로드한
  /// 뒤 메모리에 들고 있어서, 편집 화면에서 병합/분리/길이조정을 저장해도 자동으로는
  /// 반영되지 않는다(구 #4 목록 확인 화면이 없어지면서 "학습 시작 전 일괄 확정" 지점이
  /// 사라졌으니, 학습 중간에 편집하고 돌아올 때마다 다시 읽어와야 한다).
  Future<void> reloadSegments() async {
    final segments = await ref.read(segmentationRepositoryProvider).getSegments(mediaId);
    if (!mounted) return;
    final clampedIndex = segments.isEmpty ? 0 : state.currentIndex.clamp(0, segments.length - 1);
    // 2026-08-10: 병합/분리로 문장이 재인덱싱됐을 수 있으니, 옛 fullyCompletedIndices를
    // 그대로 들고 있지 않고 방금 불러온 segments의 `completed` 필드에서 다시 계산한다
    // — 그래야 병합된 문장이 실제로 둘 다 완료했을 때만 체크로 남고, 병합 때문에
    // 밀려난 다른 문장이 엉뚱하게 체크되는 일이 없다.
    state = state.copyWith(
      segments: segments,
      currentIndex: clampedIndex,
      fullyCompletedIndices: _completedIndicesOf(segments),
    );
    if (state.viewMode == ShadowingViewMode.single) _runSentenceLoop();
  }

  /// **2026-08-26 추가 — 가족 테스터 요청**: 한꺼번에 보기(목록) 화면에서 편집 화면을
  /// 거치지 않고 연필 아이콘 옆의 버튼으로 바로 다음 문장과 합친다. 병합 알고리즘
  /// 자체는 [SegmentationReviewController.mergeWithNext]와 동일하다(텍스트/한글 뜻
  /// 이어붙이기, 구간 확장) — 다만 이 컨트롤러가 이미 메모리에 들고 있는 목록을 직접
  /// 고쳐서, 별도 편집 컨트롤러를 새로 띄우고 다시 불러오는 왕복 없이 목록에 즉시
  /// 반영한다. 마지막 문장(다음이 없음)이면 아무것도 하지 않고 false를 반환한다.
  Future<bool> mergeSentenceWithNext(int index) async {
    if (index < 0 || index >= state.segments.length - 1) return false;
    final list = [...state.segments];
    final a = list[index];
    final b = list[index + 1];
    final mergedText = (a.text == null && b.text == null) ? null : '${a.text ?? ''} ${b.text ?? ''}'.trim();
    final mergedTranslation = (a.translation == null && b.translation == null)
        ? null
        : '${a.translation ?? ''} ${b.translation ?? ''}'.trim();
    final merged = a.copyWith(
      id: '${a.id}-merged-${DateTime.now().millisecondsSinceEpoch}',
      text: mergedText,
      clearText: mergedText == null,
      translation: mergedTranslation,
      clearTranslation: mergedTranslation == null,
      endMs: b.endMs,
      edited: true,
      completed: a.completed && b.completed,
    );
    list[index] = merged;
    list.removeAt(index + 1);
    final reindexed = [for (var i = 0; i < list.length; i++) list[i].copyWith(index: i)];

    // 합쳐진 지점 뒤로 문장들이 한 칸씩 당겨지므로, 지금 보고 있던 위치도 같이 보정한다.
    final newCurrentIndex = (state.currentIndex > index ? state.currentIndex - 1 : state.currentIndex)
        .clamp(0, reindexed.length - 1);

    state = state.copyWith(
      segments: reindexed,
      currentIndex: newCurrentIndex,
      fullyCompletedIndices: _completedIndicesOf(reindexed),
    );

    try {
      await ref.read(segmentationRepositoryProvider).saveEditedSegments(mediaId, reindexed);
    } catch (_) {
      // 저장 실패해도 화면 표시(로컬 상태)는 유지 — 다른 편집 액션과 동일한 원칙.
    }
    return true;
  }

  /// 현재 문장을 "잘 안되는 문장"으로 표시/해제(#5 학습 화면 체크 버튼). 서버(Fake 구현체
  /// 기준 로컬 캐시)에 영구 저장한다.
  Future<void> toggleFlag() async {
    final current = state.currentSegment;
    if (current == null) return;
    final updated = current.copyWith(flaggedByUser: !current.flaggedByUser);
    final newSegments = [...state.segments];
    newSegments[state.currentIndex] = updated;
    state = state.copyWith(segments: newSegments);

    try {
      await ref.read(segmentationRepositoryProvider).saveEditedSegments(mediaId, newSegments);
    } catch (_) {
      // 저장 실패해도 화면 표시(로컬 상태)는 유지 — 다음 진입 시 반영 안 될 수 있음을
      // 사용자가 알 방법은 없지만, 학습 흐름을 막을 정도의 오류는 아니라고 판단.
    }
  }

  /// 학습 옵션 시트에서 바꾼 값은 이번 세션에 곧바로 적용되는 동시에, 다음에 새
  /// 학습을 시작할 때의 기본값으로도 저장된다(마이 > 설정(#12)의 "학습 기본값"과
  /// 같은 저장소에 반영 — 2026-08-18: 실사용 피드백으로 세션 한정 적용을 폐기,
  /// 매번 다시 설정해야 하는 번거로움을 없앴다).
  void updateOptions({
    int? repeatCount,
    double? speed,
    bool? handsFree,
    bool? autoTranslation,
    SentenceGapMode? sentenceGapMode,
  }) {
    state = state.copyWith(
      targetRepeats: repeatCount ?? state.targetRepeats,
      playbackSpeed: speed ?? state.playbackSpeed,
      handsFree: handsFree ?? state.handsFree,
      showTranslation: autoTranslation ?? state.showTranslation,
      sentenceGapMode: sentenceGapMode ?? state.sentenceGapMode,
    );
    unawaited(_persistOptionsAsDefault(
      repeatCount: repeatCount,
      speed: speed,
      handsFree: handsFree,
      autoTranslation: autoTranslation,
      sentenceGapMode: sentenceGapMode,
    ));
  }

  Future<void> _persistOptionsAsDefault({
    int? repeatCount,
    double? speed,
    bool? handsFree,
    bool? autoTranslation,
    SentenceGapMode? sentenceGapMode,
  }) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.getSettings();
    await repo.updateSettings(current.copyWith(
      defaultRepeatCount: repeatCount,
      defaultPlaybackSpeed: speed,
      handsFreeMode: handsFree,
      autoShowTranslation: autoTranslation,
      sentenceGapMode: sentenceGapMode,
    ));
  }

  /// 한 문장씩 보기의 정지 버튼 — 자동 듣기↔말하기 루프를 즉시 멈춘다(반복 횟수는
  /// 유지). [resumeOrRestart](원형 CTA)로 멈춘 지점부터 이어서 재생하거나,
  /// [restartCurrentStep](다시 듣기 버튼)으로 처음부터 다시 시작할 수 있다.
  ///
  /// 2026-08-09 버그 수정: 예전엔 정지 후 다시 재생하면 무조건 문장 처음으로 돌아갔다
  /// — [AudioPlayerService.stopSegment]는 일시정지만 할 뿐 되감지 않는데, 정작 재생
  /// 재개 경로([restartCurrentStep] → `_runSentenceLoop` → `playSegmentOnce`)가 항상
  /// `seek(startMs)`를 호출했기 때문이다. "듣기(listening)" 단계에서 멈췄을 때만
  /// [awaitingResume]을 세운다 — "말하기(speaking)" 단계는 실제 오디오 재생이 없는
  /// 타이머일 뿐이라 이어서 재생할 위치 자체가 없다(그 경우엔 다음 재생이 정상적으로
  /// 듣기 단계를 처음부터 다시 시작한다).
  Future<void> stopSingleMode() async {
    final wasListening = state.phase == ShadowingPhase.listening;
    _gen++;
    await ref.read(audioPlayerServiceProvider).stopSegment();
    if (!mounted) return;
    state = state.copyWith(phase: ShadowingPhase.idle, isBuffering: false, awaitingResume: wasListening);
  }

  Future<LearningSessionResult> buildSessionResult() async {
    return LearningSessionResult(
      mediaId: mediaId,
      sentencesCompleted: state.fullyCompletedIndices.length,
      totalSentencesInMedia: state.segments.length,
      durationMs: DateTime.now().difference(state.sessionStartedAt).inMilliseconds,
      completedAt: DateTime.now(),
    );
  }
}
