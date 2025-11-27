import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Модель настроек пользователя
class UserSettings {
  final String phone;
  final String email;
  final bool hasPassword;

  const UserSettings({
    required this.phone,
    required this.email,
    required this.hasPassword,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      hasPassword: json['has_password'] ?? false,
    );
  }
}

/// Провайдер для получения настроек пользователя
final userSettingsProvider = FutureProvider<UserSettings>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = await authService.getUserId();
  if (userId == null) {
    throw Exception('Пользователь не авторизован');
  }

  final api = ref.read(apiServiceProvider);
  final data = await api.post(
    '/get_user_settings.php',
    body: {'user_id': userId},
  );

  return UserSettings.fromJson(data);
});
