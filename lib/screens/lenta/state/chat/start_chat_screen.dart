import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/transparent_route.dart';
import 'personal_chat_screen.dart';

/// Страница для начала нового чата с поиском пользователей
class StartChatScreen extends StatefulWidget {
  const StartChatScreen({super.key});

  @override
  State<StartChatScreen> createState() => _StartChatScreenState();
}

class _StartChatScreenState extends State<StartChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const PaceAppBar(title: 'Начать общение'),
        body: Column(
          children: [
            // ─── Поле поиска ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: _SearchField(
                controller: _searchController,
                hintText: 'Поиск пользователей',
              ),
            ),

            // ─── Список людей ───
            Expanded(child: _PeopleList(query: _query)),
          ],
        ),
      ),
    );
  }
}

/// ─── Виджет поля поиска ───
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.textPrimary,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: AppColors.textPlaceholder,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.outline, width: 1.2),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
      ),
    );
  }
}

/// ─── Список людей ───
class _PeopleList extends StatelessWidget {
  final String query;

  const _PeopleList({required this.query});

  // Временный список людей (заменить на данные из API)
  static const _people = <_Person>[
    _Person(1, 'Алексей Лукашин', 35, 'Владимир', 'assets/avatar_1.png'),
    _Person(2, 'Татьяна Свиридова', 39, 'Владимир', 'assets/avatar_3.png'),
    _Person(3, 'Борис Жарких', 40, 'Владимир', 'assets/avatar_2.png'),
    _Person(4, 'Юрий Селиванов', 37, 'Москва', 'assets/avatar_5.png'),
    _Person(
      5,
      'Екатерина Виноградова',
      30,
      'Санкт-Петербург',
      'assets/avatar_4.png',
    ),
    _Person(6, 'Анастасия Бутузова', 35, 'Ярославль', 'assets/avatar_9.png'),
  ];

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = q.isEmpty
        ? _people
        : _people
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.city.toLowerCase().contains(q),
              )
              .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Табличный блок
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final p = items[i];
                return Column(
                  children: [
                    if (i.isEven)
                      ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: _RowTile(person: p),
                      )
                    else
                      _RowTile(person: p),
                  ],
                );
              }),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// ─── Строка в списке людей ───
class _RowTile extends StatelessWidget {
  final _Person person;

  const _RowTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // Открываем персональный чат
        final result = await Navigator.of(context).push(
          TransparentPageRoute(
            builder: (_) => PersonalChatScreen(
              chatId: 0, // Новый чат, будет создан на сервере
              userId: person.id,
              userName: person.name,
              userAvatar: person.avatar,
            ),
          ),
        );

        // Возвращаемся назад после создания чата
        if (result == true && context.mounted) {
          Navigator.of(context).pop(true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                person.avatar,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, __) => Container(
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
            IconButton(
              tooltip: 'Написать',
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.pencil,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  TransparentPageRoute(
                    builder: (_) => PersonalChatScreen(
                      chatId: 0,
                      userId: person.id,
                      userName: person.name,
                      userAvatar: person.avatar,
                    ),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Модель человека ───
class _Person {
  final int id;
  final String name;
  final int age;
  final String city;
  final String avatar;

  const _Person(this.id, this.name, this.age, this.city, this.avatar);
}
