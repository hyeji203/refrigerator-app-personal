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

      final data = response.data;
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
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      if (msg != null) throw Exception(msg);
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw Exception('서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인해주세요.');
      }
      throw Exception('네트워크 오류: ${e.message}');
    } catch (e) {
      throw Exception('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  // 로그인 - 실패 시 예외를 던짐
  Future<void> login(String loginId, String password) async {
    try {
      final response = await ApiService.dio.post('/auth/login', data: {
        'loginId': loginId,
        'password': password,
      });

      final data = response.data;
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
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      if (msg != null) throw Exception(msg);
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw Exception('서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인해주세요.');
      }
      throw Exception('네트워크 오류: ${e.message}');
    } catch (e) {
      throw Exception('로그인 중 오류가 발생했습니다: $e');
    }
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
