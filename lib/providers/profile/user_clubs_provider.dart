// ────────────────────────────────────────────────────────────────────────────
//  USER CLUBS PROVIDER
//
//  FutureProvider для загрузки клубов пользователя из API
//  Используется во вкладке "Клубы" профиля
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../../core/models/club.dart';

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
final userClubsProvider = FutureProvider.family<List<Club>, int>((
  ref,
  userId,
) async {
  final api = ref.watch(apiServiceProvider);

  try {
    // Загружаем клубы, в которых пользователь является участником
    // Используем параметр member_user_id для фильтрации по участникам
    final data = await api.get(
      '/get_clubs.php',
      queryParams: {'detail': 'true', 'member_user_id': userId.toString()},
      timeout: const Duration(seconds: 12),
    );

    if (data['success'] != true) {
      throw Exception(data['message'] as String? ?? 'Ошибка загрузки клубов');
    }

    // Получаем список клубов из ответа (уже отфильтрованы по участникам на сервере)
    final clubsList = data['clubs'] as List<dynamic>? ?? [];

    // Преобразуем в список Club моделей
    final userClubs = clubsList
        .map((club) => Club.fromJson(club as Map<String, dynamic>))
        .toList();

    return userClubs;
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    // Ошибка будет обработана через AsyncValue.error
    rethrow;
  }
});
