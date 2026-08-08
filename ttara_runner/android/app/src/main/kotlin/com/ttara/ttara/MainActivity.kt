package com.ttara.ttara

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// just_audio_background(audio_service)가 백그라운드 재생용 캐시된 FlutterEngine을 자체
// 관리하므로, 일반 FlutterActivity 대신 이 베이스 클래스를 써야 한다 — 안 그러면
// JustAudioBackground.init()이 "wrong Activity class" PlatformException으로 즉시 실패하고
// main()이 runApp()에 도달하지 못해 앱이 네이티브 스플래시에서 멈춘다.
class MainActivity : AudioServiceFragmentActivity()
