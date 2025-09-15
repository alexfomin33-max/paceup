import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 🔹 Первый экран регистрации — ввод базовых данных спортсмена
class Regstep1Screen extends StatefulWidget {
  final int userId; // ID пользователя

  const Regstep1Screen({super.key, required this.userId});

  @override
  Regstep1ScreenState createState() => Regstep1ScreenState();
}

/// 🔹 Публичный класс состояния для Regstep1Screen
class Regstep1ScreenState extends State<Regstep1Screen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  String? selectedGender;
  String? selectedSport;

  final List<String> genders = ['Муж', 'Жен'];
  final List<String> sports = ['Бег', 'Велосипед', 'Плавание'];

  bool get isFormValid {
    return nameController.text.isNotEmpty &&
        surnameController.text.isNotEmpty &&
        dobController.text.isNotEmpty &&
        selectedGender != null &&
        cityController.text.isNotEmpty &&
        selectedSport != null;
  }

  /// 🔹 Метод для сохранения в базе введенных данных (перед переходом на следующую странцу)
  Future<void> saveForm() async {
    try {
      final response = await http.post(
        Uri.parse('http://api.paceup.ru/save_reg_form1.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId, 
          'name': nameController.text, 
          'surname': surnameController.text, 
          'dateage': dobController.text, 
          'city': cityController.text, 
          'gender': selectedGender!, 
          'sport': selectedSport!
        }),
      );
     // print(response.body);
    } catch (e) {}
  }

  /// 🔹 Переход на следующий экран, если форма валидна
  Future<void> _checkAndContinue() async {
    if (isFormValid) {
      await saveForm();
      Navigator.pushReplacementNamed(
        context,
        '/regstep2',
        arguments: {'userId': widget.userId},
      );
    }
  }

  @override
  void initState() {
    super.initState();
    nameController.addListener(() => setState(() {}));
    surnameController.addListener(() => setState(() {}));
    dobController.addListener(() => setState(() {}));
    cityController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Данные спортсмена',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF323743),
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),
                CustomTextField(controller: nameController, label: 'Имя*'),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: surnameController,
                  label: 'Фамилия*',
                ),
                const SizedBox(height: 20),
                CustomDateField(
                  controller: dobController,
                  label: 'Дата рождения*',
                ),
                const SizedBox(height: 20),
                CustomDropdownField(
                  label: 'Пол*',
                  value: selectedGender,
                  items: genders,
                  onChanged: (value) => setState(() => selectedGender = value),
                ),
                const SizedBox(height: 20),
                CustomTextField(controller: cityController, label: 'Город*'),
                const SizedBox(height: 20),
                CustomDropdownField(
                  label: 'Основной вид спорта*',
                  value: selectedSport,
                  items: sports,
                  onChanged: (value) => setState(() => selectedSport = value),
                ),
                const SizedBox(height: 50),
                ContinueButton(
                  onPressed: _checkAndContinue,
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

// ==========================
// Текстовое поле с обязательным указанием '*'
// ==========================
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label.replaceAll('*', ''),
            style: const TextStyle(
              color: Color(0xFF565D6D),
              fontSize: 16,
              fontFamily: 'Inter',
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
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
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
    );
  }
}

// ==========================
// Поле для выбора даты рождения
// ==========================
class CustomDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const CustomDateField({
    super.key,
    required this.controller,
    required this.label,
  });

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      controller.text = DateFormat('dd.MM.yyyy').format(pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            label: RichText(
              text: TextSpan(
                text: label.replaceAll('*', ''),
                style: const TextStyle(
                  color: Color(0xFF565D6D),
                  fontSize: 16,
                  fontFamily: 'Inter',
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
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
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

// ==========================
// Dropdown для выбора значения
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
              color: Color(0xFF565D6D),
              fontSize: 16,
              fontFamily: 'Inter',
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
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: onChanged,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      ),
    );
  }
}

// ==========================
// Кнопка "Продолжить"
// ==========================
class ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isEnabled;

  const ContinueButton({
    super.key,
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
      child: const Text(
        'Продолжить',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
