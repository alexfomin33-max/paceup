import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'together_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// together_providers.dart
//
// Провайдеры для вкладок "Участники" и "Добавить".
// Делаем их autoDispose, чтобы не держать лишние данные в памяти.
// ─────────────────────────────────────────────────────────────────────────────

final togetherApiProvider = Provider<TogetherApi>((ref) => TogetherApi());

final togetherMembersProvider =
    FutureProvider.autoDispose.family<List<TogetherMemberDto>, int>((
  ref,
  activityId,
) async {
  final api = ref.watch(togetherApiProvider);
  return api.getMembers(activityId: activityId);
});

final togetherCandidatesProvider =
    FutureProvider.autoDispose.family<List<TogetherCandidateDto>, int>((
  ref,
  activityId,
) async {
  final api = ref.watch(togetherApiProvider);
  return api.getCandidates(activityId: activityId);
});

final togetherInviteStatusProvider =
    FutureProvider.autoDispose.family<TogetherInviteStatusDto, int>((
  ref,
  activityId,
) async {
  final api = ref.watch(togetherApiProvider);
  return api.getInviteStatus(activityId: activityId);
});

