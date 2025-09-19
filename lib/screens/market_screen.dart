import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  int _segment = 0;

  // фильтры
  Set<Gender> _filterGender = {Gender.female, Gender.male, Gender.both};
  bool _onlyAvailable = false;
  SortMode _sort = SortMode.relevance;

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final items = _applyFilters(_demoItems);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _MarketTopBar(
              segment: _segment,
              onChanged: (v) => setState(() => _segment = v),
              onLeftAction: _openFilters, // ← фильтры снизу
              onRightAction: () {}, // можно будет повесить ещё действие
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isOpen = _expanded.contains(i);
                  return _MarketCard(
                    item: item,
                    expanded: isOpen,
                    onToggle: () {
                      setState(() {
                        isOpen ? _expanded.remove(i) : _expanded.add(i);
                      });
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MarketItem> _applyFilters(List<MarketItem> source) {
    var list = source.where((e) {
      final okGender = _filterGender.contains(e.gender);
      final okAvail = !_onlyAvailable || e.buttonEnabled;
      return okGender && okAvail;
    }).toList();

    switch (_sort) {
      case SortMode.relevance:
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

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FiltersResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FiltersSheet(
        gender: _filterGender,
        onlyAvailable: _onlyAvailable,
        sort: _sort,
      ),
    );

    if (result != null) {
      setState(() {
        _filterGender = result.gender;
        _onlyAvailable = result.onlyAvailable;
        _sort = result.sort;
      });
    }
  }
}

/// ──────────────────────────────── TOP BAR ────────────────────────────────
class _MarketTopBar extends StatelessWidget {
  final int segment;
  final ValueChanged<int> onChanged;
  final VoidCallback onLeftAction;
  final VoidCallback onRightAction;

  const _MarketTopBar({
    required this.segment,
    required this.onChanged,
    required this.onLeftAction,
    required this.onRightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          _CircleGlassButton(
            icon: CupertinoIcons.slider_horizontal_3, // фильтры
            onTap: onLeftAction,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SegmentGlass(
              value: segment,
              onChanged: onChanged,
              segments: const {0: 'Слоты', 1: 'Вещи'},
            ),
          ),
          const SizedBox(width: 8),
          _CircleGlassButton(
            icon: CupertinoIcons.slider_horizontal_below_rectangle,
            onTap: onRightAction,
          ),
        ],
      ),
    );
  }
}

class _CircleGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleGlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      ),
    );
  }
}

class _SegmentGlass extends StatelessWidget {
  final Map<int, String> segments;
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentGlass({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: segments.entries.map((e) {
          final selected = value == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.text
                          : AppColors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ──────────────────────────────── CARD ────────────────────────────────
class _MarketCard extends StatelessWidget {
  final MarketItem item;
  final bool expanded;
  final VoidCallback onToggle;

  const _MarketCard({
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent, // нужен Material для InkWell
          child: InkWell(
            borderRadius: radius,
            onTap: onToggle, // ← ТАП ПО ЛЮБОМУ МЕСТУ КАРТОЧКИ
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  // верхняя строка
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumb(imageUrl: item.imageUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Заголовок + стрелка
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Стрелка оставляем — она тоже будет работать
                                GestureDetector(
                                  onTap: onToggle,
                                  child: AnimatedRotation(
                                    duration: const Duration(milliseconds: 150),
                                    turns: expanded ? 0.5 : 0.0, // down -> up
                                    child: Icon(
                                      CupertinoIcons.chevron_down,
                                      size: 18,
                                      color: AppColors.text.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Чипы
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _ChipPill(
                                  text: item.distance,
                                  icon: CupertinoIcons.location,
                                ),
                                _ChipPill(
                                  text: item.gender == Gender.female
                                      ? 'Ж'
                                      : item.gender == Gender.male
                                      ? 'М'
                                      : 'Ж/М',
                                  icon: CupertinoIcons.person_2,
                                  light: true,
                                ),
                                _ChipPrice(text: _formatPrice(item.price)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Кнопка справа — свой обработчик; нажатие по ней
                      // НЕ вызовет onTap у InkWell (карточки)
                      SizedBox(
                        width: 92,
                        child: _BuyButton(
                          text: item.buttonText,
                          enabled: item.buttonEnabled,
                          locked: item.locked,
                          onTap: () {
                            // TODO: действие покупки/брони
                          },
                        ),
                      ),
                    ],
                  ),

                  // детали (раскрывашка)
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _DetailsBlock(item: item),
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    // 5000 -> 5 000 ₽
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buf.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buf.write(' ');
    }
    return '${buf.toString()} ₽';
  }
}

class _DetailsBlock extends StatelessWidget {
  final MarketItem item;

  const _DetailsBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      color: Colors.black,
    );

    Widget row(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: textStyle)),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(CupertinoIcons.calendar, item.dateText ?? 'Дата: уточняется'),
          const SizedBox(height: 6),
          row(
            CupertinoIcons.map_pin_ellipse,
            item.placeText ?? 'Место: уточняется',
          ),
          const SizedBox(height: 6),
          row(CupertinoIcons.tag, item.typeText ?? 'Тип: забег'),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: перейти на экран слота/деталей
              },
              icon: const Icon(CupertinoIcons.info, size: 16),
              label: const Text(
                'Подробнее',
                style: TextStyle(fontFamily: 'Inter'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String imageUrl;

  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        image: imageUrl.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: imageUrl.isEmpty
          ? Icon(
              CupertinoIcons.photo,
              color: AppColors.text.withValues(alpha: 0.4),
            )
          : null,
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool light;

  const _ChipPill({required this.text, this.icon, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF6F7F9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.text.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPrice extends StatelessWidget {
  final String text;

  const _ChipPrice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8C6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC8A)),
      ),
      child: const Center(
        child: Text(
          // текст задаётся выше через _formatPrice
          '',
        ),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final bool locked;
  final VoidCallback onTap;

  const _BuyButton({
    required this.text,
    required this.enabled,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? AppColors.primary : Colors.grey.shade300;
    final fg = enabled ? Colors.white : Colors.grey.shade700;

    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          locked ? CupertinoIcons.lock : CupertinoIcons.cart,
          size: 16,
        ),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// ──────────────────────────────── FILTER SHEET ────────────────────────────────
enum SortMode { relevance, priceAsc, priceDesc }

class _FiltersResult {
  final Set<Gender> gender;
  final bool onlyAvailable;
  final SortMode sort;

  _FiltersResult(this.gender, this.onlyAvailable, this.sort);
}

class _FiltersSheet extends StatefulWidget {
  final Set<Gender> gender;
  final bool onlyAvailable;
  final SortMode sort;

  const _FiltersSheet({
    required this.gender,
    required this.onlyAvailable,
    required this.sort,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Set<Gender> _gender;
  late bool _onlyAvailable;
  late SortMode _sort;

  @override
  void initState() {
    super.initState();
    _gender = {...widget.gender};
    _onlyAvailable = widget.onlyAvailable;
    _sort = widget.sort;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    _toggleChip('Ж', _gender.contains(Gender.female), () {
                      setState(() => _gender.toggle(Gender.female));
                    }),
                    _toggleChip('М', _gender.contains(Gender.male), () {
                      setState(() => _gender.toggle(Gender.male));
                    }),
                    _toggleChip('Ж/М', _gender.contains(Gender.both), () {
                      setState(() => _gender.toggle(Gender.both));
                    }),
                  ],
                ),
                const SizedBox(height: 16),
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
                  value: _sort,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
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

  Widget _toggleChip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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

/// ──────────────────────────────── DATA ────────────────────────────────
enum Gender { female, male, both }

class MarketItem {
  final String title;
  final String distance; // "21,1 км"
  final int price; // 3000
  final Gender gender;
  final bool buttonEnabled;
  final String buttonText; // "Купить" / "Бронь"
  final bool locked; // для "Бронь" с замком
  final String imageUrl;

  // для деталей
  final String? dateText;
  final String? placeText;
  final String? typeText;

  MarketItem({
    required this.title,
    required this.distance,
    required this.price,
    required this.gender,
    required this.buttonEnabled,
    required this.buttonText,
    required this.locked,
    required this.imageUrl,
    this.dateText,
    this.placeText,
    this.typeText,
  });
}

extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}

/// демо-данные
final _demoItems = <MarketItem>[
  MarketItem(
    title: '«Ночь. Стрелка. Ярославль»',
    distance: '21,1 км',
    price: 3000,
    gender: Gender.female,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: '',
    dateText: '12 июля 2025, 21:00',
    placeText: 'Ярославль, набережная',
    typeText: 'Полумарафон',
  ),
  MarketItem(
    title: 'Марафон "Алые Паруса"',
    distance: '42,2 км',
    price: 4500,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: '',
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
    imageUrl: '',
    dateText: '7 июня 2025, 10:00',
    placeText: 'СПб, Гребной канал',
    typeText: 'Плавание',
  ),
  MarketItem(
    title: 'LUKA ULTRA BIKE г.Самара 2025',
    distance: '100 К',
    price: 6800,
    gender: Gender.both,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: '',
    dateText: '1 июня 2025, 08:00',
    placeText: 'Самара',
    typeText: 'Велогонка',
  ),
  MarketItem(
    title: 'Минский полумарафон 2025',
    distance: '10 км',
    price: 3500,
    gender: Gender.female,
    buttonEnabled: false,
    buttonText: 'Бронь',
    locked: true,
    imageUrl: '',
    dateText: '14 сентября 2025, 10:00',
    placeText: 'Минск',
    typeText: 'Полумарафон',
  ),
  MarketItem(
    title: 'Полумарафон «Красная нить»',
    distance: '21,1 км',
    price: 2500,
    gender: Gender.male,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: '',
    dateText: '6 июля 2025, 10:00',
    placeText: 'Москва',
    typeText: 'Полумарафон',
  ),
  MarketItem(
    title: 'Женский забег "Медный Всадник"',
    distance: '5 км',
    price: 2200,
    gender: Gender.female,
    buttonEnabled: true,
    buttonText: 'Купить',
    locked: false,
    imageUrl: '',
    dateText: '20 июля 2025, 11:00',
    placeText: 'Санкт-Петербург',
    typeText: 'Забег',
  ),
];
