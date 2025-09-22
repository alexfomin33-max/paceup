// lib/screens/market_screen.dart
// Экран "Маркет": две вкладки — «Слоты» и «Вещи».
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../models/market_models.dart';
import '../widgets/market_slot_card.dart';
import '../widgets/market_goods_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // Какая вкладка: 0 — «Слоты», 1 — «Вещи»
  int _segment = 0;

  // Поиск (используем только на вкладке «Слоты»)
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Фильтр по полу — общий для обеих вкладок (быстрые кнопки пола)
  Set<Gender> _filterGender = {Gender.female, Gender.male};

  // Категория для «Вещей» (вместо поиска)
  final List<String> _goodsCategories = const ['Все', 'Обувь', 'Часы'];
  String _selectedGoodsCategory = 'Все';

  // Наборы раскрытых карточек
  final Set<int> _expandedSlots = {};
  final Set<int> _expandedGoods = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Готовим отфильтрованные данные под каждую вкладку
    final slotItems = _applySlotFilters(_demoItems);
    final goodsItems = _applyGoodsFilters(_demoGoods);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1, // маленькая тень снизу
        shadowColor: Colors.black26,
        automaticallyImplyLeading: false,
        title: null,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Центр: табы «Слоты — Вещи»
                Center(
                  child: _TopTabs(
                    value: _segment,
                    onChanged: (v) => setState(() => _segment = v),
                    segments: const ['Слоты', 'Вещи'],
                  ),
                ),

                // Правый край: иконка "Продать"
                Positioned(
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: открыть экран добавления слота/вещи
                      print('Иконка Продать нажата');
                    },
                    child: const Icon(
                      CupertinoIcons.money_rubl_circle,
                      size: 26,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // 2) Весь контент — один ListView: «хедеры» (поиск/категория + кнопки пола) И карточки.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (_segment == 0)
            ? _buildSlotsList(slotItems)
            : _buildGoodsList(goodsItems),
      ),
    );
  }

  // ======================= СЛОТЫ =======================

  Widget _buildSlotsList(List<MarketItem> items) {
    // Два "служебных" элемента-хедера: 0 — поле поиска, 1 — кнопки пола.
    const int headerCount = 2;
    return ListView.separated(
      key: const ValueKey('slots'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          // 3) Поле поиска — белый фон, иконка, скроллится вместе со списком.
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
          // 4–5) Кнопки пола: порядок "Мужской" → "Женский", компактные + иконки.
          return _GenderQuickRow(
            // male first
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

        // Сами карточки слотов
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

  // ======================= ВЕЩИ =======================

  Widget _buildGoodsList(List<GoodsItem> items) {
    // Здесь тоже два "хедера":
    // 0 — выпадающий список (вместо поиска),
    // 1 — те же быстрые кнопки пола.
    const int headerCount = 2;
    return ListView.separated(
      key: const ValueKey('goods'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          // 6) Выпадающий список категорий (белый фон, скругления).
          return _CategoryDropdown(
            value: _selectedGoodsCategory,
            options: _goodsCategories,
            onChanged: (val) => setState(() {
              _selectedGoodsCategory = val ?? 'Все';
            }),
          );
        }
        if (index == 1) {
          // Те же быстрые кнопки пола под выпадающим списком
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

        // Карточки товаров
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

  // ======================= ФИЛЬТРАЦИЯ ДАННЫХ =======================

  // Слоты: фильтр по полу + поиск по названию (без сортировок и доступности, их мы убрали с модальным фильтром).
  List<MarketItem> _applySlotFilters(List<MarketItem> source) {
    final q = _searchQuery;
    return source.where((e) {
      final okGender = _filterGender.contains(e.gender);
      final okSearch = q.isEmpty || e.title.toLowerCase().contains(q);
      return okGender && okSearch;
    }).toList();
  }

  // Вещи: фильтр по полу + категория (выпадающий список).
  List<GoodsItem> _applyGoodsFilters(List<GoodsItem> source) {
    return source.where((e) {
      final okGender = _filterGender.contains(e.gender);
      final okCat = _selectedGoodsCategory == 'Все'
          ? true
          : _categoryOf(e) == _selectedGoodsCategory;
      return okGender && okCat;
    }).toList();
  }

  // Очень простая эвристика для категорий (для демо):
  // — если в названии есть "Часы" → "Часы"
  // — иначе считаем "Обувь" (кроссовки и т.п.)
  String _categoryOf(GoodsItem item) {
    final t = item.title.toLowerCase();
    if (t.contains('часы')) return 'Часы';
    return 'Обувь';
  }
}

/// ───────────────────────── UI: Табы ─────────────────────────
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
      ],
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
              color: isSelected ? Colors.black87 : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              segments[index],
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }),
    ),
  );
}

/// ───────────────────────── UI: Поле поиска ─────────────────────────
/// Белый фон, иконка лупы слева, крестик справа (очистить).
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
          color: AppColors.greytext,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        prefixIcon: const Icon(
          CupertinoIcons.search,
          size: 18,
          color: Colors.black54,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: Colors.black38,
                ),
                onPressed: onClear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
    );
  }
}

/// ───────────────────────── UI: Выпадающий список категорий ─────────────────────────
/// Белый фон, скругления, варианты из _goodsCategories.
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
      value: value,
      isExpanded: true,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
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

/// ───────────────────────── UI: Быстрые кнопки пола ─────────────────────────
/// Порядок: "Мужской" → "Женский". Компактные (ширина по содержимому), с иконками.
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
        _OvalToggle(
          label: 'Мужской',
          icon: Icons.male, // 5) иконка Марса (male)
          selected: maleSelected,
          onTap: onMaleTap,
        ),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          icon: Icons.female, // 5) иконка Венеры (female)
          selected: femaleSelected,
          onTap: onFemaleTap,
        ),
      ],
    );
  }
}

class _OvalToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OvalToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.secondary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Компактная ширина: ширина определяется содержимым + padding
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20), // овальная форма
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // важное: пусть под контент
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Удобное расширение: toggle() — если элемент есть, удалить; если нет — добавить.
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

/// ────────────────────── Д Е М О - Д А Н Н Ы Е ──────────────────────
/// Эти данные для примера. В реальном приложении подгружайте их из API.

final _demoItems = <MarketItem>[
  MarketItem(
    title: '«Ночь. Стрелка. Ярославль»',
    distance: '21,1 км',
    price: 3000,
    gender: Gender.female,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_1.png',
  ),
  MarketItem(
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
  MarketItem(
    title: 'Соревнования "Медный Всадник" SWIM',
    distance: '1 500 м',
    price: 5000,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_3.png',
  ),
  MarketItem(
    title: 'LUKA ULTRA BIKE г.Самара 2025',
    distance: '100 К',
    price: 6800,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_4.png',
  ),
  MarketItem(
    title: 'Минский полумарафон 2025',
    distance: '10 км',
    price: 3500,
    gender: Gender.female,
    buttonEnabled: false,
    buttonText: 'Бронь',
    locked: true,
    imageUrl: 'assets/slot_5.png',
  ),
  MarketItem(
    title: 'Полумарафон «Красная нить»',
    distance: '21,1 км',
    price: 2500,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: 'assets/slot_6.png',
  ),
  MarketItem(
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
  GoodsItem(
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
  GoodsItem(
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
  GoodsItem(
    title: 'Часы Garmin Forerunner 255',
    images: ['assets/watch_1.png', 'assets/watch_2.png', 'assets/watch_3.png'],
    price: 20000,
    gender: Gender.female,
    city: 'Москва',
  ),
  GoodsItem(
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
