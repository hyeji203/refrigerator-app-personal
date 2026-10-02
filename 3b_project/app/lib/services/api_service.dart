import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 크롬(웹)은 같은 PC의 서버를 localhost로 접속 → Wi-Fi IP가 바뀌어도 수정 불필요
  // 실제 기기는 PC IP 사용 (Wi-Fi가 바뀌면 ipconfig로 확인해 수정)
  // Android 에뮬레이터: 'http://10.0.2.2:8080/api'
  static const String baseUrl = kIsWeb
      ? 'http://localhost:8080/api'
      : 'http://192.168.123.123:8080/api';

  static final Dio _dio = _createDio(connectTimeout: const Duration(seconds: 30));
  static final Dio _dioLong = _createDio(connectTimeout: const Duration(minutes: 5));

  static Dio _createDio({required Duration connectTimeout}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: const Duration(minutes: 5),
      headers: {'Content-Type': 'application/json'},
    ));

    // 매 요청마다 SharedPreferences에서 최신 토큰을 읽어 Authorization 헤더에 주입
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final auth = options.headers['Authorization'];
          print('[Dio] ${options.method} ${options.path} | Auth: ${auth != null ? auth.toString().substring(0, auth.toString().length.clamp(0, 30)) + "..." : "NONE"}');
          return handler.next(options);
        },
        onError: (error, handler) {
          print('[Dio] Error ${error.response?.statusCode} | ${error.requestOptions.path}');
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  static Dio get dio => _dio;
  static Dio get dioLong => _dioLong;

  // JWT 토큰 설정
  static void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _dioLong.options.headers['Authorization'] = 'Bearer $token';
  }

  // 토큰 제거 (로그아웃 시)
  static void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
    _dioLong.options.headers.remove('Authorization');
  }
}
