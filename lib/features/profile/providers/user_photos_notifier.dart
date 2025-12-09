// ────────────────────────────────────────────────────────────────────────────
//  USER PHOTOS NOTIFIER
//
//  StateNotifier для управления фотографиями пользователя
//  Возможности:
//  • Загрузка фотографий из активностей и постов
//  • Сортировка по дате (свежие сверху)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import 'user_photos_state.dart';

class UserPhotosNotifier extends StateNotifier<UserPhotosState> {
  final ApiService _api;
  final int userId;

  UserPhotosNotifier({
    required ApiService api,
    required this.userId,
  })  : _api = api,
        super(UserPhotosState.initial());

  /// Загрузка фотографий пользователя
  ///
  /// Загружает все фотографии из активностей и постов пользователя,
  /// отсортированные по дате создания (свежие сверху)
  Future<void> load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final map = await _api.post(
        '/user_photos.php',
        body: {'user_id': '$userId'},
        timeout: const Duration(seconds: 12),
      );

      // Проверяем успешность ответа
      if (map['success'] != true) {
        throw Exception(map['message']?.toString() ?? 'Ошибка загрузки фотографий');
      }

      // Парсим список фотографий
      final photosList = map['photos'] as List<dynamic>? ?? [];
      final photos = photosList
          .map((json) => UserPhoto.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        photos: photos,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.format(e),
        isLoading: false,
      );
    }
  }

  /// Обновление фотографий (refresh)
  Future<void> refresh() async {
    await load();
  }
}

