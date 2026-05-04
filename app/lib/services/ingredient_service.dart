import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/ingredient.dart';

class IngredientApiService {

  // 식재료 전체 조회
  static Future<List<Ingredient>> getIngredients(int userId) async {
    final response = await ApiService.dio.get('/ingredients/user/$userId');
    List data = response.data as List;
    return data.map((e) => Ingredient.fromJson(e)).toList();
  }

  // 식재료 추가
  static Future<Ingredient> addIngredient(int userId, Map<String, dynamic> body) async {
    final response = await ApiService.dio.post('/ingredients/user/$userId', data: body);
    return Ingredient.fromJson(response.data);
  }

  // 식재료 수정
  static Future<Ingredient> updateIngredient(int ingredientId, Map<String, dynamic> body) async {
    final response = await ApiService.dio.put('/ingredients/$ingredientId', data: body);
    return Ingredient.fromJson(response.data);
  }

  // 식재료 삭제
  static Future<void> deleteIngredient(int ingredientId) async {
    await ApiService.dio.delete('/ingredients/$ingredientId');
  }

  // 유통기한 임박 재료 조회
  static Future<List<Ingredient>> getExpiringIngredients(int userId) async {
    final response = await ApiService.dio.get('/ingredients/user/$userId/expiring');
    List data = response.data as List;
    return data.map((e) => Ingredient.fromJson(e)).toList();
  }

  // 냉장고 사진 분석 - AI 인식만 하고 저장은 하지 않음
  static Future<List<String>> analyzeImage(Uint8List imageBytes) async {
    FormData formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: 'fridge.jpg',
      ),
    });

    final response = await ApiService.dio.post(
      '/scan/analyze',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return List<String>.from(response.data['recognizedIngredients'] ?? []);
  }

  // 사용자가 확정한 재료 목록 일괄 저장
  static Future<List<Ingredient>> saveIngredientsBatch(
      int userId, List<Map<String, dynamic>> items) async {
    final response = await ApiService.dio.post(
      '/ingredients/user/$userId/batch',
      data: items,
    );
    final List data = response.data as List;
    return data.map((e) => Ingredient.fromJson(e)).toList();
  }
}
