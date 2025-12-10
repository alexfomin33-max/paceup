import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // TODO: вернуть при реализации загрузки городов
// import 'dart:async';
// import '../../../../../providers/services/api_provider.dart'; // TODO: вернуть при реализации загрузки городов

/// Возвращает список сливеров для вкладки «Общая»
List<Widget> buildGeneralStatsSlivers() {
  return [
    SliverToBoxAdapter(child: _GeneralContent()),
    const SliverToBoxAdapter(child: SizedBox(height: 18)),
  ];
}

class _GeneralContent extends StatefulWidget {
  const _GeneralContent();
  @override
  State<_GeneralContent> createState() => _GeneralContentState();
}

class _GeneralContentState extends State<_GeneralContent> {
  // Фильтр пользователей
  static const _userFilters = ['Подписки', 'Город', 'Все пользователи'];
  String _userFilter = 'Все пользователи';

  // Параметры статистики
  static const _parameters = [
    'Расстояние',
    'Тренировок',
    'Общее время',
    'Набор высоты',
    'Средний темп',
    'Средний пульс',
  ];
  String _parameter = 'Расстояние';

  // Вид спорта: 0 бег, 1 вело, 2 плавание (single-select)
  int _sport = 0;

  // ── поле города
  final cityCtrl = TextEditingController();

  @override
  void dispose() {
    cityCtrl.dispose();
    super.dispose();
  }

  // TODO: Загрузка списка городов из БД через API (реализуем позже)
  // /// Загрузка списка городов из БД через API
  // Future<void> _loadCities() async {
  //   try {
  //     final api = ref.read(apiServiceProvider);
  //     final data = await api
  //         .get('/get_cities.php')
  //         .timeout(
  //           const Duration(seconds: 5),
  //           onTimeout: () {
  //             throw TimeoutException(
  //               'Превышено время ожидания загрузки городов',
  //             );
  //           },
  //         );
  //
  //     if (data['success'] == true && data['cities'] != null) {
  //       final cities = data['cities'] as List<dynamic>? ?? [];
  //       if (mounted) {
  //         setState(() {
  //           _cities = cities.map((city) => city.toString()).toList();
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     // В случае ошибки оставляем пустой список
  //     // Пользователь все равно сможет ввести город вручную
  //     // Ошибка не критична, так как автокомплит работает и без списка
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Верхняя строка: фильтр пользователей + иконки спорта
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _DropdownField<String>(
                value: _userFilter,
                items: _userFilters,
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _userFilter) {
                    setState(() {
                      _userFilter = newValue;
                      // Очищаем поле города при смене фильтра
                      if (newValue != 'Город') {
                        cityCtrl.clear();
                      }
                    });
                  }
                },
              ),
              const Spacer(),
              _SportIcon(
                selected: _sport == 0,
                icon: Icons.directions_run,
                onTap: () => setState(() => _sport = 0),
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 1,
                icon: Icons.directions_bike,
                onTap: () => setState(() => _sport = 1),
              ),
              const SizedBox(width: 8),
              _SportIcon(
                selected: _sport == 2,
                icon: Icons.pool,
                onTap: () => setState(() => _sport = 2),
              ),
            ],
          ),
        ),
        // ── Поле поиска города (показывается только при выборе "Город")
        if (_userFilter == 'Город') ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: cityCtrl,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.getTextPrimaryColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'Введите город',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextPlaceholderColor(context),
                ),
                filled: true,
                fillColor: AppColors.getSurfaceColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: AppColors.getBorderColor(context),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: AppColors.getBorderColor(context),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: AppColors.getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
        // ── Выпадающий список параметров (показывается всегда)
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _DropdownField<String>(
            value: _parameter,
            items: _parameters,
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _parameter) {
                setState(() => _parameter = newValue);
              }
            },
          ),
        ),
        // ── Таблица рейтинга
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: _SectionTitle('Рейтинг'),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            border: Border(
              top: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: List.generate(_rows.length, (i) {
              final r = _rows[i];
              final isMe = r.rank == 4;
              return _FriendRow(
                rank: r.rank,
                name: r.name,
                value: r.value,
                avatar: r.avatar,
                highlight: isMe,
                isLast: i == _rows.length - 1,
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ───── UI helpers

// ── переиспользуемый выпадающий список
class _DropdownField<T extends String> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final double? minWidth;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minWidth != null
          ? BoxConstraints(minWidth: minWidth!)
          : const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.7,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(
            CupertinoIcons.chevron_down,
            size: 14,
            color: AppColors.getIconPrimaryColor(context),
          ),
          dropdownColor: AppColors.getSurfaceColor(context),
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.getTextPrimaryColor(context),
          ),
          onChanged: onChanged,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.getTextPrimaryColor(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SportIcon extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _SportIcon({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary
              : AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? AppColors.getSurfaceColor(context)
              : AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.getTextSecondaryColor(context)
            : AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  final bool highlight;
  final bool isLast;

  const _FriendRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatar,
    required this.highlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: highlight
                    ? AppColors.success
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: Image(
              image: avatar,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: highlight
                  ? AppColors.success
                  : AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),
      ],
    );
  }
}

// Демо-данные для таблицы
class _RowData {
  final int rank;
  final String name;
  final String value;
  final AssetImage avatar;
  const _RowData(this.rank, this.name, this.value, this.avatar);
}

const _rows = <_RowData>[
  _RowData(1, 'Алексей Лукашин', '272,8', AssetImage('assets/avatar_1.png')),
  _RowData(2, 'Татьяна Свиридова', '214,7', AssetImage('assets/avatar_3.png')),
  _RowData(3, 'Борис Жарких', '197,2', AssetImage('assets/avatar_2.png')),
  _RowData(4, 'Евгений Бойко', '145,8', AssetImage('assets/avatar_0.png')),
  _RowData(
    5,
    'Екатерина Виноградова',
    '108,5',
    AssetImage('assets/avatar_4.png'),
  ),
  _RowData(6, 'Юрий Селиванов', '96,4', AssetImage('assets/avatar_5.png')),
];
