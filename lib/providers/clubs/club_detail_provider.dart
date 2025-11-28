// ────────────────────────────────────────────────────────────────────────────
//  CLUB DETAIL PROVIDER
//
//  StateNotifierProvider для управления состоянием экрана детальной информации о клубе
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';
import 'club_detail_notifier.dart';
import 'club_detail_state.dart';

/// Provider для ClubDetail (зависит от clubId)
///
/// Использование:
/// ```dart
/// final clubState = ref.watch(clubDetailProvider(clubId));
///
/// // Загрузка данных
/// ref.read(clubDetailProvider(clubId).notifier).loadClub();
///
/// // Вступление в клуб
/// ref.read(clubDetailProvider(clubId).notifier).joinClub();
/// ```
final clubDetailProvider =
    StateNotifierProvider.family<ClubDetailNotifier, ClubDetailState, int>((
      ref,
      clubId,
    ) {
      final api = ref.watch(apiServiceProvider);
      final authService = ref.watch(authServiceProvider);
      final notifier = ClubDetailNotifier(
        api: api,
        authService: authService,
        clubId: clubId,
        ref: ref,
      );

      // Автоматическая загрузка данных при создании провайдера
      Future.microtask(() => notifier.loadClub());

      return notifier;
    });
