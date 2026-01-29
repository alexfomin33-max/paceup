import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../../features/profile/screens/profile_screen.dart';
import '../../../../../../../../core/widgets/transparent_route.dart';

/// Провайдер участников маршрута с группировкой по датам.
final routeParticipantsProvider = FutureProvider.family<
    List<RouteParticipantsByDate>,
    ({int routeId, String? date})>(
  (ref, params) async {
    return RoutesService().getRouteParticipants(
      routeId: params.routeId,
      date: params.date,
    );
  },
);

class MembersRouteScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MembersRouteScreen> createState() =>
      _MembersRouteScreenState();
}

class _MembersRouteScreenState extends ConsumerState<MembersRouteScreen> {
  DateTime? _date;
  // ── отдельный фокус для пикера, чтобы не возвращалась клавиатура
  final _pickerFocusNode = FocusNode(debugLabel: 'membersRoutePickerFocus');

  @override
  void dispose() {
    _pickerFocusNode.dispose();
    super.dispose();
  }

  // ── выбор даты через Cupertino-календарь (как в add_event_screen)
  Future<void> _pickDate() async {
    _unfocusKeyboard();
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
      setState(() {
        _date = temp;
        // Инвалидируем провайдер для обновления данных
        ref.invalidate(
          routeParticipantsProvider(
            (routeId: widget.routeId, date: _dateToApiFormat(temp)),
          ),
        );
      });
    }
  }

  // ── преобразование даты в формат API (YYYY-MM-DD) или null для "все время"
  String? _dateToApiFormat(DateTime? date) {
    if (date == null) return null;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: const BorderRadius.vertical(
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
                    color: AppColors.getBorderColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),

                // ── ПАНЕЛЬ С КНОПКАМИ
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
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

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    // Получаем данные участников из API
    final participantsAsync = ref.watch(
      routeParticipantsProvider(
        (routeId: widget.routeId, date: _dateToApiFormat(_date)),
      ),
    );

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Участники маршрута',
          showBottomDivider: false, // ← без нижней линии
        ),

        body: participantsAsync.when(
          data: (participantsByDate) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                  routeParticipantsProvider(
                    (routeId: widget.routeId, date: _dateToApiFormat(_date)),
                  ),
                );
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Подшапка: название + чип сложности + поле даты
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.getSurfaceColor(context),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              widget.routeTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ),
                          if ((widget.difficultyText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: _DifficultyChip(
                                text: widget.difficultyText!,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _LabeledDateField(
                            label: 'Дата',
                            text: _date == null ? '' : _fmtDate(_date!),
                            onTap: _pickDate,
                            onClear: _date != null
                                ? () {
                                    setState(() {
                                      _date = null;
                                      ref.invalidate(
                                        routeParticipantsProvider(
                                          (
                                            routeId: widget.routeId,
                                            date: null,
                                          ),
                                        ),
                                      );
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ── Список участников, сгруппированных по датам
                  if (participantsByDate.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Нет участников',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ...participantsByDate.map((group) {
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _SectionHeader(group.dateLabel),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            sliver: SliverToBoxAdapter(
                              child: _MembersTable(
                                participants: group.participants,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        ],
                      );
                    }).toList(),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(
              radius: 12,
              color: AppColors.brandPrimary,
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText.rich(
                TextSpan(
                  text: 'Ошибка: ${e.toString()}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
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
  final VoidCallback? onClear;

  const _LabeledDateField({
    required this.label,
    required this.text,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      controller: TextEditingController(text: text),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.getTextSecondaryColor(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: AppColors.getTextSecondaryColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
          ),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onClear != null && text.isNotEmpty)
              IconButton(
                icon: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: AppColors.getTextSecondaryColor(context),
                ),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          ],
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
    return SizedBox(
      width: _kVDivW,
      child: FractionallySizedBox(
        heightFactor: 0.5, // ← половина высоты строки
        child: VerticalDivider(
          width: _kVDivW,
          thickness: 0.5,
          color: AppColors.getDividerColor(context),
        ),
      ),
    );
  }
}

// ───────────────────────── Таблица (как в friend_races_content.dart)
class _MembersTable extends StatelessWidget {
  final List<RouteParticipant> participants;
  const _MembersTable({required this.participants});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            // ── Тень из темы (более заметная в темной теме)
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: List.generate(participants.length, (i) {
          final p = participants[i];
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                TransparentPageRoute(
                  builder: (_) => ProfileScreen(userId: p.userId),
                ),
              );
            },
            child: Column(
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
                                child: p.avatar.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: p.avatar,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _avatarPlaceholder(context),
                                      )
                                    : _avatarPlaceholder(context),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
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
                              _kmText(p.distanceKm),
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.getTextPrimaryColor(context),
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
                                    p.durationText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
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
                                    p.heartRate != null
                                        ? '${p.heartRate}'
                                        : '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
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
                ...(i != participants.length - 1
                    ? [
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 52,
                          color: AppColors.getDividerColor(context),
                        ),
                      ]
                    : []),
              ],
            ),
          );
        }),
      ),
    );
  }

  static String _kmText(double km) {
    final txt = km.toStringAsFixed(2).replaceAll('.', ',');
    return '$txt км';
  }

  static Widget _avatarPlaceholder(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context),
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.person_fill,
        size: 20,
        color: AppColors.getIconSecondaryColor(context),
      ),
    );
  }
}

// ───────────────────────── Вспомогательные виджеты

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getBackgroundColor(context),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextSecondaryColor(context),
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

