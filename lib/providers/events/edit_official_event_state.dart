// ────────────────────────────────────────────────────────────────────────────
//  EDIT OFFICIAL EVENT STATE
//
//  Модель состояния для экрана редактирования официального события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Состояние экрана редактирования официального события
@immutable
class EditOfficialEventState {
  /// Идет ли загрузка данных события
  final bool isLoadingData;

  /// Идет ли удаление события
  final bool isDeleting;

  /// Ошибка (если есть)
  final String? error;

  /// Вид активности ('Бег', 'Велосипед', 'Плавание')
  final String? activity;

  /// Дата события
  final DateTime? date;

  /// Время события
  final TimeOfDay? time;

  /// Координаты выбранного места
  final LatLng? selectedLocation;

  /// Флаг сохранения шаблона
  final bool saveTemplate;

  /// Логотип (новый файл)
  final File? logoFile;

  /// URL существующего логотипа
  final String? logoUrl;

  /// Имя файла существующего логотипа
  final String? logoFilename;

  /// Фоновая картинка (новый файл)
  final File? backgroundFile;

  /// URL существующей фоновой картинки
  final String? backgroundUrl;

  /// Имя файла существующей фоновой картинки
  final String? backgroundFilename;

  const EditOfficialEventState({
    this.isLoadingData = true,
    this.isDeleting = false,
    this.error,
    this.activity,
    this.date,
    this.time,
    this.selectedLocation,
    this.saveTemplate = false,
    this.logoFile,
    this.logoUrl,
    this.logoFilename,
    this.backgroundFile,
    this.backgroundUrl,
    this.backgroundFilename,
  });

  /// Начальное состояние
  static EditOfficialEventState initial() => const EditOfficialEventState();

  /// Копирование состояния с обновлением полей
  EditOfficialEventState copyWith({
    bool? isLoadingData,
    bool? isDeleting,
    String? error,
    String? activity,
    DateTime? date,
    TimeOfDay? time,
    LatLng? selectedLocation,
    bool? saveTemplate,
    File? logoFile,
    String? logoUrl,
    String? logoFilename,
    File? backgroundFile,
    String? backgroundUrl,
    String? backgroundFilename,
    bool clearError = false,
    bool clearLogo = false,
    bool clearBackground = false,
  }) {
    return EditOfficialEventState(
      isLoadingData: isLoadingData ?? this.isLoadingData,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      activity: activity ?? this.activity,
      date: date ?? this.date,
      time: time ?? this.time,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      saveTemplate: saveTemplate ?? this.saveTemplate,
      logoFile: clearLogo ? null : (logoFile ?? this.logoFile),
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      logoFilename: clearLogo ? null : (logoFilename ?? this.logoFilename),
      backgroundFile:
          clearBackground ? null : (backgroundFile ?? this.backgroundFile),
      backgroundUrl:
          clearBackground ? null : (backgroundUrl ?? this.backgroundUrl),
      backgroundFilename: clearBackground
          ? null
          : (backgroundFilename ?? this.backgroundFilename),
    );
  }
}

