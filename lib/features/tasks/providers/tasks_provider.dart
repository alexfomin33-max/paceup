// ────────────────────────────────────────────────────────────────────────────
//  TASKS PROVIDER
//
//  Провайдер для загрузки и управления задачами
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../domain/models/task.dart';

/// Провайдер для получения задач из API (исключая принятые пользователем)
final tasksProvider = FutureProvider<List<TasksByMonth>>((ref) async {
  final api = ApiService();
  final authService = AuthService();
  final userId = await authService.getUserId();
  
  try {
    final data = await api.get(
      '/get_tasks.php',
      queryParams: {
        if (userId != null) 'user_id': userId.toString(),
        if (userId != null) 'exclude_user_tasks': 'true',
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
    return null;
  } catch (e) {
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
  
  try {
    final data = await api.get(
      '/get_task_participants.php',
      queryParams: {
        'task_id': taskId.toString(),
        if (userId != null) 'user_id': userId.toString(),
      },
      timeout: const Duration(seconds: 15),
    );

    if (data['success'] == true) {
      final participantsList = data['participants'] as List? ?? [];
      final participants = participantsList
          .whereType<Map<String, dynamic>>()
          .map((json) => TaskParticipant.fromJson(json))
          .toList();
      
      final isParticipating = (data['is_current_user_participating'] as bool?) ?? false;
      
      return TaskParticipantsData(
        participants: participants,
        isCurrentUserParticipating: isParticipating,
      );
    }
    return const TaskParticipantsData(participants: [], isCurrentUserParticipating: false);
  } catch (e) {
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

