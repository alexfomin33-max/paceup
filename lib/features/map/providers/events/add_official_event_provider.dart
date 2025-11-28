// ────────────────────────────────────────────────────────────────────────────
//  ADD OFFICIAL EVENT PROVIDER
//
//  Провайдеры для экрана создания официального события
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_official_event_notifier.dart';
import 'add_official_event_state.dart';
import 'add_official_event_templates_notifier.dart';
import 'add_official_event_submit_notifier.dart';

/// Provider для управления состоянием формы
final addOfficialEventFormProvider =
    StateNotifierProvider<AddOfficialEventNotifier, AddOfficialEventState>(
  (ref) => AddOfficialEventNotifier(),
);

/// Provider для загрузки списка шаблонов
final templatesListProvider =
    AsyncNotifierProvider<TemplatesListNotifier, List<String>>(
  TemplatesListNotifier.new,
);

/// Provider для загрузки данных конкретного шаблона
final templateDataProvider =
    AsyncNotifierProvider.family<TemplateDataNotifier, EventTemplate, String>(
  TemplateDataNotifier.new,
);

/// Provider для отправки формы
final submitEventProvider =
    AsyncNotifierProvider<SubmitEventNotifier, void>(
  SubmitEventNotifier.new,
);

