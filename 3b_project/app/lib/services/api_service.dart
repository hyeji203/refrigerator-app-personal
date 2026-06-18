import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api'; // 크롬/Windows 데스크탑
  // 실제 기기 테스트: 'http://172.22.34.79:8080/api' (PC IP 확인 후 변경)
  // Android 에뮬레이터: 'http://10.0.2.2:8080/api'

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
