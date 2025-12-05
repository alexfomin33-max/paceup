// ────────────────────────────────────────────────────────────────────────────
//  ADD OFFICIAL EVENT STATE
//
//  Модель состояния для формы создания официального события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Состояние формы создания официального события
@immutable
class AddOfficialEventState {
  /// Название события
  final String name;

  /// Место проведения
  final String place;

  /// Описание
  final String description;

  /// Ссылка на страницу мероприятия
  final String link;

  /// Вид активности
  final String? activity;

  /// Дата проведения
  final DateTime? date;

  /// Время начала
  final TimeOfDay? time;

  /// Дистанции (в метрах)
  final List<String> distances;

  /// Логотип
  final File? logoFile;

  /// Фоновая картинка
  final File? backgroundFile;

  /// Координаты выбранного места
  final LatLng? selectedLocation;

  /// Сохранить шаблон
  final bool saveTemplate;

  /// Название шаблона
  final String templateName;

  const AddOfficialEventState({
    this.name = '',
    this.place = '',
    this.description = '',
    this.link = '',
    this.activity,
    this.date,
    this.time,
    this.distances = const [''],
    this.logoFile,
    this.backgroundFile,
    this.selectedLocation,
    this.saveTemplate = false,
    this.templateName = 'Субботний коферан',
  });

  /// Начальное состояние
  factory AddOfficialEventState.initial() => const AddOfficialEventState();

  /// Проверка валидности формы
  bool get isValid =>
      name.trim().isNotEmpty &&
      place.trim().isNotEmpty &&
      activity != null &&
      date != null &&
      selectedLocation != null;

  /// Создание копии с обновлёнными полями
  AddOfficialEventState copyWith({
    String? name,
    String? place,
    String? description,
    String? link,
    String? activity,
    DateTime? date,
    TimeOfDay? time,
    List<String>? distances,
    File? logoFile,
    File? backgroundFile,
    LatLng? selectedLocation,
    bool? saveTemplate,
    String? templateName,
  }) {
    return AddOfficialEventState(
      name: name ?? this.name,
      place: place ?? this.place,
      description: description ?? this.description,
      link: link ?? this.link,
      activity: activity ?? this.activity,
      date: date ?? this.date,
      time: time ?? this.time,
      distances: distances ?? this.distances,
      logoFile: logoFile ?? this.logoFile,
      backgroundFile: backgroundFile ?? this.backgroundFile,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      saveTemplate: saveTemplate ?? this.saveTemplate,
      templateName: templateName ?? this.templateName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddOfficialEventState &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          place == other.place &&
          description == other.description &&
          link == other.link &&
          activity == other.activity &&
          date == other.date &&
          time == other.time &&
          listEquals(distances, other.distances) &&
          logoFile == other.logoFile &&
          backgroundFile == other.backgroundFile &&
          selectedLocation == other.selectedLocation &&
          saveTemplate == other.saveTemplate &&
          templateName == other.templateName;

  @override
  int get hashCode =>
      Object.hash(
        name,
        place,
        description,
        link,
        activity,
        date,
        time,
        distances,
        logoFile,
        backgroundFile,
        selectedLocation,
        saveTemplate,
        templateName,
      );
}

