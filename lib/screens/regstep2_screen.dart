import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_theme.dart';

class Regstep2Screen extends StatefulWidget {
  final int userId;

  const Regstep2Screen({super.key, required this.userId});

  @override
  _Regstep2ScreenState createState() => _Regstep2ScreenState();
}

class _Regstep2ScreenState extends State<Regstep2Screen> {
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController maxPulseController = TextEditingController();

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
                  'Параметры спортсмена',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF323743),
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: действие кнопки "Пропустить"
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerRight,
                    ),
                    child: const Text(
                      'Пропустить',
                      style: TextStyle(
                        color: AppColors.greytext,
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                CustomTextField(
                  controller: heightController,
                  label: 'Рост, см',
                  maxLength: 3,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: weightController,
                  label: 'Вес, кг',
                  maxLength: 3,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: maxPulseController,
                  label: 'Максимальный пульс',
                  maxLength: 3,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.greytext,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
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
// Текстовое поле белое, только цифры
// ==========================
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength = 3,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: Color(0xFF565D6D),
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
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
        'Завершить',
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
