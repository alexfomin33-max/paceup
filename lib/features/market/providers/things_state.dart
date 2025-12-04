// ────────────────────────────────────────────────────────────────────────────
//  THINGS STATE
//
//  Модель состояния для списка вещей с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import '../models/market_models.dart';

/// Состояние списка вещей
class ThingsState {
  final List<GoodsItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int total;

  const ThingsState({
    required this.items,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = false,
    this.total = 0,
  });

  ThingsState copyWith({
    List<GoodsItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? total,
  }) {
    return ThingsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }

  /// Начальное состояние
  factory ThingsState.initial() {
    return const ThingsState(items: []);
  }

  /// Состояние загрузки
  factory ThingsState.loading() {
    return const ThingsState(items: [], isLoading: true);
  }

  /// Состояние ошибки
  factory ThingsState.error(String error) {
    return ThingsState(items: const [], error: error);
  }
}

