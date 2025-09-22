// lib/screens/market_screen.dart
// Экран "Маркет": две вкладки — «Слоты» и «Вещи».
// Здесь только логика экрана: переключение вкладок, фильтры, списки и демо-данные.
// Сами карточки (слота и товара) вынесены в отдельные виджеты и импортируются ниже.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Модели и виджеты карточек (мы их вынесли из экрана в отдельные файлы)
import '../models/market_models.dart';
import '../widgets/market_slot_card.dart';
import '../widgets/market_goods_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // Какую вкладку показываем: 0 — «Слоты», 1 — «Вещи»
  int _segment = 0;

  // Параметры фильтрации (применяются только к «Слотам»)
  Set<Gender> _filterGender = {Gender.female, Gender.male}; // показывать Ж и М
  bool _onlyAvailable = false; // если true — показывать только доступные слоты
  SortMode _sort = SortMode.relevance; // сортировка

  // Наборы «раскрытых» карточек (индексы элементов списка)
  // Храним отдельно для слотов и для вещей
  final Set<int> _expandedSlots = {};
  final Set<int> _expandedGoods = {};

  @override
  Widget build(BuildContext context) {
    // Применяем фильтры и сортировку к исходным демо-данным (только для слотов)
    final slotItems = _applyFilters(_demoItems);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        // Кнопка слева — открывает фильтры (работают только для «Слоты»)
        leading: _RoundIconButton(
          icon: CupertinoIcons.slider_horizontal_3,
          onPressed: _openFilters,
        ),
        // Заголовок — наши «табы» (визуальные переключатели)
        title: _TopTabs(
          value: _segment,
          onChanged: (v) => setState(() => _segment = v), // переключаем вкладку
          segments: const ['Слоты', 'Вещи'],
        ),
        centerTitle: true,
        // Правая иконка — резерв (пока без действия)
        actions: [
          _RoundIconButton(
            icon: CupertinoIcons.slider_horizontal_below_rectangle,
            onPressed: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),

      // AnimatedSwitcher красиво анимирует смену целого списка при переключении вкладки
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // Если выбрана вкладка «Слоты» (0) — рисуем список слотов,
        // иначе — список товаров («Вещи»)
        child: (_segment == 0)
            ? ListView.separated(
                key: const ValueKey(
                  'slots',
                ), // ключ, чтобы AnimatedSwitcher понимал: это другой список
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                itemCount: slotItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final isOpen = _expandedSlots.contains(
                    i,
                  ); // раскрыта ли карточка с индексом i
                  return MarketSlotCard(
                    item: slotItems[i], // данные слота
                    expanded: isOpen, // флаг «раскрыто»
                    onToggle: () {
                      // переключить раскрытие
                      setState(() {
                        _expandedSlots.toggle(i);
                      });
                    },
                  );
                },
              )
            : ListView.separated(
                key: const ValueKey('goods'),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                itemCount: _demoGoods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final isOpen = _expandedGoods.contains(i);
                  return GoodsCard(
                    item: _demoGoods[i], // данные товара
                    expanded: isOpen,
                    onToggle: () {
                      setState(() {
                        _expandedGoods.toggle(i);
                      });
                    },
                  );
                },
              ),
      ),
    );
  }

  // Применяем фильтры и сортировку к списку слотов.
  // Вещи (_demoGoods) сейчас не фильтруем — по ТЗ фильтры только для «Слоты».
  List<MarketItem> _applyFilters(List<MarketItem> source) {
    // 1) фильтруем по полу и доступности
    var list = source.where((e) {
      final okGender = _filterGender.contains(e.gender); // подходит ли пол
      final okAvail =
          !_onlyAvailable ||
          e.buttonEnabled; // если нужен только доступный — проверяем
      return okGender && okAvail;
    }).toList();

    // 2) сортируем по выбранному режиму
    switch (_sort) {
      case SortMode.relevance:
        // «По релевантности» — ничего не делаем (оригинальный порядок)
        break;
      case SortMode.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortMode.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    return list;
  }

  // Открываем модальное окно с фильтрами (нижний лист).
  // ВАЖНО: если выбран раздел «Вещи», фильтры не открываем (по ТЗ).
  Future<void> _openFilters() async {
    if (_segment == 1) return; // фильтры только для «Слоты»

    final result = await showModalBottomSheet<_FiltersResult>(
      context: context,
      useSafeArea: true, // учитывать вырезы/панели
      isScrollControlled: true, // лист может быть высоким
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Передаём текущие значения в форму фильтров
      builder: (_) => _FiltersSheet(
        gender: _filterGender,
        onlyAvailable: _onlyAvailable,
        sort: _sort,
      ),
    );

    // Если пользователь нажал «Применить» — придут новые значения
    if (result != null) {
      setState(() {
        _filterGender = result.gender;
        _onlyAvailable = result.onlyAvailable;
        _sort = result.sort;
      });
    }
  }
}

/// ────────────────────── Верхняя панель и фильтры (оставим здесь) ──────────────────────

/// Маленькая круглая кнопка-иконка для AppBar
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: InkWell(
      customBorder: const CircleBorder(), // круглая форма для эффекта нажатия
      onTap: onPressed,
      child: Icon(icon, size: 20, color: AppColors.secondary),
    ),
  );
}

/// Переключатель вкладок «Слоты/Вещи» (простой кастомный таббар)
class _TopTabs extends StatelessWidget {
  final int value; // выбранный индекс вкладки
  final List<String> segments; // подписи вкладок
  final ValueChanged<int> onChanged; // колбэк при нажатии

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
        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(segments.length, (index) {
        final isSelected = value == index;
        return GestureDetector(
          onTap: () => onChanged(index), // переключаем вкладку
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

/// Результат работы листа фильтров — три значения, которые мы возвращаем на экран
class _FiltersResult {
  final Set<Gender> gender;
  final bool onlyAvailable;
  final SortMode sort;
  _FiltersResult(this.gender, this.onlyAvailable, this.sort);
}

/// Внутренний StatefulWidget — сам лист с UI фильтров
class _FiltersSheet extends StatefulWidget {
  final Set<Gender> gender; // стартовые значения «Пол»
  final bool onlyAvailable; // стартовое значение «Только доступные»
  final SortMode sort; // стартовая сортировка

  const _FiltersSheet({
    required this.gender,
    required this.onlyAvailable,
    required this.sort,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  // Локальные копии значений (редактируем их в форме)
  late Set<Gender> _gender;
  late bool _onlyAvailable;
  late SortMode _sort;

  @override
  void initState() {
    super.initState();
    // Делаем копии, чтобы пока пользователь крутит чекбоксы — не менять экран
    _gender = {...widget.gender};
    _onlyAvailable = widget.onlyAvailable;
    _sort = widget.sort;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Нужен отступ снизу на случай, если открыта клавиатура (вдруг будет форма)
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // высота = по контенту
        children: [
          const SizedBox(height: 8),
          // Маленькая серенькая полоска — «ручка» для перетаскивания листа
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E4EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Фильтры',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDEFF3)),

          // Содержимое фильтров
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Блок «Пол»
                const Text(
                  'Пол',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    // Чип «Ж»
                    _toggleChip(
                      'Ж',
                      _gender.contains(Gender.female),
                      () => setState(() => _gender.toggle(Gender.female)),
                    ),
                    // Чип «М»
                    _toggleChip(
                      'М',
                      _gender.contains(Gender.male),
                      () => setState(() => _gender.toggle(Gender.male)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Чекбокс «Только доступные»
                Row(
                  children: [
                    Checkbox(
                      value: _onlyAvailable,
                      onChanged: (v) =>
                          setState(() => _onlyAvailable = v ?? false),
                      side: const BorderSide(color: AppColors.border),
                      activeColor: AppColors.secondary,
                    ),
                    const Text(
                      'Только доступные',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Выбор сортировки
                const Text(
                  'Сортировка',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SortMode>(
                  initialValue: _sort,
                  onChanged: (v) =>
                      setState(() => _sort = v ?? SortMode.relevance),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SortMode.relevance,
                      child: Text('По релевантности'),
                    ),
                    DropdownMenuItem(
                      value: SortMode.priceAsc,
                      child: Text('Цена по возрастанию'),
                    ),
                    DropdownMenuItem(
                      value: SortMode.priceDesc,
                      child: Text('Цена по убыванию'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEDEFF3)),

          // Кнопки снизу: «Отмена» и «Применить»
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                // Отмена — просто закрыть лист без возврата результата
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Применить — возвращаем выбранные значения на экран через Navigator.pop(result)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _FiltersResult(_gender, _onlyAvailable, _sort),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Маленький самодельный «чип»-переключатель (Ж/М)
  Widget _toggleChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, // переключаем состояние
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

// Удобное расширение для Set: toggle() — если есть элемент, удалить; если нет — добавить.
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

/// ────────────────────── ДЕМО-ДАННЫЕ (оставим в экране) ──────────────────────
/// Эти данные просто для примера. В реальном приложении вы будете подгружать их с сервера.

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
