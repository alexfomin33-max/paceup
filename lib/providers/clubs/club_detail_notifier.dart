// ────────────────────────────────────────────────────────────────────────────
//  CLUB DETAIL NOTIFIER
//
//  StateNotifier для управления состоянием экрана детальной информации о клубе
//  Возможности:
//  • Загрузка данных клуба
//  • Вступление/выход из клуба
//  • Переключение вкладок
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_handler.dart';
import '../../providers/profile/user_clubs_provider.dart';
import 'club_detail_state.dart';

class ClubDetailNotifier extends StateNotifier<ClubDetailState> {
  final ApiService _api;
  final AuthService _authService;
  final int clubId;
  final Ref _ref;

  ClubDetailNotifier({
    required ApiService api,
    required AuthService authService,
    required this.clubId,
    required Ref ref,
  }) : _api = api,
       _authService = authService,
       _ref = ref,
       super(ClubDetailState.initial());

  /// Загрузка данных клуба
  Future<void> loadClub() async {
    state = state.copyWith(isLoading: true, error: null, clearError: true);

    try {
      final userId = await _authService.getUserId();

      final data = await _api.get(
        '/get_clubs.php',
        queryParams: {'club_id': clubId.toString()},
      );

      if (data['success'] == true && data['club'] != null) {
        final club = data['club'] as Map<String, dynamic>;

        // Проверяем права на редактирование
        final clubUserId = club['user_id'] as int?;
        final canEdit = userId != null && clubUserId == userId;

        // Проверяем, является ли пользователь участником клуба
        bool isMember = false;
        if (userId != null) {
          final members = club['members'] as List<dynamic>? ?? [];
          isMember = members.any((m) => m['user_id'] == userId);
        }

        state = state.copyWith(
          clubData: club,
          canEdit: canEdit,
          isMember: isMember,
          isRequest: false, // Сбрасываем статус заявки при загрузке
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          error: data['message'] as String? ?? 'Клуб не найден',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: ErrorHandler.formatWithContext(e, context: 'загрузке клуба'),
        isLoading: false,
      );
    }
  }

  /// Вступление в клуб
  Future<void> joinClub() async {
    if (state.isJoining || state.clubData == null) return;

    state = state.copyWith(isJoining: true);

    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        state = state.copyWith(isJoining: false);
        // TODO: Show error to user (e.g., SnackBar)
        return;
      }

      final data = await _api.post(
        '/join_club.php',
        body: {'club_id': clubId.toString(), 'user_id': userId.toString()},
      );

      if (data['success'] == true) {
        final isMember = data['is_member'] as bool? ?? false;
        final isRequest = data['is_request'] as bool? ?? false;

        state = state.copyWith(
          isMember: isMember,
          isRequest: isRequest,
          isJoining: false,
        );

        // Обновляем данные клуба (чтобы обновилось количество участников)
        await loadClub();

        // Инвалидируем provider клубов пользователя
        _ref.invalidate(userClubsProvider(userId));
      } else {
        state = state.copyWith(isJoining: false);
        // TODO: Show error to user (e.g., SnackBar)
      }
    } catch (e) {
      state = state.copyWith(isJoining: false);
      // TODO: Show error to user (e.g., SnackBar)
    }
  }

  /// Выход из клуба
  Future<void> leaveClub() async {
    if (state.isJoining || state.clubData == null) return;

    state = state.copyWith(isJoining: true);

    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        state = state.copyWith(isJoining: false);
        // TODO: Show error to user (e.g., SnackBar)
        return;
      }

      final data = await _api.post(
        '/leave_club.php',
        body: {'club_id': clubId.toString(), 'user_id': userId.toString()},
      );

      if (data['success'] == true) {
        state = state.copyWith(
          isMember: false,
          isRequest: false,
          isJoining: false,
        );

        // Обновляем данные клуба (чтобы обновилось количество участников)
        await loadClub();

        // Инвалидируем provider клубов пользователя
        _ref.invalidate(userClubsProvider(userId));
      } else {
        state = state.copyWith(isJoining: false);
        // TODO: Show error to user (e.g., SnackBar)
      }
    } catch (e) {
      state = state.copyWith(isJoining: false);
      // TODO: Show error to user (e.g., SnackBar)
    }
  }

  /// Переключение вкладки
  void setTab(int newTab) {
    state = state.copyWith(tab: newTab);
  }

  /// Перезагрузка данных клуба
  Future<void> reload() async {
    await loadClub();
  }
}
