import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../../theme/app_theme.dart';

class MembersRouteScreen extends StatefulWidget {
  final int routeId;
  final String routeTitle;
  final String? difficultyText; // например: "Сложный маршрут"

  const MembersRouteScreen({
    super.key,
    required this.routeId,
    required this.routeTitle,
    this.difficultyText,
  });

  @override
  State<MembersRouteScreen> createState() => _MembersRouteScreenState();
}

class _MembersRouteScreenState extends State<MembersRouteScreen> {
  DateTime? _date;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Выберите дату',
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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
          'Участники маршрута',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Подшапка: название + чип сложности + поле даты
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
                    Center(
                      child: _DifficultyChip(text: widget.difficultyText!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _LabeledDateField(
                    label: 'Дата',
                    text: _date == null ? '24.06.2025' : _fmtDate(_date!),
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Секция "Сегодня"
          const SliverToBoxAdapter(child: _SectionHeader('Сегодня')),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverToBoxAdapter(child: _MembersTable(rows: _todayRows)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Секция "22.07.2025"
          const SliverToBoxAdapter(child: _SectionHeader('22.07.2025')),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverToBoxAdapter(child: _MembersTable(rows: _july22Rows)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Секция "16.07.2025"
          const SliverToBoxAdapter(child: _SectionHeader('16.07.2025')),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            sliver: SliverToBoxAdapter(child: _MembersTable(rows: _july16Rows)),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ───────────────────────── Поле даты с плавающим лейблом (как в regstep2_screen)
class _LabeledDateField extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onTap;

  const _LabeledDateField({
    required this.label,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      controller: TextEditingController(text: text),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.greytext,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: Color(0xFF565D6D),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppColors.greytext,
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

// ── фикс-ширины правых колонок (подгони под макет/вкус)
const double _kKmColW = 68; // «км»
const double _kTimeColW = 60; // «время»
const double _kHrColW = 52; // «пульс»
const double _kVDivW = 1; // вертикальный разделитель

class _HalfVDivider extends StatelessWidget {
  const _HalfVDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _kVDivW,
      child: FractionallySizedBox(
        heightFactor: 0.5, // ← половина высоты строки
        child: VerticalDivider(
          width: _kVDivW,
          thickness: 0.5,
          color: Color(0xFFEAEAEA),
        ),
      ),
    );
  }
}

// ───────────────────────── Таблица (как в friend_races_content.dart)
class _MembersTable extends StatelessWidget {
  final List<_MemberRow> rows;
  const _MembersTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
          bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
        ),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i];
          return Column(
            children: [
              IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Колонка 1: аватар + имя (+ подпись) — РАСТЯГИВАЕТСЯ
                      Expanded(
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                r.avatarAsset,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (r.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      r.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.greytext,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // │ разделитель
                      const _HalfVDivider(),

                      // ── Колонка 2: КМ — ФИКС ширина
                      SizedBox(
                        width: _kKmColW,
                        child: Center(
                          child: Text(
                            _kmText(r.km),
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),

                      // │ разделитель
                      const _HalfVDivider(),

                      // ── Колонка 3: ВРЕМЯ — ФИКС ширина
                      SizedBox(
                        width: _kTimeColW,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  r.time,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // │ разделитель
                      const _HalfVDivider(),

                      // ── Колонка 4: ПУЛЬС — ФИКС ширина
                      SizedBox(
                        width: _kHrColW,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.heart,
                                size: 12,
                                color: Color(0xFFFF3B30),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${r.hr}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (i != rows.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFEAEAEA),
                ),
            ],
          );
        }),
      ),
    );
  }

  static String _kmText(double km) {
    final txt = km.toStringAsFixed(2).replaceAll('.', ',');
    return '$txt км';
  }
}

// ───────────────────────── Вспомогательные виджеты

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.greytext,
        ),
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

// ───────────────────────── Модель и демо-данные

class _MemberRow {
  final String name;
  final String avatarAsset;
  final double km;
  final String time;
  final int hr;
  final String? subtitle; // например, «18 июня 2025»

  const _MemberRow({
    required this.name,
    required this.avatarAsset,
    required this.km,
    required this.time,
    required this.hr,
    this.subtitle,
  });
}

const _todayRows = <_MemberRow>[
  _MemberRow(
    name: 'Алексей Лукашин',
    avatarAsset: 'assets/Avatar_1.png',
    km: 26.05,
    time: '1:26:03',
    hr: 143,
  ),
  _MemberRow(
    name: 'Татьяна Свиридова',
    avatarAsset: 'assets/Avatar_3.png',
    km: 23.18,
    time: '2:07:32',
    hr: 157,
  ),
];

const _july22Rows = <_MemberRow>[
  _MemberRow(
    name: 'Игорь Зелёный',
    avatarAsset: 'assets/Avatar_2.png',
    km: 25.31,
    time: '1:48:23',
    hr: 135,
  ),
  _MemberRow(
    name: 'Дмитрий Фадеев',
    avatarAsset: 'assets/Avatar_6.png',
    km: 22.10,
    time: '1:57:42',
    hr: 149,
  ),
  _MemberRow(
    name: 'Екатерина Виноградова',
    avatarAsset: 'assets/Avatar_4.png',
    km: 18.46,
    time: '2:18:36',
    hr: 163,
  ),
];

const _july16Rows = <_MemberRow>[
  _MemberRow(
    name: 'Анатолий Курагин',
    avatarAsset: 'assets/Avatar_5.png',
    km: 20.16,
    time: '1:42:55',
    hr: 140,
  ),
];
