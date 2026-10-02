import 'package:dio/dio.dart';

/// 예외를 사용자에게 보여줄 문장으로 바꾼다.
/// 개발자용 예외 원문(DioException, 스택 등)은 노출하지 않는다.
String friendlyErrorMessage(
  Object error, {
  String fallback = '문제가 발생했어요. 잠시 후 다시 시도해 주세요.',
}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return '서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '응답이 너무 오래 걸려요. 잠시 후 다시 시도해 주세요.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final data = error.response?.data;
        final serverMsg = data is Map ? data['message'] : null;
        // 4xx는 서버가 사용자용 문장을 내려줌(예: "이미 사용 중인 아이디입니다.")
        // 5xx는 외부 API 원문이 섞일 수 있어 노출하지 않음
        if (status >= 400 && status < 500 && serverMsg is String) {
          return serverMsg;
        }
        if (status == 401 || status == 403) {
          return '로그인이 만료됐어요. 다시 로그인해 주세요.';
        }
        return fallback;
      default:
        return fallback;
    }
  }
  // 앱 코드에서 직접 만든 Exception('문장')은 문장만 보여준다
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return fallback;
}
