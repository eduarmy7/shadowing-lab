package com.ttara.ttara

import android.media.MediaMetadataRetriever
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// just_audio_background(audio_service)가 백그라운드 재생용 캐시된 FlutterEngine을 자체
// 관리하므로, 일반 FlutterActivity 대신 이 베이스 클래스를 써야 한다 — 안 그러면
// JustAudioBackground.init()이 "wrong Activity class" PlatformException으로 즉시 실패하고
// main()이 runApp()에 도달하지 못해 앱이 네이티브 스플래시에서 멈춘다.
class MainActivity : AudioServiceFragmentActivity() {
    private val coverArtChannel = "com.ttara.ttara/cover_art"

    // 2026-08-09: 오디오 파일에 임베딩된 앨범 아트(오디오북 표지 등)를 추출한다.
    // MediaMetadataRetriever.getEmbeddedPicture()는 안드로이드 SDK에 내장돼 있어
    // 별도 플러그인 의존성 없이 바로 쓸 수 있다 — audio_waveforms 사고 이후로 굳이
    // 새 서드파티 네이티브 패키지를 추가하기보다, 이렇게 작은 채널 하나로 직접
    // 구현하는 쪽을 택했다.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, coverArtChannel).setMethodCallHandler { call, result ->
            if (call.method == "extract") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val bytes = retriever.embeddedPicture
                    result.success(bytes)
                } catch (e: Exception) {
                    result.success(null)
                } finally {
                    retriever.release()
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
