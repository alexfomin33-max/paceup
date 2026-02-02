// lib/features/lenta/screens/activity/together/together_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/api_service.dart'; // для ApiException
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../providers/services/auth_provider.dart';
import 'together_providers.dart';
import '../../../../profile/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TogetherScreen: объединенный экран с контентом добавления и участников
// ─────────────────────────────────────────────────────────────────────────────
// Для владельца/участника: показываем «Группа участников» + «Добавить участников».
// Для зрителя (видит тренировку в ленте, но не участник): только «Группа участников»,
// чтобы посмотреть, с кем тренировались (в т.ч. тех, на кого не подписан).
// ─────────────────────────────────────────────────────────────────────────────
class TogetherScreen extends ConsumerStatefulWidget {
  final int activityId;

  const TogetherScreen({super.key, required this.activityId});

  @override
  ConsumerState<TogetherScreen> createState() => _TogetherScreenState();
}

class _TogetherScreenState extends ConsumerState<TogetherScreen> {
  // ────────────────────────────────────────────────────────────────────────────
  // Состояние для поиска кандидатов
  // ────────────────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<int> _busyIds = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────────────
    // Показывать блок «Добавить участников» только владельцу/участнику группы
    // ────────────────────────────────────────────────────────────────────────
    final membersState = ref.watch(
      togetherMembersProvider(widget.activityId),
    );
    final currentUserIdAsync = ref.watch(currentUserIdProvider);
    final canAddMembers = membersState.maybeWhen(
      data: (members) {
        final userId = currentUserIdAsync.valueOrNull;
        if (userId == null) return false;
        return members.any((m) => m.id == userId);
      },
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: PaceAppBar(
        title: 'Совместная тренировка',
        backgroundColor: AppColors.getSurfaceColor(context),
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ────────────────────────────────────────────────────────────────────
          // Секция участников (сверху) — видна всем (владелец, участник, зритель)
          // ────────────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Группа участников',
                    style: AppTextStyles.h15w6,
                  ),
                ),
                const SizedBox(height: 12),
                _MembersSection(activityId: widget.activityId),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // ────────────────────────────────────────────────────────────────────
          // Секция добавления кандидатов — только для владельца/участника
          // ────────────────────────────────────────────────────────────────────
          if (canAddMembers)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Добавить участников',
                      style: AppTextStyles.h15w6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _SearchField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CandidatesSection(
                    activityId: widget.activityId,
                    query: _query,
                    busyIds: _busyIds,
                    onBusyChanged: (id, isBusy) {
                      setState(() {
                        if (isBusy) {
                          _busyIds.add(id);
                        } else {
                          _busyIds.remove(id);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

          // ────────────────────────────────────────────────────────────────────
          // Нижний отступ
          // ────────────────────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Секция кандидатов для добавления
// ─────────────────────────────────────────────────────────────────────────────
class _CandidatesSection extends ConsumerWidget {
  final int activityId;
  final String query;
  final Set<int> busyIds;
  final void Function(int id, bool isBusy) onBusyChanged;

  const _CandidatesSection({
    required this.activityId,
    required this.query,
    required this.busyIds,
    required this.onBusyChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(togetherCandidatesProvider(activityId));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CupertinoActivityIndicator(radius: 10)),
        ),
        error: (e, _) {
          // ────────────────────────────────────────────────────────────────────
          // ✅ УЛУЧШЕННАЯ ОБРАБОТКА ОШИБОК: извлекаем понятное сообщение
          // ────────────────────────────────────────────────────────────────────
          String errorMessage = 'Неизвестная ошибка';

          if (e is ApiException) {
            errorMessage = e.message;
            // Убираем префикс "Неизвестная ошибка: " если он есть
            if (errorMessage.startsWith('Неизвестная ошибка: ')) {
              errorMessage =
                  errorMessage.substring('Неизвестная ошибка: '.length);
            }
            // Извлекаем только сообщение об ошибке БД, если оно есть
            if (errorMessage.contains('Ошибка базы данных:')) {
              final dbErrorMatch =
                  RegExp(r'Ошибка базы данных:\s*(.+)').firstMatch(errorMessage);
              if (dbErrorMatch != null) {
                errorMessage =
                    'Ошибка базы данных: ${dbErrorMatch.group(1)}';
              }
            }
          } else {
            errorMessage = e.toString();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SelectableText.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Ошибка загрузки пользователей:\n\n'),
                  TextSpan(text: errorMessage),
                ],
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
            ),
          );
        },
        data: (candidates) {
          // ────────────────────────────────────────────────────────────────────
          // ✅ Локальный поиск по full_name (без доп. запросов)
          // ────────────────────────────────────────────────────────────────────
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? candidates
              : candidates
                  .where((u) => u.fullName.toLowerCase().contains(q))
                  .toList(growable: false);

          final ui = filtered
              .map(
                (u) => _Person(
                  u.fullName,
                  u.age,
                  u.city,
                  u.avatar,
                  pending: u.pending || busyIds.contains(u.id),
                  id: u.id,
                  sameWorkout: u.sameWorkout,
                ),
              )
              .toList(growable: false);

          return Column(
            children: List.generate(ui.length, (i) {
              final p = ui[i];
              return _CandidateRowTile(
                person: p,
                activityId: activityId,
                onInviteSent: () {
                  onBusyChanged(p.id, true);
                  ref.invalidate(togetherCandidatesProvider(activityId));
                },
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Секция участников
// ─────────────────────────────────────────────────────────────────────────────
class _MembersSection extends ConsumerWidget {
  final int activityId;

  const _MembersSection({required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(togetherMembersProvider(activityId));

    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: SelectableText.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Ошибка загрузки участников:\n\n'),
              TextSpan(text: e.toString()),
            ],
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.error,
            ),
          ),
        ),
      ),
      data: (members) {
        final uiMembers = members
            .map(
              (m) => _Person(
                m.fullName,
                m.age,
                m.city,
                m.avatar,
                id: m.id,
                sameWorkout: false,
              ),
            )
            .toList(growable: false);

        return Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
              ),
              child: Column(
                children: List.generate(uiMembers.length, (i) {
                  final p = uiMembers[i];
                  return _MemberRowTile(
                    person: p,
                    activityId: activityId,
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Поле поиска
// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _SearchField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.5,
        ),
        boxShadow: [
          const BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          hintText: 'Поиск',
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Строка кандидата с кнопкой добавления
// ─────────────────────────────────────────────────────────────────────────────
class _CandidateRowTile extends ConsumerWidget {
  final _Person person;
  final int activityId;
  final VoidCallback onInviteSent;

  const _CandidateRowTile({
    required this.person,
    required this.activityId,
    required this.onInviteSent,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ✅ Навигация на экран профиля пользователя
  // ────────────────────────────────────────────────────────────────────────────
  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfileScreen(userId: person.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // ────────────────────────────────────────────────────────────────────
          // ✅ Кликабельная область: аватар и текст (имя, фамилия)
          // ────────────────────────────────────────────────────────────────────
          Expanded(
            child: InkWell(
              onTap: () => _navigateToProfile(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.network(
                        person.avatar,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.skeletonBase,
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (person.sameWorkout)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Та же тренировка',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ────────────────────────────────────────────────────────────────────
          // ✅ Кнопка добавления (не кликабельна для навигации)
          // ────────────────────────────────────────────────────────────────────
          person.pending
              ? const _PendingButton()
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // ────────────────────────────────────────────────────────
                      // ✅ Отправляем приглашение + сразу показываем
                      // "песочные часы" локально
                      // ────────────────────────────────────────────────────────
                      onInviteSent();
                      try {
                        final api = ref.read(togetherApiProvider);
                        await api.sendInvite(
                          activityId: activityId,
                          recipientId: person.id,
                        );
                      } catch (_) {
                        // Ошибку отдаст сервер/ApiService
                      } finally {
                        ref.invalidate(
                          togetherCandidatesProvider(activityId),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Пригласить',
                        style: AppTextStyles.h14w5.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Строка участника (с кнопкой "Покинуть" для текущего пользователя)
// ─────────────────────────────────────────────────────────────────────────────
class _MemberRowTile extends ConsumerWidget {
  final _Person person;
  final int activityId;
  const _MemberRowTile({
    required this.person,
    required this.activityId,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ✅ Навигация на экран профиля пользователя
  // ────────────────────────────────────────────────────────────────────────────
  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ProfileScreen(userId: person.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ────────────────────────────────────────────────────────────────────────────
    // Проверяем, является ли участник текущим пользователем
    // ────────────────────────────────────────────────────────────────────────────
    final currentUserIdAsync = ref.watch(currentUserIdProvider);
    final isCurrentUser = currentUserIdAsync.maybeWhen(
      data: (userId) => userId != null && userId == person.id,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // ────────────────────────────────────────────────────────────────────
          // ✅ Кликабельная область: аватар и текст (имя)
          // ────────────────────────────────────────────────────────────────────
          Expanded(
            child: InkWell(
              onTap: () => _navigateToProfile(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.network(
                        person.avatar,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.skeletonBase,
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ────────────────────────────────────────────────────────────────────
          // ✅ Кнопка "Покинуть" (только для текущего пользователя)
          // ────────────────────────────────────────────────────────────────────
          if (isCurrentUser)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // ────────────────────────────────────────────────────────────
                  // ✅ Выходим из группы, но тренировка у пользователя сохраняется
                  // (мы только снимаем участие в группе)
                  // ────────────────────────────────────────────────────────────
                  try {
                    final api = ref.read(togetherApiProvider);
                    await api.leaveGroup(activityId: activityId);
                    ref.invalidate(togetherMembersProvider(activityId));
                  } catch (_) {
                    // Ошибку показываем выше через перезагрузку провайдера
                    ref.invalidate(togetherMembersProvider(activityId));
                  }
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'Покинуть',
                    style: AppTextStyles.h14w5.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка ожидания (в стиле кнопки "Отписаться")
// ─────────────────────────────────────────────────────────────────────────────
class _PendingButton extends StatelessWidget {
  const _PendingButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.getTextPrimaryColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Text(
          'Приглашён',
          style: AppTextStyles.h14w5.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Модель персоны (объединенная для кандидатов и участников)
// ─────────────────────────────────────────────────────────────────────────────
class _Person {
  final int id;
  final String name;
  final int age;
  final String city;
  final String avatar;
  final bool pending;
  final bool sameWorkout;
  const _Person(
    this.name,
    this.age,
    this.city,
    this.avatar, {
    this.id = 0,
    this.pending = false,
    this.sameWorkout = false,
  });
}
