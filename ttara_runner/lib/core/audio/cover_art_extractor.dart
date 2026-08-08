import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 오디오 파일에 임베딩된 앨범 아트(오디오북 표지 등)를 추출한다 — 다른 쉐도잉 앱들이
/// 최근 학습 목록에 표지를 보여주는 것과 동일한 기능. 네이티브 쪽(Android
/// `MediaMetadataRetriever`, iOS `AVAsset` common metadata)에서 원본 바이트만 읽어오고,
/// 여기서 앱 캐시 디렉터리에 파일로 저장해 [MediaItem.coverArtPath]에 넣을 경로를 만든다.
///
/// 표지가 없는 파일(대부분의 음성 녹음/일부 오디오북)이 훨씬 흔하므로, 실패는 예외가
/// 아니라 그냥 null로 처리한다 — 호출측(`UploadController`)은 null이면 아이콘으로
/// 폴백한다.
class CoverArtExtractor {
  static const _channel = MethodChannel('com.ttara.ttara/cover_art');

  /// [localFilePath]에서 표지 이미지를 추출해 앱 캐시에 저장하고, 저장된 파일의 절대
  /// 경로를 반환한다. 표지가 없거나 추출에 실패하면 null.
  Future<String?> extractAndCache({required String mediaId, required String localFilePath}) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('extract', {'path': localFilePath});
      if (bytes == null || bytes.isEmpty) return null;

      final cacheDir = await getApplicationCacheDirectory();
      final coversDir = Directory('${cacheDir.path}/covers');
      if (!await coversDir.exists()) await coversDir.create(recursive: true);

      final coverFile = File('${coversDir.path}/$mediaId.jpg');
      await coverFile.writeAsBytes(bytes, flush: true);
      return coverFile.path;
    } catch (e) {
      debugPrint('[CoverArtExtractor] extract failed: $e');
      return null;
    }
  }
}
