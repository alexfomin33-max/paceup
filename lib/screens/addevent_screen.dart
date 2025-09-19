import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final clubCtrl = TextEditingController(text: 'CoffeeRun_vld');
  final templateCtrl = TextEditingController(text: 'Субботний коферан');

  // выборы
  String? activity = 'Бег';
  DateTime? date = DateTime.now();
  TimeOfDay? time = const TimeOfDay(hour: 12, minute: 00);

  // ✅ вот сюда добавляем список клубов и выбранный клуб:
  final List<String> clubs = ['CoffeeRun_vld', 'RunTown', 'TriClub'];
  String? selectedClub = 'CoffeeRun_vld';

  // чекбоксы
  bool createFromClub = false;
  bool saveTemplate = false;

  // медиа
  final picker = ImagePicker();
  File? logoFile;
  final List<File?> photos = [null, null, null];

  bool get isFormValid =>
      (nameCtrl.text.trim().isNotEmpty) &&
      (placeCtrl.text.trim().isNotEmpty) &&
      (activity != null) &&
      (date != null) &&
      (time != null);

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(_refresh);
    placeCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    placeCtrl.dispose();
    descCtrl.dispose();
    clubCtrl.dispose();
    templateCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _pickLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => logoFile = File(x.path));
  }

  Future<void> _pickPhoto(int i) async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => photos[i] = File(x.path));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: date ?? now,
      locale: const Locale('ru'),
      helpText: 'Дата проведения',
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Время проведения',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => time = picked);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  String _fmtTime(TimeOfDay? t) {
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _submit() {
    if (!isFormValid) return;
    // TODO: отправка формы
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Мероприятие создано (демо)')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity != null && d.primaryVelocity! > 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Добавление события', style: AppTextStyles.h1),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              onPressed: () {
                // TODO: сохранить черновик
              },
              icon: const Icon(CupertinoIcons.arrow_down_doc),
              tooltip: 'Сохранить',
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Медиа: логотип + 3 фото (визуальный стиль как в newpost) ----------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MediaColumn(
                      label: 'Логотип',
                      file: logoFile,
                      onPick: _pickLogo,
                      onRemove: () => setState(() => logoFile = null),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SmallLabel('Фото события'),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 70,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) => _MediaTile(
                                file: photos[i],
                                onPick: () => _pickPhoto(i),
                                onRemove: () =>
                                    setState(() => photos[i] = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ---------- Название ----------
                EventTextField(
                  controller: nameCtrl,
                  label: 'Название события*',
                ),
                const SizedBox(height: 20),

                // ---------- Вид активности ----------
                EventDropdownField(
                  label: 'Вид активности*',
                  value: activity,
                  items: const ['Бег', 'Велосипед', 'Плавание', 'Триатлон'],
                  onChanged: (v) => setState(() => activity = v),
                ),
                const SizedBox(height: 20),

                // ---------- Место + кнопка "Карта" ----------
                EventTextField(
                  controller: placeCtrl,
                  label: 'Место проведения*',
                  trailing: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: открытие карты выбора точки
                        },
                        style: OutlinedButton.styleFrom(
                          shape: const CircleBorder(),
                          side: const BorderSide(color: AppColors.border),
                          foregroundColor: Colors.black87,
                          backgroundColor: Colors.white,
                          padding:
                              EdgeInsets.zero, // чтобы иконка была по центру
                        ),
                        child: const Icon(CupertinoIcons.placemark, size: 20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- Дата / Время ----------
                Row(
                  children: [
                    Expanded(
                      child: EventDateField(
                        label: 'Дата проведения*',
                        valueText: _fmtDate(date),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EventDateField(
                        label: 'Время',
                        valueText: _fmtTime(time),
                        icon: CupertinoIcons.time,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---------- Описание ----------
                EventTextField(
                  controller: descCtrl,
                  label: 'Описание события',
                  maxLines: 5,
                ),
                const SizedBox(height: 16),

                // ---------- Создать от имени клуба ----------
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: createFromClub,
                        onChanged: (v) =>
                            setState(() => createFromClub = v ?? false),
                        side: BorderSide(color: AppColors.border),
                        activeColor: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Создать от имени клуба'),
                  ],
                ),
                const SizedBox(height: 8),
                EventDropdownField(
                  label: '', // ← пустая строка: лейбл не рисуем
                  value: selectedClub,
                  items: clubs,
                  enabled: createFromClub,
                  onChanged: (v) => setState(() {
                    selectedClub = v;
                    clubCtrl.text = v ?? '';
                  }),
                ),
                const SizedBox(height: 16),

                // ---------- Сохранить шаблон ----------
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: saveTemplate,
                        onChanged: (v) =>
                            setState(() => saveTemplate = v ?? false),
                        side: const BorderSide(color: AppColors.border),
                        activeColor: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Сохранить шаблон'),
                  ],
                ),
                const SizedBox(height: 8),

                EventTextField(
                  controller: templateCtrl,
                  label: '',
                  enabled: saveTemplate,
                  // ← ⚡️ вот это главное
                ),

                const SizedBox(height: 28),
                CreateButton(
                  text: 'Создать мероприятие',
                  onPressed: _submit,
                  isEnabled: isFormValid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//
// --------------------------- ЛОКАЛЬНЫЕ ВИДЖЕТЫ В СТИЛЕ regstep1 ---------------------------
//

class EventTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool enabled;
  final Widget? trailing;

  const EventTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // цвета/бордеры в зависимости от enabled
    final textColor = enabled
        ? Colors.black
        : Colors.black.withValues(alpha: 0.4);
    final fill = enabled ? Colors.white : const Color(0xFFF6F7F9); // чуть серее
    final borderColor = AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: textColor, fontFamily: 'Inter'),
      decoration: InputDecoration(
        // если label пустой — не показываем подпись
        label: label.isEmpty ? null : _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),

        // обычные рамки
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),

        // 🔸 рамка, когда поле отключено
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
    );

    if (trailing == null) return field;

    return Row(
      crossAxisAlignment: maxLines == 1
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        trailing!,
      ],
    );
  }
}

class EventDateField extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;

  const EventDateField({
    super.key,
    required this.label,
    required this.valueText,
    this.icon = CupertinoIcons.calendar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: valueText),
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            label: _labelWithStar(label),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6),
              child: Icon(icon, size: 18, color: Colors.black87),
            ),
            prefixIconConstraints: const BoxConstraints(
              minHeight: 18,
              minWidth: 18 + 14,
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
          ),
        ),
      ),
    );
  }
}

class EventDropdownField extends StatelessWidget {
  final String label; // может быть пустым
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final bool enabled;

  const EventDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? Colors.black
        : Colors.black.withValues(alpha: 0.4);
    final fill = enabled ? Colors.white : const Color(0xFFF6F7F9);
    final borderColor = AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    return InputDecorator(
      decoration: InputDecoration(
        label: label.isEmpty ? null : _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: borderColor),
        ),
        // 🔸 рамка, когда поле отключено
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          // бледная стрелка, когда выключено
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? Colors.black54 : Colors.black26,
          ),
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
          // показываем текущее значение в бледном виде, если disabled
          disabledHint: value == null
              ? const SizedBox.shrink()
              : Text(
                  value!,
                  style: TextStyle(color: textColor, fontFamily: 'Inter'),
                ),
          onChanged: enabled ? onChanged : null,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(color: textColor, fontFamily: 'Inter'),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class CreateButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isEnabled;

  const CreateButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? AppColors.primary : Colors.grey.shade400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

//
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ (как в newpost) ---------------------------
//

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4),
    );
  }
}

class _MediaColumn extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove; // ← новое

  const _MediaColumn({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 6),
        _MediaTile(file: file, onPick: onPick, onRemove: onRemove),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // 📌 Если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: AppColors.background,
            border: Border.all(color: AppColors.border), // ← рамка только здесь
          ),
          child: const Center(
            child: Icon(CupertinoIcons.photo, size: 28, color: Colors.grey),
          ),
        ),
      );
    }

    // 📌 Если фото выбрано — превью без рамки
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onPick, // тап по фото — заменить
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              image: DecorationImage(
                image: FileImage(file!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    final paint = Paint()
      ..color = const Color(0xFFBDC1CA)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));

    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        final next = d + dashWidth;
        canvas.drawPath(m.extractPath(d, next), paint);
        d = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//
// --------------------------- УТИЛИТА: лейбл с красной звёздочкой ---------------------------
//

Widget _labelWithStar(String label) {
  return RichText(
    text: TextSpan(
      text: label.replaceAll('*', ''),
      style: const TextStyle(
        color: Color(0xFF565D6D),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      children: [
        if (label.contains('*'))
          const TextSpan(
            text: '*',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
      ],
    ),
  );
}
