// ────────────────────────────────────────────────────────────────────────────
//  CONNECTED TRACKERS PROVIDER
//
//  StateNotifierProvider для управления состоянием экрана подключенных трекеров
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connected_trackers_notifier.dart';
import 'connected_trackers_state.dart';

/// Provider для ConnectedTrackers
final connectedTrackersProvider =
    StateNotifierProvider<ConnectedTrackersNotifier, ConnectedTrackersState>(
  (ref) => ConnectedTrackersNotifier(),
);

