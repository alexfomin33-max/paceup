import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SuzdalScreen extends StatefulWidget {
  const SuzdalScreen({super.key});

  @override
  State<SuzdalScreen> createState() => _SuzdalScreenState();
}

class _SuzdalScreenState extends State<SuzdalScreen> {
  @override
  Widget build(BuildContext context) {
    const double percent = 21784 / 110033; // ≈ 0.198

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─────────── Верхнее фото + кнопка "назад"
          SliverAppBar(
            pinned: false,
            floating: false,
            expandedHeight: 160,
            elevation: 0,
            backgroundColor: Colors.white,
            leadingWidth: 60,
            leading: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: const FlexibleSpaceBar(
              background: Image(
                image: AssetImage('assets/suzdal_panorama.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ─────────── Белый блок: заголовок + описание + прогресс
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  // тонкая тень вниз ~1px
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 1),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: const Column(
                children: [
                  Text(
                    'Суздаль',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Это маленький, но очень уютный городок. '
                    'Музей деревянного зодчества погружает в эпоху XIX века. '
                    'Здесь можно увидеть быт крестьян ушедшего времени.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.greytext,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Узкий прогресс-бар по центру
                  Center(
                    child: SizedBox(
                      width: 240,
                      child: _MiniProgress(percent: percent),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '21 784 из 110 033 шагов',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.greytext,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 25)),

          // ─────────── Секция "Прогресс друзей"
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _SectionTitle('Прогресс друзей'),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                      bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
                    ),
                  ),
                  child: Column(
                    children: List.generate(_rows.length, (i) {
                      final r = _rows[i];
                      final highlight = r.rank == 6; // зелёным шестой
                      return _FriendRow(
                        rank: r.rank,
                        name: r.name,
                        value: r.steps,
                        avatar: r.avatar,
                        highlight: highlight,
                        isLast: i == _rows.length - 1,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───── Вспомогательные виджеты

class _MiniProgress extends StatelessWidget {
  final double percent;
  const _MiniProgress({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (percent.clamp(0.0, 1.0)) * c.maxWidth;
        return Row(
          children: [
            Container(
              width: w,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF22CCB2),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
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
                color: highlight ? const Color(0xFF22CCB2) : AppColors.text,
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.text,
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
              color: highlight ? const Color(0xFF22CCB2) : AppColors.text,
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

// Демо-данные
class _RowData {
  final int rank;
  final String name;
  final String steps;
  final AssetImage avatar;
  const _RowData(this.rank, this.name, this.steps, this.avatar);
}

const _rows = <_RowData>[
  _RowData(1, 'Алексей Лукашин', '110 033', AssetImage('assets/Avatar_1.png')),
  _RowData(
    2,
    'Татьяна Свиридова',
    '110 033',
    AssetImage('assets/Avatar_3.png'),
  ),
  _RowData(3, 'Игорь Зелёный', '75 971', AssetImage('assets/Avatar_2.png')),
  _RowData(4, 'Анатолий Курагин', '42 426', AssetImage('assets/Avatar_5.png')),
  _RowData(
    5,
    'Екатерина Виноградова',
    '29 756',
    AssetImage('assets/Avatar_4.png'),
  ),
  _RowData(
    6,
    'Константин Разумовский',
    '21 784',
    AssetImage('assets/Avatar_0.png'),
  ),
];
