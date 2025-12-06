import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services/api_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../widgets/custom_text_field.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Первый экран регистрации — ввод базовых данных спортсмена
class Regstep1Screen extends ConsumerStatefulWidget {
  final int userId; // ID пользователя, передается с предыдущего экрана

  const Regstep1Screen({super.key, required this.userId});

  @override
  ConsumerState<Regstep1Screen> createState() => Regstep1ScreenState();
}

/// 🔹 Класс состояния экрана регистрации
class Regstep1ScreenState extends ConsumerState<Regstep1Screen> {
  // 🔹 Контроллеры для текстовых полей
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  // ── отдельный фокус для пикера, чтобы клавиатура не возвращалась
  final FocusNode _pickerFocusNode = FocusNode(debugLabel: 'regstep1Picker');

  // 🔹 Выбранные значения для dropdown
  String? selectedGender;
  String? selectedSport;

  // 🔹 Списки возможных значений
  final List<String> genders = ['Муж', 'Жен'];
  final List<String> sports = ['Бег', 'Велосипед', 'Плавание'];

  /// 🔹 Проверка корректности заполнения формы
  bool get isFormValid {
    return nameController.text.trim().isNotEmpty &&
        surnameController.text.trim().isNotEmpty &&
        dobController.text.isNotEmpty &&
        selectedGender != null &&
        cityController.text.trim().isNotEmpty &&
        selectedSport != null;
  }

  /// 🔹 Метод сохранения введённых данных на сервере
  Future<void> saveForm() async {
    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        await api.post(
          '/save_reg_form1.php',
          body: {
            'user_id': '${widget.userId}', // 🔹 PHP ожидает строки
            'name': nameController.text.trim(),
            'surname': surnameController.text.trim(),
            'dateage': dobController.text,
            'city': cityController.text.trim(),
            'gender': selectedGender!,
            'sport': selectedSport!,
          },
        );
      },
    );
  }

  /// 🔹 Метод проверки валидности формы и перехода на следующий экран
  Future<void> _checkAndContinue() async {
    final formState = ref.read(formStateProvider);
    if (!isFormValid || formState.isSubmitting) return;

    await saveForm();

    // 🔹 Если была ошибка, не переходим дальше
    final updatedState = ref.read(formStateProvider);
    if (updatedState.hasErrors) return;

    // Проверка, что виджет ещё монтирован перед использованием context
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/regstep2',
      arguments: {'userId': widget.userId},
    );
  }

  @override
  void initState() {
    super.initState();

    // 🔹 Очищаем ошибку при изменении полей
    // Используем Future.microtask, так как ref.read недоступен в initState
    Future.microtask(() {
      final formNotifier = ref.read(formStateProvider.notifier);
      nameController.addListener(() {
        formNotifier.clearGeneralError();
      });
      surnameController.addListener(() {
        formNotifier.clearGeneralError();
      });
      dobController.addListener(() {
        formNotifier.clearGeneralError();
      });
      cityController.addListener(() {
        formNotifier.clearGeneralError();
      });
    });
  }

  @override
  void dispose() {
    // 🔹 Освобождаем все контроллеры при уничтожении виджета
    nameController.dispose();
    surnameController.dispose();
    dobController.dispose();
    cityController.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем состояние формы
    final formState = ref.watch(formStateProvider);

    // 🔹 Получаем высоту клавиатуры для адаптации контента
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 🔹 Базовый отступ снизу, который уменьшается при появлении клавиатуры
    final verticalPadding = 50.0 - (keyboardHeight * 0.2).clamp(0.0, 30.0);

    return Scaffold(
      // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.getBackgroundColor(context),
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            // 🔹 Скролл для маленьких экранов
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 30,
                vertical: verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🔹 Заголовок экрана
                  const Text(
                    'Данные спортсмена',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h17w6,
                  ),
                  const SizedBox(height: 30),

                  // 🔹 Поля ввода
                  CustomTextField(
                    controller: nameController,
                    label: 'Имя*',
                    showRequiredStar: true,
                  ),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: surnameController,
                    label: 'Фамилия*',
                    showRequiredStar: true,
                  ),
                  const SizedBox(height: 22),
                  CustomDateField(
                    controller: dobController,
                    label: 'Дата рождения*',
                    pickerFocusNode: _pickerFocusNode,
                  ),
                  const SizedBox(height: 22),
                  CustomDropdownField(
                    label: 'Пол*',
                    value: selectedGender,
                    items: genders,
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value;
                      });
                      ref.read(formStateProvider.notifier).clearGeneralError();
                    },
                  ),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: cityController,
                    label: 'Город*',
                    showRequiredStar: true,
                  ),
                  const SizedBox(height: 22),
                  CustomDropdownField(
                    label: 'Основной вид спорта*',
                    value: selectedSport,
                    items: sports,
                    onChanged: (value) {
                      setState(() {
                        selectedSport = value;
                      });
                      ref.read(formStateProvider.notifier).clearGeneralError();
                    },
                  ),
                  const SizedBox(height: 50),

                  // 🔹 Показываем ошибку, если есть
                  FormErrorDisplay(formState: formState),

                  // 🔹 Кнопка продолжения
                  Center(
                    child: PrimaryButton(
                      text: 'Продолжить',
                      onPressed: _checkAndContinue,
                      enabled: isFormValid && !formState.isSubmitting,
                      isLoading: formState.isSubmitting,
                      width: MediaQuery.of(context).size.width / 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// 🔹 Поле для выбора даты рождения
// ==========================
class CustomDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FocusNode pickerFocusNode;

  const CustomDateField({
    super.key,
    required this.controller,
    required this.label,
    required this.pickerFocusNode,
  });

  /// 🔹 Открытие DatePicker снизу (Cupertino стиль)
  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).requestFocus(pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
    // 🔹 Переменная для хранения выбранной даты, объявлена вне builder
    // чтобы сохраняться между перестроениями
    DateTime selectedDate = DateTime(2000);

    // 🔹 Если в контроллере уже есть дата, парсим её
    if (controller.text.isNotEmpty) {
      try {
        selectedDate = DateFormat('dd.MM.yyyy').parse(controller.text);
      } catch (e) {
        selectedDate = DateTime(2000);
      }
    }

    await showCupertinoModalPopup(
      context: context,
      builder: (popupContext) {
        // 🔹 Адаптивная высота DatePicker: 40% от высоты экрана, но в пределах 250-350px
        final screenHeight = MediaQuery.of(context).size.height;
        final pickerHeight = (screenHeight * 0.35).clamp(250.0, 350.0);
        // 🔹 Высота панели с кнопками: фиксированная 44px
        final headerHeight = 44.0;
        // 🔹 Высота разделителя: 1px
        final dividerHeight = 1.0;

        return Container(
          height: pickerHeight + headerHeight + dividerHeight,
          color: AppColors.surface,
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(popupContext),
                      child: const Text('Отменить'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () {
                        // 🔹 Обновляем контроллер с выбранной датой
                        controller.text = DateFormat(
                          'dd.MM.yyyy',
                        ).format(selectedDate);
                        Navigator.pop(popupContext);
                      },
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),
              // 🔹 Сам пикер даты с адаптивной высотой
              SizedBox(
                height: pickerHeight,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedDate,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) {
                    // 🔹 Обновляем переменную, объявленную в области видимости _selectDate
                    selectedDate = d;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        // 🔹 Только для чтения, открывает DatePicker по тапу
        child: TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                text: label.replaceAll('*', ''),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,

                  fontWeight: FontWeight.w500,
                ),
                children: [
                  if (label.contains('*'))
                    const TextSpan(
                      text: '*',
                      style: TextStyle(color: AppColors.error, fontSize: 16),
                    ),
                ],
              ),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
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
          ),
        ),
      ),
    );
  }
}

// ==========================
// 🔹 Dropdown для выбора значения
// ==========================
class CustomDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label.replaceAll('*', ''),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,

              fontWeight: FontWeight.w500,
            ),
            children: [
              if (label.contains('*'))
                const TextSpan(
                  text: '*',
                  style: TextStyle(color: AppColors.error, fontSize: 16),
                ),
            ],
          ),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
