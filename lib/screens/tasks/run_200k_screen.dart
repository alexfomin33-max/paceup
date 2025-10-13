import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class Run200kScreen extends StatefulWidget {
  const Run200kScreen({super.key});

  @override
  State<Run200kScreen> createState() => _Run200kScreenState();
}

class _Run200kScreenState extends State<Run200kScreen> {
  int _segment = 0; // 0 — Все, 1 — Друзья

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─────────── Верхнее фото + кнопка "назад"
          SliverAppBar(
            pinned: false,
            floating: false,
            expandedHeight: 140,
            elevation: 0,
            backgroundColor: AppColors.surface,
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
                image: AssetImage('assets/200k_run.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ─────────── Круглая иконка наполовину на фото, наполовину на белом блоке
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Белый блок с заголовком, подписью и узким прогресс-баром
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      // тонкая тень вниз ~1px
                      BoxShadow(
                        color: Color(0x14000000),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  // добавили +36 сверху, чтобы нижняя половина круга не перекрывала текст
                  padding: const EdgeInsets.fromLTRB(16, 16 + 36, 16, 16),
                  child: const Column(
                    children: [
                      Text(
                        '200 км бега',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Пробегите за месяц суммарно 200 километров.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.greytext,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: 12),

                      // узкий прогресс-бар по центру
                      Center(
                        child: SizedBox(
                          width: 240,
                          child: _MiniProgress(percent: 145.8 / 200.0),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '145,8 из 200 км',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.greytext,
                        ),
                      ),
                    ],
                  ),
                ),

                // Сам круг: центр ровно на границе фото/белого блока
                Positioned(
                  top:
                      -36, // 72/2 со знаком минус — половина на фото, половина на белом фоне
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8A376),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ), // белая рамка 2px
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_run,
                          size: 34,
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─────────── Сегменты на сером фоне (вынесены из белого блока)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Center(
                child: _SegmentedPill(
                  left: 'Все',
                  right: 'Друзья',
                  value: _segment,
                  onChanged: (v) => setState(() => _segment = v),
                ),
              ),
            ),
          ),

          // ─────────── Контент
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: _SectionTitle('Прогресс друзей'),
                ),

                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFEAEAEA), // тонкая линия сверху
                        width: 0.5,
                      ),
                      bottom: BorderSide(
                        color: Color(0xFFEAEAEA), // тонкая линия снизу
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
                        value: r.kmText,
                        avatar: r.avatar,
                        highlight: isMe,
                        isLast: i == _rows.length - 1,
                      );
                    }),
                  ),
                ),
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

// одинаковая ширина сегментов, плашка фиксированной ширины
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;
  const _SegmentedPill({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280, // ширина блока сегментов
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFEAEAEA), // тонкая светло-серая линия
            width: 1,
          ),
        ),

        child: Row(
          children: [
            Expanded(child: _seg(0, left)),
            Expanded(child: _seg(1, right)),
          ],
        ),
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.surface : AppColors.text,
            ),
          ),
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
          const Divider(
            height: 1,
            thickness: 0.5, // более тонкая линия
            color: Color(0xFFEAEAEA), // светло-серая
          ),
      ],
    );
  }
}

// Демо-данные
class _RowData {
  final int rank;
  final String name;
  final String kmText;
  final AssetImage avatar;
  const _RowData(this.rank, this.name, this.kmText, this.avatar);
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
