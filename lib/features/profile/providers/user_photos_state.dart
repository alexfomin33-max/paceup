// ────────────────────────────────────────────────────────────────────────────
//  USER PHOTOS STATE
//
//  Модель состояния для фотографий пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Модель одной фотографии
@immutable
class UserPhoto {
  /// URL фотографии
  final String url;

  /// Дата создания активности/поста
  final String createdAt;

  /// Тип: 'activity' или 'post'
  final String type;

  const UserPhoto({
    required this.url,
    required this.createdAt,
    required this.type,
  });

  factory UserPhoto.fromJson(Map<String, dynamic> json) {
    return UserPhoto(
      url: (json['url'] ?? '') as String,
      createdAt: (json['created_at'] ?? '') as String,
      type: (json['type'] ?? 'activity') as String,
    );
  }
}

/// Состояние фотографий пользователя
@immutable
class UserPhotosState {
  /// Список фотографий
  final List<UserPhoto> photos;

  /// Идет ли загрузка
  final bool isLoading;

  /// Ошибка загрузки (если есть)
  final String? error;

  const UserPhotosState({
    this.photos = const [],
    this.isLoading = false,
    this.error,
  });

  /// Начальное состояние (загрузка)
  factory UserPhotosState.initial() =>
      const UserPhotosState(photos: [], isLoading: true);

  /// Состояние загрузки
  UserPhotosState copyWith({
    List<UserPhoto>? photos,
    bool? isLoading,
    String? error,
  }) {
    return UserPhotosState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPhotosState &&
          runtimeType == other.runtimeType &&
          photos == other.photos &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(photos, isLoading, error);
}

