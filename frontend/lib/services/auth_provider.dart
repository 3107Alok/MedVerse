import 'package:flutter/material.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    Map<String, dynamic>? extraData,
  }) async {
    _setLoading(true);
    _user = await _authService.signUp(
      email: email,
      password: password,
      name: name,
      role: role,
      extraData: extraData,
    );
    _setLoading(false);
    return _user != null;
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _user = await _authService.signIn(email, password);
    _setLoading(false);
    return _user != null;
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _user = await _authService.signInWithGoogle();
    _setLoading(false);
    return _user != null;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }
}
