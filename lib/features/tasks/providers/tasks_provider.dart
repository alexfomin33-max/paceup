// ────────────────────────────────────────────────────────────────────────────
//  TASKS PROVIDER
//
//  Провайдер для загрузки и управления задачами
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../domain/models/task.dart';

/// Провайдер для получения задач из API (исключая принятые пользователем)
final tasksProvider = FutureProvider<List<TasksByMonth>>((ref) async {
  final api = ApiService();
  final authService = AuthService();
  final userId = await authService.getUserId();
  
  debugPrint('📡 tasksProvider: начало загрузки задач, userId=$userId');
  
  try {
    final queryParams = <String, String>{
      if (userId != null) 'user_id': userId.toString(),
      if (userId != null) 'exclude_user_tasks': 'true',
    };
    
    debugPrint('📡 tasksProvider: queryParams=$queryParams');
    
    final data = await api.get(
      '/get_tasks.php',
      queryParams: queryParams,
      timeout: const Duration(seconds: 15),
    );

    debugPrint('📡 tasksProvider: получен ответ от API, keys=${data.keys.toList()}');
    
    final List rawList = data['tasks'] as List? ?? const [];
    debugPrint('📡 tasksProvider: rawList.length=${rawList.length}');
    
    final result = rawList
        .whereType<Map<String, dynamic>>()
        .map((json) => TasksByMonth.fromApi(json))
        .toList();
    
    debugPrint('✅ tasksProvider: успешно загружено ${result.length} групп задач по месяцам');
    for (var monthGroup in result) {
      debugPrint('   - ${monthGroup.monthYearLabel}: ${monthGroup.tasks.length} задач');
    }
    
    return result;
  } catch (e, stackTrace) {
    // В случае ошибки возвращаем пустой список
    debugPrint('❌ tasksProvider: ошибка при загрузке задач: $e');
    debugPrint('❌ tasksProvider: stackTrace: $stackTrace');
    return [];
  }
});

/// Провайдер для получения активных задач пользователя
final userTasksProvider = FutureProvider<List<TasksByMonth>>((ref) async {
  final api = ApiService();
  final authService = AuthService();
  final userId = await authService.getUserId();
  
  if (userId == null) {
    return [];
  }
  
  try {
    final data = await api.get(
      '/get_user_tasks.php',
      queryParams: {
        'user_id': userId.toString(),
      },
      timeout: const Duration(seconds: 15),
    );

    final List rawList = data['tasks'] as List? ?? const [];
    
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((json) => TasksByMonth.fromApi(json))
        .toList();
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    return [];
  }
});

/// Провайдер для получения одной задачи по ID
final taskDetailProvider = FutureProvider.family<Task?, int>((ref, taskId) async {
  final api = ApiService();
  final authService = AuthService();
  final userId = await authService.getUserId();
  
  try {
    final queryParams = <String, String>{
      'task_id': taskId.toString(),
    };
    
    // Добавляем user_id, если пользователь авторизован, чтобы получить прогресс
    if (userId != null) {
      queryParams['user_id'] = userId.toString();
    }
    
    final data = await api.get(
      '/get_task.php',
      queryParams: queryParams,
      timeout: const Duration(seconds: 15),
    );

    if (data['success'] == true && data['task'] != null) {
      return Task.fromApi(data['task'] as Map<String, dynamic>);
    }
    
    // Если success = false, логируем сообщение об ошибке
    if (data.containsKey('message')) {
      debugPrint('⚠️ get_task.php вернул ошибку для task_id=$taskId: ${data['message']}');
    } else {
      debugPrint('⚠️ get_task.php вернул success=false для task_id=$taskId, но нет message. Данные: $data');
    }
    
    return null;
  } catch (e) {
    // Логируем ошибку для отладки
    final errorMessage = e.toString();
    debugPrint('❌ Ошибка при загрузке задачи task_id=$taskId: $errorMessage');
    
    // Если это ошибка "Задача не найдена" или похожая, возвращаем null
    // чтобы экран показал "Задача не найдена" вместо технической ошибки
    if (errorMessage.contains('не найдена') || 
        errorMessage.contains('not found') ||
        errorMessage.contains('404')) {
      return null;
    }
    
    // Для других ошибок также возвращаем null, чтобы не показывать технические детали
    // Пользователь увидит "Задача не найдена" в UI
    return null;
  }
});

/// Модель участника задачи
class TaskParticipant {
  final int userId;
  final String name;
  final String surname;
  final String fullName;
  final String avatar;
  final double currentValue;
  final String valueText;

  const TaskParticipant({
    required this.userId,
    required this.name,
    required this.surname,
    required this.fullName,
    required this.avatar,
    required this.currentValue,
    required this.valueText,
  });

  factory TaskParticipant.fromJson(Map<String, dynamic> json) {
    return TaskParticipant(
      userId: (json['user_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      surname: (json['surname'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatar: (json['avatar'] as String?) ?? '',
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      valueText: (json['value_text'] as String?) ?? '',
    );
  }
}

/// Провайдер для получения участников задачи
final taskParticipantsProvider = FutureProvider.family<TaskParticipantsData, int>((ref, taskId) async {
  final api = ApiService();
  final authService = AuthService();
  final userId = await authService.getUserId();
  
    debugPrint('📡 taskParticipantsProvider: запрос для taskId=$taskId, userId=$userId');
  
  try {
    final queryParams = <String, String>{
      'task_id': taskId.toString(),
      if (userId != null) 'user_id': userId.toString(),
    };
    
    debugPrint('📡 taskParticipantsProvider: queryParams=$queryParams');
    debugPrint('📡 taskParticipantsProvider: полный URL будет: /get_task_participants.php?task_id=$taskId${userId != null ? '&user_id=$userId' : ''}');
    
    final data = await api.get(
      '/get_task_participants.php',
      queryParams: queryParams,
      timeout: const Duration(seconds: 15),
    );

    debugPrint('📡 taskParticipantsProvider: ответ для taskId=$taskId: success=${data['success']}, participantsCount=${(data['participants'] as List?)?.length ?? 0}, isParticipating=${data['is_current_user_participating']}');

    if (data['success'] == true) {
      final participantsList = data['participants'] as List? ?? [];
      final participants = participantsList
          .whereType<Map<String, dynamic>>()
          .map((json) => TaskParticipant.fromJson(json))
          .toList();
      
      final isParticipating = (data['is_current_user_participating'] as bool?) ?? false;
      
      debugPrint('✅ taskParticipantsProvider: успешно загружено для taskId=$taskId: ${participants.length} участников, isParticipating=$isParticipating');
      
      return TaskParticipantsData(
        participants: participants,
        isCurrentUserParticipating: isParticipating,
      );
    }
    
    debugPrint('⚠️ taskParticipantsProvider: success=false для taskId=$taskId');
    return const TaskParticipantsData(participants: [], isCurrentUserParticipating: false);
  } catch (e, stackTrace) {
    debugPrint('❌ taskParticipantsProvider: ошибка для taskId=$taskId: $e');
    debugPrint('❌ taskParticipantsProvider: тип ошибки: ${e.runtimeType}');
    debugPrint('❌ taskParticipantsProvider: stackTrace: $stackTrace');
    
    // Если это ошибка "HTML вместо JSON", возможно задача не существует
    // или есть проблема на сервере - возвращаем пустые данные
    // но логируем для отладки
    if (e.toString().contains('HTML вместо JSON')) {
      debugPrint('⚠️ taskParticipantsProvider: Сервер вернул HTML для taskId=$taskId. Возможно, задача не существует или есть ошибка на сервере.');
    }
    
    return const TaskParticipantsData(participants: [], isCurrentUserParticipating: false);
  }
});

/// Данные об участниках задачи
class TaskParticipantsData {
  final List<TaskParticipant> participants;
  final bool isCurrentUserParticipating;

  const TaskParticipantsData({
    required this.participants,
    required this.isCurrentUserParticipating,
  });
}

/// Провайдер для управления участием в задаче
final taskParticipationProvider = FutureProvider.family<bool, int>((ref, taskId) async {
  final authService = AuthService();
  final userId = await authService.getUserId();
  
  if (userId == null) return false;
  
  try {
    // Получаем данные об участниках, чтобы узнать статус текущего пользователя
    final participantsData = await ref.watch(taskParticipantsProvider(taskId).future);
    return participantsData.isCurrentUserParticipating;
  } catch (e) {
    return false;
  }
});

