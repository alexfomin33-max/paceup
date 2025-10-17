// Экран "Маркет": две вкладки — «Слоты» и «Вещи».
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/market_models.dart';
import 'tabs/slots/market_slot_card.dart';
import 'tabs/things/market_things_card.dart';
import 'state/sale_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  /// 0 — «Слоты», 1 — «Вещи»
  int _segment = 0;

  // Поиск (только для «Слоты»)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Быстрые кнопки пола (общие для обеих вкладок)
  final Set<Gender> _filterGender = {Gender.female, Gender.male};

  // Категории для «Вещей»
  final List<String> _goodsCategories = const ['Все', 'Обувь', 'Часы'];
  String _selectedGoodsCategory = 'Все';

  // Раскрытые карточки
  final Set<int> _expandedSlots = {};
  final Set<int> _expandedGoods = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotItems = _applySlotFilters(_demoItems);
    final goodsItems = _applyGoodsFilters(_demoGoods);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.shadowStrong,
        automaticallyImplyLeading: false,
        title: null,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: _TopTabs(
                    value: _segment,
                    onChanged: (v) => setState(() => _segment = v),
                    segments: const ['Слоты', 'Вещи'],
                  ),
                ),
                Positioned(
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        CupertinoPageRoute(builder: (_) => const SaleScreen()),
                      );
                    },

                    child: const Icon(
                      CupertinoIcons.money_rubl_circle,
                      size: 22,
                      color: AppColors.iconPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_segment == 0)
            ? _buildSlotsList(slotItems)
            : _buildGoodsList(goodsItems),
      ),
    );
  }

  // ───────────── СЛОТЫ ─────────────

  Widget _buildSlotsList(List<MarketItem> items) {
    const int headerCount = 2; // 0 — поиск, 1 — кнопки пола
    return ListView.separated(
      key: const ValueKey('slots'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _SearchField(
            controller: _searchCtrl,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          );
        }
        if (index == 1) {
          return _GenderQuickRow(
            maleSelected: _filterGender.contains(Gender.male),
            femaleSelected: _filterGender.contains(Gender.female),
            onMaleTap: () {
              setState(() {
                _filterGender.toggle(Gender.male);
                if (_filterGender.isEmpty) _filterGender.add(Gender.male);
              });
            },
            onFemaleTap: () {
              setState(() {
                _filterGender.toggle(Gender.female);
                if (_filterGender.isEmpty) _filterGender.add(Gender.female);
              });
            },
          );
        }

        final i = index - headerCount;
        final isOpen = _expandedSlots.contains(i);
        return MarketSlotCard(
          item: items[i],
          expanded: isOpen,
          onToggle: () => setState(() => _expandedSlots.toggle(i)),
        );
      },
    );
  }

  // ───────────── ВЕЩИ ─────────────

  Widget _buildGoodsList(List<GoodsItem> items) {
    const int headerCount = 2; // 0 — категория, 1 — кнопки пола
    return ListView.separated(
      key: const ValueKey('goods'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _CategoryDropdown(
            value: _selectedGoodsCategory,
            options: _goodsCategories,
            onChanged: (val) => setState(() {
              _selectedGoodsCategory = val ?? 'Все';
            }),
          );
        }
        if (index == 1) {
          return _GenderQuickRow(
            maleSelected: _filterGender.contains(Gender.male),
            femaleSelected: _filterGender.contains(Gender.female),
            onMaleTap: () {
              setState(() {
                _filterGender.toggle(Gender.male);
                if (_filterGender.isEmpty) _filterGender.add(Gender.male);
              });
            },
            onFemaleTap: () {
              setState(() {
                _filterGender.toggle(Gender.female);
                if (_filterGender.isEmpty) _filterGender.add(Gender.female);
              });
            },
          );
        }

        final i = index - headerCount;
        final isOpen = _expandedGoods.contains(i);
        return GoodsCard(
          item: items[i],
          expanded: isOpen,
          onToggle: () => setState(() => _expandedGoods.toggle(i)),
        );
      },
    );
  }

  // ───────────── Фильтрация ─────────────

  List<MarketItem> _applySlotFilters(List<MarketItem> source) {
    final q = _searchQuery;
    return source.where((e) {
      final okGender = _filterGender.contains(e.gender);
      final okSearch = q.isEmpty || e.title.toLowerCase().contains(q);
      return okGender && okSearch;
    }).toList();
  }

  List<GoodsItem> _applyGoodsFilters(List<GoodsItem> source) {
    return source.where((e) {
      final okGender = _filterGender.contains(e.gender);
      final okCat = _selectedGoodsCategory == 'Все'
          ? true
          : _categoryOf(e) == _selectedGoodsCategory;
      return okGender && okCat;
    }).toList();
  }

  String _categoryOf(GoodsItem item) {
    final t = item.title.toLowerCase();
    if (t.contains('часы')) return 'Часы';
    return 'Обувь';
  }
}

// ───────────── UI Подкомпоненты ─────────────

class _TopTabs extends StatelessWidget {
  final int value;
  final List<String> segments;
  final ValueChanged<int> onChanged;

  const _TopTabs({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: const Border(
        top: BorderSide(
          color: AppColors.border, // тонкая линия сверху
          width: 0.5,
        ),
        bottom: BorderSide(
          color: AppColors.border, // тонкая линия снизу
          width: 0.5,
        ),
        left: BorderSide(color: AppColors.border, width: 0.5),
        right: BorderSide(color: AppColors.border, width: 0.5),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(segments.length, (index) {
        final isSelected = value == index;
        return GestureDetector(
          onTap: () => onChanged(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              segments[index],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? AppColors.surface : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: const Icon(
          CupertinoIcons.search,
          size: 18,
          color: AppColors.iconSecondary,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: AppColors.iconTertiary,
                ),
                onPressed: onClear,
              )
            : null,
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
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
    );
  }
}

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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
      items: options
          .map(
            (o) => DropdownMenuItem<String>(
              value: o,
              child: Text(o, style: const TextStyle(fontFamily: 'Inter')),
            ),
          )
          .toList(),
    );
  }
}

class _GenderQuickRow extends StatelessWidget {
  final bool maleSelected;
  final bool femaleSelected;
  final VoidCallback onMaleTap;
  final VoidCallback onFemaleTap;

  const _GenderQuickRow({
    required this.maleSelected,
    required this.femaleSelected,
    required this.onMaleTap,
    required this.onFemaleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OvalToggle(label: 'Мужской', selected: maleSelected, onTap: onMaleTap),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          selected: femaleSelected,
          onTap: onFemaleTap,
        ),
      ],
    );
  }
}

class _OvalToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OvalToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.brandPrimary : AppColors.surface;
    final fg = selected ? AppColors.surface : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// Удобное расширение: toggle() — если элемент есть, удалить; если нет — добавить.
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

// ───────────── ДЕМО-ДАННЫЕ ─────────────

final _demoItems = <MarketItem>[
  const MarketItem(
    title: '«Ночь. Стрелка. Ярославль»',
    distance: '21,1 км',
    price: 3000,
    gender: Gender.female,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_1.png',
  ),
  const MarketItem(
    title: 'Марафон "Алые Паруса"',
    distance: '42,2 км',
    price: 4500,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_2.png',
    dateText: '25 мая 2025, 09:00',
    placeText: 'Санкт-Петербург',
    typeText: 'Марафон',
  ),
  const MarketItem(
    title: 'Соревнования "Медный Всадник" SWIM',
    distance: '1 500 м',
    price: 5000,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_3.png',
  ),
  const MarketItem(
    title: 'LUKA ULTRA BIKE г.Самара 2025',
    distance: '100 К',
    price: 6800,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_4.png',
  ),
  const MarketItem(
    title: 'Минский полумарафон 2025',
    distance: '10 км',
    price: 3500,
    gender: Gender.female,
    buttonEnabled: false,
    buttonText: 'Бронь',
    locked: true,
    imageUrl: 'assets/slot_5.png',
  ),
  const MarketItem(
    title: 'Полумарафон «Красная нить»',
    distance: '21,1 км',
    price: 2500,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_6.png',
  ),
  const MarketItem(
    title: 'Женский забег "Медный Всадник"',
    distance: '5 км',
    price: 2200,
    gender: Gender.female,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_7.png',
  ),
];

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
