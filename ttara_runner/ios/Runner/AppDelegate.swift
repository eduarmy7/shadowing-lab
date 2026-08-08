import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 2026-08-09: 오디오 파일에 임베딩된 앨범 아트(오디오북 표지 등)를 추출한다.
    // Android의 MediaMetadataRetriever와 대응되는 iOS 쪽 채널 — AVAsset의 공통
    // 메타데이터(artwork)만 읽으면 되므로 별도 플러그인 없이 AVFoundation으로 충분하다.
    let coverArtChannel = FlutterMethodChannel(
      name: "com.ttara.ttara/cover_art",
      binaryMessenger: engineBridge.binaryMessenger
    )
    coverArtChannel.setMethodCallHandler { call, result in
      guard call.method == "extract",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(nil)
        return
      }
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      let artworkItem = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
      ).first
      if let data = artworkItem?.dataValue {
        result(FlutterStandardTypedData(bytes: data))
      } else {
        result(nil)
      }
    }
  }
}
