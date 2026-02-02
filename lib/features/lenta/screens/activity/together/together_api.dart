import '../../../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// together_api.dart
//
// Мини-обёртка над PHP API для совместных тренировок.
//
// ВАЖНО:
// - ApiService сам добавляет заголовок UserID (через AuthService), поэтому
//   backend читает текущего пользователя из заголовков.
// ─────────────────────────────────────────────────────────────────────────────

class TogetherMemberDto {
  final int id;
  final String fullName;
  final int age;
  final String city;
  final String avatar;
  final bool isOwner;

  const TogetherMemberDto({
    required this.id,
    required this.fullName,
    required this.age,
    required this.city,
    required this.avatar,
    required this.isOwner,
  });

  factory TogetherMemberDto.fromJson(Map<String, dynamic> j) {
    return TogetherMemberDto(
      id: _asInt(j['id']),
      fullName: j['full_name']?.toString() ?? '',
      age: _asInt(j['age']),
      city: j['city']?.toString() ?? '',
      avatar: j['avatar']?.toString() ?? '',
      isOwner: _asBool(j['is_owner']),
    );
  }
}

class TogetherCandidateDto {
  final int id;
  final String fullName;
  final int age;
  final String city;
  final String avatar;
  final bool pending;
  /// Пользователь с такой же тренировкой (автоопределение по треку + время ±5 мин)
  final bool sameWorkout;

  const TogetherCandidateDto({
    required this.id,
    required this.fullName,
    required this.age,
    required this.city,
    required this.avatar,
    required this.pending,
    this.sameWorkout = false,
  });

  factory TogetherCandidateDto.fromJson(Map<String, dynamic> j) {
    return TogetherCandidateDto(
      id: _asInt(j['id']),
      fullName: j['full_name']?.toString() ?? '',
      age: _asInt(j['age']),
      city: j['city']?.toString() ?? '',
      avatar: j['avatar']?.toString() ?? '',
      pending: _asBool(j['pending']),
      sameWorkout: _asBool(j['same_workout']),
    );
  }
}

class TogetherInviteStatusDto {
  final bool hasPending;
  final int? inviteId;
  final int? senderId;
  final int? activityId;

  const TogetherInviteStatusDto({
    required this.hasPending,
    required this.inviteId,
    required this.senderId,
    required this.activityId,
  });

  factory TogetherInviteStatusDto.fromJson(Map<String, dynamic> j) {
    final hasPending = _asBool(j['has_pending']);
    final invite = j['invite'];
    if (!hasPending || invite is! Map<String, dynamic>) {
      return const TogetherInviteStatusDto(
        hasPending: false,
        inviteId: null,
        senderId: null,
        activityId: null,
      );
    }
    return TogetherInviteStatusDto(
      hasPending: true,
      inviteId: invite['id'] == null ? null : _asInt(invite['id']),
      senderId: invite['sender_id'] == null ? null : _asInt(invite['sender_id']),
      activityId:
          invite['activity_id'] == null ? null : _asInt(invite['activity_id']),
    );
  }
}

class TogetherApi {
  final ApiService _api;
  TogetherApi({ApiService? api}) : _api = api ?? ApiService();

  // ───────────────────────────────────────────────────────────────────────────
  // Участники
  // ───────────────────────────────────────────────────────────────────────────
  Future<List<TogetherMemberDto>> getMembers({required int activityId}) async {
    final data = await _api.post(
      '/together_get_members.php',
      body: {'activity_id': activityId},
    );
    final raw = data['members'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TogetherMemberDto.fromJson)
        .toList(growable: false);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Кандидаты (подписки + подписчики) + пользователи с такой же тренировкой
  // ───────────────────────────────────────────────────────────────────────────
  Future<List<TogetherCandidateDto>> getCandidates({
    required int activityId,
  }) async {
    final data = await _api.post(
      '/together_get_candidates.php',
      body: {'activity_id': activityId},
    );
    final rawUsers = data['users'];
    final rawSame = data['same_workout_users'];
    final List<TogetherCandidateDto> sameWorkout = rawSame is List
        ? rawSame
            .whereType<Map<String, dynamic>>()
            .map(TogetherCandidateDto.fromJson)
            .toList(growable: false)
        : <TogetherCandidateDto>[];
    final Set<int> sameIds = sameWorkout.map((e) => e.id).toSet();
    final List<TogetherCandidateDto> users = rawUsers is List
        ? rawUsers
            .whereType<Map<String, dynamic>>()
            .map(TogetherCandidateDto.fromJson)
            .where((u) => !sameIds.contains(u.id))
            .toList(growable: false)
        : <TogetherCandidateDto>[];
    return [...sameWorkout, ...users];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Приглашение
  // ───────────────────────────────────────────────────────────────────────────
  Future<int?> sendInvite({
    required int activityId,
    required int recipientId,
  }) async {
    final data = await _api.post(
      '/together_send_invite.php',
      body: {
        'activity_id': activityId,
        'recipient_id': recipientId,
      },
    );
    final id = data['invite_id'];
    if (id == null) return null;
    return _asInt(id);
  }

  Future<TogetherInviteStatusDto> getInviteStatus({
    required int activityId,
  }) async {
    final data = await _api.post(
      '/together_get_invite_status.php',
      body: {'activity_id': activityId},
    );
    return TogetherInviteStatusDto.fromJson(data);
  }

  Future<void> respondInvite({
    required int inviteId,
    required bool accept,
  }) async {
    await _api.post(
      '/together_respond_invite.php',
      body: {
        'invite_id': inviteId,
        'action': accept ? 'accept' : 'decline',
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Выход из группы
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> leaveGroup({required int activityId}) async {
    await _api.post(
      '/together_leave_group.php',
      body: {'activity_id': activityId},
    );
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase();
  if (s == null || s.isEmpty) return false;
  return s == '1' || s == 'true' || s == 'yes' || s == 'on';
}

