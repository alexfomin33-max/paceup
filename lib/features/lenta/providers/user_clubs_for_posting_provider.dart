// ────────────────────────────────────────────────────────────────────────────
//  USER CLUBS FOR POSTING PROVIDER
//
//  Загрузка клубов, от имени которых пользователь может публиковать посты:
//  владелец (создатель) клуба или админ клуба. API: get_user_clubs.php
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/services/api_provider.dart';

/// Элемент списка клуба для выбора при создании поста (id + name)
typedef UserClubForPosting = Map<String, dynamic>;

/// Загружает клубы, где пользователь — владелец или админ (для постинга).
///
/// Использование:
/// ```dart
/// final clubsAsync = ref.watch(userClubsForPostingProvider(userId));
/// clubsAsync.when(
///   data: (clubs) => DropdownButton(items: clubs.map(...).toList()),
///   loading: () => CircularProgressIndicator(),
///   error: (_, __) => Text('Ошибка загрузки клубов'),
/// );
/// ```
final userClubsForPostingProvider =
    FutureProvider.family<List<UserClubForPosting>, int>((ref, userId) async {
  if (userId <= 0) return [];

  final api = ref.watch(apiServiceProvider);

  Map<String, dynamic> data;
  try {
    data = await api.get(
      '/get_user_clubs.php',
      queryParams: {'user_id': userId.toString()},
      timeout: const Duration(seconds: 12),
    );
  } catch (_) {
    rethrow;
  }

  // При success: false не бросаем — возвращаем пустой список, чтобы выпадающий список оставался активным
  if (data['success'] != true) return [];

  final raw = data['clubs'];
  if (raw == null || raw is! List) return [];

  final list = <UserClubForPosting>[];
  for (final c in raw) {
    if (c is! Map<String, dynamic>) continue;
    final id = c['id'];
    final name = c['name'];
    if (id == null || name == null) continue;
    final idInt = id is int ? id : (id is num ? id.toInt() : null);
    if (idInt == null) continue;
    list.add({
      'id': idInt,
      'name': name is String ? name : name.toString(),
    });
  }
  return list;
});
