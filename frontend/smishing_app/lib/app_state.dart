import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/user_profile.dart';
import 'services/auth_api_service.dart';
import 'services/token_storage.dart';

final appState = AppState();

// SharedPreferences 키 상수
const _kGuestScanCount = 'guest_scan_count';
const _kHasAgreedPermission = 'has_agreed_permission';
const _kSmishingAlert = 'smishing_alert';
const _kCautionAlert = 'caution_alert';

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

  bool _hasAgreedPermission = false;

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

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    _guestScanCount = prefs.getInt(_kGuestScanCount) ?? 0;
    _hasAgreedPermission = prefs.getBool(_kHasAgreedPermission) ?? false;
    _smishingAlert = prefs.getBool(_kSmishingAlert) ?? true;
    _cautionAlert = prefs.getBool(_kCautionAlert) ?? false;
    notifyListeners();
  }

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

  void toggleSmishingAlert() async {
    _smishingAlert = !_smishingAlert;
    if (!_smishingAlert) {
      _cautionAlert = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSmishingAlert, _smishingAlert);
    await prefs.setBool(_kCautionAlert, _cautionAlert);
    notifyListeners();
  }

  void toggleCautionAlert() async {
    _cautionAlert = !_cautionAlert;
    if (_cautionAlert) {
      _smishingAlert = true;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSmishingAlert, _smishingAlert);
    await prefs.setBool(_kCautionAlert, _cautionAlert);
    notifyListeners();
  }

  Future<void> updateUserName(String name) async {
    final profile = await AuthApiService.updateMe(name: name);
    _applyUserProfile(profile, displayName: profile.name ?? name);
    notifyListeners();
  }

  void _applyUserProfile(UserProfile profile, {String? displayName}) {
    _userId = profile.id;
    _userEmail = profile.email ?? '';
    _userName = displayName ?? profile.name ?? _emailToDisplayName(_userEmail);
    _isLoggedIn = true;
    _guestScanCount = 0;
  }

  String _emailToDisplayName(String email) {
    if (email.isEmpty) return '사용자';
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return email.substring(0, at);
  }

  Future<bool> restoreSession() async {
    _isAuthLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.readAccessToken();
      if (token == null || token.isEmpty) return false;

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

  void increaseGuestScan() async {
    if (!_isLoggedIn && _guestScanCount < _maxGuestScanCount) {
      _guestScanCount++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kGuestScanCount, _guestScanCount);
      notifyListeners();
    }
  }

  void resetGuestScan() async {
    _guestScanCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGuestScanCount, 0);
    notifyListeners();
  }

  void agreePermission() async {
    _hasAgreedPermission = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasAgreedPermission, true);
    notifyListeners();
  }

  void resetPermission() async {
    _hasAgreedPermission = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasAgreedPermission, false);
    notifyListeners();
  }
}
