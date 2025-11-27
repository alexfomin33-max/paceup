// lib/screens/tabs/available_content.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../description/swim_trip_screen.dart';
import '../../../core/widgets/transparent_route.dart';

class AvailableContent extends StatelessWidget {
  const AvailableContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Скролл + внутренние горизонтальные отступы
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MonthLabel('Июнь 2025'),
            const SizedBox(height: 8),

            const _AvailableGrid(
              children: [
                AvailableTaskCard(
                  imageProvider: AssetImage('assets/ride200.jpg'),
                  title: 'Проехать 200 км на велосипеде за июнь',
                ),
                AvailableTaskCard(
                  imageProvider: AssetImage('assets/swim10.jpg'),
                  title: 'Проплыть в июне 10 км',
                ),
                AvailableTaskCard(
                  imageProvider: AssetImage('assets/run50.jpg'),
                  title: 'Пробежать 50 км за июнь',
                ),
              ],
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Экспедиции'),
            const SizedBox(height: 8),

            _ExpeditionGrid(
              children: [
                const AvailableExpeditionCard(
                  imageProvider: AssetImage('assets/Travel_velo.png'),
                  title: 'Путешествия на велосипеде',
                ),
                AvailableExpeditionCard(
                  imageProvider: const AssetImage('assets/Travel_swim.png'),
                  title: 'Плавательное приключение',
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      TransparentPageRoute(
                        builder: (_) => const SwimTripScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// ===== Локальные виджеты «Доступных» =====

class _MonthLabel extends StatelessWidget {
  final String text;
  const _MonthLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : null,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : null,
      ),
    );
  }
}

class _AvailableGrid extends StatelessWidget {
  final List<Widget> children;
  const _AvailableGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0, // квадратные карточки
      physics: const NeverScrollableScrollPhysics(), // скроллит общий SCSV
      shrinkWrap: true,
      children: children,
    );
  }
}

/// Грид для карточек экспедиций с квадратными карточками
class _ExpeditionGrid extends StatelessWidget {
  final List<Widget> children;
  const _ExpeditionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0, // квадратные карточки
      physics: const NeverScrollableScrollPhysics(), // скроллит общий SCSV
      shrinkWrap: true,
      children: children,
    );
  }
}

class AvailableTaskCard extends StatelessWidget {
  final ImageProvider imageProvider;
  final String title;
  final VoidCallback? onPressed;

  const AvailableTaskCard({
    super.key,
    required this.imageProvider,
    required this.title,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border.all(color: AppColors.getBorderColor(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Картинка занимает 2/3 верхней части карточки
            Expanded(
              flex: 2,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // Текст занимает 1/3 нижней части карточки
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AvailableExpeditionCard extends StatelessWidget {
  final ImageProvider imageProvider;
  final String title;
  final VoidCallback? onPressed;

  const AvailableExpeditionCard({
    super.key,
    required this.imageProvider,
    required this.title,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border.all(color: AppColors.getBorderColor(context)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Картинка занимает 2/3 верхней части карточки
            Expanded(
              flex: 2,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // Текст занимает 1/3 нижней части карточки
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
