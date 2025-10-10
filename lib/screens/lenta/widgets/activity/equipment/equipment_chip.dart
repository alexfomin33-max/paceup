// lib/screens/lenta/widgets/activity/equipment/equipment_chip.dart
import 'package:flutter/material.dart';
import '../../../../../models/activity_lenta.dart' as al;
import 'equipment_popup.dart';

/// Чип экипировки. Только UI + показ попапа по тапу.
class EquipmentChip extends StatelessWidget {
  final List<al.Equipment> items;

  const EquipmentChip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final al.Equipment? e = items.isNotEmpty ? items.first : null;
    final String name = (e?.name ?? '').trim().isNotEmpty
        ? e!.name
        : "Asics Jolt 3 Wide 'Dive Blue'";
    final int mileage = e?.mileage ?? 582;
    final String img = e?.img ?? '';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // аватарка обуви
          Positioned(
            left: 3,
            top: 3,
            bottom: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: img.isNotEmpty
                  ? Image.network(img, width: 50, height: 50, fit: BoxFit.fill)
                  : Image.asset(
                      'assets/Asics.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.fill,
                    ),
            ),
          ),
          // текст
          Positioned(
            left: 60,
            top: 7,
            right: 60,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "$name\n",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF323743),
                    ),
                  ),
                  const TextSpan(
                    text: "Пробег: ",
                    style: TextStyle(fontSize: 11, color: Color(0xFF565D6D)),
                  ),
                  TextSpan(
                    text: "$mileage",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF171A1F),
                    ),
                  ),
                  const TextSpan(
                    text: " км",
                    style: TextStyle(fontSize: 11, color: Color(0xFF565D6D)),
                  ),
                ],
              ),
            ),
          ),
          // кнопка вызова попапа
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => EquipmentPopup.show(context),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
