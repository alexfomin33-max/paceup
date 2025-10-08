import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

import 'photo_content.dart';
import 'members_content.dart';
import 'stats_content.dart';
import 'glory_content.dart';

class CoffeeRunVldScreen extends StatefulWidget {
  const CoffeeRunVldScreen({super.key});

  @override
  State<CoffeeRunVldScreen> createState() => _CoffeeRunVldScreenState();
}

class _CoffeeRunVldScreenState extends State<CoffeeRunVldScreen> {
  int _tab = 0; // 0 Фото, 1 Участники, 2 Статистика, 3 Зал славы

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Лёгкая предзагрузка ключевых картинок, чтобы не фризило на входе
    for (final a in const [
      'assets/vladimir.png',
      'assets/coffeerun_vld_logo.png',
      'assets/coffeerun_vld_photo_1.png',
      'assets/coffeerun_vld_photo_2.png',
      'assets/coffeerun_vld_photo_3.png',
      'assets/coffeerun_vld_photo_4.png',
      'assets/coffeerun_vld_photo_5.png',
      'assets/coffeerun_vld_photo_6.png',
      'assets/coffeerun_vld_photo_7.png',
      'assets/coffeerun_vld_photo_8.png',
      'assets/coffeerun_vld_photo_9.png',
    ]) {
      precacheImage(AssetImage(a), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───────── Cover + overlay-кнопки
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Cover
                  Image.asset(
                    'assets/vladimir.png',
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  // Верхние кнопки
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _CircleIconBtn(
                            icon: CupertinoIcons.back,
                            semantic: 'Назад',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),

                          _CircleIconBtn(
                            icon: CupertinoIcons.pencil,
                            semantic: 'Редактировать',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ───────── «Шапка» карточки клуба
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Лого + имя
                    Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/coffeerun_vld_logo.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'CoffeeRun_vld',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Описание
                    const Text(
                      'Сообщество любителей городских пробежек.\n• Бегаем по субботам\n• Финиш с горячим кофе и чаем',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Инфо-блок
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: const Column(
                        children: [
                          _InfoRow(
                            icon: CupertinoIcons.lock_fill,
                            text: 'Закрытое беговое сообщество',
                          ),
                          SizedBox(height: 8),
                          _InfoRow(
                            icon: CupertinoIcons.calendar,
                            text: 'Создано: 16 октября 2023',
                          ),
                          SizedBox(height: 8),
                          _InfoRow(
                            icon: CupertinoIcons.person_2_fill,
                            text: 'Участников: 400',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Кнопка «Запрос на вступление»
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Запрос на вступление',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ───────── Табы + контент
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          _TabBtn(
                            text: 'Фото',
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                          _vDivider(),
                          _TabBtn(
                            text: 'Участники',
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                          _vDivider(),
                          _TabBtn(
                            text: 'Статистика',
                            selected: _tab == 2,
                            onTap: () => setState(() => _tab = 2),
                          ),
                          _vDivider(),
                          _TabBtn(
                            text: 'Зал славы',
                            selected: _tab == 3,
                            onTap: () => setState(() => _tab = 3),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    if (_tab == 0)
                      const Padding(
                        padding: EdgeInsets.all(2),
                        child: CoffeeRunVldPhotoContent(),
                      )
                    else if (_tab == 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 0, bottom: 0),
                        child: CoffeeRunVldMembersContent(),
                      )
                    else if (_tab == 2)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: CoffeeRunVldStatsContent(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: CoffeeRunVldGloryContent(),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 24, color: AppColors.border);
}

/// ——— helpers (как в coffeerun_screen.dart)

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final String? semantic;
  final VoidCallback onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.30),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.secondary : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        // одинаковый отступ от текста до вертикального разделителя
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
