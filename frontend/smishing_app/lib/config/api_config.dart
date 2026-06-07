/// API 서버 베이스 URL 설정.
///
/// **기본값 = NAS 프로덕션 서버** (`https://api.maknae.synology.me`)
/// `--dart-define` 없이 빌드/실행하면 항상 NAS를 사용합니다.
///
/// 로컬 PC 백엔드 테스트가 필요할 때만 아래처럼 덮어씁니다.
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000        # 에뮬레이터
/// flutter run --dart-define=API_BASE_URL=http://<PC_사설IP>:4000    # 실제 폰
/// ```
class ApiConfig {
  /// NAS 백엔드 — 앱 기본 연결 대상
  static const String productionBaseUrl = 'https://api.maknae.synology.me';

  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );

  /// trailing slash 제거된 베이스 URL
  static String get baseUrl {
    final trimmed = _rawBaseUrl.trim();
    if (trimmed.isEmpty) return productionBaseUrl;
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
