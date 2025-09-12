import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../design/app_theme.dart';

class Regstep1Screen extends StatefulWidget {
  final int userId;

  const Regstep1Screen({super.key, required this.userId});

  @override
  _Regstep1ScreenState createState() => _Regstep1ScreenState();
}

class _Regstep1ScreenState extends State<Regstep1Screen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  String? selectedGender;
  String? selectedSport;

  final List<String> genders = ['Муж', 'Жен'];
  final List<String> sports = ['Бег', 'Велосипед', 'Плавание'];

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
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(controller: cityController, label: 'Город*'),
                const SizedBox(height: 20),
                CustomDropdownField(
                  label: 'Основной вид спорта*',
                  value: selectedSport,
                  items: sports,
                  onChanged: (value) {
                    setState(() {
                      selectedSport = value;
                    });
                  },
                ),
                const SizedBox(height: 50),
                const ContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// Текстовое поле белое
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
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
          borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: Color(0xFF2ECC70), width: 2),
        ),
      ),
    );
  }
}

// ==========================
// Дата рождения
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
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
              borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: Color(0xFF2ECC70), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// Dropdown белый
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
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
          borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFBDC1CA), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2ECC70), width: 2),
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
// Кнопка Продолжить
// ==========================
class ContinueButton extends StatelessWidget {
  const ContinueButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
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
