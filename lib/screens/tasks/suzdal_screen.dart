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
            backgroundColor: AppColors.surface,
            leadingWidth: 60,
            leading: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.scrim40,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.back,
                        color: AppColors.surface,
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
                color: AppColors.surface,
                boxShadow: [
                  // тонкая тень вниз ~1px
                  BoxShadow(
                    color: AppColors.shadowSoft,
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
                      color: AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
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
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                      bottom: BorderSide(color: AppColors.border, width: 0.5),
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
              decoration: const BoxDecoration(
                color: AppColors.accentMint,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppRadius.xs),
                    bottomRight: Radius.circular(AppRadius.xs),
                  ),
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
                color: highlight ? AppColors.accentMint : AppColors.textPrimary,
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
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: highlight ? AppColors.accentMint : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
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
  _RowData(1, 'Алексей Лукашин', '110 033', AssetImage('assets/avatar_1.png')),
  _RowData(
    2,
    'Татьяна Свиридова',
    '110 033',
    AssetImage('assets/avatar_3.png'),
  ),
  _RowData(3, 'Борис Жарких', '75 971', AssetImage('assets/avatar_2.png')),
  _RowData(4, 'Юрий Селиванов', '42 426', AssetImage('assets/avatar_5.png')),
  _RowData(
    5,
    'Екатерина Виноградова',
    '29 756',
    AssetImage('assets/avatar_4.png'),
  ),
  _RowData(6, 'Евгений Бойко', '21 784', AssetImage('assets/avatar_0.png')),
];
