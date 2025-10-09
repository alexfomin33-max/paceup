import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../theme/app_theme.dart';

class AllResultsScreen extends StatefulWidget {
  final int routeId;
  final String routeTitle;
  final String? difficultyText; // например: "Сложный маршрут"

  const AllResultsScreen({
    super.key,
    required this.routeId,
    required this.routeTitle,
    this.difficultyText,
  });

  @override
  State<AllResultsScreen> createState() => _AllResultsScreenState();
}

class _AllResultsScreenState extends State<AllResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.text,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Назад',
        ),
        centerTitle: true,
        title: const Text(
          'Общие результаты',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── подшапка в стиле my_results_screen.dart
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    widget.routeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if ((widget.difficultyText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(child: _DifficultyChip(text: widget.difficultyText!)),
                ],
              ],
            ),
          ),

          // ── слайдер «Все / Друзья» как в favorites_screen.dart
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.text,
              indicatorColor: AppColors.secondary,
              indicatorWeight: 1,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(child: _TabLabel(text: 'Все')),
                Tab(child: _TabLabel(text: 'Друзья')),
              ],
            ),
          ),

          // ── содержимое вкладок
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: const [
                _ResultsList(data: _demoAll, highlightMyRank: 1),
                _ResultsList(data: _demoFriends, highlightMyRank: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── ВКЛАДКА-СПИСОК

class _ResultsList extends StatelessWidget {
  final List<_RowData> data;
  final int? highlightMyRank; // ранк, который подсвечиваем (например, «я»)

  const _ResultsList({required this.data, this.highlightMyRank});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // карточка лидера (первая строка), как на макете
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 240,
              ), // ~как на макете
              child: _LeaderCard(item: data.first),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // таблица, как в run_200k_screen.dart (тонкие разделители)
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
          ), // ← по 4 px слева/справа
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                  bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                ),
              ),
              child: Column(
                children: List.generate(data.length - 1, (i) {
                  final r = data[i + 1]; // начиная со 2-го
                  final highlight =
                      (highlightMyRank != null && r.rank == highlightMyRank);
                  return _ResultRow(
                    item: r,
                    highlight: highlight,
                    isLast: i == data.length - 2,
                  );
                }),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ───────────────────────── UI-элементы

class _LeaderCard extends StatelessWidget {
  final _RowData item;
  const _LeaderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          // трофей — слева сверху
          const Positioned(
            left: 0,
            top: 0,
            child: Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: AppColors.gold,
            ),
          ),
          // дата — справа сверху
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              item.dateText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.greytext,
              ),
            ),
          ),

          // основной центрированный контент
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20), // отступ под иконки сверху
              // аватар по центру
              ClipOval(
                child: Image(
                  image: item.avatar,
                  width: 72, // чуть крупнее
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),

              // имя по центру
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 10),

              // метрики: каждая по центру своей половины ширины карточки
              Row(
                children: [
                  Expanded(
                    child: _MetricCenter(
                      icon: CupertinoIcons.time,
                      text: item.timeText,
                    ),
                  ),
                  Expanded(
                    child: _MetricCenter(
                      materialIcon: Icons.speed,
                      text: item.paceText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCenter extends StatelessWidget {
  final IconData? icon; // можно просто icon: ...
  final IconData? cupertinoIcon; // или cupertinoIcon: ...
  final IconData? materialIcon; // или materialIcon: ...
  final String text;

  const _MetricCenter({
    this.icon,
    this.cupertinoIcon,
    this.materialIcon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final IconData? _resolved = icon ?? materialIcon ?? cupertinoIcon;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_resolved != null) const SizedBox(width: 2), // чуть воздуха слева
        if (_resolved != null)
          Icon(_resolved, size: 14, color: AppColors.greytext),
        if (_resolved != null) const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.text,
            ),
          ),
        ),
        if (_resolved != null) const SizedBox(width: 2),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final _RowData item;
  final bool highlight;
  final bool isLast;

  const _ResultRow({
    required this.item,
    required this.highlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '${item.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: highlight ? const Color(0xFF22CCB2) : AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: Image(
              image: item.avatar,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          // имя + дата (две строки)
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.greytext,
                  ),
                ),
              ],
            ),
          ),
          // Правая колонка: ИКОНКА + ВРЕМЯ, выравниваем по левому краю своей колонки
          Expanded(
            flex: 4, // можно 3–5; подбери визуально
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.start, // ← влево внутри колонки
              children: [
                const Icon(
                  CupertinoIcons.time,
                  size: 14,
                  color: AppColors.greytext,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left, // ← текст тоже влево
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: highlight
                          ? const Color(0xFF22CCB2)
                          : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEAEAEA)),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  const _TabLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String text;
  const _DifficultyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final lc = text.toLowerCase();
    Color c;
    if (lc.contains('лёгк')) {
      c = const Color(0xFF37C76A);
    } else if (lc.contains('средн')) {
      c = const Color(0xFFF3A536);
    } else {
      c = const Color(0xFFE8534A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
    );
  }
}

// ───────────────────────── Демо-модель и данные

class _RowData {
  final int rank;
  final String name;
  final String dateText; // "18 июня 2025"
  final String timeText; // "1:26:03"
  final String paceText; // "4:15 /км"
  final AssetImage avatar;

  const _RowData({
    required this.rank,
    required this.name,
    required this.dateText,
    required this.timeText,
    required this.paceText,
    required this.avatar,
  });
}

// Вкладка «Все» — первый элемент используется как лидер
const _demoAll = <_RowData>[
  _RowData(
    rank: 1,
    name: 'Константин Разумовский',
    dateText: '08.05.2024',
    timeText: '1:25:46',
    paceText: '4:15 /км',
    avatar: AssetImage('assets/Avatar_0.png'),
  ),
  _RowData(
    rank: 2,
    name: 'Алексей Лукашин',
    dateText: '18 июня 2025',
    timeText: '1:26:03',
    paceText: '4:16 /км',
    avatar: AssetImage('assets/Avatar_1.png'),
  ),
  _RowData(
    rank: 3,
    name: 'Татьяна Свиридова',
    dateText: '26 сентября 2024',
    timeText: '1:27:12',
    paceText: '4:20 /км',
    avatar: AssetImage('assets/Avatar_3.png'),
  ),
  _RowData(
    rank: 4,
    name: 'Игорь Зелёный',
    dateText: '11 мая 2025',
    timeText: '1:27:23',
    paceText: '4:21 /км',
    avatar: AssetImage('assets/Avatar_2.png'),
  ),
  _RowData(
    rank: 5,
    name: 'Анатолий Курагин',
    dateText: '7 августа 2023',
    timeText: '1:27:30',
    paceText: '4:21 /км',
    avatar: AssetImage('assets/Avatar_5.png'),
  ),
  _RowData(
    rank: 6,
    name: 'Екатерина Виноградова',
    dateText: '18 апреля 2024',
    timeText: '1:27:44',
    paceText: '4:22 /км',
    avatar: AssetImage('assets/Avatar_4.png'),
  ),
  _RowData(
    rank: 7,
    name: 'Дмитрий Фадеев',
    dateText: '22 июля 2025',
    timeText: '1:28:01',
    paceText: '4:23 /км',
    avatar: AssetImage('assets/Avatar_2.png'),
  ),
  _RowData(
    rank: 8,
    name: 'Полина Холина',
    dateText: '18 мая 2025',
    timeText: '1:30:23',
    paceText: '4:31 /км',
    avatar: AssetImage('assets/Avatar_3.png'),
  ),
];

/// Вкладка «Друзья»
const _demoFriends = <_RowData>[
  _RowData(
    rank: 1,
    name: 'Константин Разумовский',
    dateText: '08.05.2024',
    timeText: '1:25:46',
    paceText: '4:15 /км',
    avatar: AssetImage('assets/Avatar_0.png'),
  ),
  _RowData(
    rank: 2,
    name: 'Алексей Лукашин',
    dateText: '18 июня 2025',
    timeText: '1:26:03',
    paceText: '4:16 /км',
    avatar: AssetImage('assets/Avatar_1.png'),
  ),
  _RowData(
    rank: 3,
    name: 'Татьяна Свиридова',
    dateText: '26 сентября 2024',
    timeText: '1:27:12',
    paceText: '4:20 /км',
    avatar: AssetImage('assets/Avatar_3.png'),
  ),
  _RowData(
    rank: 4,
    name: 'Игорь Зелёный',
    dateText: '11 мая 2025',
    timeText: '1:27:23',
    paceText: '4:21 /км',
    avatar: AssetImage('assets/Avatar_2.png'),
  ),
];
