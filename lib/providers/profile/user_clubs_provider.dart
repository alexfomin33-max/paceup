// ────────────────────────────────────────────────────────────────────────────
//  USER CLUBS PROVIDER
//
//  FutureProvider для загрузки клубов пользователя из API
//  Используется во вкладке "Клубы" профиля
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../../models/club.dart';

/// Provider для загрузки клубов пользователя
///
/// Использование:
/// ```dart
/// final clubsAsync = ref.watch(userClubsProvider(userId));
///
/// clubsAsync.when(
///   data: (clubs) => ClubsList(clubs: clubs),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Ошибка: $err'),
/// );
/// ```
final userClubsProvider = FutureProvider.family<List<Club>, int>(
  (ref, userId) async {
    final api = ref.watch(apiServiceProvider);

    try {
      // Загружаем все клубы с подробной информацией
      final data = await api.get(
        '/get_clubs.php',
        queryParams: {'detail': 'true'},
        timeout: const Duration(seconds: 12),
      );

      if (data['success'] != true) {
        throw Exception(
          data['message'] as String? ?? 'Ошибка загрузки клубов',
        );
      }

      // Получаем список клубов из ответа
      final clubsList = data['clubs'] as List<dynamic>? ?? [];

      // Фильтруем клубы по user_id (клубы, созданные этим пользователем)
      final userClubs = clubsList
          .where((club) {
            final clubData = club as Map<String, dynamic>;
            final clubUserId = clubData['user_id'] as int?;
            return clubUserId == userId;
          })
          .map((club) => Club.fromJson(club as Map<String, dynamic>))
          .toList();

      return userClubs;
    } catch (e) {
      // В случае ошибки возвращаем пустой список
      // Ошибка будет обработана через AsyncValue.error
      rethrow;
    }
  },
);

