import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences를 감싼 경량 로컬 저장소. 스캐폴드 단계의 모든 Local*Repository
/// 구현체가 이 클래스를 통해 JSON을 읽고 쓴다.
///
/// 프로덕션 전환 시 Drift(SQLite)/Isar로 교체 권장 — 특히 문장 세그먼트처럼
/// 레코드 수가 많고 쿼리(정렬/필터)가 필요한 데이터는 관계형/NoSQL DB가 유리하다.
/// Repository 인터페이스가 이미 계층을 분리해두었으므로, 이 클래스와
/// data/repositories/local_*.dart 구현체만 교체하면 상위 레이어(domain/presentation)는
/// 변경할 필요가 없다 (02_app_architecture.md 참고).
class LocalKvStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> setJson(String key, Object value) async {
    final prefs = await _instance;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<T?> getJson<T>(String key, T Function(dynamic decoded) decoder) async {
    final prefs = await _instance;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return decoder(jsonDecode(raw));
    } catch (_) {
      // 파싱 실패 시 기본값 사용 + 로깅 (에러 처리 전략: 데이터 파싱 오류 대응).
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _instance;
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await _instance;
    await prefs.clear();
  }
}
