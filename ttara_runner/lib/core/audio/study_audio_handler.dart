import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'audio_player_service.dart';

/// 잠금화면/알림의 미디어 미니 플레이어를 우리 학습 로직에 직접 연결하는 커스텀
/// 핸들러. `audio_service`가 요구하는 표준 프로토콜(재생/일시정지/다음/이전)을
/// 구현하되, 그 호출을 [AudioPlayerService]의 재생기로 곧장 넘기지 않고 현재 화면의
/// [onNotificationPlay] 등 콜백으로 위임한다 — 그래야 알림에서 재생을 눌러도 문장
/// 반복 횟수/속도 설정이 그대로 적용되고, 정지를 눌러도 진짜로 멈춘 채 있는다.
///
/// **2026-08-09 도입 배경**: 예전엔 `just_audio_background`가 알림 버튼을 재생기에
/// 직접(우리 컨트롤러를 거치지 않고) 매핑해서, "따라 말하기" 대기 시간처럼 의도적으로
/// 재생이 멈춰 있는 순간에 알림에서 재생을 누르면 문장 경계 감시가 전혀 안 걸린 채
/// 파일 끝까지 죽 재생됐다(사용자 보고). 그 증상을 막으려 위치를 감시하다 어긋나면
/// 되돌리는 땜빵(watchdog)을 넣었지만, 이번엔 반대로 알림에서 정지를 누른 "바로 그
/// 순간"의 레이스 때문에 알림이 사라졌다 스스로 다시 재생되는 새 증상이 생겼다(사용자
/// 보고). 알림 버튼이 애초에 재생기를 직접 만지지 않고 앱 로직을 거치게 만들면 두
/// 증상 모두 근본적으로 사라진다.
///
/// [ShadowingController]가 화면에 들어올 때 콜백을 등록하고 나갈 때 [clearCallbacks]로
/// 해제한다 — 이 핸들러 자체는 앱 전역에서 하나만 살아있는 싱글톤(main.dart에서 생성),
/// 콜백이 없을 때(학습 화면 밖)는 재생기를 직접 조작하는 것으로 안전하게 폴백한다.
class StudyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _service;

  void Function()? onNotificationPlay;
  void Function()? onNotificationPause;
  void Function()? onNotificationSkipToNext;
  void Function()? onNotificationSkipToPrevious;

  StudyAudioHandler(this._service) {
    _service.playingStream.listen((_) => _broadcastState());
    _service.processingStateStream.listen((_) => _broadcastState());
    _service.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
    _broadcastState();
  }

  void _broadcastState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _service.isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_service.processingState),
      playing: _service.isPlaying,
      speed: 1.0,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// 학습 화면에 진입할 때 호출 — 알림에 표시할 정보를 채운다. "쉐도잉랩"을 제목으로,
  /// 실제 파일명을 그 아래 부제로 보여준다(음악 앱의 곡명/아티스트 자리와 동일한 구성).
  void updateNowPlaying({required String fileName, Uri? artUri}) {
    mediaItem.add(MediaItem(
      id: fileName,
      title: '쉐도잉랩',
      album: fileName,
      artUri: artUri,
      duration: _service.duration,
    ));
  }

  void clearNowPlaying() => mediaItem.add(null);

  void clearCallbacks() {
    onNotificationPlay = null;
    onNotificationPause = null;
    onNotificationSkipToNext = null;
    onNotificationSkipToPrevious = null;
  }

  @override
  Future<void> play() async {
    if (onNotificationPlay != null) {
      onNotificationPlay!();
    } else {
      await _service.play();
    }
  }

  @override
  Future<void> pause() async {
    if (onNotificationPause != null) {
      onNotificationPause!();
    } else {
      await _service.pause();
    }
  }

  @override
  Future<void> stop() async {
    if (onNotificationPause != null) {
      onNotificationPause!();
    } else {
      await _service.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _service.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    onNotificationSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onNotificationSkipToPrevious?.call();
  }
}
