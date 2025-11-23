import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../../theme/app_theme.dart';
import '../../../../../../../../widgets/app_bar.dart';
import '../../../../../../../widgets/interactive_back_swipe.dart';

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

  // ── выбор даты через Cupertino-календарь (как в add_event_screen)
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    DateTime temp = DateUtils.dateOnly(_date ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: DateTime(now.year - 5),
      maximumDate: DateTime(now.year + 5),
      initialDateTime: temp.isBefore(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() => _date = temp);
    }
  }

  // ── показ Cupertino-модального окна с пикером (как в add_event_screen)
  Future<T?> _showCupertinoSheet<T>({required Widget child}) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // маленькая серая полоска сверху (grabber)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),

                // ── ПАНЕЛЬ С КНОПКАМИ
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Отмена'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        child: const Text('Готово'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // ── сам пикер
                SizedBox(height: 260, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Участники маршрута',
          showBottomDivider: false, // ← без нижней линии
        ),

        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Подшапка: название + чип сложности + поле даты
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
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
                          fontWeight: FontWeight.w500,
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
                      text: _date == null ? '' : _fmtDate(_date!),
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
              sliver: SliverToBoxAdapter(
                child: _MembersTable(rows: _todayRows),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Секция "22.07.2025"
            const SliverToBoxAdapter(child: _SectionHeader('22.07.2025')),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverToBoxAdapter(
                child: _MembersTable(rows: _july22Rows),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Секция "16.07.2025"
            const SliverToBoxAdapter(child: _SectionHeader('16.07.2025')),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              sliver: SliverToBoxAdapter(
                child: _MembersTable(rows: _july16Rows),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
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
        color: AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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
          borderSide: const BorderSide(color: AppColors.border),
        ),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppColors.textSecondary,
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
          color: AppColors.divider,
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
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
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
                                    ),
                                  ),
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
                              fontWeight: FontWeight.w400,
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
                                    fontWeight: FontWeight.w400,
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
                                color: AppColors.error,
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
                                    fontWeight: FontWeight.w400,
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
                  indent: 52,
                  color: AppColors.divider,
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
          color: AppColors.textSecondary,
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
      c = AppColors.success;
    } else if (lc.contains('средн')) {
      c = AppColors.warning;
    } else {
      c = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
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

  const _MemberRow({
    required this.name,
    required this.avatarAsset,
    required this.km,
    required this.time,
    required this.hr,
  });
}

const _todayRows = <_MemberRow>[
  _MemberRow(
    name: 'Алексей Лукашин',
    avatarAsset: 'assets/avatar_1.png',
    km: 26.05,
    time: '1:26:03',
    hr: 143,
  ),
  _MemberRow(
    name: 'Татьяна Свиридова',
    avatarAsset: 'assets/avatar_3.png',
    km: 23.18,
    time: '2:07:32',
    hr: 157,
  ),
];

const _july22Rows = <_MemberRow>[
  _MemberRow(
    name: 'Борис Жарких',
    avatarAsset: 'assets/avatar_2.png',
    km: 25.31,
    time: '1:48:23',
    hr: 135,
  ),
  _MemberRow(
    name: 'Александр Палаткин',
    avatarAsset: 'assets/avatar_6.png',
    km: 22.10,
    time: '1:57:42',
    hr: 149,
  ),
  _MemberRow(
    name: 'Екатерина Виноградова',
    avatarAsset: 'assets/avatar_4.png',
    km: 18.46,
    time: '2:18:36',
    hr: 163,
  ),
];

const _july16Rows = <_MemberRow>[
  _MemberRow(
    name: 'Юрий Селиванов',
    avatarAsset: 'assets/avatar_5.png',
    km: 20.16,
    time: '1:42:55',
    hr: 140,
  ),
];
