import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as jab;

/// [just_audio]를 감싸 "문장 구간(startMs~endMs) 재생"이라는 도메인 개념을 노출하는
/// 얇은 서비스. WaveformPlayer 위젯과 ShadowingController가 공통으로 사용한다.
///
/// 영상 파일도 오디오 트랙만 재생한다(화면엔 파형만 노출 — UX 문서 권장, 성능/배터리 이점).
/// 백그라운드 재생은 main.dart의 JustAudioBackground.init()과 결합해 동작한다.
class AudioPlayerService {
  AudioPlayer _player = AudioPlayer();
  String? _currentSource;
  bool _currentSourceIsLocal = true;
  StreamSubscription<Duration>? _boundarySub;
  Completer<void>? _activeCompleter;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get isPlaying => _player.playing;

  /// asset:///-스킴 접두사 — 앱 번들(Flutter AssetBundle)에 포함된 오디오를 가리킨다.
  /// "샘플로 체험하기"(QA 🔴-3, `assets/sample/`) 및 라이브러리 목업 데이터가 사용한다.
  static const _assetScheme = 'asset:///';

  /// 로컬 파일 경로 / 원격 URL / 번들 asset(`asset:///`) 중 하나를 오디오 소스로 설정.
  /// 이미 같은 소스가 "성공적으로" 로드되어 있다면 재로딩하지 않는다.
  ///
  /// **2026-08-06 버그 수정 (1)**: 예전엔 `_currentSource = pathOrUrl`을 실제 로딩
  /// (`setAsset`/`setAudioSource`) *전에* 미리 써버려서, 로딩이 도중에 실패해도(예:
  /// 일시적 리소스 경합, 손상된 캐시 파일) "이미 로드된 소스"로 영구히 표시됐다 —
  /// 그러면 이후 [playSegmentOnce]를 아무리 다시 호출해도 이 함수가 매번 조용히
  /// 스킵되면서 **비어있는 플레이어**에 대고 seek/play를 시도하게 되어, "재생 버튼을
  /// 눌러도 버퍼링 스피너만 영원히 도는" 증상으로 나타났다. 이제 실제 로딩이 끝난
  /// 뒤에만 `_currentSource`를 갱신하고, 실패하면 null로 되돌려 다음 시도가 진짜로
  /// 다시 로딩하게 한다.
  ///
  /// **2026-08-06 버그 수정 (2, 더 근본적인 원인)**: `main.dart`의
  /// `JustAudioBackground.init()`이 앱 전역에 걸려 있어 **모든** `AudioSource`가
  /// `just_audio_background`의 `MediaItem` 태그를 가지고 있어야 하는데(없으면
  /// `Bad state: ... every AudioSource ...`), 이 서비스는 태그를 전혀 안 채우고
  /// 있었다 — `silence_detector.dart`의 내부 프로브 플레이어는 이 세션 초반에 이미
  /// 고쳤지만, 정작 사용자에게 보이는 **진짜 재생**을 담당하는 이 서비스는 그때
  /// 놓쳤다. 그 결과 실기기에서 재생 시도가 매번 이 예외로 실패했고 — 위 (1)번
  /// 버그와 겹쳐서 목록/한 문장 화면에서는 조용히 무한 버퍼링으로, 편집 화면에서는
  /// (직접 `setSource`를 호출하는 경로라 매번 새로 시도됨) "미리듣기를 재생할 수
  /// 없어요" 에러로 나타났다.
  Future<void> setSource(String pathOrUrl, {required bool isLocal}) async {
    if (_currentSource == pathOrUrl) return;

    try {
      final tag = jab.MediaItem(id: pathOrUrl, title: '쉐도잉랩');
      if (pathOrUrl.startsWith(_assetScheme)) {
        final assetPath = pathOrUrl.substring(_assetScheme.length);
        await _player.setAudioSource(AudioSource.asset(assetPath, tag: tag));
      } else {
        final source = isLocal
            ? AudioSource.uri(Uri.file(pathOrUrl), tag: tag)
            : AudioSource.uri(Uri.parse(pathOrUrl), tag: tag);
        await _player.setAudioSource(source);
      }
      _currentSource = pathOrUrl;
      _currentSourceIsLocal = isLocal;
    } catch (e) {
      _currentSource = null;
      rethrow;
    }
  }

  /// [startMs]~[endMs] 구간만 반복 없이 1회 재생 후 자동 정지.
  /// 쉐도잉 학습 화면의 "원어민 음성 재생" 단계, #4 편집 화면의 카드 미리듣기에서 사용.
  ///
  /// **2026-08-06 버그 수정**: `just_audio`의 `AudioPlayer.play()`는 fire-and-forget이
  /// 아니다 — 반환하는 `Future`가 **재생이 일시정지되거나 자연 종료될 때까지** 완료되지
  /// 않는다. 예전 코드는 `await _player.play()`를 먼저 하고 그 다음 줄에서 "여기서
  /// 멈춰라" 하는 [positionStream] 리스너를 등록했는데, `play()`가 안 끝나니 그 리스너
  /// 등록 코드 자체가 실행되지 않아서 — 문장 경계에서 멈추는 로직이 전혀 걸리지 않고
  /// 파일이 끝날 때까지(혹은 무기한) 그대로 재생됐다(실기기에서 "소리는 나는데 문장
  /// 단위로 안 끊기고 통으로 재생됨"으로 재현). 경계 리스너를 먼저 걸어둔 뒹, `play()`는
  /// 기다리지 않고(`unawaited`) 시작만 시킨다 — 그래야 리스너가 실제로 [endMs]에서
  /// `pause()`를 호출할 수 있다.
  Future<void> playSegmentOnce({
    required int startMs,
    required int endMs,
    double speed = 1.0,
  }) async {
    await _boundarySub?.cancel();
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(); // 이전 호출이 아직 대기 중이었다면 여기서 풀어준다.
    }
    await _player.setSpeed(speed);
    await _player.seek(Duration(milliseconds: startMs));

    final completer = Completer<void>();
    _activeCompleter = completer;
    _boundarySub = _player.positionStream.listen((pos) {
      if (pos.inMilliseconds >= endMs) {
        _player.pause();
        if (!completer.isCompleted) completer.complete();
      }
    });
    // 재생이 자연 종료(파일 끝)되는 경우도 대비.
    _player.processingStateStream.firstWhere((s) => s == ProcessingState.completed).then((_) {
      if (!completer.isCompleted) completer.complete();
    });

    unawaited(_player.play());

    // **2026-08-06 추가 — 자동 복구.** 실기기에서 오래 쓸수록(수십~백여 문장 재생 후)
    // 예외 없이 조용히 재생이 안 되는 현상이 재현됐다 — 로그에 에러가 전혀 안 남아서
    // Dart 쪽 버그(리스너/Future 누수 등)는 이미 여러 차례 고쳤지만, 그래도 남아있는
    // 걸 보면 하드웨어 MP3 디코더(`c2.sec.mp3.decoder`)가 반복적인 seek/flush를
    // 오래 버티다 가끔 내부 상태가 꼬이는 것으로 의심된다 — 코덱 자체 문제라면
    // Dart 레벨에서 "왜"를 완전히 고칠 수는 없다. 대신 "예상 시간을 벗어나면 고장난
    // 것으로 보고 강제 리셋 후 예외를 던진다" — 그러면 이 메서드를 호출한 쪽
    // (`ShadowingController._playWithRetry`)의 기존 1회 재시도 로직이 자동으로 다시
    // 시도하는데, 이번엔 방금 강제로 새로 로드한 신선한 소스/플레이어 상태에서
    // 재생하므로 실제로 복구될 가능성이 높다.
    //
    // 2026-08-07: 118분 실제 파일 재생 테스트에서 이 감지+복구가 여러 차례 실제로
    // 발동했고 매번 성공적으로 복구됐지만, 배율이 3배+4초라 감지까지 문장당 최대
    // 7~16초씩 화면이 멈춘 것처럼 보였다(사용자 체감상 "몇 초 멈췄다 풀림"). 로컬
    // 파일 재생은 네트워크 지연이 없어 정상 재생이면 훨씬 여유 있게 끝나므로, 배율을
    // 줄여 고장 감지를 더 빠르게 해서 멈춤 체감 시간을 줄인다.
    final expectedMs = (endMs - startMs).clamp(200, 1 << 31);
    try {
      await completer.future.timeout(Duration(milliseconds: expectedMs * 2 + 2500));
    } on TimeoutException {
      debugPrint('[AudioPlayerService] playSegmentOnce timed out (startMs=$startMs endMs=$endMs) '
          '— forcing a hard reset and surfacing as a failure so the caller retries.');
      await _hardReset();
      rethrow;
    }
  }

  /// 재생이 멎었을 때 코덱 상태를 초기화한다.
  ///
  /// **2026-08-07 수정**: 처음엔 같은 [AudioPlayer] 객체에 `stop()` 후 소스만 다시
  /// 로드했다 — 실기기 로그로 확인해보니 이 방식도 겉으론 성공한다(ExoPlayerImpl이
  /// Release/Init되고 새 코덱이 RUNNING 상태까지 간다). 그런데 그 직후 재시도로
  /// 실제 문장을 재생하면 **네이티브 로그가 단 한 줄도 안 남긴 채** 다시 조용히
  /// 멈췄다(107번째 실패 후 이 리셋을 넣어 227번째까지는 버텼지만, 결국 같은 증상
  /// 재발) — `stop()`+재로드만으로는 `just_audio`/미디어 채널 쪽에 남은 어떤 내부
  /// 상태(코덱이 아니라 플랫폼 채널/플레이어 핸들 자체)까지는 못 씻어낸다는 뜻이다.
  /// 그래서 이번엔 더 강하게 — 기존 [AudioPlayer] 인스턴스를 아예 `dispose()`하고
  /// 완전히 새 인스턴스로 교체한다. [positionStream] 등 게터들이 `_player`를 매번
  /// 새로 참조하므로, 이후 호출자가 다시 구독하면 자연히 새 인스턴스를 보게 된다.
  Future<void> _hardReset() async {
    await _boundarySub?.cancel();
    _boundarySub = null;
    _activeCompleter = null;
    final source = _currentSource;
    final isLocal = _currentSourceIsLocal;
    final oldPlayer = _player;
    _player = AudioPlayer();
    // 2026-08-07: dispose() 전에 stop()을 한 번 먼저 호출해 마지막 상태 이벤트를
    // 정리시킨다 — 118분 파일 테스트에서 stop() 없이 바로 dispose()했더니 just_audio
    // 내부 스트림에 아주 살짝 늦게 도착한 이벤트가 이미 close된 Subject에 부딪히며
    // "Bad state: Cannot add new events after calling close"가 (앱을 죽이지는 않지만)
    // 로그에 찍혔다. 완전히 없앤다는 보장은 없지만(근본적으로 플랫폼 채널 이벤트 도착
    // 타이밍은 우리가 제어할 수 없다) 레이스 가능성을 줄인다.
    try {
      await oldPlayer.stop();
    } catch (_) {}
    try {
      await oldPlayer.dispose();
    } catch (_) {
      // 예전 인스턴스가 이미 맛이 가서 dispose 자체가 실패해도(있을 수 있음) 새
      // 인스턴스로의 교체는 이미 끝났으니 아래 재로딩은 계속 진행한다.
    }
    _currentSource = null; // 다음 setSource가 "이미 로드됨"으로 스킵하지 않고 진짜로 다시 로드하게.
    if (source != null) {
      try {
        await setSource(source, isLocal: isLocal);
      } catch (e) {
        debugPrint('[AudioPlayerService] _hardReset: reload failed: $e');
      }
    }
  }

  /// **2026-08-06 추가**: 정지/건너뛰기/편집 진입처럼 재생 중간에 사용자가 흐름을
  /// 끊는 모든 동작에서 호출해야 한다. 예전엔 컨트롤러의 정지/건너뛰기 메서드들이
  /// 화면 상태([ShadowingSessionState.phase] 등)만 idle로 되돌리고, 실제
  /// [playSegmentOnce]가 걸어둔 [_boundarySub](경계 도달 시 pause) 리스너와 그
  /// 완료를 기다리는 `Completer`는 그대로 방치했다 — 다음 재생이 시작될 때
  /// [playSegmentOnce] 맨 앞의 `_boundarySub?.cancel()`이 그 리스너를 늦게라도
  /// 정리하긴 하지만, 그 사이 새 재생과 오래된(응답 없는) 리스너/Future가 뒤섞이며
  /// "여러 번 조작한 뒤부터 재생이 조용히 안 됨" 증상의 원인이 됐다(에러 로그도 안
  /// 남는 이유 — 예외가 아니라 방치된 비동기 상태라서). 정지 계열 동작은 전부 이
  /// 메서드로 확실히 정리한다.
  Future<void> stopSegment() async {
    await _boundarySub?.cancel();
    _boundarySub = null;
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(); // playSegmentOnce를 기다리던 호출측을 즉시 풀어준다.
    }
    _activeCompleter = null;
    await _player.pause();
  }

  /// 롱프레스 프리뷰(0.5배속 임시 재생) 등 단순 재생/일시정지.
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> dispose() async {
    await _boundarySub?.cancel();
    await _player.dispose();
  }
}
