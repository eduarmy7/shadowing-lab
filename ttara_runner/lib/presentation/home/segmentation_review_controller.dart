import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/sentence_segment.dart';
import '../common_widgets/boundary_handle.dart';
import '../providers/repository_providers.dart';

class SegmentationReviewState {
  final List<SentenceSegment> segments;
  final bool isLoading;
  final String? error;

  const SegmentationReviewState({
    this.segments = const [],
    this.isLoading = true,
    this.error,
  });

  SegmentationReviewState copyWith({
    List<SentenceSegment>? segments,
    bool? isLoading,
    String? error,
  }) {
    return SegmentationReviewState(
      segments: segments ?? this.segments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final segmentationReviewProvider = StateNotifierProvider.autoDispose
    .family<SegmentationReviewController, SegmentationReviewState, String>(
  (ref, mediaId) => SegmentationReviewController(ref, mediaId),
);

/// [SentenceEditScreen] 뷰모델 — 앱의 핵심 차별화 지점. 자동 분리(자막 파싱 또는
/// 무음 감지) 결과를 그대로 받아들이거나(대부분의 경우) 필요한 문장만 그때그때
/// 미세조정할 수 있게 한다(Progressive Disclosure: 편집 기능은 필요할 때만 노출).
/// 2026-08-06: 예전엔 학습 시작 전 전체 문장을 한 화면에서 확인/확정하는 별도
/// 게이트 화면이 있었지만(문장이 수천 개인 콘텐츠에서는 애초에 불가능한 요구라
/// 폐기), 지금은 이 뷰모델이 #5 학습 화면에서 열리는 [SentenceEditScreen] 전용이다.
///
/// 경계 드래그의 px→ms 변환은 [SentenceEditScreen]의 `_EditWaveform`이 실제 트랙
/// RenderBox 폭 기준으로 계산해서 [adjustBoundary]에 ms 단위로 그대로 넘겨준다 —
/// 이 컨트롤러는 px를 전혀 모른다.
class SegmentationReviewController extends StateNotifier<SegmentationReviewState> {
  final Ref ref;
  final String mediaId;
  static const _snapThresholdMs = 150;

  SegmentationReviewController(this.ref, this.mediaId) : super(const SegmentationReviewState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final segments = await ref.read(segmentationRepositoryProvider).getSegments(mediaId);
      state = state.copyWith(segments: segments, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '문장을 불러오지 못했어요');
    }
  }

  /// 병합/분리/초기화처럼 그 자체로 "확정된 액션"(버튼 한 번 = 되돌릴 의도 없는
  /// 액션)은 즉시 로컬에 저장한다 — 저장을 미루면 그 전에 화면을 나갈 때 편집 내용이
  /// 통째로 사라지기 때문이다.
  ///
  /// **경계 드래그/스테퍼 조정은 여기 해당하지 않는다** — 사용자가 길이를 여러 번
  /// 만지작거리다 마음에 들 때 직접 "저장" 버튼을 눌러야 저장되도록 했다(자동저장은
  /// 오히려 "덜 확정된" 상태를 계속 덮어써서 혼란스럽다는 피드백). [commitBoundaryEdit]이
  /// 그 "저장" 버튼이 호출하는 대상이다.
  Future<void> _persist() async {
    try {
      await ref.read(segmentationRepositoryProvider).saveEditedSegments(mediaId, state.segments);
    } catch (_) {
      // 자동 저장 실패는 조용히 무시 — 사용자가 "저장" 버튼을 다시 누르면 재시도된다.
    }
  }

  /// 화면의 명시적 "저장" 버튼이 호출한다 — 경계 드래그/스테퍼로 조정한 길이는
  /// 자동저장되지 않으므로, 사용자가 조정을 다 마친 뒤 이 메서드를 통해서만 저장된다.
  /// Future를 반환해 화면이 저장 완료 후 토스트를 보여줄 수 있게 한다.
  Future<void> commitBoundaryEdit() => _persist();

  /// **2026-08-07 버그 수정**: 무음구간 자동 스냅을 예전엔 이 메서드(매 드래그
  /// *프레임*마다 호출됨) 안에서 즉시 적용했다 — 그런데 사람 손가락의 한 프레임
  /// 이동량은 보통 2~19ms 정도로 스냅 기준(150ms)보다 항상 작다. 그러니 핸들이 이미
  /// 이웃 문장 경계에 붙어있는 상태(예: 두 문장 사이 간격이 원래 0인 경우)에서는,
  /// 아무리 계속 드래그해도 매 프레임 끝에서 "150ms 이내면 다시 붙인다" 규칙에 걸려
  /// 즉시 원위치로 튕겨 돌아갔다 — 사실상 절대 빠져나올 수 없는 함정이었다(우연히
  /// 한 프레임 안에서 150ms 넘는 큰 델타가 들어온 경우에만 빠져나올 수 있었는데,
  /// 이건 사람 드래그로는 거의 안 생긴다). 로그로 실측 확인: 같은 위치(startMs
  /// 그대로)가 수백 번 연속 찍혔다. 표준적인 "자석 스냅" UX처럼, 스냅은 드래그
  /// *도중*이 아니라 손을 뗄 때([finalizeBoundaryDrag])만 적용하도록 옮겼다 — 이제
  /// 드래그하는 동안은 스냅 없이 자유롭게 움직이고, 놓았을 때 근처면 붙는다.
  void adjustBoundary(String segmentId, HandleSide side, int deltaMs) {
    final list = [...state.segments];
    final idx = list.indexWhere((s) => s.id == segmentId);
    if (idx < 0) return;
    var seg = list[idx];

    if (side == HandleSide.left) {
      final lowerBound = idx > 0 ? list[idx - 1].endMs : 0;
      final newStart = (seg.startMs + deltaMs).clamp(lowerBound, seg.endMs - 300);
      seg = seg.copyWith(startMs: newStart, edited: true);
    } else {
      final upperBound = idx < list.length - 1 ? list[idx + 1].endMs : seg.endMs + 60000;
      final newEnd = (seg.endMs + deltaMs).clamp(seg.startMs + 300, upperBound);
      seg = seg.copyWith(endMs: newEnd, edited: true);
    }
    list[idx] = seg;
    state = state.copyWith(segments: list);
  }

  /// 드래그를 놓았을 때 호출 — 이웃 문장과의 간격이 [_snapThresholdMs] 이내면 그
  /// 경계에 딱 붙인다("무음구간 자동 스냅"). [adjustBoundary] 도중에는 더 이상 이
  /// 스냅을 적용하지 않는다(위 클래스독 참고).
  void finalizeBoundaryDrag(String segmentId, HandleSide side) {
    final list = [...state.segments];
    final idx = list.indexWhere((s) => s.id == segmentId);
    if (idx < 0) return;
    var seg = list[idx];

    if (side == HandleSide.left && idx > 0) {
      final prevEnd = list[idx - 1].endMs;
      if ((seg.startMs - prevEnd).abs() < _snapThresholdMs && seg.startMs != prevEnd) {
        seg = seg.copyWith(startMs: prevEnd, edited: true);
        list[idx] = seg;
        state = state.copyWith(segments: list);
      }
    } else if (side == HandleSide.right && idx < list.length - 1) {
      final nextStart = list[idx + 1].startMs;
      if ((seg.endMs - nextStart).abs() < _snapThresholdMs && seg.endMs != nextStart) {
        seg = seg.copyWith(endMs: nextStart, edited: true);
        list[idx] = seg;
        state = state.copyWith(segments: list);
      }
    }
  }

  /// 접근성 대체 경로: 핸들 선택 후 +0.1초/-0.1초 스테퍼.
  /// 2026-08-06: 드래그와 마찬가지로 자동 저장하지 않는다 — 사용자가 길이 조정을
  /// 몇 번이고 반복한 뒤 화면의 "저장" 버튼을 눌러야 실제로 저장된다([commitBoundaryEdit]).
  void nudgeBoundary(String segmentId, HandleSide side, {required bool increase}) {
    adjustBoundary(segmentId, side, increase ? 100 : -100);
    // 스테퍼는 드래그와 달리 탭 1번=독립된 확정 동작이라("계속 반복 호출되며 매번
    // 튕겨나가는" 함정이 없다) 매번 스냅을 적용해도 안전하다.
    finalizeBoundaryDrag(segmentId, side);
  }

  void mergeWithNext(String segmentId) {
    final list = [...state.segments];
    final idx = list.indexWhere((s) => s.id == segmentId);
    if (idx < 0 || idx >= list.length - 1) return;
    final a = list[idx];
    final b = list[idx + 1];
    // 텍스트가 아예 없는 구간(무음 감지 결과)끼리 병합하면 병합 결과도 텍스트 없이
    // 유지한다 — 없는 텍스트를 지어내지 않는다.
    final mergedText = (a.text == null && b.text == null) ? null : '${a.text ?? ''} ${b.text ?? ''}'.trim();
    // 2026-08-07: split과 같은 이유로 새 id를 준다 — 병합도 두 문장을 하나의 새
    // 문장으로 합치는 구조적 변화라, id가 그대로면 편집 화면의 파형 표시 시간창이
    // 안 넓어져서(여전히 a만큼의 좁은 창) "병합이 안 된 것처럼" 보인다.
    // 2026-08-10: 완료 표시(초록 체크)는 두 문장 다 완료했을 때만 병합 결과도 완료로
    // 본다 — `a.copyWith`가 기본으로 a의 completed만 물려받으면, "완료된 문장 + 아직
    // 안 한 문장"을 합쳤을 때 실제로는 절반만 학습한 병합 문장이 완료로 표시된다.
    final merged = a.copyWith(
      id: '${a.id}-merged-${DateTime.now().millisecondsSinceEpoch}',
      text: mergedText,
      clearText: mergedText == null,
      endMs: b.endMs,
      edited: true,
      completed: a.completed && b.completed,
    );
    list[idx] = merged;
    list.removeAt(idx + 1);
    state = state.copyWith(segments: _reindex(list));
    _persist();
  }

  /// 2026-08-06: 반으로 무조건 나누던 방식에서, 사용자가 파형 위에서 직접 드래그로
  /// 고른 지점([splitMs], 절대 ms)에서 나누는 방식으로 바꿨다(`SentenceEditScreen`의
  /// 분리 마커) — 문장 길이가 균등하지 않은 경우가 훨씬 많아서다.
  /// 자막모드(텍스트 있음)는 나눠진 시간 비율만큼 단어 수를 나눠 각 반쪽에 배분한다
  /// (정확한 워드 타이밍이 없으니 근사치 — 완벽히 맞지 않으면 사용자가 텍스트를 직접
  /// 수정할 수 있는 건 아니지만, 적어도 "앞부분이 더 길면 단어도 더 많이" 정도는 맞춘다).
  /// 성공하면 true, 분리할 수 없는 상황(너무 짧은 문장/단어가 1개뿐)이면 false를
  /// 반환한다 — 호출측(`SentenceEditScreen`)이 결과에 맞는 토스트를 보여줄 수 있게.
  ///
  /// **2026-08-07 버그 수정**: `splitMs.clamp(seg.startMs + 100, seg.endMs - 100)`가
  /// 문장 길이가 200ms 이하면(무음 감지로 나뉜 아주 짧은 문장에서 실제로 나올 수 있음)
  /// 하한이 상한보다 커져 Dart `num.clamp`가 `ArgumentError`를 던졌다 — 이 메서드는
  /// `void`였고 호출부(`_confirmSplit`)도 try/catch가 없어서, 사용자 입장에서는 "분리"
  /// 버튼을 눌러도 토스트도 안 뜨고 목록도 안 바뀌는 "아무 반응 없음"으로만 보였다
  /// (예외 자체는 unhandled Future error로 흘렀을 텐데, 마침 그 타이밍에 로그 캡처가
  /// 끊겨있어 직접 확인은 못 했다 — 코드 리뷰로 찾은 실제 크래시 경로).
  bool splitSegmentAt(String segmentId, int splitMs) {
    final list = [...state.segments];
    final idx = list.indexWhere((s) => s.id == segmentId);
    if (idx < 0) {
      debugPrint('[splitSegmentAt] FAILED: segmentId=$segmentId not found in ${list.length} segments');
      return false;
    }
    final seg = list[idx];

    // 문장이 200ms보다 짧으면 양쪽 최소 100ms를 보장하는 여백을 둘 수 없다 — 이럴 땐
    // 그냥 정확히 중간 지점에서 나눈다(중간은 항상 startMs~endMs 안에 있어 안전).
    final lower = seg.startMs + 100;
    final upper = seg.endMs - 100;
    final clampedSplitMs = lower < upper ? splitMs.clamp(lower, upper) : (seg.startMs + seg.endMs) ~/ 2;
    debugPrint('[splitSegmentAt] idx=$idx seg.startMs=${seg.startMs} seg.endMs=${seg.endMs} '
        'text=${seg.text} splitMs=$splitMs clampedSplitMs=$clampedSplitMs');

    SentenceSegment first;
    SentenceSegment second;
    // 2026-08-07 버그 수정: 분리된 앞쪽 절반이 원본과 같은 id를 그대로 유지했다 —
    // `SentenceEditScreen`의 `_EditWaveform`은 (드래그 중 트랙이 계속 다시 가운데
    // 정렬되며 튀는 걸 막으려고) segment.id가 바뀔 때만 파형 표시 시간창을 다시
    // 계산하는데, id가 그대로면 분리가 실제로는 성공했어도(startMs/endMs는 바뀜)
    // 화면에는 분리 전과 똑같은 넓은 시간창이 그대로 남아있어 "분리가 안 된 것처럼"
    // 보였다(사용자가 직접 짚어낸 원인). 분리는 드래그처럼 같은 문장을 다듬는 게
    // 아니라 하나를 진짜 둘로 쪼개는 구조적 변화이므로, 양쪽 다 새 id를 받는 게
    // 맞다 — 이러면 위 화면의 id 기반 감지가 정상적으로 걸린다.
    final splitTag = DateTime.now().millisecondsSinceEpoch;

    if (seg.text == null) {
      first = seg.copyWith(id: '${seg.id}-split-$splitTag-a', endMs: clampedSplitMs, edited: true);
      second = seg.copyWith(
        id: '${seg.id}-split-$splitTag-b',
        startMs: clampedSplitMs,
        edited: true,
      );
    } else {
      final words = seg.text!.trim().split(RegExp(r'\s+'));
      if (words.length < 2) {
        debugPrint('[splitSegmentAt] FAILED: only ${words.length} word(s), cannot split text');
        return false; // 단어가 1개면 분리 불가
      }

      final ratio = (clampedSplitMs - seg.startMs) / seg.durationMs;
      final mid = (words.length * ratio).round().clamp(1, words.length - 1);
      final firstText = words.sublist(0, mid).join(' ');
      final secondText = words.sublist(mid).join(' ');

      first = seg.copyWith(
          id: '${seg.id}-split-$splitTag-a', text: firstText, endMs: clampedSplitMs, edited: true);
      second = seg.copyWith(
        id: '${seg.id}-split-$splitTag-b',
        text: secondText,
        startMs: clampedSplitMs,
        edited: true,
      );
    }

    list.replaceRange(idx, idx + 1, [first, second]);
    state = state.copyWith(segments: _reindex(list));
    debugPrint('[splitSegmentAt] SUCCESS: first=[${first.startMs}-${first.endMs}] '
        'second=[${second.startMs}-${second.endMs}] total segments now ${list.length}');
    _persist();
    return true;
  }

  List<SentenceSegment> _reindex(List<SentenceSegment> list) => [
        for (var i = 0; i < list.length; i++) list[i].copyWith(index: i),
      ];
}
