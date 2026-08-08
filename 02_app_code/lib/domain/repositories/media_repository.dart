import 'dart:async';

import '../entities/media_item.dart';

/// 홈 탭(#1) "내 파일" 목록의 로컬 CRUD. 순수 로컬 데이터이므로(01_ux_design.md
/// #1 화면 상태 처리: "Error 해당없음, 로컬 저장이라 거의 발생 안함") 기본 구현은
/// [LocalMediaRepository](data/repositories/local_media_repository.dart)면 충분하다.
/// 클라우드 동기화(로그인 사용자 대상)는 후순위 — 필요 시 이 인터페이스를 그대로 유지한 채
/// 원격 백업 구현체로 교체 가능하도록 추상화해둔다.
abstract class MediaRepository {
  Future<List<MediaItem>> getAll();
  Future<MediaItem?> getById(String id);
  Future<void> save(MediaItem item);
  Future<void> delete(String id);
  Future<void> rename(String id, String newFileName);

  /// 목록 변경(추가/삭제/진행률 갱신)을 실시간 반영하기 위한 스트림 — 홈 화면이 구독.
  Stream<List<MediaItem>> watchAll();
}
