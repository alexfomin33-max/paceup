// ────────────────────────────────────────────────────────────────────────────
//  EDIT OFFICIAL EVENT PROVIDER
//
//  StateNotifierProvider для управления состоянием экрана редактирования официального события
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';
import 'edit_official_event_notifier.dart';
import 'edit_official_event_state.dart';

/// Provider для EditOfficialEvent (зависит от eventId)
final editOfficialEventProvider = StateNotifierProvider.family<
    EditOfficialEventNotifier, EditOfficialEventState, int>((ref, eventId) {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);
  final notifier = EditOfficialEventNotifier(
    api: api,
    auth: auth,
    eventId: eventId,
  );

  return notifier;
});

