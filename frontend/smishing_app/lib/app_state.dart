import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'services/auth_api_service.dart';
import 'services/token_storage.dart';

final appState = AppState();

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String _userName = '게스트';
  String _userEmail = '';
  String? _userId;
  double _fontSize = 1.0;
  bool _smishingAlert = true;
  bool _cautionAlert = false;

  bool _isLoggedIn = false;
  bool _isAuthLoading = false;
  int _guestScanCount = 0;
  final int _maxGuestScanCount = 3;

  bool _hasAgreedPermission = false; // 권한 동의 여부

  bool get isDarkMode => _isDarkMode;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String? get userId => _userId;
  double get fontSize => _fontSize;
  bool get smishingAlert => _smishingAlert;
  bool get cautionAlert => _cautionAlert;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthLoading => _isAuthLoading;
  int get guestScanCount => _guestScanCount;
  int get maxGuestScanCount => _maxGuestScanCount;
  bool get canUseGuestScan => _guestScanCount < _maxGuestScanCount;
  int get remainingScanCount => _maxGuestScanCount - _guestScanCount;

  bool get hasAgreedPermission => _hasAgreedPermission;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  void toggleSmishingAlert() {
    _smishingAlert = !_smishingAlert;
    notifyListeners();
  }

  void toggleCautionAlert() {
    _cautionAlert = !_cautionAlert;
    notifyListeners();
  }

  void _applyUserProfile(UserProfile profile, {String? displayName}) {
    _userId = profile.id;
    _userEmail = profile.email ?? '';
    _userName = displayName ?? _emailToDisplayName(_userEmail);
    _isLoggedIn = true;
    _guestScanCount = 0;
  }

  String _emailToDisplayName(String email) {
    if (email.isEmpty) return '사용자';
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return email.substring(0, at);
  }

  /// 앱 시작 시 저장된 JWT로 세션 복구 (/api/users/me).
  Future<bool> restoreSession() async {
    _isAuthLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.readAccessToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      final profile = await AuthApiService.getMe();
      _applyUserProfile(profile);
      return true;
    } catch (_) {
      await AuthApiService.clearSession();
      _clearUserSession();
      return false;
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  /// 로그인/회원가입 API 성공 후 세션 반영.
  void setAuthenticatedSession(UserProfile profile, {String? displayName}) {
    _applyUserProfile(profile, displayName: displayName);
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthApiService.clearSession();
    _clearUserSession();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_isLoggedIn) {
      await AuthApiService.deleteAccount();
    } else {
      await AuthApiService.clearSession();
    }
    _clearUserSession();
    notifyListeners();
  }

  void _clearUserSession() {
    _isLoggedIn = false;
    _userId = null;
    _userName = '게스트';
    _userEmail = '';
  }

  void increaseGuestScan() {
    if (!_isLoggedIn && _guestScanCount < _maxGuestScanCount) {
      _guestScanCount++;
      notifyListeners();
    }
  }

  void resetGuestScan() {
    _guestScanCount = 0;
    notifyListeners();
  }

  void agreePermission() {
    _hasAgreedPermission = true;
    notifyListeners();
  }

  void resetPermission() {  // 테스트용 - 필요시 사용
    _hasAgreedPermission = false;
    notifyListeners();
  }
}
