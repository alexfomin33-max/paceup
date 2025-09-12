import 'dart:convert';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  //final storage = const FlutterSecureStorage();
  final String baseUrl = "http://api.paceup.ru";

  //Future<String?> getAccessToken() async => await storage.read(key: "access_token");
  //Future<String?> getRefreshToken() async => await storage.read(key: "refresh_token");
  //Future<String?> getUserId() async => await storage.read(key: "user_id");
  //временный костыль
  Future<String?> getAccessToken() async {
    return "13378195076b4b696468b5ed3f522d03";
  }
  Future<String?> getRefreshToken() async {
    return "09be5ed7ad6d166086cd94d654874a16e7dd202e86e69a7d5e85ce23586fd3b1";
  }
  Future<int?> getUserId() async {
    final userIdStr = "1";

    return int.tryParse(userIdStr);
}

  Future<void> saveTokens(String access, String refresh) async {
     //временный костыль
   // await storage.write(key: "access_token", value: access);
   // await storage.write(key: "refresh_token", value: refresh);
  }

  Future<void> logout() async {
     //временный костыль
    //await storage.deleteAll();
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
        "UserID": "$userID",
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

    //print(response.body);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["success"] == true) {
        //временный костыль
       // await storage.write(key: "access_token", value: data["access_token"]);
        return true;
      }
    }
    return false;
  }
}
