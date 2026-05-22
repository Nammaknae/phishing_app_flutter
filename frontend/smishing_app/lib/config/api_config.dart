/// API 서버 베이스 URL.
/// - 로컬 백엔드(에뮬레이터): `http://10.0.2.2:4000`
/// - 실제 기기 + PC 로컬: `http://<PC_IP>:4000`
/// - 배포 서버: 아래 기본값
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.maknae.synology.me',
  );
}
