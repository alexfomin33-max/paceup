// lib/widgets/pills.dart

import 'package:flutter/material.dart';

/// Пилюля с дистанцией (фикс. ширина, серый фон)
class DistancePill extends StatelessWidget {
  final String text;
  const DistancePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Круглая пилюля пола (Ж/М), разный цвет подложки/текста.
class GenderPill extends StatelessWidget {
  final bool female;

  const GenderPill.female({super.key}) : female = true;
  const GenderPill.male({super.key}) : female = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: female ? const Color(0xFFFDF1F5) : const Color(0xFFF1F8FD),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        female ? 'Ж' : 'М',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: female ? const Color(0xFFE8618C) : const Color(0xFF379AE6),
        ),
      ),
    );
  }
}

/// Пилюля цены (жёлтая), узкая фикс. ширина.
class PricePill extends StatelessWidget {
  final String text;
  const PricePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9EE),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF98690C),
        ),
      ),
    );
  }
}

/// Пилюля города (серый фон, эластичная по ширине).
class CityPill extends StatelessWidget {
  final String text;
  const CityPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Colors.black,
        ),
      ),
    );
  }
}
