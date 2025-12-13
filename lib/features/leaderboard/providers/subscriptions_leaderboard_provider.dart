// lib/features/leaderboard/providers/subscriptions_leaderboard_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Провайдер для загрузки лидерборда подписок
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../models/leaderboard_data.dart';

/// Результат загрузки лидерборда подписок
class SubscriptionsLeaderboardResult {
  final List<LeaderboardRowData> leaderboard;
  final int? currentUserRank;

  const SubscriptionsLeaderboardResult({
    required this.leaderboard,
    this.currentUserRank,
  });
}

/// Провайдер для загрузки лидерборда подписок
/// 
/// Параметры:
/// - sport: 0=бег, 1=вело, 2=плавание (по умолчанию 0)
/// - period: 'current_week', 'current_month', 'current_year', 'custom'
final subscriptionsLeaderboardProvider = FutureProvider.autoDispose
    .family<SubscriptionsLeaderboardResult, SubscriptionsLeaderboardParams>(
  (ref, params) async {
    final api = ApiService();
    final auth = AuthService();
    
    final userId = await auth.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final queryParams = <String, String>{
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
      '/get_leaderboard_subscriptions.php',
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

    return SubscriptionsLeaderboardResult(
      leaderboard: leaderboard,
      currentUserRank: currentUserRank,
    );
  },
);

/// Параметры для загрузки лидерборда подписок
class SubscriptionsLeaderboardParams {
  final int sport; // 0=бег, 1=вело, 2=плавание
  final String period; // 'current_week', 'current_month', 'current_year', 'custom'
  final String? dateStart; // Для custom периода
  final String? dateEnd; // Для custom периода
  final bool genderMale; // Показывать мужчин
  final bool genderFemale; // Показывать женщин
  final String parameter; // Параметр статистики: 'Расстояние', 'Тренировок', и т.д.

  const SubscriptionsLeaderboardParams({
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
      other is SubscriptionsLeaderboardParams &&
          runtimeType == other.runtimeType &&
          sport == other.sport &&
          period == other.period &&
          dateStart == other.dateStart &&
          dateEnd == other.dateEnd &&
          genderMale == other.genderMale &&
          genderFemale == other.genderFemale &&
          parameter == other.parameter;

  @override
  int get hashCode => sport.hashCode ^ 
      period.hashCode ^ 
      dateStart.hashCode ^ 
      dateEnd.hashCode ^
      genderMale.hashCode ^
      genderFemale.hashCode ^
      parameter.hashCode;
}

