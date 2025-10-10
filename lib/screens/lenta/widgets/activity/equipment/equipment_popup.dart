// lib/screens/lenta/widgets/activity/equipment/equipment_popup.dart
import 'package:flutter/material.dart';

/// Простой статичный попап экипировки.
/// - Рисуется поверх всего через OverlayEntry (без навигации/диалогов).
/// - Сам закрывается по тапу по фону.
/// - Размеры/верстка совпадают с твоим макетом (288×112, 2 строки по 56).
/// - Вынесен в отдельный файл, чтобы переиспользовать где угодно.
///
/// Использование:
///   EquipmentPopup.show(context);
class EquipmentPopup {
  /// Показать попап в rootOverlay.
  static void show(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;

    /// Локальная функция закрытия — чтобы можно было вызывать изнутри.
    void close() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Тап по фону закрывает попап
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              behavior: HitTestBehavior.opaque,
            ),
          ),

          // Сам "пузырь" по центру (можно позиционировать иначе при желании)
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 288,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  // Тень как в твоём изначальном варианте для этого попапа
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: const _PopupContent(),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }
}

/// Внутренний контент попапа: две строки обуви 56px + тонкий разделитель.
/// Разметка повторяет твою из `Popup`, но упрощена за счёт переиспользуемого `_ShoeRow`.
class _PopupContent extends StatelessWidget {
  const _PopupContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ShoeRow(
          imageAsset: 'assets/Hoka.png',
          name: 'Hoka One One Bondi 8',
          mileageKm: 836,
        ),
        Divider(height: 1, thickness: 1, color: Color(0xFFECECEC)),
        _ShoeRow(
          imageAsset: 'assets/Anta.png',
          name: 'Anta M C202',
          mileageKm: 1204,
        ),
      ],
    );
  }
}

/// Одна строка обуви в попапе.
/// Слева — 80px под картинку, справа — текстовый блок 208px.
/// Общая высота — 56px (как в твоём макете).
class _ShoeRow extends StatelessWidget {
  final String imageAsset;
  final String name;
  final int mileageKm;

  const _ShoeRow({
    required this.imageAsset,
    required this.name,
    required this.mileageKm,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Row(
        children: [
          // Левая область под картинку 80×56
          Container(
            width: 80,
            height: 56,
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Image.asset(imageAsset, fit: BoxFit.fill),
          ),

          // Правая область 208×56 — текст в две строки
          Expanded(
            child: Container(
              height: 56,
              color: Colors.white,
              padding: const EdgeInsets.only(left: 5, top: 8, right: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$name\n',
                      style: const TextStyle(
                        color: Color(0xFF323743),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.67,
                      ),
                    ),
                    const TextSpan(
                      text: 'Пробег: ',
                      style: TextStyle(
                        color: Color(0xFF565D6D),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 1.64,
                      ),
                    ),
                    TextSpan(
                      text: '$mileageKm',
                      style: const TextStyle(
                        color: Color(0xFF171A1F),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.64,
                      ),
                    ),
                    const TextSpan(
                      text: ' км',
                      style: TextStyle(
                        color: Color(0xFF565D6D),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        height: 1.64,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
