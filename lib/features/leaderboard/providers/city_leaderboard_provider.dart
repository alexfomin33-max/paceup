// lib/features/leaderboard/providers/city_leaderboard_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Провайдер для загрузки лидерборда пользователей города
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../models/leaderboard_data.dart';

/// Результат загрузки лидерборда города
class CityLeaderboardResult {
  final List<LeaderboardRowData> leaderboard;
  final int? currentUserRank;

  const CityLeaderboardResult({
    required this.leaderboard,
    this.currentUserRank,
  });
}

/// Провайдер для загрузки лидерборда города
/// 
/// Параметры:
/// - city: название города (обязательный)
/// - sport: 0=бег, 1=вело, 2=плавание (по умолчанию 0)
/// - period: 'current_week', 'current_month', 'current_year', 'custom'
final cityLeaderboardProvider = FutureProvider.autoDispose
    .family<CityLeaderboardResult, CityLeaderboardParams>(
  (ref, params) async {
    final api = ApiService();
    final auth = AuthService();
    
    final userId = await auth.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    if (params.city == null || params.city!.isEmpty) {
      // Если город не выбран, возвращаем пустой результат
      return const CityLeaderboardResult(
        leaderboard: [],
        currentUserRank: null,
      );
    }

    final queryParams = <String, String>{
      'city': params.city!,
      'sport': params.sport.toString(),
      'period': params.period,
      'gender_male': params.genderMale.toString(),
      'gender_female': params.genderFemale.toString(),
      'parameter': params.parameter,
    };

    if (params.period == 'custom' && params.dateStart != null && params.dateEnd != null) {
      queryParams['date_start'] = params.dateStart!;
      queryParams['date_end'] = params.dateEnd!;
    }

    final response = await api.get(
      '/get_leaderboard_city.php',
      queryParams: queryParams,
    );

    if (response['success'] != true) {
      throw Exception(response['message']?.toString() ?? 'Ошибка загрузки лидерборда');
    }

    final leaderboardRaw = response['leaderboard'] as List<dynamic>? ?? [];
    final leaderboard = leaderboardRaw
        .map((e) => LeaderboardRowData.fromJson(e as Map<String, dynamic>))
        .toList();

    // Получаем ранг текущего пользователя из ответа
    final currentUserRank = response['current_user_rank'] as int?;

    return CityLeaderboardResult(
      leaderboard: leaderboard,
      currentUserRank: currentUserRank,
    );
  },
);

/// Параметры для загрузки лидерборда города
class CityLeaderboardParams {
  final String? city; // Название города (обязательный)
  final int sport; // 0=бег, 1=вело, 2=плавание
  final String period; // 'current_week', 'current_month', 'current_year', 'custom'
  final String? dateStart; // Для custom периода
  final String? dateEnd; // Для custom периода
  final bool genderMale; // Показывать мужчин
  final bool genderFemale; // Показывать женщин
  final String parameter; // Параметр статистики: 'Расстояние', 'Тренировок', и т.д.

  const CityLeaderboardParams({
    this.city,
    this.sport = 0,
    this.period = 'current_week',
    this.dateStart,
    this.dateEnd,
    this.genderMale = true,
    this.genderFemale = true,
    this.parameter = 'Расстояние',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityLeaderboardParams &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          sport == other.sport &&
          period == other.period &&
          dateStart == other.dateStart &&
          dateEnd == other.dateEnd &&
          genderMale == other.genderMale &&
          genderFemale == other.genderFemale &&
          parameter == other.parameter;

  @override
  int get hashCode => city.hashCode ^
      sport.hashCode ^ 
      period.hashCode ^ 
      dateStart.hashCode ^ 
      dateEnd.hashCode ^
      genderMale.hashCode ^
      genderFemale.hashCode ^
      parameter.hashCode;
}
