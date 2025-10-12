// lib/screens/lenta/widgets/activity/equipment/equipment_chip.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../models/activity_lenta.dart' as al;
import 'equipment_popup.dart';

/// Чип экипировки с якорным попапом (поведение как в дорефакторинговом Equipment).
/// Важные детали пиксель-паритета:
/// - Общая высота 56, фон #F3F4F6, радиус 28
/// - Внутренний горизонтальный паддинг 10 (снаружи ActivityBlock уже даёт 6)
/// - Картинка 50×50 с радиусом 25 (позиционирование left:3, top/bottom:3)
/// - Кнопка справа 28×28, белая, иконка CupertinoIcons.ellipsis size:16
class EquipmentChip extends StatefulWidget {
  final List<al.Equipment> items;

  const EquipmentChip({super.key, required this.items});

  @override
  State<EquipmentChip> createState() => _EquipmentChipState();
}

class _EquipmentChipState extends State<EquipmentChip> {
  // ключ для вычисления позиции кнопки — сюда якорим попап
  final GlobalKey _menuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final al.Equipment? e = widget.items.isNotEmpty ? widget.items.first : null;
    final String name = (e?.name ?? '').trim().isNotEmpty
        ? e!.name
        : "Asics Jolt 3 Wide 'Dive Blue'";
    final int mileage = e?.mileage ?? 582;
    final String img = e?.img ?? '';

    return Padding(
      // как было в исходном Equipment: внутренний паддинг 10
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
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
                    ? Image.network(
                        img,
                        width: 50,
                        height: 50,
                        fit: BoxFit.fill,
                      )
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
                        height: 1.69, // как в исходнике
                      ),
                    ),
                    const TextSpan(
                      text: "Пробег: ",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF565D6D),
                        height: 1.64,
                      ),
                    ),
                    TextSpan(
                      text: "$mileage",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF171A1F),
                        height: 1.64,
                      ),
                    ),
                    const TextSpan(
                      text: " км",
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF565D6D),
                        height: 1.64,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // кнопка вызова попапа (якорь)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () =>
                      EquipmentPopup.showAnchored(context, anchorKey: _menuKey),
                  child: Container(
                    key: _menuKey, // ← важный ключ для позиционирования попапа
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
