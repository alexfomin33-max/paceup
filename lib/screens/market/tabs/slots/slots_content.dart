// lib/screens/market/tabs/slots/slots_content.dart
// Всё, что относится к вкладке «Слоты»: поиск, фильтрация, список, раскрытие карточек.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/text_styles.dart';
import '../../../../models/market_models.dart';
import 'widgets/market_slot_card.dart';

class SlotsContent extends StatefulWidget {
  const SlotsContent({super.key});

  @override
  State<SlotsContent> createState() => _SlotsContentState();
}

class _SlotsContentState extends State<SlotsContent> {
  // Поиск по названию события
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Раскрытые карточки (по индексу в текущем списке)
  final Set<int> _expanded = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _applyFilters(_demoItems);

    const headerCount = 1; // только строка поиска

    return ListView.separated(
      key: const ValueKey('slots_list'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length + headerCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _SearchField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          );
        }

        final i = index - headerCount;
        final isOpen = _expanded.contains(i);

        return MarketSlotCard(
          item: items[i],
          expanded: isOpen,
          onToggle: () => setState(() => _expanded.toggle(i)),
        );
      },
    );
  }

  // ————————————————— Фильтрация (только поиск по названию) —————————————————

  List<MarketItem> _applyFilters(List<MarketItem> source) {
    final q = _searchQuery;
    return source.where((e) {
      final okSearch = q.isEmpty || e.title.toLowerCase().contains(q);
      return okSearch;
    }).toList();
  }
}

// ————————————————— Внутренние UI-компоненты —————————————————

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Listener(
      // При повторном тапе на поле, если оно уже в фокусе, снимаем фокус
      onPointerDown: (_) {
        // Сохраняем состояние фокуса ДО обработки тапа TextField
        final wasFocused = widget.focusNode.hasFocus;

        // Если поле уже было в фокусе, снимаем фокус после обработки тапа
        if (wasFocused) {
          // Используем небольшую задержку, чтобы дать TextField обработать тап
          // (например, для установки курсора), затем снимаем фокус
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && widget.focusNode.hasFocus) {
              FocusScope.of(context).unfocus();
            }
          });
        }
      },
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 17,
          ),
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                  onPressed: widget.onClear,
                )
              : null,
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
    );
  }
}

// ————————————————— Утилита: Set.toggle —————————————————
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

// ————————————————— ДЕМО-ДАННЫЕ (без фильтра по gender) —————————————————
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
