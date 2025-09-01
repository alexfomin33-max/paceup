import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final storage = const FlutterSecureStorage();
  final String baseUrl = "http://api.paceup.ru";

  Future<String?> getAccessToken() async => await storage.read(key: "access_token");
  Future<String?> getRefreshToken() async => await storage.read(key: "refresh_token");
  Future<String?> getUserId() async => await storage.read(key: "user_id");

  Future<void> saveTokens(String access, String refresh) async {
    await storage.write(key: "access_token", value: access);
    await storage.write(key: "refresh_token", value: refresh);
  }

  Future<void> logout() async {
    await storage.deleteAll();
  }

  // Проверка access_token на валидность
  Future<bool> isAuthorized() async {
    final token = await getAccessToken();
    if (token == null) return false;

    final userID = await getUserId();
    if (userID == null) return false;

    final response = await http.post(
      Uri.parse("$baseUrl/check_token.php"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        "UserID": userID,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["valid"] == true) return true;
    }

    // Если access_token просрочен, пробуем обновить
    return await refreshToken();
  }

  // Обновление access_token через refresh_token
  Future<bool> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final userID = await getUserId();
    if (userID == null) return false;

    final response = await http.post(
      Uri.parse("$baseUrl/refresh.php"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"refresh_token": refresh, "userID": userID}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["success"] == true) {
        await storage.write(key: "access_token", value: data["access_token"]);
        return true;
      }
    }
    return false;
  }
}
