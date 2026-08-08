import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_item.dart';
import '../providers/repository_providers.dart';

/// [awaitingSubtitleDecision]: 영상 파일을 골랐을 때만 거치는 중간 단계 — 자막(SRT/VTT)을
/// 추가할지 물어본다(00_input.md "영상+자막" 문장분리 경로). 음성 파일은 이 단계 없이
/// 바로 [uploading]으로 넘어간다(음성만 있으면 처음부터 무음 감지 경로가 확정이라
/// 물어볼 것이 없다).
enum UploadPhase { idle, awaitingSubtitleDecision, uploading, error }

class UploadState {
  final UploadPhase phase;
  final String? fileName;
  final double progress;
  final String? errorMessage;
  // awaitingSubtitleDecision 단계에서만 값이 있음 — 사용자가 자막을 고르거나 건너뛸 때까지
  // 들고 있어야 하는 원본 파일 정보.
  final String? _pendingLocalPath;
  final MediaSourceType? _pendingSourceType;
  // 2026-08-06: 등록이 성공적으로 끝나면 여기 채워진다 — [FileUploadScreen]이 이 값의
  // 변화를 `ref.listen`으로 지켜보다가 직접 다음 화면으로 넘어간다(아래 클래스 doc 참고,
  // "왜 이 필드가 필요한가").
  final String? registeredMediaId;

  const UploadState({
    this.phase = UploadPhase.idle,
    this.fileName,
    this.progress = 0,
    this.errorMessage,
    String? pendingLocalPath,
    MediaSourceType? pendingSourceType,
    this.registeredMediaId,
  })  : _pendingLocalPath = pendingLocalPath,
        _pendingSourceType = pendingSourceType;

  String? get pendingLocalPath => _pendingLocalPath;
  MediaSourceType? get pendingSourceType => _pendingSourceType;

  UploadState copyWith({
    UploadPhase? phase,
    String? fileName,
    double? progress,
    String? errorMessage,
    String? pendingLocalPath,
    MediaSourceType? pendingSourceType,
    String? registeredMediaId,
  }) {
    return UploadState(
      phase: phase ?? this.phase,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      pendingLocalPath: pendingLocalPath ?? _pendingLocalPath,
      pendingSourceType: pendingSourceType ?? _pendingSourceType,
      registeredMediaId: registeredMediaId ?? this.registeredMediaId,
    );
  }
}

final uploadControllerProvider =
    StateNotifierProvider.autoDispose<UploadController, UploadState>((ref) => UploadController(ref));

/// #2 파일 업로드 화면 뷰모델. 시스템 파일 피커로 로컬 파일을 고르고(네트워크 업로드
/// 아님 — 2026-08-05 STT 폐기 이후 서버 전송 자체가 없다), 영상이면 자막(SRT/VTT)
/// 첨부 여부를 물은 뒤 [SegmentationRepository.registerLocalMedia]로 등록해 로컬
/// [MediaItem]을 만든다.
///
/// **2026-08-06 버그 수정 — "등록 100%에서 화면이 영원히 멈춤".** 실기기에서 실제
/// 큰 파일(57MB mp3)로 재현: 로그로 확인해보니 [pickMedia] 내부 작업은 항상 0.5초
/// 안에 완전히 성공했는데(파일 복사→등록→저장 전부 끝남) 화면은 계속 "준비 중 100%"에
/// 머물렀다 — 즉 버그는 이 컨트롤러가 아니라 호출 쪽의 화면 전환 로직에 있었다.
/// 원래 `FileUploadScreen`의 `_PickerView._pick()`가 `pickMedia()`를 기다렸다가 자기
/// 자신의 `BuildContext`로 직접 `context.pushReplacement(...)`를 호출했는데,
/// `pickMedia()`가 진행되는 동안 `state.phase`가 `uploading`으로 바뀌면서
/// `FileUploadScreen`이 자식 위젯을 `_PickerView` → `_UploadingView`로 즉시 스위치해
/// 버린다 — 그러면 `_PickerView`(와 `_pick()`가 캡처해 들고 있던 그 `context`)는 화면
/// 전환 로직이 끝나기도 전에 이미 언마운트된 상태가 되고, `await pickMedia()`가 끝난
/// 시점엔 `context.mounted`가 false라서 `pushReplacement` 호출 자체가 조용히
/// 무시됐다(에러도, 로그도 없이). 그래서 [registeredMediaId] 필드를 새로 두고
/// `FileUploadScreen`이 자기 자신의(항상 살아있는) context로 `ref.listen`을 통해
/// 직접 화면을 전환하도록 바꿨다 — 더 이상 어떤 자식 위젯의 context에도 의존하지
/// 않는다.
class UploadController extends StateNotifier<UploadState> {
  final Ref ref;
  UploadController(this.ref) : super(const UploadState());

  /// 메인 미디어 파일을 고른다. [sourceHint]로 음성/영상 중 어느 쪽을 고를지 미리
  /// 알려줘야 한다 — 파일 피커의 허용 확장자를 그 종류로 좁혀서 사용자가 원하는
  /// 파일을 더 쉽게 찾게 한다("파일에서 선택" 진입 시 화면이 먼저 물어본다,
  /// `file_upload_screen.dart`의 `_SourceTypeSheet` 참고). 영상이면
  /// [UploadPhase.awaitingSubtitleDecision]으로 전환해 화면이 자막 첨부 여부를
  /// 물어보게 하고(반환값 null), 음성이면 그 자리에서 바로 등록까지 마치고 mediaId를
  /// 반환한다.
  Future<String?> pickMedia({required MediaSourceType sourceHint}) async {
    state = const UploadState(phase: UploadPhase.idle);
    final allowedExtensions =
        sourceHint == MediaSourceType.video ? AppConstants.supportedVideoExtensions : AppConstants.supportedAudioExtensions;
    debugPrint('[pickMedia] calling FilePicker.pickFiles (sourceHint=$sourceHint)...');
    final result = await _pickFilesOrTimeout(allowedExtensions: allowedExtensions);
    debugPrint('[pickMedia] FilePicker.pickFiles returned: '
        'path=${result?.files.single.path} name=${result?.files.single.name} '
        'size=${result?.files.single.size}');
    if (result == null) return null; // 사용자가 취소했거나(반환 null) 타임아웃(에러 상태로 전환됨)
    if (result.files.single.path == null) return null;

    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    final ext = fileName.split('.').last.toLowerCase();

    // 피커 자체를 sourceHint의 확장자로 좁혀뒀지만(iOS 파일 앱 등 일부 환경에서는
    // 필터가 느슨하게 적용될 수 있어) 여기서도 한 번 더 확인한다.
    if (!allowedExtensions.contains(ext)) {
      final kindLabel = sourceHint == MediaSourceType.video ? '영상(mp4·mov)' : '음성(mp3·m4a·wav)';
      state = state.copyWith(
        phase: UploadPhase.error,
        errorMessage: '$kindLabel 파일이 아니에요. 다시 선택해주세요.',
      );
      return null;
    }

    final sourceType = sourceHint;

    if (sourceType == MediaSourceType.video) {
      state = UploadState(
        phase: UploadPhase.awaitingSubtitleDecision,
        fileName: fileName,
        pendingLocalPath: path,
        pendingSourceType: sourceType,
      );
      return null;
    }

    return _registerAndSave(localPath: path, fileName: fileName, sourceType: sourceType, subtitlePath: null);
  }

  /// 자막 파일(SRT/VTT)을 골라 함께 등록한다 — 자막이 있으면 문장분리가 자막 파싱
  /// 경로를 탄다(#4에서 텍스트와 함께 편집 가능).
  Future<String?> pickSubtitleAndContinue() async {
    final path = state.pendingLocalPath;
    final sourceType = state.pendingSourceType;
    final fileName = state.fileName;
    if (path == null || sourceType == null || fileName == null) return null;

    final result = await _pickFilesOrTimeout(allowedExtensions: AppConstants.supportedSubtitleExtensions);
    if (result == null || result.files.single.path == null) {
      // 자막 선택을 취소했거나(사용자) 시간이 너무 오래 걸렸다면(에러 상태) 여전히
      // 자막 여부를 물어보는 화면에 머문다.
      return null;
    }
    final subtitlePath = result.files.single.path!;
    return _registerAndSave(
      localPath: path,
      fileName: fileName,
      sourceType: sourceType,
      subtitlePath: subtitlePath,
    );
  }

  /// "자막 없이 계속" — 무음/일시정지 구간 감지 경로로 진행(#4에서 텍스트 없이 편집).
  Future<String?> continueWithoutSubtitle() async {
    final path = state.pendingLocalPath;
    final sourceType = state.pendingSourceType;
    final fileName = state.fileName;
    if (path == null || sourceType == null || fileName == null) return null;

    return _registerAndSave(localPath: path, fileName: fileName, sourceType: sourceType, subtitlePath: null);
  }

  /// [FilePicker.pickFiles]를 감싼다 — 큰 실제 파일(content:// URI)을 고르면 안드로이드가
  /// 앱 캐시로 파일을 통째로 복사하는데, 이 복사 도중 화면이 꺼지거나 기기가 백그라운드
  /// 프로세스를 절전 처리하면 일부 기기(실기기+에뮬레이터 모두 재현됨)에서 FlutterEngine이
  /// Activity와의 연결을 끊어버려 피커의 `Future`가 영원히 응답을 못 받는다 — 그러면
  /// 화면이 "OO% 준비 중"에서 사용자가 재시도할 방법도 없이 그대로 멈춘다. 무한 대기
  /// 대신 [AppConstants.filePickTimeoutMinutes] 뒤에는 재시도 가능한 에러로 전환한다.
  Future<FilePickerResult?> _pickFilesOrTimeout({required List<String> allowedExtensions}) async {
    try {
      return await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      ).timeout(const Duration(minutes: AppConstants.filePickTimeoutMinutes));
    } on TimeoutException {
      state = state.copyWith(
        phase: UploadPhase.error,
        errorMessage: '파일을 불러오는 데 시간이 너무 오래 걸려요. 다시 시도해주세요.',
      );
      return null;
    }
  }

  Future<String?> _registerAndSave({
    required String localPath,
    required String fileName,
    required MediaSourceType sourceType,
    required String? subtitlePath,
  }) async {
    state = UploadState(phase: UploadPhase.uploading, fileName: fileName, progress: 0);
    debugPrint('[_registerAndSave] start localPath=$localPath fileName=$fileName');

    try {
      final mediaId = await ref.read(segmentationRepositoryProvider).registerLocalMedia(
            localFilePath: localPath,
            fileName: fileName,
            subtitleFilePath: subtitlePath,
            onProgress: (p) {
              if (mounted) state = state.copyWith(progress: p);
            },
          );
      debugPrint('[_registerAndSave] registerLocalMedia returned mediaId=$mediaId, saving MediaItem...');

      await ref.read(mediaRepositoryProvider).save(MediaItem(
            id: mediaId,
            fileName: fileName,
            localPath: localPath,
            sourceType: sourceType,
            durationMs: 0, // 재생 시 just_audio가 실제 duration을 채움(스캐폴드 한계)
            status: MediaStatus.analyzing,
            createdAt: DateTime.now(),
          ));
      debugPrint('[_registerAndSave] MediaItem saved, done.');

      // 화면 전환은 이 값의 변화를 지켜보는 FileUploadScreen이 직접 한다(클래스 doc
      // 참고) — 여기서 context.pushReplacement를 호출하지 않는다.
      if (mounted) state = state.copyWith(registeredMediaId: mediaId);
      return mediaId;
    } catch (e, st) {
      // 로컬 파일 접근 실패(권한/손상 파일 등) — 네트워크 개념이 없으니 "네트워크를
      // 확인해주세요" 같은 문구는 더 이상 맞지 않는다.
      debugPrint('[_registerAndSave] FAILED: $e\n$st');
      state = state.copyWith(phase: UploadPhase.error, errorMessage: '파일을 불러오지 못했어요. 다시 선택해주세요.');
      return null;
    }
  }

  void reset() => state = const UploadState();
}
