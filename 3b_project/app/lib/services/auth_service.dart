import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  int? _userId;
  String? _loginId;
  String? _username;
  String? _email;
  String? _phone;
  String? _allergies;
  bool _isLoggedIn = false;

  int? get userId => _userId;
  String? get loginId => _loginId;
  String? get username => _username;
  String? get email => _email;
  String? get phone => _phone;
  String? get allergies => _allergies;
  bool get isLoggedIn => _isLoggedIn;

  // 회원가입
  Future<void> register(String loginId, String username, String password,
      String email, String phone) async {
    try {
      final response = await ApiService.dio.post('/auth/register', data: {
        'loginId': loginId,
        'username': username,
        'password': password,
        'email': email,
        'phone': phone,
      });
      await _saveSessionData(response.data);
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '회원가입 중 오류가 발생했습니다');
    }
  }

  // 로그인
  Future<void> login(String loginId, String password) async {
    try {
      final response = await ApiService.dio.post('/auth/login', data: {
        'loginId': loginId,
        'password': password,
      });
      await _saveSessionData(response.data);
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '로그인 중 오류가 발생했습니다');
    }
  }

  // 세션 데이터 저장
  Future<void> _saveSessionData(Map<String, dynamic> data) async {
    _userId = data['userId'];
    _loginId = data['loginId'];
    _username = data['username'];
    _email = data['email'];
    _phone = data['phone'];
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setInt('userId', _userId!);
    await prefs.setString('loginId', _loginId!);
    await prefs.setString('username', _username!);
    if (_email != null) await prefs.setString('email', _email!);
    if (_phone != null) await prefs.setString('phone', _phone!);

    ApiService.setAuthToken(data['token']);
    notifyListeners();
  }

  // 프로필 수정 (서버 연동)
  Future<void> updateProfile({
    String? username,
    String? email,
    String? phone,
    String? password,
  }) async {
    try {
      final response = await ApiService.dio.patch('/users/$_userId', data: {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      await _saveSessionData(response.data);
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '프로필 수정 중 오류가 발생했습니다');
    }
  }

  // 알레르기 저장
  Future<void> saveAllergies(String allergies) async {
    try {
      _allergies = allergies;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('allergies', allergies);
      notifyListeners();
    } catch (e) {
      throw Exception('알레르기 저장 중 오류가 발생했습니다');
    }
  }

  // 알레르기 불러오기
  Future<void> loadAllergies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allergies = prefs.getString('allergies');
      notifyListeners();
    } catch (e) {
      throw Exception('알레르기 불러오기 중 오류가 발생했습니다');
    }
  }

  // 백엔드 없이 테스트용 로그인
  Future<void> devLogin() async {
    _userId = 1;
    _loginId = 'test';
    _username = '테스트유저';
    _email = 'test@test.com';
    _phone = '010-0000-0000';
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', _userId!);
    await prefs.setString('loginId', _loginId!);
    await prefs.setString('username', _username!);

    notifyListeners();
  }

  // DioException 처리
  Exception _parseDioException(DioException e, {required String fallback}) {
    final msg = e.response?.data?['message'];
    if (msg != null) return Exception(msg);
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return Exception('서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인해주세요.');
    }
    return Exception('$fallback: ${e.message}');
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          .isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  // 자동 로그인
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && !_isTokenExpired(token)) {
      _userId = prefs.getInt('userId');
      _loginId = prefs.getString('loginId');
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _phone = prefs.getString('phone');
      _allergies = prefs.getString('allergies');
      _isLoggedIn = true;
      ApiService.setAuthToken(token);
      notifyListeners();
    } else if (token != null) {
      await _clearAuthPrefs();
    }
  }

  Future<void> _clearAuthPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('loginId');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('phone');
    await prefs.remove('allergies');
  }

  // 로그아웃
  Future<void> logout() async {
    await _clearAuthPrefs();
    ApiService.clearAuthToken();
    _userId = null;
    _loginId = null;
    _username = null;
    _email = null;
    _phone = null;
    _allergies = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
