// lib/screens/map/events/coffeerun/coffeerun_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'description_content.dart';
import 'members_content.dart';

class CoffeerunScreen extends StatefulWidget {
  const CoffeerunScreen({super.key});

  @override
  State<CoffeerunScreen> createState() => _CoffeerunScreenState();
}

class _CoffeerunScreenState extends State<CoffeerunScreen> {
  int _tab = 0; // 0 — Описание, 1 — Участники

  static const _gallery = <String>[
    'assets/coffeerun_1.png',
    'assets/coffeerun_2.png',
    'assets/coffeerun_3.png',
  ];

  void _openGallery(int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (_) => _GalleryViewer(images: _gallery, startIndex: startIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = MembersContent.demoCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, // верх уже учли в шапке
        bottom: true, // добавит отступ снизу под «бровь»
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───────── Шапка без AppBar: SafeArea + кнопки у краёв + логотип по центру
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 92,
                          child: Row(
                            children: [
                              _CircleIconBtn(
                                icon: CupertinoIcons.back,
                                semantic: 'Назад',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              Expanded(
                                child: Center(
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/coffeerun.png',
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              _CircleIconBtn(
                                icon: CupertinoIcons.pencil,
                                semantic: 'Редактировать',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Остальная часть шапки
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '"Субботний коферан"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 10),

                          const _InfoRow(
                            icon: CupertinoIcons.person_crop_circle,
                            text: 'CoffeeRun_vld',
                          ),
                          const SizedBox(height: 6),
                          const _InfoRow(
                            icon: CupertinoIcons.calendar_today,
                            text: '14 июня, 8:00',
                          ),
                          const SizedBox(height: 6),
                          const _InfoRow(
                            icon: CupertinoIcons.location_solid,
                            text: 'Дворянская улица, 27Ак1, Владимир',
                          ),

                          const SizedBox(height: 12),

                          // 3 фото: квадрат, радиус 4, кликабельные — галерея
                          Row(
                            children: [
                              _SquarePhoto(
                                'assets/coffeerun_1.png',
                                onTap: () => _openGallery(0),
                              ),
                              const SizedBox(width: 10),
                              _SquarePhoto(
                                'assets/coffeerun_2.png',
                                onTap: () => _openGallery(1),
                              ),
                              const SizedBox(width: 10),
                              _SquarePhoto(
                                'assets/coffeerun_3.png',
                                onTap: () => _openGallery(2),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Кнопки действий — secondary, радиус 4
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.surface,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Присоединиться',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.surface,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Вступить в клуб',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ───────── ЕДИНЫЙ нижний блок: вкладки + контент (без анимации)
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Вкладки: каждая — в своей половине, центрирование текста, больше высота
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HalfTab(
                              text: 'Описание',
                              selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: _HalfTab(
                              text: 'Участники (${MembersContent.demoCount})',
                              selected: _tab == 1,
                              onTap: () => setState(() => _tab = 1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: AppColors.border),

                    // Контент активной вкладки — без AnimatedSwitcher
                    if (_tab == 0)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: DescriptionContent(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 0, bottom: 0),
                        child: MembersContent(),
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
}

/// ─── helpers

/// Полупрозрачная круглая кнопка-иконка
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
          child: Icon(icon, size: 18, color: AppColors.surface),
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

class _SquarePhoto extends StatelessWidget {
  final String path;
  final VoidCallback? onTap;
  const _SquarePhoto(this.path, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            child: Image.asset(path, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Текст вкладки, центрированный в своей половине.
/// Активная вкладка — без жирности (оба w500), цвет у активной — secondary.
class _HalfTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _HalfTab({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.secondary : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
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

/// Полноэкранный просмотрщик: пейджер + зум
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int startIndex;
  const _GalleryViewer({required this.images, required this.startIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.startIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              itemBuilder: (_, i) {
                return Center(
                  child: InteractiveViewer(
                    maxScale: 4,
                    minScale: 1,
                    child: Image.asset(widget.images[i], fit: BoxFit.contain),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.surface,
                    size: 18,
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
