// lib/screens/profile/tabs/equipment/equipment_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
//                                Вкладка «Снаряжение»
//  Изменения:
//  • Заменена локальная кнопка ElevatedButton.icon на глобальный виджет
//    PrimaryButton (lib/widgets/primary_button.dart) с тем же визуалом.
//  • Остальной код без функциональных изменений.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../main/widgets/gear_screen.dart';
import 'adding/adding_equipment_screen.dart';
import 'viewing/viewing_equipment_screen.dart';
// ↓ Глобальная бренд-кнопка
import '../../../../widgets/primary_button.dart';

class GearTab extends StatefulWidget {
  const GearTab({super.key});
  @override
  State<GearTab> createState() => _GearTabState();
}

class _GearTabState extends State<GearTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ────────────────────────── Демо-данные
  static const _shoes = <_GearItem>[
    _GearItem(
      title: "Asics Jolt 3 Wide",
      asset: 'assets/Asics.png',
      value: '582 км',
    ),
    _GearItem(
      title: 'Hoka One One Bondi 8',
      asset: 'assets/Hoka.png',
      value: '836 км',
    ),
    _GearItem(title: 'Anta M C202', asset: 'assets/Anta.png', value: '1204 км'),
  ];

  static const _bikes = <_GearItem>[
    _GearItem(
      title: 'Pinarello Bolide TR Ultegra Di2',
      asset: 'assets/bicycle.png',
      value: '3475 км',
    ),
    _GearItem(
      title: 'SCOTT Addict Gravel 10',
      asset: 'assets/Scott.png',
      value: '2136 км',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prefs = GearPrefsScope.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ─── Кроссовки
        SliverToBoxAdapter(
          child: _SectionHeaderWithToggle(
            title: 'Кроссовки',
            value: prefs.showShoes,
            onChanged: (v) => prefs.showShoes = v,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 2)),
        SliverToBoxAdapter(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      const ViewingEquipmentScreen(initialSegment: 0),
                ),
              );
            },
            child: const _GearListCard(items: _shoes),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ─── Велосипеды
        SliverToBoxAdapter(
          child: _SectionHeaderWithToggle(
            title: 'Велосипеды',
            value: prefs.showBikes,
            onChanged: (v) => prefs.showBikes = v,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 2)),
        SliverToBoxAdapter(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      const ViewingEquipmentScreen(initialSegment: 1),
                ),
              );
            },
            child: const _GearListCard(items: _bikes),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ─── Кнопка "Добавить снаряжение" (теперь глобальный PrimaryButton)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: PrimaryButton(
                text: 'Добавить снаряжение',
                // Иконку даём через leading (цвет возьмётся от кнопки, задавать не надо)
                leading: const Icon(CupertinoIcons.plus_circle, size: 18),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const AddingEquipmentScreen(),
                    ),
                  );
                },
                // width: 260, // ← если нужна фиксированная ширина, раскомментируй
                // expanded: true, // ← или растянуть на всю ширину
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ───────────────────── Заголовок секции со свитчем
class _SectionHeaderWithToggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SectionHeaderWithToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            'На главном экране',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.brandPrimary,
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Карточка-список с элементами снаряжения
class _GearListCard extends StatelessWidget {
  final List<_GearItem> items;
  const _GearListCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: List.generate(items.length, (i) {
            final it = items[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.asset(
                          it.asset,
                          width: 64,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          it.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        it.value,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.divider,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ───────────────────── Модель элемента снаряжения
class _GearItem {
  final String title;
  final String asset;
  final String value;
  const _GearItem({
    required this.title,
    required this.asset,
    required this.value,
  });
}
