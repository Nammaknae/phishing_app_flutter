import 'package:flutter/material.dart';

final appState = AppState();

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String _userName = '홍길동';
  double _fontSize = 1.0;
  bool _smishingAlert = true;
  bool _cautionAlert = false;

  bool _isLoggedIn = false;
  int _guestScanCount = 0;
  final int _maxGuestScanCount = 3;

  bool get isDarkMode => _isDarkMode;
  String get userName => _userName;
  double get fontSize => _fontSize;
  bool get smishingAlert => _smishingAlert;
  bool get cautionAlert => _cautionAlert;

  bool get isLoggedIn => _isLoggedIn;
  int get guestScanCount => _guestScanCount;
  int get maxGuestScanCount => _maxGuestScanCount;
  bool get canUseGuestScan => _guestScanCount < _maxGuestScanCount;
  int get remainingScanCount => _maxGuestScanCount - _guestScanCount;

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

  void login() {
    _isLoggedIn = true;
    _guestScanCount = 0;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
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
}
