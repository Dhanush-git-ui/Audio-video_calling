import 'package:flutter/material.dart';

class UserSessionProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool _isLoggedIn = false;
  String _userName = '';
  String _userRole = 'Patient'; // 'Doctor' or 'Patient' or 'Guest'

  bool get isOnline => _isOnline;
  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userRole => _userRole;

  void login(String name, String role) {
    _isLoggedIn = true;
    _isOnline = true;
    _userName = name;
    _userRole = role;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _isOnline = false;
    _userName = '';
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }
}
