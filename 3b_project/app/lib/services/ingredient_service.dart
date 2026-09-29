import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/ingredient.dart';
import 'api_service.dart';

class IngredientApiService {
  static Future<List<Ingredient>> getIngredients(int userId) async {
    final res = await ApiService.dio.get('/ingredients/user/$userId');
    return (res.data as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<List<Ingredient>> getExpiringIngredients(int userId) async {
    final res = await ApiService.dio.get('/ingredients/user/$userId/expiring');
    return (res.data as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<Ingredient> addIngredient(
      int userId, Map<String, dynamic> data) async {
    final res =
        await ApiService.dio.post('/ingredients/user/$userId', data: data);
    return Ingredient.fromJson(res.data);
  }

  static Future<void> updateIngredient(
      int ingredientId, Map<String, dynamic> data) async {
    await ApiService.dio.put('/ingredients/$ingredientId', data: data);
  }

  static Future<void> deleteIngredient(int ingredientId) async {
    await ApiService.dio.delete('/ingredients/$ingredientId');
  }

  static Future<List<Ingredient>> saveIngredientsBatch(
      int userId, List<Map<String, dynamic>> payloads) async {
    final res = await ApiService.dioLong
        .post('/ingredients/user/$userId/batch', data: payloads);
    return (res.data as List).map((e) => Ingredient.fromJson(e)).toList();
  }

  static Future<List<String>> analyzeImage(Uint8List imageBytes,
      {int? userId}) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(imageBytes, filename: 'scan.jpg'),
      if (userId != null) 'userId': userId.toString(),
    });
    final res = await ApiService.dioLong.post(
      '/scan/analyze',
      data: formData,
    );
    final list = res.data['recognizedIngredients'] as List?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }
}
