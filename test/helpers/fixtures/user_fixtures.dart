// ────────────────────────────────────────────────────────────────────────────
//  USER FIXTURES
//
//  Фикстуры для создания тестовых данных пользователей
//  Используются в unit и widget тестах
// ────────────────────────────────────────────────────────────────────────────

/// Фикстуры для создания тестовых пользователей
class UserFixtures {
  /// Создаёт базового пользователя для тестов
  static Map<String, dynamic> createUser({
    int? id,
    String? name,
    String? avatar,
    int? userGroup,
    String? city,
    int? age,
    int? followers,
    int? following,
  }) {
    return {
      'id': id ?? 1,
      'name': name ?? 'Test User',
      'avatar': avatar ?? 'https://example.com/avatar.jpg',
      'user_group': userGroup ?? 0,
      'city': city ?? 'Moscow',
      'age': age ?? 25,
      'followers': followers ?? 100,
      'following': following ?? 50,
      'total_distance': 1000,
      'total_activities': 50,
      'total_time': 36000,
    };
  }

  /// Создаёт пользователя с минимальными данными
  static Map<String, dynamic> createMinimalUser({
    int? id,
    String? name,
  }) {
    return {
      'id': id ?? 1,
      'name': name ?? 'Test User',
    };
  }

  /// Создаёт список пользователей для тестов
  static List<Map<String, dynamic>> createUserList({
    int count = 3,
  }) {
    return List.generate(
      count,
      (index) => createUser(
        id: index + 1,
        name: 'User ${index + 1}',
      ),
    );
  }

  /// Создаёт JSON для API ответа с пользователями
  static Map<String, dynamic> createApiResponse({
    List<Map<String, dynamic>>? users,
    bool success = true,
  }) {
    final usersList = users ?? createUserList();
    
    return {
      'success': success,
      'data': usersList,
    };
  }
}
