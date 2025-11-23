// lib/screens/market/tabs/things/things_content.dart
// Всё, что относится к вкладке «Вещи»: выбор категории, список, раскрытие карточек.

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../models/market_models.dart';
import 'widgets/market_things_card.dart';

class ThingsContent extends StatefulWidget {
  const ThingsContent({super.key});

  @override
  State<ThingsContent> createState() => _ThingsContentState();
}

class _ThingsContentState extends State<ThingsContent> {
  final List<String> _categories = const ['Все', 'Обувь', 'Часы'];
  String _selected = 'Все';

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final items = _applyFilters(_demoGoods);

    const headerCount = 1; // только селектор категории

    return ListView.separated(
      key: const ValueKey('things_list'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _CategoryDropdown(
            value: _selected,
            options: _categories,
            onChanged: (v) => setState(() => _selected = v ?? 'Все'),
          );
        }

        final i = index - headerCount;
        final isOpen = _expanded.contains(i);

        return GoodsCard(
          item: items[i],
          expanded: isOpen,
          onToggle: () => setState(() => _expanded.toggle(i)),
        );
      },
    );
  }

  // ————————————————— Фильтрация (только по категории) —————————————————

  List<GoodsItem> _applyFilters(List<GoodsItem> source) {
    return source.where((e) {
      if (_selected == 'Все') return true;
      return _categoryOf(e) == _selected;
    }).toList();
  }

  String _categoryOf(GoodsItem item) {
    final t = item.title.toLowerCase();
    if (t.contains('часы')) return 'Часы';
    return 'Обувь';
  }
}

// ————————————————— Внутренние UI-компоненты —————————————————

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownWidth = screenWidth * 0.3;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 4),
        child: SizedBox(
          width: dropdownWidth,
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            onChanged: onChanged,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Стрелка выпадающего меню
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            decoration: InputDecoration(
              isDense: true,
              // Убираем фон
              filled: false,
              contentPadding: const EdgeInsets.fromLTRB(0, 6, 16, 8),
              // Только нижняя подчеркивающая линия
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outline),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outline),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outline, width: 2),
              ),
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: options.map((o) {
              return DropdownMenuItem<String>(
                value: o,
                child: Text(
                  o,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ————————————————— Утилита: Set.toggle —————————————————
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

// ————————————————— ДЕМО-ДАННЫЕ (без фильтра по gender) —————————————————
final _demoGoods = <GoodsItem>[
  const GoodsItem(
    title: 'Трейловые кроссовки Ino8 Trailfly Ultra G300',
    images: [
      'assets/sneakers1_1.png',
      'assets/sneakers1_2.png',
      'assets/sneakers1_3.png',
    ],
    price: 12000,
    gender: Gender.male,
    city: 'Москва',
    description:
        'Размер евро 45 —29,5см по стельке.\n'
        'Личная встреча в Липецке или Москве, отправка Сдэком, Почтой, Авито-доставкой.\n'
        'Возможно привезти на Белые ночи или Кудыкину гору.',
  ),
  const GoodsItem(
    title: 'Salomon XT-Rush 2',
    images: [
      'assets/sneakers2_1.png',
      'assets/sneakers2_2.png',
      'assets/sneakers2_3.png',
      'assets/sneakers2_4.png',
      'assets/sneakers2_5.png',
    ],
    price: 10500,
    gender: Gender.female,
    city: 'Москва',
    description:
        'Размер 36,5 \n'
        'Куплены в Мюнхене, ни разу не носились.\n'
        'Передача по договоренности в Москве.',
  ),
  const GoodsItem(
    title: 'Часы Garmin Forerunner 255',
    images: ['assets/watch_1.png', 'assets/watch_2.png', 'assets/watch_3.png'],
    price: 20000,
    gender: Gender.female,
    city: 'Москва',
  ),
  const GoodsItem(
    title: 'Adidas Boston 11',
    images: [
      'assets/sneakers3_1.png',
      'assets/sneakers3_2.png',
      'assets/sneakers3_3.png',
      'assets/sneakers3_4.png',
    ],
    price: 10500,
    gender: Gender.female,
    city: 'Москва',
  ),
];
