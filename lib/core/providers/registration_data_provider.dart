// ────────────────────────────────────────────────────────────────────────────
//  REGISTRATION DATA PROVIDER
//
//  Провайдер для хранения данных регистрации между экранами
//  Используется для передачи данных между шагами регистрации
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 🔹 Модель данных регистрации
class RegistrationData {
  /// 🔹 Имя пользователя
  final String? firstName;

  /// 🔹 Фамилия пользователя
  final String? lastName;

  /// 🔹 Дата рождения
  final DateTime? birthDate;

  /// 🔹 Пол ('Мужской' или 'Женский')
  final String? gender;

  /// 🔹 Город проживания
  final String? city;

  /// 🔹 Основной вид спорта ('running', 'cycling', 'swimming', 'skiing')
  final String? mainSport;

  /// 🔹 Аватар (файл)
  final File? avatar;

  const RegistrationData({
    this.firstName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.city,
    this.mainSport,
    this.avatar,
  });

  /// 🔹 Создание копии с обновленными полями
  RegistrationData copyWith({
    String? Function()? firstName,
    String? Function()? lastName,
    DateTime? Function()? birthDate,
    String? Function()? gender,
    String? Function()? city,
    String? Function()? mainSport,
    File? Function()? avatar,
  }) {
    return RegistrationData(
      firstName: firstName != null ? firstName() : this.firstName,
      lastName: lastName != null ? lastName() : this.lastName,
      birthDate: birthDate != null ? birthDate() : this.birthDate,
      gender: gender != null ? gender() : this.gender,
      city: city != null ? city() : this.city,
      mainSport: mainSport != null ? mainSport() : this.mainSport,
      avatar: avatar != null ? avatar() : this.avatar,
    );
  }

  /// 🔹 Проверка, заполнены ли все обязательные поля
  bool get isComplete {
    return firstName != null &&
        firstName!.isNotEmpty &&
        lastName != null &&
        lastName!.isNotEmpty &&
        birthDate != null &&
        gender != null &&
        city != null &&
        city!.isNotEmpty &&
        mainSport != null;
  }

  /// 🔹 Очистка всех данных
  RegistrationData clear() {
    return const RegistrationData();
  }
}

/// 🔹 Notifier для управления данными регистрации
class RegistrationDataNotifier extends StateNotifier<RegistrationData> {
  RegistrationDataNotifier() : super(const RegistrationData());

  /// 🔹 Установка имени
  void setFirstName(String firstName) {
    state = state.copyWith(firstName: () => firstName.trim());
  }

  /// 🔹 Установка фамилии
  void setLastName(String lastName) {
    state = state.copyWith(lastName: () => lastName.trim());
  }

  /// 🔹 Установка даты рождения
  void setBirthDate(DateTime birthDate) {
    state = state.copyWith(birthDate: () => birthDate);
  }

  /// 🔹 Установка пола
  void setGender(String gender) {
    state = state.copyWith(gender: () => gender);
  }

  /// 🔹 Установка города
  void setCity(String city) {
    state = state.copyWith(city: () => city.trim());
  }

  /// 🔹 Установка основного вида спорта
  void setMainSport(String mainSport) {
    state = state.copyWith(mainSport: () => mainSport);
  }

  /// 🔹 Установка аватара
  void setAvatar(File avatar) {
    state = state.copyWith(avatar: () => avatar);
  }

  /// 🔹 Очистка всех данных
  void clear() {
    state = const RegistrationData();
  }
}

/// 🔹 Провайдер для данных регистрации
final registrationDataProvider =
    StateNotifierProvider<RegistrationDataNotifier, RegistrationData>((ref) {
  return RegistrationDataNotifier();
});
