// ────────────────────────────────────────────────────────────────────────────
//  ADD OFFICIAL EVENT NOTIFIER
//
//  Notifier для управления состоянием формы создания официального события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'add_official_event_state.dart';

/// Notifier для управления формой создания официального события
class AddOfficialEventNotifier extends StateNotifier<AddOfficialEventState> {
  AddOfficialEventNotifier() : super(AddOfficialEventState.initial());

  /// Обновление названия
  void updateName(String value) {
    state = state.copyWith(name: value);
  }

  /// Обновление места проведения
  void updatePlace(String value) {
    state = state.copyWith(place: value);
  }

  /// Обновление описания
  void updateDescription(String value) {
    state = state.copyWith(description: value);
  }

  /// Обновление ссылки
  void updateLink(String value) {
    state = state.copyWith(link: value);
  }

  /// Обновление вида активности
  void updateActivity(String? value) {
    state = state.copyWith(activity: value);
  }

  /// Обновление даты
  void updateDate(DateTime? value) {
    state = state.copyWith(date: value);
  }

  /// Обновление времени (необязательное для официальных событий)
  void updateTime(TimeOfDay? value) {
    state = state.copyWith(time: value);
  }

  /// Добавление нового поля дистанции
  void addDistanceField() {
    final newDistances = [...state.distances, ''];
    state = state.copyWith(distances: newDistances);
  }

  /// Обновление дистанции по индексу
  void updateDistance(int index, String value) {
    final newDistances = List<String>.from(state.distances);
    // Расширяем массив, если индекс выходит за границы
    while (newDistances.length <= index) {
      newDistances.add('');
    }
    newDistances[index] = value;
    state = state.copyWith(distances: newDistances);
  }

  /// Обновление логотипа
  void updateLogoFile(File? file) {
    state = state.copyWith(logoFile: file);
  }

  /// Обновление фоновой картинки
  void updateBackgroundFile(File? file) {
    state = state.copyWith(backgroundFile: file);
  }

  /// Обновление координат места
  void updateLocation(LatLng? location, String? address) {
    state = state.copyWith(
      selectedLocation: location,
      place: address ?? state.place,
    );
  }

  /// Обновление флага сохранения шаблона
  void updateSaveTemplate(bool value) {
    state = state.copyWith(saveTemplate: value);
  }

  /// Обновление названия шаблона
  void updateTemplateName(String value) {
    state = state.copyWith(templateName: value);
  }

  /// Загрузка данных из шаблона
  void loadFromTemplate({
    required String name,
    required String place,
    required String description,
    required String link,
    String? activity,
    DateTime? date,
    TimeOfDay? time, // ── время из шаблона (необязательное)
    LatLng? location,
    List<String>? distances,
  }) {
    state = state.copyWith(
      name: name,
      place: place,
      description: description,
      link: link,
      activity: activity,
      date: date,
      time: time,
      selectedLocation: location,
      distances: distances ?? [''],
    );
  }

  /// Сброс формы
  void reset() {
    state = AddOfficialEventState.initial();
  }
}

