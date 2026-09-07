import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 2026-09-01 추가 — "한 문장씩 보기" 전용. 영상 파일을 업로드한 콘텐츠에서
/// [WaveformPlayer] 대신(또는 그 자리에) 원본 영상을 눈으로 보면서 복습할 수 있게
/// 한다.
///
/// **실제 오디오는 여전히 [AudioPlayerService]가 전담한다** — 이 위젯은 화면 표시만
/// 담당하는 "무음 비디오"다([setVolume]으로 0 처리). 문장 구간 반복/속도/정지 같은
/// 정교한 로직(스톨 감지, 하드 리셋 등)은 기존 오디오 엔진을 그대로 두고 건드리지
/// 않는다 — 이 위젯은 [isPlaying](= `ShadowingPhase.listening`)과 [startMs]/[endMs]를
/// 보고 오디오 재생과 시각적으로만 맞춰 따라간다. 핸즈프리(화면 꺼짐) 상태에서는 이
/// 위젯이 아예 화면에 없으므로(한 문장씩 보기 자체가 화면을 보는 모드) 신경 쓸 필요가
/// 없다.
class SentenceVideoPlayer extends StatefulWidget {
  final String videoPath;
  final int startMs;
  final int endMs;
  final bool isPlaying;
  final double playbackSpeed;
  // "듣기" 단계가 새로 시작될 때마다(같은 문장 반복 포함) 바뀌는 값 —
  // ShadowingController.playAttempt/ShadowingSessionState.playAttempt 문서 참고.
  final int playAttempt;

  const SentenceVideoPlayer({
    super.key,
    required this.videoPath,
    required this.startMs,
    required this.endMs,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.playAttempt,
  });

  @override
  State<SentenceVideoPlayer> createState() => _SentenceVideoPlayerState();
}

class _SentenceVideoPlayerState extends State<SentenceVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  // 2026-09-01 버그 수정: "문장 간격(따라 말하기 대기시간)"이 짧은/없는 설정에서는
  // 반복 주기가 한 프레임 안에서 벌어질 만큼 빨라, seek/play/pause 네이티브 호출이
  // 겹쳐 들어올 수 있다. "지금 재생 중이어야 하는가"라는 **의도만** 큐에 쌓아두고,
  // 네이티브 호출은 [_drainIntent]가 한 번에 하나씩만 순차 실행한다 — 처리 중에
  // 새 의도가 들어오면 그냥 최신 값으로 덮어쓰고, 현재 처리가 끝난 뒤 그 최신
  // 의도를 이어서 처리한다(겹쳐서 두 개가 동시에 나가는 일 자체가 없다).
  bool? _pendingShouldPlay; // null이면 대기 중인 의도 없음.
  bool _draining = false;
  // 2026-09-01 버그 수정 (2): [didUpdateWidget]에서 `oldWidget.playAttempt`와 비교하는
  // 방식은, 비디오 초기화(수백ms~1초 이상 걸림)가 끝나기 전에 여러 번의 리빌드가
  // 이미 지나가버린 경우(특히 "공간없이"라 반복 주기가 짧을 때) `_ready`가 될 때까지
  // 그 리빌드들을 다 걸러내야 했는데, `_setUp()`이 준비를 마치고 `widget`을 읽는
  // 시점 자체가 프레임 스케줄과 별개의 비동기 타이밍이라 최신 `playAttempt`를 못
  // 읽어오는 경우가 실기기에서 확인됐다(재현: 첫 재생부터 정지영상). "이전 위젯 값과
  // 비교" 대신, **내가 마지막으로 실제로 재생을 시작시킨 시도 번호**를 직접 들고 있고
  // 매번(리빌드 여부와 무관하게, `_ready`가 된 직후를 포함해) 최신 [widget.playAttempt]와
  // 비교한다 — 몇 번의 리빌드를 건너뛰었든 상관없이 항상 올바르게 수렴한다.
  int? _lastStartedAttempt;
  bool? _lastRequestedShouldPlay; // 동일한 의도를 중복으로 큐에 쌓지 않기 위한 dedupe.

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<void> _setUp() async {
    // 2026-09-01 버그 수정: 소리를 0으로 줄여도(setVolume) 플랫폼 플레이어는 여전히
    // 오디오 포커스를 요청한다 — 이게 재생 중이던 AudioPlayerService(잠금화면 미니
    // 플레이어 포함)의 포커스를 뺏어가서, 시스템이 "일시정지" 신호를 보내고 그게
    // StudyAudioHandler.onNotificationPause를 타고 들어와 학습 루프 전체가 재생
    // 직후 곧바로 멈추는 원인이었다(실기기 로그로 확인: 사용자가 아무 것도 안 눌렀는데
    // stopSingleMode가 자동 호출됨). mixWithOthers:true로 오디오 포커스 요청 자체를
    // 하지 않게 해서 기존 오디오 재생과 충돌하지 않게 한다.
    final controller = VideoPlayerController.file(
      File(widget.videoPath),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0); // 소리는 AudioPlayerService가 담당 — 겹치지 않게 무음.
    } catch (_) {
      // 손상된 파일/미지원 코덱 등 — 오디오 학습 루프는 이 실패와 무관하게 계속
      // 동작해야 하므로, 여기선 자리표시자만 남기고 조용히 실패 처리한다.
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    controller.addListener(_onTick);
    await controller.seekTo(Duration(milliseconds: widget.startMs)); // 정지 상태에서도 올바른 첫 프레임을 보여준다.
    _sync();
  }

  /// 오디오 쪽 [playSegmentOnce]와 동일한 "문장 끝에서 멈춤" 개념을 시각적으로만
  /// 흉내낸다 — 여긴 정교한 스톨 감지가 필요 없다(어긋나도 다음 재생 시작 시 항상
  /// [startMs]로 다시 seek하므로 눈에 띄는 드리프트가 누적되지 않는다).
  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.position.inMilliseconds >= widget.endMs && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void didUpdateWidget(covariant SentenceVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      _controller?.setPlaybackSpeed(widget.playbackSpeed);
    }
    _sync();
  }

  /// "지금 이 [widget]이 원하는 상태"와 "내가 마지막으로 실제 적용한 상태"를 비교해
  /// 필요한 만큼만 큐에 의도를 쌓는다. 리빌드가 몇 번 건너뛰어졌든, 이 함수가 호출되는
  /// 시점의 [widget]은 항상 최신 값을 가리키므로(Flutter가 보장) 매번 정확하게
  /// 수렴한다 — [oldWidget]과의 비교(에지 감지)에 의존하지 않는다.
  void _sync() {
    if (!_ready) return; // 아직 준비 전이면 [_setUp] 마지막에 한 번 더 호출된다.
    if (widget.isPlaying && widget.playAttempt != _lastStartedAttempt) {
      _lastStartedAttempt = widget.playAttempt;
      _requestShouldPlay(true);
    } else if (!widget.isPlaying && _lastRequestedShouldPlay != false) {
      _requestShouldPlay(false);
    }
  }

  void _requestShouldPlay(bool shouldPlay) {
    _lastRequestedShouldPlay = shouldPlay;
    _pendingShouldPlay = shouldPlay;
    if (!_draining) _drainIntent();
  }

  /// 2026-09-01 버그 수정: "문장 간격 없음" 설정에서는 듣기→말하기→듣기 전환이 한
  /// 프레임 안에서 벌어질 만큼 빨라, pause()와 play() 네이티브 호출이 거의 동시에
  /// 겹쳐 나갈 수 있었다(사용자 실측: 5번 반복 중 첫 번째만 영상이 움직이고 나머지는
  /// 정지영상 — 둘 중 어느 쪽이 나중에 실제로 적용될지 순서가 보장되지 않아서였다).
  /// 이제는 "재생해야 하는가"라는 의도만 [_pendingShouldPlay]에 최신값으로 갱신해두고,
  /// 이 루프가 그 값을 한 번에 하나씩만 순차 소비한다 — 처리 도중 값이 또 바뀌면
  /// while 조건이 그걸 감지해 이어서 처리하므로, 네이티브 호출 두 개가 동시에 나가는
  /// 경우 자체가 생기지 않는다.
  Future<void> _drainIntent() async {
    _draining = true;
    try {
      while (_pendingShouldPlay != null) {
        final shouldPlay = _pendingShouldPlay!;
        _pendingShouldPlay = null;
        final controller = _controller;
        if (controller == null || !mounted) return;
        if (shouldPlay) {
          // 2026-09-01 버그 수정: 이 세 단계 사이 어디서든 화면 전환(예: 영상 모드 →
          // 한꺼번에 보기)으로 이 위젯이 dispose될 수 있다 — 그러면 [dispose]가 이미
          // controller.dispose()를 호출한 뒤인데, 여기서 그대로 이어서 play()를
          // 호출하면 이미 정리된 컨트롤러에 재생을 거는 꼴이 되어 짧게 소리가 새어
          // 나오는 문제가 있었다(사용자 실측: 영상 모드에서 리스트로 전환하는 순간
          // 겹쳐 들림). 매 단계 직후 `mounted`를 다시 확인해 안전하게 중단한다.
          await controller.seekTo(Duration(milliseconds: widget.startMs));
          if (!mounted) return;
          await controller.setPlaybackSpeed(widget.playbackSpeed);
          if (!mounted) return;
          await controller.play();
        } else {
          await controller.pause();
        }
        if (!mounted) return;
      }
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || !_ready || controller == null) {
      // 로딩/실패 중에도 레이아웃이 흔들리지 않게 같은 비율의 자리표시자를 유지한다.
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: _failed
              ? Icon(Icons.videocam_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant)
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
