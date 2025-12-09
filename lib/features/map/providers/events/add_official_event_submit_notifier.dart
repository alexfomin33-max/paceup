// ────────────────────────────────────────────────────────────────────────────
//  ADD OFFICIAL EVENT SUBMIT NOTIFIER
//
//  AsyncNotifier для отправки формы создания официального события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import 'add_official_event_state.dart';

/// AsyncNotifier для отправки формы
class SubmitEventNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Начальное состояние — не загружаем ничего
    return;
  }

  /// Отправка формы создания события
  Future<void> submit(AddOfficialEventState formState) async {
    // Проверка валидности формы
    if (!formState.isValid) {
      throw Exception('Форма не заполнена полностью');
    }

    state = const AsyncValue.loading();

    try {
      final api = ref.read(apiServiceProvider);
      final auth = ref.read(authServiceProvider);
      final userId = await auth.getUserId();

      if (userId == null) {
        throw Exception('Ошибка авторизации. Необходимо войти в систему');
      }

      // Формируем данные
      final files = <String, File>{};
      final fields = <String, String>{};

      // Добавляем файлы
      if (formState.logoFile != null) {
        files['logo'] = formState.logoFile!;
      }
      if (formState.backgroundFile != null) {
        files['background'] = formState.backgroundFile!;
      }

      // Добавляем поля формы
      fields['user_id'] = userId.toString();
      fields['name'] = formState.name.trim();
      fields['activity'] = formState.activity!;
      fields['place'] = formState.place.trim();
      fields['latitude'] = formState.selectedLocation!.latitude.toString();
      fields['longitude'] = formState.selectedLocation!.longitude.toString();
      fields['event_date'] = _formatDate(formState.date!);
      fields['description'] = formState.description.trim();

      // Собираем дистанции (только непустые)
      final distanceValues = formState.distances
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();

      // Добавляем ссылку
      if (formState.link.trim().isNotEmpty) {
        fields['event_link'] = formState.link.trim();
      }

      // Добавляем шаблон, если нужно сохранить
      if (formState.saveTemplate &&
          formState.templateName.trim().isNotEmpty) {
        fields['template_name'] = formState.templateName.trim();
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        final jsonBody = <String, dynamic>{
          'user_id': fields['user_id'],
          'name': fields['name'],
          'activity': fields['activity'],
          'place': fields['place'],
          'latitude': fields['latitude'],
          'longitude': fields['longitude'],
          'event_date': fields['event_date'],
          'description': fields['description'],
          'event_link': fields['event_link'] ?? '',
          'template_name': fields['template_name'] ?? '',
        };
        if (distanceValues.isNotEmpty) {
          jsonBody['distance'] = distanceValues;
        }
        data = await api.post('/create_official_event.php', body: jsonBody);
      } else {
        // Multipart запрос с файлами
        // Для multipart нужно отправлять дистанции как массив
        final multipartFields = Map<String, String>.from(fields);
        for (int i = 0; i < distanceValues.length; i++) {
          multipartFields['distance[$i]'] = distanceValues[i];
        }

        data = await api.postMultipart(
          '/create_official_event.php',
          files: files,
          fields: multipartFields,
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем ответ
      if (data['success'] == true) {
        state = const AsyncValue.data(null);
      } else if (data['success'] == false) {
        final errorMessage =
            data['message']?.toString() ?? 'Ошибка при создании события';
        throw Exception(errorMessage);
      } else {
        throw Exception('Неожиданный формат ответа сервера');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  /// Форматирование даты (dd.mm.yyyy)
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }
}

