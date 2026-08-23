import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/subtitle_parser.dart';
import '../../domain/entities/media_item.dart';
import '../providers/repository_providers.dart';

/// [picking]: 시스템 파일 피커가 떠 있는 동안(그리고 피커가 닫힌 직후 결과를 검증하는
/// 그 찰나) 보여주는 단계 — 2026-08-08 버그 수정 참고([UploadController.pickMedia] 코드
/// 주석).
///
/// [awaitingSubtitleDecision]: 영상 파일을 골랐을 때만 거치는 중간 단계 — 자막(SRT/VTT/SMI)을
/// 추가할지 물어본다(00_input.md "영상+자막" 문장분리 경로). 음성 파일은 이 단계 없이
/// 바로 [uploading]으로 넘어간다(음성만 있으면 처음부터 무음 감지 경로가 확정이라
/// 물어볼 것이 없다). 영상+자막 파일을 한 번에 같이 골라(아래 [pickMedia] 문서 참고)
/// 자동으로 짝지어졌으면 이 단계 자체를 건너뛴다.
///
/// [awaitingLanguageDecision]: **2026-08-22 추가** — 자막이 여러 언어 트랙을 담은
/// SMI(`detectSamiLanguageTracks`)로 밝혀졌을 때만 거치는 단계. 어느 트랙을 문장
/// 텍스트로 쓸지 사용자가 직접 고른다(다운로드한 SMI 다수가 한국어 트랙을 먼저 담고
/// 있어, 안 물어보면 영어 쉐도잉 앱에 한국어 문장이 나오는 문제가 있었다).
enum UploadPhase { idle, picking, awaitingSubtitleDecision, awaitingLanguageDecision, uploading, error }

class UploadState {
  final UploadPhase phase;
  final String? fileName;
  final double progress;
  final String? errorMessage;
  // awaitingSubtitleDecision/awaitingLanguageDecision 단계에서만 값이 있음 — 사용자가
  // 자막/언어를 고르거나 건너뛸 때까지 들고 있어야 하는 원본 파일 정보.
  final String? _pendingLocalPath;
  final MediaSourceType? _pendingSourceType;
  // awaitingLanguageDecision 단계에서만 값이 있음 — 이미 골라진(또는 자동 매칭된)
  // 자막 파일 경로와, 그 안에서 발견된 언어 트랙 목록.
  final String? _pendingSubtitlePath;
  final List<SamiLanguageTrack> detectedLanguageTracks;
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
    String? pendingSubtitlePath,
    this.detectedLanguageTracks = const [],
    this.registeredMediaId,
  })  : _pendingLocalPath = pendingLocalPath,
        _pendingSourceType = pendingSourceType,
        _pendingSubtitlePath = pendingSubtitlePath;

  String? get pendingLocalPath => _pendingLocalPath;
  MediaSourceType? get pendingSourceType => _pendingSourceType;
  String? get pendingSubtitlePath => _pendingSubtitlePath;

  UploadState copyWith({
    UploadPhase? phase,
    String? fileName,
    double? progress,
    String? errorMessage,
    String? pendingLocalPath,
    MediaSourceType? pendingSourceType,
    String? pendingSubtitlePath,
    List<SamiLanguageTrack>? detectedLanguageTracks,
    String? registeredMediaId,
  }) {
    return UploadState(
      phase: phase ?? this.phase,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      pendingLocalPath: pendingLocalPath ?? _pendingLocalPath,
      pendingSourceType: pendingSourceType ?? _pendingSourceType,
      pendingSubtitlePath: pendingSubtitlePath ?? _pendingSubtitlePath,
      detectedLanguageTracks: detectedLanguageTracks ?? this.detectedLanguageTracks,
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
  /// `file_upload_screen.dart`의 `_SourceTypeSheet` 참고).
  ///
  /// **2026-08-22 추가 — 영상+자막 한 번에 선택**: 영상일 땐 피커를 자막 확장자까지
  /// 함께 허용하고 `allowMultiple: true`로 연다. 다운로드한 영상은 흔히 같은 폴더에
  /// "영상.mp4" + "영상.smi"처럼 같은 이름의 자막 파일이 나란히 있는데(사용자 실사용
  /// 스크린샷으로 확인), 파일 피커 한 번에 둘 다 선택하면 뒤의 "자막 있나요?" 질문
  /// 단계를 건너뛰고 바로 등록으로 진행한다. **완전 자동은 아니다** — 안드로이드의
  /// Storage Access Framework는 앱이 사용자가 직접 고른 파일에만 접근하게 강제해서
  /// (이 앱의 "사용자가 선택한 파일만 접근" 데이터 안전성 정책과도 일치, 폴더 전체
  /// 접근 권한을 요구하지 않는다), 폴더를 뒤져 같은 이름 자막을 자동으로 찾아 붙이는
  /// 건 애초에 불가능하다 — 대신 한 번의 선택으로 둘 다 고르게 해 두 번째 피커
  /// 화면을 없앤 것이 현실적인 최선이다. 영상만 골랐으면(자막 없이, 또는 자막 확장자를
  /// 안 고르는 파일 매니저에서) 예전처럼 [UploadPhase.awaitingSubtitleDecision]으로
  /// 넘어간다. 음성은 그대로 단일 선택, 그 자리에서 바로 등록까지 마친다.
  ///
  /// **2026-08-08 버그 수정**: 예전엔 이 함수 맨 앞에서 `state`를 [UploadPhase.idle]로
  /// 되돌려놓고서야 시스템 파일 피커를 열었다 — 그 결과, 시스템 피커에서 파일을 고르고
  /// 우리 화면으로 돌아오는 그 순간 화면엔 여전히 "idle"(=파일 소스를 고르는 최초 화면,
  /// `_PickerView`)이 렌더링돼 있었다. 실제로 [uploading]으로 바뀌기까지의 그 짧은 프레임
  /// 동안 사용자 눈에는 "어디서 가져올까요?" 화면이 다시 뜬 것처럼 보여, "선택이 안 된
  /// 건가?" 하고 오해하기 쉬웠다(사용자 보고로 발견). 대신 피커를 열기 전부터
  /// [UploadPhase.picking](로딩 인디케이터)으로 전환해, 피커가 닫힌 뒤에도 다음 단계로
  /// 넘어가기 전까지 "처리 중"이라는 화면이 끊김 없이 이어지게 한다.
  Future<String?> pickMedia({required MediaSourceType sourceHint}) async {
    state = const UploadState(phase: UploadPhase.picking);
    final isVideo = sourceHint == MediaSourceType.video;
    final allowedExtensions = isVideo
        ? [...AppConstants.supportedVideoExtensions, ...AppConstants.supportedSubtitleExtensions]
        : AppConstants.supportedAudioExtensions;
    debugPrint('[pickMedia] calling FilePicker.pickFiles (sourceHint=$sourceHint)...');
    // 2026-08-22 버그 수정: 음성 선택 시 FileType.custom + allowedExtensions로 열었더니
    // 실기기에서 m4a 파일이 아예 목록에 안 보인다는 제보 — 안드로이드가 file_picker의
    // 커스텀 확장자를 MIME 타입으로 변환할 때 mp3/wav는 표준 매핑이 확실하지만 m4a는
    // 기기/런처에 따라 매핑이 애매해서 필터에서 통째로 빠지는 경우가 있는, file_picker의
    // 잘 알려진 문제다. 음성은 안드로이드 내장 "오디오" 카테고리(FileType.audio, MIME
    // "audio/*")로 열어 이 문제를 피하고, 선택 후 확장자 검증(아래)으로 mp3/m4a/wav만
    // 실제로 받아들인다. 영상+자막 다중 선택은 자막 확장자(.smi 등)가 애초에 표준
    // MIME이 없어 FileType.custom이 필수라 그대로 둔다.
    final result = await _pickFilesOrTimeout(
      allowedExtensions: allowedExtensions,
      allowMultiple: isVideo,
      type: isVideo ? FileType.custom : FileType.audio,
    );
    debugPrint('[pickMedia] FilePicker.pickFiles returned '
        '${result?.files.length ?? 0} file(s): ${result?.files.map((f) => f.name).join(', ')}');
    if (result == null) {
      // 사용자가 시스템 피커를 그냥 닫은 경우(취소) — 타임아웃/에러였다면
      // _pickFilesOrTimeout이 이미 error 상태로 바꿔놨을 것이므로 그 경우엔 덮어쓰지 않는다.
      if (state.phase == UploadPhase.picking) state = const UploadState();
      return null;
    }

    if (!isVideo) {
      if (result.files.single.path == null) return null;
      final path = result.files.single.path!;
      final fileName = result.files.single.name;
      final ext = fileName.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        state = state.copyWith(phase: UploadPhase.error, errorMessage: '음성(mp3·m4a·wav) 파일이 아니에요. 다시 선택해주세요.');
        return null;
      }
      return _registerAndSave(
          localPath: path, fileName: fileName, sourceType: MediaSourceType.audio, subtitlePath: null);
    }

    // ── 영상: 여러 개(영상+자막) 선택됐을 수 있으니 확장자로 구분해 매칭한다.
    final videoFile = _firstWithExtension(result.files, AppConstants.supportedVideoExtensions);
    final subtitleFile = _firstWithExtension(result.files, AppConstants.supportedSubtitleExtensions);
    if (videoFile?.path == null) {
      state = state.copyWith(phase: UploadPhase.error, errorMessage: '영상(mp4·mov) 파일이 아니에요. 다시 선택해주세요.');
      return null;
    }

    final path = videoFile!.path!;
    final fileName = videoFile.name;

    if (subtitleFile?.path != null) {
      // 영상+자막을 한 번에 골랐다 — "자막 있나요?" 질문을 건너뛰고 곧장 언어 확인/등록으로.
      return _detectLanguageThenRegister(
        localPath: path,
        fileName: fileName,
        sourceType: MediaSourceType.video,
        subtitlePath: subtitleFile!.path!,
      );
    }

    state = UploadState(
      phase: UploadPhase.awaitingSubtitleDecision,
      fileName: fileName,
      pendingLocalPath: path,
      pendingSourceType: MediaSourceType.video,
    );
    return null;
  }

  PlatformFile? _firstWithExtension(List<PlatformFile> files, List<String> extensions) {
    for (final f in files) {
      if (extensions.contains(f.name.split('.').last.toLowerCase())) return f;
    }
    return null;
  }

  /// 자막 파일(SRT/VTT/SMI)을 골라 함께 등록한다 — 자막이 있으면 문장분리가 자막 파싱
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
    return _detectLanguageThenRegister(
      localPath: path,
      fileName: fileName,
      sourceType: sourceType,
      subtitlePath: result.files.single.path!,
    );
  }

  /// **2026-08-22 추가**: 자막 파일이 정해지고 나면(수동 선택이든, 영상과 함께 자동
  /// 매칭됐든) 곧장 등록하지 않고 먼저 내용을 훑어 여러 언어 트랙이 있는지 본다.
  /// 트랙이 2개 이상이면 [UploadPhase.awaitingLanguageDecision]으로 전환해 사용자가
  /// 직접 고르게 하고(화면이 [chooseLanguageAndRegister]를 호출), 트랙이 1개
  /// 이하면(SRT/VTT이거나 단일 언어 SMI) 예전처럼 바로 등록한다.
  Future<String?> _detectLanguageThenRegister({
    required String localPath,
    required String fileName,
    required MediaSourceType sourceType,
    required String subtitlePath,
  }) async {
    List<SamiLanguageTrack> tracks = const [];
    try {
      final content = await readSubtitleFileAsText(subtitlePath);
      tracks = detectSamiLanguageTracks(content);
    } catch (_) {
      // 여기서 못 읽거나 형식이 이상해도 실제 파싱 실패 처리는 분석 단계
      // (fake_segmentation_repository.dart의 watchJobStatus)에 맡긴다 — 여기서는
      // "언어가 여러 개인지"만 훑어보는 것뿐이라 실패해도 조용히 단일 트랙 취급한다.
    }

    if (tracks.length <= 1) {
      return _registerAndSave(
        localPath: localPath,
        fileName: fileName,
        sourceType: sourceType,
        subtitlePath: subtitlePath,
      );
    }

    state = UploadState(
      phase: UploadPhase.awaitingLanguageDecision,
      fileName: fileName,
      pendingLocalPath: localPath,
      pendingSourceType: sourceType,
      pendingSubtitlePath: subtitlePath,
      detectedLanguageTracks: tracks,
    );
    return null;
  }

  /// 언어 선택 화면에서 사용자가 트랙을 고르면 호출 — 그 트랙으로 등록을 마친다.
  ///
  /// **2026-08-22 추가**: 고른 언어(=학습 언어)와 별개로, 같은 파일에 한국어 트랙이
  /// 더 있으면(`findKoreanLanguageClassId`) 자동으로 "한글 뜻"(`translation`) 소스로
  /// 함께 등록한다 — 마이>설정의 "한글 뜻 자동 표시"가 실제로 값을 보여주게 되는 유일한
  /// 경로. 별도 UI로 다시 묻지 않는다("영어 음성엔 영어 자막, 한글 뜻은 같은 파일의
  /// 한국어 트랙에서" — 사용자 요청).
  Future<String?> chooseLanguageAndRegister(String classId) async {
    final localPath = state.pendingLocalPath;
    final subtitlePath = state.pendingSubtitlePath;
    final sourceType = state.pendingSourceType;
    final fileName = state.fileName;
    if (localPath == null || subtitlePath == null || sourceType == null || fileName == null) return null;

    final translationClassId = findKoreanLanguageClassId(state.detectedLanguageTracks, studyClassId: classId);

    return _registerAndSave(
      localPath: localPath,
      fileName: fileName,
      sourceType: sourceType,
      subtitlePath: subtitlePath,
      subtitleLanguageClassId: classId,
      translationLanguageClassId: translationClassId,
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
  Future<FilePickerResult?> _pickFilesOrTimeout({
    required List<String> allowedExtensions,
    bool allowMultiple = false,
    FileType type = FileType.custom,
  }) async {
    try {
      return await FilePicker.pickFiles(
        type: type,
        // file_picker는 type이 custom이 아니면 allowedExtensions를 넘기는 것 자체를
        // assert로 막는다 — FileType.audio 등 내장 카테고리를 쓸 땐 반드시 비워야 한다.
        allowedExtensions: type == FileType.custom ? allowedExtensions : null,
        allowMultiple: allowMultiple,
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
    String? subtitleLanguageClassId,
    String? translationLanguageClassId,
  }) async {
    state = UploadState(phase: UploadPhase.uploading, fileName: fileName, progress: 0);
    debugPrint('[_registerAndSave] start localPath=$localPath fileName=$fileName');

    try {
      final mediaId = await ref.read(segmentationRepositoryProvider).registerLocalMedia(
            localFilePath: localPath,
            fileName: fileName,
            subtitleFilePath: subtitlePath,
            subtitleLanguageClassId: subtitleLanguageClassId,
            translationLanguageClassId: translationLanguageClassId,
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

      // 2026-08-09: 표지(앨범 아트) 추출은 화면 전환을 막지 않는다 — 대부분의 파일에는
      // 표지가 없고, 있어도 홈 카드를 예쁘게 꾸며주는 부가 정보일 뿐이라 실패하거나
      // 느려도 업로드 흐름에 영향을 주면 안 된다. 끝나면 저장된 MediaItem을 갱신해
      // 홈 목록이 반응형으로 갱신되게 한다.
      if (sourceType == MediaSourceType.audio) {
        unawaited(_extractCoverArtInBackground(mediaId: mediaId, localPath: localPath));
      }

      return mediaId;
    } catch (e, st) {
      // 로컬 파일 접근 실패(권한/손상 파일 등) — 네트워크 개념이 없으니 "네트워크를
      // 확인해주세요" 같은 문구는 더 이상 맞지 않는다.
      debugPrint('[_registerAndSave] FAILED: $e\n$st');
      state = state.copyWith(phase: UploadPhase.error, errorMessage: '파일을 불러오지 못했어요. 다시 선택해주세요.');
      return null;
    }
  }

  Future<void> _extractCoverArtInBackground({required String mediaId, required String localPath}) async {
    final coverPath = await ref
        .read(coverArtExtractorProvider)
        .extractAndCache(mediaId: mediaId, localFilePath: localPath);
    if (coverPath == null) return;
    final repo = ref.read(mediaRepositoryProvider);
    final item = await repo.getById(mediaId);
    if (item == null) return; // 그 사이 삭제됐을 수 있음
    await repo.save(item.copyWith(coverArtPath: coverPath));
  }

  void reset() => state = const UploadState();
}
