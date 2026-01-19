import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/services/api_service.dart'; // для ApiException
import '../../together_providers.dart';

class AddingContent extends ConsumerStatefulWidget {
  final int activityId;

  const AddingContent({
    super.key,
    required this.activityId,
  });

  @override
  ConsumerState<AddingContent> createState() => _AddingContentState();
}

class _AddingContentState extends ConsumerState<AddingContent> {
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
    final state = ref.watch(togetherCandidatesProvider(widget.activityId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12), // ← только поле поиска
          child: _SearchField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity, // ← full width
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CupertinoActivityIndicator(radius: 10)),
            ),
            error: (e, _) {
              // ─────────────────────────────────────────────────────────────
              // ✅ УЛУЧШЕННАЯ ОБРАБОТКА ОШИБОК: извлекаем понятное сообщение
              // ─────────────────────────────────────────────────────────────
              String errorMessage = 'Неизвестная ошибка';
              
              if (e is ApiException) {
                errorMessage = e.message;
                // Убираем префикс "Неизвестная ошибка: " если он есть
                if (errorMessage.startsWith('Неизвестная ошибка: ')) {
                  errorMessage = errorMessage.substring('Неизвестная ошибка: '.length);
                }
                // Извлекаем только сообщение об ошибке БД, если оно есть
                if (errorMessage.contains('Ошибка базы данных:')) {
                  final dbErrorMatch = RegExp(r'Ошибка базы данных:\s*(.+)').firstMatch(errorMessage);
                  if (dbErrorMatch != null) {
                    errorMessage = 'Ошибка базы данных: ${dbErrorMatch.group(1)}';
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
              // ─────────────────────────────────────────────────────────────
              // ✅ Локальный поиск по full_name (без доп. запросов)
              // ─────────────────────────────────────────────────────────────
              final q = _query.trim().toLowerCase();
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
                      pending: u.pending || _busyIds.contains(u.id),
                      id: u.id,
                    ),
                  )
                  .toList(growable: false);

              return Column(
                children: List.generate(ui.length, (i) {
                  final p = ui[i];
                  return Column(
                    children: [
                      _RowTile(
                        person: p,
                        trailing: p.pending
                            ? const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  CupertinoIcons.hourglass,
                                  size: 22,
                                  color: AppColors.textTertiary,
                                ),
                              )
                            : SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  onPressed: () async {
                                    // ───────────────────────────────────
                                    // ✅ Отправляем приглашение + сразу
                                    // показываем "песочные часы" локально
                                    // ───────────────────────────────────
                                    setState(() => _busyIds.add(p.id));
                                    try {
                                      final api = ref.read(togetherApiProvider);
                                      await api.sendInvite(
                                        activityId: widget.activityId,
                                        recipientId: p.id,
                                      );
                                    } catch (_) {
                                      // Ошибку отдаст сервер/ApiService
                                    } finally {
                                      ref.invalidate(
                                        togetherCandidatesProvider(
                                          widget.activityId,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    CupertinoIcons.add_circled,
                                    size: 22,
                                    color: AppColors.brandPrimary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 18,
                                ),
                              ),
                      ),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _SearchField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Поиск',
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 4),
          child: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 30),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Person person;
  final Widget trailing;
  const _RowTile({required this.person, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                const SizedBox(height: 2),
                Text(
                  '${person.age} лет, ${person.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Person {
  final int id;
  final String name;
  final int age;
  final String city;
  final String avatar;
  final bool pending;
  const _Person(
    this.name,
    this.age,
    this.city,
    this.avatar, {
    this.id = 0,
    this.pending = false,
  });
}
