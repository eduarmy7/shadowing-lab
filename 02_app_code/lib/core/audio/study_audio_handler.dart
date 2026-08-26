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

  // 2026-08-26 추가: audio_service 기본 정지 아이콘(drawable/audio_service_stop)이
  // 여백 없이 꽉 찬 정사각형이라 재생(▶) 아이콘보다 훨씬 커 보인다는 실사용자
  // 제보로, 여백을 둔 표준 Material 비율의 아이콘을 직접 만들어 대신 쓴다
  // (`android/app/src/main/res/drawable/ic_stop_notification.xml` 참고).
  static const _stopControl = MediaControl(
    androidIcon: 'drawable/ic_stop_notification',
    label: '정지',
    action: MediaAction.stop,
  );

  // 2026-08-26 추가 — 실사용자 제보: 알림/잠금화면 미니 플레이어에 재생/일시정지
  // 토글 버튼 하나뿐이라, "따라 말하기" 대기 구간(실제 오디오는 안 나오지만 학습
  // 루프는 계속 진행 중인 상태)에는 재생 아이콘(▶)이 떠서 "지금 멈춰있나?" 헷갈리고,
  // 그 상태에서 눌러도 이미 진행 중이던 루프라 체감상 "정지 버튼이 안 먹힌다"로
  // 보였다. 토글 버튼(재생↔일시정지 아이콘 표시용)은 그대로 두되, 상태와 무관하게
  // 항상 눌리는 별도의 정지(■) 버튼을 추가한다 — 눌리는 즉시 학습 루프 자체를
  // 멈춘다([StudyAudioHandler.stop] 참고).
  void _broadcastState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _service.isPlaying ? MediaControl.pause : MediaControl.play,
        _stopControl,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      // 압축(잠금화면 미니 플레이어) 뷰에는 토글+정지+다음을 우선 보여준다 — 이전
      // 곡으로 가는 것보다 "멈추기"가 훨씬 급한 동작이라는 사용자 피드백 반영.
      androidCompactActionIndices: const [1, 2, 3],
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

  /// 2026-08-26 추가된 알림의 전용 정지(■) 버튼이 호출하는 경로 — [pause]와 의도적으로
  /// 동일하게 동작한다(둘 다 학습 루프 자체를 멈추는 [onNotificationPause] 콜백으로
  /// 라우팅). 이 앱엔 "일시정지 후 나중에 이어듣기"와 "완전 정지"를 구분해야 할
  /// 별도 요구사항이 없어 굳이 다른 동작을 만들지 않는다.
  @override
  Future<void> stop() async {
    if (onNotificationPause != null) {
      onNotificationPause!();
    } else {
      await _service.pause();
    }
  }

  /// **2026-08-26 버그 수정 — 진짜 원인 발견**: `audio_service`는 사용자가 알림을
  /// 직접 스와이프해서 지우면 자동으로 이 콜백을 호출한다(기본 구현은 [stop]만
  /// 호출). 그런데 [stop]/[pause]는 재생만 멈출 뿐 [mediaItem](지금 재생 중인 항목
  /// 정보)은 지우지 않는다 — 그래서 사용자가 알림을 눈으로 사라지게 해도 내부적으론
  /// "세션이 아직 살아있다"는 신호가 남아있었고, 앱을 다시 열면 그 신호만 보고
  /// 학습 화면으로 돌아가는 버그로 이어졌다(main.dart/app_router.dart의
  /// "세션이 살아있으면 학습 화면 유지" 로직 참고). 알림을 직접 지우는 건 재생
  /// 중이던 문장 처음으로 돌아가는 "일시정지"와 달리 확실한 "세션 종료" 의사표시로
  /// 보고, 재생 정지에 더해 [clearNowPlaying]까지 호출한다.
  @override
  Future<void> onNotificationDeleted() async {
    if (onNotificationPause != null) {
      onNotificationPause!();
    } else {
      await _service.pause();
    }
    clearNowPlaying();
  }

  /// **2026-08-26 추가**: `androidNotificationOngoing: true`라 알림을 손가락으로
  /// 스와이프해서 지우는 건 원래 막혀 있다 — 그래서 사용자가 "미니 플레이어를
  /// 화면에서 안 보이게 지웠다"고 한 건 알림 자체가 아니라 **앱을 최근 목록에서
  /// 스와이프해 지운 것**일 가능성이 높다. 이때 안드로이드 OS가 우리 앱의 포그라운드
  /// 서비스(와 그 알림)를 통째로 정리하는데, `audio_service`의 [onTaskRemoved] 기본
  /// 구현은 아무 것도 안 해서(위 [onNotificationDeleted]와 달리) [mediaItem]이
  /// 그대로 남아 같은 버그로 이어진다. 이 경로에서도 세션 정보를 지운다.
  @override
  Future<void> onTaskRemoved() async {
    clearNowPlaying();
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
