import '../models/user_profile.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthApiService {
  /// POST /api/auth/login
  static Future<({String accessToken, UserProfile user})> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      withAuth: false,
    );

    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(500, 'Missing accessToken in login response');
    }

    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw ApiException(500, 'Missing user in login response');
    }

    await TokenStorage.saveAccessToken(token);
    return (accessToken: token, user: UserProfile.fromJson(userJson));
  }

  /// POST /api/auth/signup
  static Future<({String accessToken, UserProfile user})> signup({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/api/auth/signup',
      body: {'email': email, 'password': password},
      withAuth: false,
    );

    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(500, 'Missing accessToken in signup response');
    }

    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw ApiException(500, 'Missing user in signup response');
    }

    await TokenStorage.saveAccessToken(token);
    return (accessToken: token, user: UserProfile.fromJson(userJson));
  }

  /// GET /api/users/me
  static Future<UserProfile> getMe() async {
    final data = await ApiClient.get('/api/users/me');
    return UserProfile.fromJson(data);
  }

  /// DELETE /api/users/me
  static Future<void> deleteAccount() async {
    await ApiClient.delete('/api/users/me');
    await TokenStorage.deleteAccessToken();
  }

  static Future<void> clearSession() async {
    await TokenStorage.deleteAccessToken();
  }
}
