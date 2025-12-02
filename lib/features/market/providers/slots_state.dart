// ────────────────────────────────────────────────────────────────────────────
//  SLOTS STATE
//
//  Модель состояния для списка слотов с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import '../models/market_models.dart';

/// Состояние списка слотов
class SlotsState {
  final List<MarketItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int total;

  const SlotsState({
    required this.items,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = false,
    this.total = 0,
  });

  SlotsState copyWith({
    List<MarketItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? total,
  }) {
    return SlotsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }

  /// Начальное состояние
  factory SlotsState.initial() {
    return const SlotsState(items: []);
  }

  /// Состояние загрузки
  factory SlotsState.loading() {
    return const SlotsState(items: [], isLoading: true);
  }

  /// Состояние ошибки
  factory SlotsState.error(String error) {
    return SlotsState(items: const [], error: error);
  }
}

