import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/error_message.dart';

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
  Future<void> register(
      String loginId, String username, String password, String email) async {
    try {
      final response = await ApiService.dio.post('/auth/register', data: {
        'loginId': loginId,
        'username': username,
        'password': password,
        'email': email,
      });
      await _saveSessionData(response.data);
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '회원가입 중 오류가 발생했습니다');
    }
  }

  // 아이디 중복 확인 (true = 사용 가능)
  Future<bool> isLoginIdAvailable(String loginId) async {
    final response = await ApiService.dio
        .get('/auth/check-id', queryParameters: {'loginId': loginId});
    return response.data['available'] == true;
  }

  // 이메일 중복 확인 (true = 사용 가능)
  Future<bool> isEmailAvailable(String email) async {
    final response = await ApiService.dio
        .get('/auth/check-email', queryParameters: {'email': email});
    return response.data['available'] == true;
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

  // ── 아이디/비밀번호 찾기 (이메일 인증코드) ──

  Future<void> _postAuth(String path, Map<String, dynamic> data,
      {required String fallback}) async {
    try {
      await ApiService.dio.post(path, data: data);
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: fallback);
    }
  }

  // 아이디 찾기: 가입 이메일로 인증코드 발송
  Future<void> sendFindIdCode(String email) => _postAuth(
      '/auth/find-id/send-code', {'email': email},
      fallback: '인증코드를 보내지 못했어요');

  // 아이디 찾기: 코드 확인 후 아이디 반환
  Future<String> findLoginId(String email, String code) async {
    try {
      final response = await ApiService.dio
          .post('/auth/find-id', data: {'email': email, 'code': code});
      return response.data['loginId'] as String;
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '아이디를 찾지 못했어요');
    }
  }

  // 비밀번호 재설정: 아이디+이메일 확인 후 인증코드 발송
  Future<void> sendResetCode(String loginId, String email) => _postAuth(
      '/auth/reset-password/send-code', {'loginId': loginId, 'email': email},
      fallback: '인증코드를 보내지 못했어요');

  // 비밀번호 재설정: 코드 확인
  Future<void> verifyResetCode(String loginId, String email, String code) =>
      _postAuth('/auth/reset-password/verify',
          {'loginId': loginId, 'email': email, 'code': code},
          fallback: '인증코드를 확인하지 못했어요');

  // 비밀번호 재설정: 새 비밀번호 저장
  Future<void> resetPassword(
          String loginId, String email, String code, String newPassword) =>
      _postAuth('/auth/reset-password', {
        'loginId': loginId,
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }, fallback: '비밀번호를 변경하지 못했어요');

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

  // 알레르기 저장 (DB 연동)
  Future<void> saveAllergies(String allergies) async {
    try {
      await ApiService.dio
          .post('/users/$_userId/allergies', data: {'allergies': allergies});
      _allergies = allergies;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('allergies', allergies);
      notifyListeners();
    } on DioException catch (e) {
      throw _parseDioException(e, fallback: '알레르기 저장 중 오류가 발생했습니다');
    }
  }

  // 알레르기 불러오기 (DB 연동)
  Future<void> loadAllergies() async {
    try {
      final response = await ApiService.dio.get('/users/$_userId/allergies');
      _allergies = response.data['allergies'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (_allergies != null) await prefs.setString('allergies', _allergies!);
      notifyListeners();
    } on DioException catch (e) {
      // 서버 오류 시 로컬 캐시 사용
      final prefs = await SharedPreferences.getInstance();
      _allergies = prefs.getString('allergies');
      notifyListeners();
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
    return Exception(friendlyErrorMessage(e, fallback: fallback));
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
      // 서버에서 최신 알레르기 정보 동기화
      await loadAllergies();
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
