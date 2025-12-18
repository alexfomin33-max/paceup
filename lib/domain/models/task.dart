// ────────────────────────────────────────────────────────────────────────────
//  TASK MODEL
//
//  Модель задачи для вкладки "Доступные задачи"
// ────────────────────────────────────────────────────────────────────────────

/// Модель задачи
class Task {
  /// ID задачи
  final int id;

  /// Название задачи
  final String name;

  /// Тип задачи ('run', 'bike', 'swim', 'walk', 'general')
  final String type;

  /// Название типа задачи для отображения
  final String typeLabel;

  /// Короткое описание
  final String shortDescription;

  /// Полное описание
  final String fullDescription;

  /// URL картинки задачи
  final String? imageUrl;

  /// URL логотипа задачи
  final String? logoUrl;

  /// Дата начала задачи
  final DateTime? dateStart;

  /// Дата окончания задачи
  final DateTime? dateEnd;

  /// Единица измерения ('km', 'm', 'min', 'h', 'days', 'weeks', 'count')
  final String unit;

  /// Название единицы измерения для отображения
  final String unitLabel;

  /// Тип метрики для подсчета ('distance', 'elevation', 'duration', 'steps', 'count', 'days', 'weeks')
  /// Определяет, что именно нужно считать из тренировок для этой задачи
  final String? metricType;

  /// Целевое значение (опционально)
  final double? targetValue;

  /// Текущий прогресс пользователя (для активных задач)
  final double? currentValue;

  /// Процент выполнения (0.0 - 1.0)
  final double? progressPercent;

  const Task({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.shortDescription,
    required this.fullDescription,
    this.imageUrl,
    this.logoUrl,
    this.dateStart,
    this.dateEnd,
    required this.unit,
    required this.unitLabel,
    this.metricType,
    this.targetValue,
    this.currentValue,
    this.progressPercent,
  });

  /// Создание из JSON ответа API
  factory Task.fromApi(Map<String, dynamic> json) {
    return Task(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? '',
      shortDescription: json['short_description']?.toString() ?? '',
      fullDescription: json['full_description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      dateStart: _parseSqlDateTime(json['date_start']?.toString()),
      dateEnd: _parseSqlDateTime(json['date_end']?.toString()),
      unit: json['unit']?.toString() ?? '',
      unitLabel: json['unit_label']?.toString() ?? '',
      metricType: json['metric_type']?.toString(),
      targetValue: json['target_value'] != null
          ? _asDouble(json['target_value'])
          : null,
      currentValue: json['current_value'] != null
          ? _asDouble(json['current_value'])
          : null,
      progressPercent: json['progress_percent'] != null
          ? _asDouble(json['progress_percent'])
          : null,
    );
  }

  /// Форматированное название задачи с целевым значением
  String get formattedTitle {
    if (targetValue != null) {
      final value = targetValue!.toStringAsFixed(
        targetValue! % 1 == 0 ? 0 : 1,
      );
      return '$name $value $unitLabel';
    }
    return name;
  }

  /// Форматированный текст прогресса (например, "145,8 / 200 км")
  String get formattedProgress {
    if (targetValue != null) {
      final current = currentValue ?? 0.0;
      final currentStr = current.toStringAsFixed(current % 1 == 0 ? 0 : 1).replaceAll('.', ',');
      final targetStr = targetValue!.toStringAsFixed(targetValue! % 1 == 0 ? 0 : 1).replaceAll('.', ',');
      return '$currentStr / $targetStr $unitLabel';
    }
    return '';
  }
}

/// Модель группы задач по месяцу
class TasksByMonth {
  /// Год
  final int year;

  /// Месяц (1-12)
  final int month;

  /// Список задач в этом месяце
  final List<Task> tasks;

  const TasksByMonth({
    required this.year,
    required this.month,
    required this.tasks,
  });

  /// Создание из JSON ответа API
  factory TasksByMonth.fromApi(Map<String, dynamic> json) {
    final tasksList = json['tasks'] as List? ?? [];
    return TasksByMonth(
      year: _asInt(json['year']),
      month: _asInt(json['month']),
      tasks: tasksList
          .whereType<Map<String, dynamic>>()
          .map((t) => Task.fromApi(t))
          .toList(),
    );
  }

  /// Форматированная строка месяца и года (например, "Декабрь 2026")
  String get monthYearLabel {
    const months = [
      '',
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[month]} $year';
  }
}

// ──────────────────────────── УТИЛИТЫ ────────────────────────────

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  if (value is double) return value.toInt();
  return 0;
}

double _asDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

/// Парсинг SQL datetime строки в DateTime
/// Формат: "YYYY-MM-DD HH:mm:ss"
DateTime? _parseSqlDateTime(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    // Пробуем стандартный формат ISO
    return DateTime.parse(s);
  } catch (_) {
    // Пробуем SQL формат "YYYY-MM-DD HH:mm:ss"
    try {
      final parts = s.split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          return DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
          );
        }
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

