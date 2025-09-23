// lib/screens/swim_trip_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SwimTripScreen extends StatelessWidget {
  const SwimTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background, // без нижней навигации: обычный пуш
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            expandedHeight: 220,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: AppColors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/Swim_trip.png', fit: BoxFit.cover),
                  // лёгкий градиент снизу для читабельности
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Заголовок и подзаголовок
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    'Плавательное путешествие',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Проплывите все самые интересные маршруты\nнашей планеты',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.greytext,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // «белая карточка»-контейнер со списком проливов
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: const [
                    _RouteCard(
                      image: AssetImage('assets/Bosfor.png'),
                      title: 'Пролив Босфор',
                      distanceKm: 29.9,
                      percent: 0.0,
                    ),
                    SizedBox(height: 10),
                    _RouteCard(
                      image: AssetImage('assets/Gibraltar.png'),
                      title: 'Гибралтарский пролив',
                      distanceKm: 65.0,
                      percent: 0.0,
                    ),
                    SizedBox(height: 10),
                    _RouteCard(
                      image: AssetImage('assets/Kerchensky.png'),
                      title: 'Керченский пролив',
                      distanceKm: 45.0,
                      percent: 0.0,
                    ),
                    SizedBox(height: 10),
                    _RouteCard(
                      image: AssetImage('assets/Beringov.png'),
                      title: 'Берингов пролив',
                      distanceKm: 86.0,
                      percent: 0.0,
                    ),
                    SizedBox(height: 10),
                    _RouteCard(
                      image: AssetImage('assets/Panamsky.png'),
                      title: 'Панамский канал',
                      distanceKm: 81.6,
                      percent: 0.0,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final ImageProvider image;
  final String title;
  final double distanceKm;
  final double percent; // 0..1

  const _RouteCard({
    required this.image,
    required this.title,
    required this.distanceKm,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // мини-превью
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: image,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // текст + прогресс
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // заголовок
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),

                // прогресс бар
                _ProgressBar(percent: percent),

                const SizedBox(height: 4),

                // подпись прогресса
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 из ${_km(distanceKm)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: AppColors.greytext,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.greytext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _km(double v) {
    // 29.9 -> "29,9 км" (как в макете)
    final s = v
        .toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)
        .replaceAll('.', ',');
    return '$s км';
  }
}

class _ProgressBar extends StatelessWidget {
  final double percent;
  const _ProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (percent.clamp(0, 1)) * c.maxWidth;
        return Row(
          children: [
            Container(
              width: w,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF22CCB2), // как в tasks_screen
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
