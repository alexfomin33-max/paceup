// lib/service/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Централизованный HTTP клиент для всех API запросов.
//
// Возможности:
//  • Singleton pattern — один экземпляр на всё приложение
//  • Автоматическое добавление токенов авторизации
//  • Обработка timeout (30 сек по умолчанию)
//  • Очистка BOM и некорректных символов в ответах
//  • Единая обработка ошибок сети и HTTP
//  • Поддержка GET/POST/PUT/DELETE/PATCH
//  • Поддержка multipart/form-data для загрузки файлов
//
// Использование:
//   final api = ApiService();
//   final data = await api.get('/users/1');
//   await api.post('/posts', body: {'title': 'Hello'});
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/app_config.dart';

/// Централизованный сервис для всех HTTP запросов
class ApiService {
  /// Base URL API (из конфигурации)
  static String get baseUrl => AppConfig.baseUrl;

  /// Таймаут по умолчанию для всех запросов (из конфигурации)
  static Duration get defaultTimeout => AppConfig.defaultTimeout;

  // ──────────────────────────── Singleton ────────────────────────────

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ──────────────────────────── HTTP Client ────────────────────────────

  final http.Client _client = http.Client();
  final AuthService _auth = AuthService();

  /// Закрытие клиента (вызывать при выходе из приложения)
  void dispose() {
    _client.close();
  }

  // ──────────────────────────── Headers ────────────────────────────

  /// Получение заголовков с токеном авторизации
  Future<Map<String, String>> _headers({
    Map<String, String>? additionalHeaders,
  }) async {
    final token = await _auth.getAccessToken();
    final userId = await _auth.getUserId();

    return {
      "Content-Type": "application/json; charset=UTF-8",
      if (token != null) "Authorization": "Bearer $token",
      if (userId != null) "UserID": "$userId",
      ...?additionalHeaders,
    };
  }

  // ──────────────────────────── Retry Logic ────────────────────────────

  /// Выполнение запроса с автоматическими повторными попытками
  /// при сетевых ошибках (SocketException, TimeoutException)
  Future<T> _executeWithRetry<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await request();
      } on SocketException {
        attempt++;
        if (attempt >= maxRetries) {
          throw ApiException(
            "Нет подключения к интернету (попыток: $maxRetries)",
          );
        }
        // Ждём перед повторной попыткой
        await Future.delayed(AppConfig.retryDelay);
      } on TimeoutException {
        attempt++;
        if (attempt >= maxRetries) {
          throw ApiException(
            "Превышено время ожидания запроса (попыток: $maxRetries)",
          );
        }
        await Future.delayed(AppConfig.retryDelay);
      }
    }
  }

  // ──────────────────────────── GET ────────────────────────────

  /// GET запрос
  ///
  /// Пример:
  /// ```dart
  /// final data = await api.get('/users/1');
  /// final users = await api.get('/users', queryParams: {'page': '1'});
  /// ```
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _executeWithRetry(() async {
      try {
        final uri = Uri.parse(
          "$baseUrl$endpoint",
        ).replace(queryParameters: queryParams);

        final response = await _client
            .get(uri, headers: await _headers(additionalHeaders: headers))
            .timeout(timeout ?? defaultTimeout);

        return _handleResponse(response);
      } on http.ClientException catch (e) {
        throw ApiException("Ошибка сети: ${e.message}");
      } catch (e) {
        if (e is! TimeoutException && e is! SocketException) {
          throw ApiException("Неизвестная ошибка: $e");
        }
        rethrow; // SocketException и TimeoutException обрабатываются в _executeWithRetry
      }
    }, maxRetries: AppConfig.maxRetries);
  }

  // ──────────────────────────── POST ────────────────────────────

  /// POST запрос
  ///
  /// Пример:
  /// ```dart
  /// final result = await api.post('/posts', body: {
  ///   'title': 'Hello',
  ///   'content': 'World',
  /// });
  /// ```
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _executeWithRetry(() async {
      try {
        final uri = Uri.parse("$baseUrl$endpoint");

        final response = await _client
            .post(
              uri,
              headers: await _headers(additionalHeaders: headers),
              body: body != null ? json.encode(body) : null,
            )
            .timeout(timeout ?? defaultTimeout);

        return _handleResponse(response);
      } on http.ClientException catch (e) {
        throw ApiException("Ошибка сети: ${e.message}");
      } catch (e) {
        if (e is! TimeoutException && e is! SocketException) {
          throw ApiException("Неизвестная ошибка: $e");
        }
        rethrow; // SocketException и TimeoutException обрабатываются в _executeWithRetry
      }
    }, maxRetries: AppConfig.maxRetries);
  }

  // ──────────────────────────── PUT ────────────────────────────

  /// PUT запрос (обновление ресурса)
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl$endpoint");

      final response = await _client
          .put(
            uri,
            headers: await _headers(additionalHeaders: headers),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException("Превышено время ожидания запроса");
    } on http.ClientException catch (e) {
      throw ApiException("Ошибка сети: ${e.message}");
    } on SocketException {
      throw ApiException("Нет подключения к интернету");
    } catch (e) {
      throw ApiException("Неизвестная ошибка: $e");
    }
  }

  // ──────────────────────────── DELETE ────────────────────────────

  /// DELETE запрос (удаление ресурса)
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl$endpoint");

      final response = await _client
          .delete(uri, headers: await _headers(additionalHeaders: headers))
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException("Превышено время ожидания запроса");
    } on http.ClientException catch (e) {
      throw ApiException("Ошибка сети: ${e.message}");
    } on SocketException {
      throw ApiException("Нет подключения к интернету");
    } catch (e) {
      throw ApiException("Неизвестная ошибка: $e");
    }
  }

  // ──────────────────────────── PATCH ────────────────────────────

  /// PATCH запрос (частичное обновление ресурса)
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl$endpoint");

      final response = await _client
          .patch(
            uri,
            headers: await _headers(additionalHeaders: headers),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException("Превышено время ожидания запроса");
    } on http.ClientException catch (e) {
      throw ApiException("Ошибка сети: ${e.message}");
    } on SocketException {
      throw ApiException("Нет подключения к интернету");
    } catch (e) {
      throw ApiException("Неизвестная ошибка: $e");
    }
  }

  // ──────────────────────────── Multipart (файлы) ────────────────────────────

  /// Отправка multipart/form-data (для загрузки файлов)
  ///
  /// Пример:
  /// ```dart
  /// await api.postMultipart('/upload', files: {
  ///   'image': File('/path/to/image.jpg'),
  /// }, fields: {
  ///   'title': 'My Photo',
  /// });
  /// ```
  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, File> files,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl$endpoint");
      final request = http.MultipartRequest('POST', uri);

      // Добавляем заголовки (без Content-Type, он будет установлен автоматически)
      final headers = await _headers();
      headers.remove('Content-Type'); // multipart сам установит
      request.headers.addAll(headers);

      // Добавляем текстовые поля
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Добавляем файлы
      for (final entry in files.entries) {
        final file = entry.value;
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();

        final multipartFile = http.MultipartFile(
          entry.key,
          stream,
          length,
          filename: file.path.split('/').last,
        );

        request.files.add(multipartFile);
      }

      // Отправка
      final streamedResponse = await request.send().timeout(
        timeout ?? defaultTimeout,
      );

      // Преобразуем в обычный Response
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException("Превышено время ожидания загрузки");
    } on http.ClientException catch (e) {
      throw ApiException("Ошибка сети: ${e.message}");
    } on SocketException {
      throw ApiException("Нет подключения к интернету");
    } catch (e) {
      throw ApiException("Неизвестная ошибка: $e");
    }
  }

  // ──────────────────────────── Обработка ответа ────────────────────────────

  /// Единая обработка всех HTTP ответов
  ///
  /// Функции:
  ///  • Очистка BOM (\uFEFF) в начале JSON
  ///  • Проверка статус-кода
  ///  • Парсинг JSON с обработкой ошибок
  ///  • Проверка поля "ok"/"success" если есть
  Map<String, dynamic> _handleResponse(http.Response response) {
    // Декодируем с очисткой BOM (как в activity_lenta.dart)
    final raw = utf8.decode(response.bodyBytes);
    final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();

    // Проверяем успешность HTTP запроса
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Пустой ответ — возвращаем пустой объект
      if (cleaned.isEmpty) {
        return {'success': true};
      }

      try {
        final decoded = json.decode(cleaned);

        // Если ответ — не объект, оборачиваем
        if (decoded is! Map<String, dynamic>) {
          return {'data': decoded};
        }

        // Проверяем поля "ok" или "success" если есть
        final data = decoded;
        if (data.containsKey('ok') && data['ok'] == false) {
          throw ApiException(data['error']?.toString() ?? 'API вернул ошибку');
        }
        if (data.containsKey('success') && data['success'] == false) {
          throw ApiException(
            data['message']?.toString() ?? 'API вернул ошибку',
          );
        }

        return data;
      } on FormatException catch (e) {
        throw ApiException("Некорректный JSON: $e");
      }
    }

    // Ошибка HTTP
    String errorMessage = "HTTP ${response.statusCode}";

    // Пытаемся извлечь сообщение об ошибке из тела ответа
    try {
      if (cleaned.isNotEmpty) {
        final errorData = json.decode(cleaned);
        if (errorData is Map<String, dynamic>) {
          errorMessage =
              errorData['error']?.toString() ??
              errorData['message']?.toString() ??
              errorMessage;
        }
      }
    } catch (_) {
      // Игнорируем ошибки парсинга
    }

    throw ApiException(errorMessage);
  }
}

// ──────────────────────────── Exception ────────────────────────────

/// Кастомное исключение для API ошибок
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
