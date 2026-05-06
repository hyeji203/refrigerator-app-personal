import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  int? _userId;
  String? _loginId;
  String? _username;
  bool _isLoggedIn = false;

  int? get userId => _userId;
  String? get loginId => _loginId;
  String? get username => _username;
  bool get isLoggedIn => _isLoggedIn;

  // 회원가입 - 실패 시 예외를 던짐
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

  // 로그인 - 실패 시 예외를 던짐
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

  // 로그인/회원가입 성공 후 세션 데이터를 메모리와 SharedPreferences에 저장
  Future<void> _saveSessionData(Map<String, dynamic> data) async {
    _userId = data['userId'];
    _loginId = data['loginId'];
    _username = data['username'];
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setInt('userId', _userId!);
    await prefs.setString('loginId', _loginId!);
    await prefs.setString('username', _username!);

    ApiService.setAuthToken(data['token']);
    notifyListeners();
  }

  // DioException을 사람이 읽을 수 있는 Exception으로 변환
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
      // base64url 패딩 보정
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

  // 자동 로그인 (앱 시작 시)
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && !_isTokenExpired(token)) {
      _userId = prefs.getInt('userId');
      _loginId = prefs.getString('loginId');
      _username = prefs.getString('username');
      _isLoggedIn = true;
      ApiService.setAuthToken(token);
      notifyListeners();
    } else if (token != null) {
      // 만료된 토큰 제거
      await prefs.clear();
    }
  }

  // 로그아웃
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.clearAuthToken();
    _userId = null;
    _loginId = null;
    _username = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
