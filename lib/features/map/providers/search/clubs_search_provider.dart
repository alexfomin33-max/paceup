// ────────────────────────────────────────────────────────────────────────────
//  CLUBS SEARCH PROVIDER
//
//  Провайдеры для поиска клубов и получения рекомендованных клубов
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';

/// Модель клуба для поиска
class ClubSearch {
  final int id;
  final String name;
  final String city;
  final int membersCount;
  final String logo;

  ClubSearch({
    required this.id,
    required this.name,
    required this.city,
    required this.membersCount,
    required this.logo,
  });

  factory ClubSearch.fromJson(Map<String, dynamic> json) {
    return ClubSearch(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      membersCount: json['members_count'] as int? ?? 0,
      logo: json['logo'] as String? ?? '',
    );
  }

  /// Формирование URL для логотипа
  String get logoUrl {
    if (logo.isEmpty) {
      return 'http://uploads.paceup.ru/images/clubs/default.png';
    }
    if (logo.startsWith('http')) return logo;
    return 'http://uploads.paceup.ru/clubs/$id/logo/$logo';
  }
}

/// Провайдер для получения рекомендованных клубов (из того же города)
final recommendedClubsProvider = FutureProvider<List<ClubSearch>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);
  
  final userId = await auth.getUserId();
  if (userId == null) {
    return [];
  }

  try {
    final response = await api.get(
      '/get_recommended_clubs.php',
      queryParams: {'limit': '50'},
    );

    if (response['success'] == true) {
      final clubs = (response['clubs'] as List<dynamic>?)
              ?.map((e) => ClubSearch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      
      if (response['message'] != null) {
        debugPrint('ℹ️ Сообщение от API: ${response['message']}');
      }
      
      return clubs;
    }
    
    final errorMessage = response['message'] as String? ?? 'Неизвестная ошибка';
    debugPrint('❌ API вернул ошибку: $errorMessage');
    return [];
  } catch (e, stackTrace) {
    debugPrint('❌ Ошибка загрузки рекомендованных клубов: $e');
    debugPrint('Stack trace: $stackTrace');
    return [];
  }
});

/// Провайдер для поиска клубов по запросу
final searchClubsProvider = FutureProvider.family<List<ClubSearch>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final api = ref.watch(apiServiceProvider);
    final auth = ref.watch(authServiceProvider);
    
    final userId = await auth.getUserId();
    if (userId == null) {
      return [];
    }

    try {
      final response = await api.get(
        '/search_clubs.php',
        queryParams: {
          'query': query.trim(),
          'limit': '50',
        },
      );

      if (response['success'] == true) {
        final clubs = (response['clubs'] as List<dynamic>?)
                ?.map((e) => ClubSearch.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return clubs;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Ошибка поиска клубов: $e');
      return [];
    }
  },
);

