// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE PROVIDER
//
//  Riverpod Provider для EditProfileNotifier
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import 'edit_profile_notifier.dart';
import 'edit_profile_state.dart';

/// Provider для EditProfileNotifier
final editProfileProvider = StateNotifierProvider.family<
    EditProfileNotifier, EditProfileState, int>(
  (ref, userId) {
    final api = ref.watch(apiServiceProvider);
    return EditProfileNotifier(
      api: api,
      userId: userId,
      ref: ref,
    );
  },
);

