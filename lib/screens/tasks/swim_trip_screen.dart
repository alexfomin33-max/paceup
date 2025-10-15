// lib/screens/swim_trip_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SwimTripScreen extends StatelessWidget {
  const SwimTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background, // фоновый серый как на tasks_screen
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            expandedHeight: 130,
            elevation: 0,
            backgroundColor: AppColors.surface,
            leadingWidth: 60,
            // 1) круглая полупрозрачная кнопка назад с белой стрелкой
            leading: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.scrim40,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.back,
                        color: AppColors.surface,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/Swim_trip.png', fit: BoxFit.cover),
                  // лёгкий градиент снизу
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 0,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.scrim20],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2) Белый блок заголовка с тонкой "тенюшкой" снизу
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  // 1px тень вниз
                  BoxShadow(
                    color: AppColors.shadowSoft,
                    offset: Offset(0, 1),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Плавательное путешествие',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Проплывите все самые интересные маршруты\nнашей планеты',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3) Список проливов в карточках как на tasks_screen
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                children: [
                  _StraitCard(
                    image: AssetImage('assets/Bosfor.png'),
                    title: 'Пролив Босфор',
                    distanceKm: 29.9,
                    percent: 0.0,
                  ),
                  SizedBox(height: 12),
                  _StraitCard(
                    image: AssetImage('assets/Gibraltar.png'),
                    title: 'Гибралтарский пролив',
                    distanceKm: 65.0,
                    percent: 0.0,
                  ),
                  SizedBox(height: 12),
                  _StraitCard(
                    image: AssetImage('assets/Kerchensky.png'),
                    title: 'Керченский пролив',
                    distanceKm: 45.0,
                    percent: 0.0,
                  ),
                  SizedBox(height: 12),
                  _StraitCard(
                    image: AssetImage('assets/Beringov.png'),
                    title: 'Берингов пролив',
                    distanceKm: 86.0,
                    percent: 0.0,
                  ),
                  SizedBox(height: 12),
                  _StraitCard(
                    image: AssetImage('assets/Panamsky.png'),
                    title: 'Панамский канал',
                    distanceKm: 81.6,
                    percent: 0.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StraitCard extends StatelessWidget {
  final ImageProvider image;
  final String title;
  final double distanceKm;
  final double percent; // 0..1

  const _StraitCard({
    required this.image,
    required this.title,
    required this.distanceKm,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // стили карточек как в tasks_screen.dart
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image(
              image: image,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(percent: percent),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 из ${_km(distanceKm)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
              decoration: const BoxDecoration(
                color: AppColors.accentMint, // как на tasks_screen
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppRadius.xs),
                    bottomRight: Radius.circular(AppRadius.xs),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
