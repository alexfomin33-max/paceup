import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'regstep2_screen.dart';
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

  // Переменные для подсветки красным
  bool nameError = false;
  bool surnameError = false;
  bool dobError = false;
  bool genderError = false;
  bool cityError = false;
  bool sportError = false;

  void _checkAndContinue() {
    setState(() {
      nameError = nameController.text.isEmpty;
      surnameError = surnameController.text.isEmpty;
      dobError = dobController.text.isEmpty;
      genderError = selectedGender == null;
      cityError = cityController.text.isEmpty;
      sportError = selectedSport == null;
    });

    if (!nameError &&
        !surnameError &&
        !dobError &&
        !genderError &&
        !cityError &&
        !sportError) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Regstep2Screen(userId: widget.userId),
        ),
      );
    }
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
                CustomTextField(
                  controller: nameController,
                  label: 'Имя*',
                  hasError: nameError,
                  onChanged: (_) {
                    if (nameError) setState(() => nameError = false);
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: surnameController,
                  label: 'Фамилия*',
                  hasError: surnameError,
                  onChanged: (_) {
                    if (surnameError) setState(() => surnameError = false);
                  },
                ),
                const SizedBox(height: 20),
                CustomDateField(
                  controller: dobController,
                  label: 'Дата рождения*',
                  hasError: dobError,
                  onDateSelected: () {
                    if (dobError) setState(() => dobError = false);
                  },
                ),
                const SizedBox(height: 20),
                CustomDropdownField(
                  label: 'Пол*',
                  value: selectedGender,
                  items: genders,
                  hasError: genderError,
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                      genderError = false;
                    });
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: cityController,
                  label: 'Город*',
                  hasError: cityError,
                  onChanged: (_) {
                    if (cityError) setState(() => cityError = false);
                  },
                ),
                const SizedBox(height: 20),
                CustomDropdownField(
                  label: 'Основной вид спорта*',
                  value: selectedSport,
                  items: sports,
                  hasError: sportError,
                  onChanged: (value) {
                    setState(() {
                      selectedSport = value;
                      sportError = false;
                    });
                  },
                ),
                const SizedBox(height: 50),
                ContinueButton(onPressed: _checkAndContinue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// Текстовое поле
// ==========================
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hasError,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      onChanged: onChanged,
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
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFFBDC1CA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFFBDC1CA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFFBDC1CA),
          ),
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
  final bool hasError;
  final VoidCallback? onDateSelected;

  const CustomDateField({
    super.key,
    required this.controller,
    required this.label,
    required this.hasError,
    this.onDateSelected,
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
      if (onDateSelected != null) onDateSelected!();
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
              borderSide: BorderSide(
                color: hasError ? Colors.red : Color(0xFFBDC1CA),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Color(0xFFBDC1CA),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Color(0xFF2ECC70),
              ),
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
  final bool hasError;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hasError,
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
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFFBDC1CA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFFBDC1CA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Color(0xFF2ECC70),
          ),
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
  final VoidCallback onPressed;

  const ContinueButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
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
