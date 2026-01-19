import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../together_providers.dart';

class MemberContent extends ConsumerWidget {
  final int activityId;

  const MemberContent({
    super.key,
    required this.activityId,
  });

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
        // ────────────────────────────────────────────────────────────────────
        // ВАЖНО: дизайн оставляем тем же, меняем только источник данных
        // ────────────────────────────────────────────────────────────────────
        final uiMembers = members
            .map(
              (m) => _Person(
                m.fullName,
                m.age,
                m.city,
                m.avatar,
              ),
            )
            .toList(growable: false);

        return Column(
          children: [
            // Табличный блок как в subscriptions_content.dart
            Container(
              width: double.infinity, // ← добавили
              decoration: const BoxDecoration(
                color: AppColors.surface,
              ),
              child: Column(
                children: List.generate(uiMembers.length, (i) {
                  final p = uiMembers[i];
                  return Column(
                    children: [
                      _RowTile(
                        person: p,
                        trailing: const SizedBox.shrink(), // без правой кнопки
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Кнопка «Покинуть группу»
            SizedBox(
              height: 44,
              width: 200,
              child: OutlinedButton(
                onPressed: () async {
                  // ─────────────────────────────────────────────────────────
                  // ✅ Выходим из группы, но тренировка у пользователя сохраняется
                  // (мы только снимаем участие в группе)
                  // ─────────────────────────────────────────────────────────
                  try {
                    final api = ref.read(togetherApiProvider);
                    await api.leaveGroup(activityId: activityId);
                    ref.invalidate(togetherMembersProvider(activityId));
                  } catch (_) {
                    // Ошибку показываем выше через перезагрузку провайдера (при необходимости)
                    ref.invalidate(togetherMembersProvider(activityId));
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide.none,
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.backgroundRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                ),
                child: const Text(
                  'Покинуть группу',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
  final String name;
  final int age;
  final String city;
  final String avatar;
  const _Person(this.name, this.age, this.city, this.avatar);
}
