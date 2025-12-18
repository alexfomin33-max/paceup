// lib/screens/tabs/available_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../description/swim_trip_screen.dart';
import '../description/run_200k_screen.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../providers/tasks_provider.dart';

class AvailableContent extends ConsumerWidget {
  const AvailableContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Загружаем задачи из API
    final tasksAsync = ref.watch(tasksProvider);

    // Скролл + внутренние горизонтальные отступы
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tasksProvider);
        await ref.read(tasksProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: tasksAsync.when(
            data: (tasksByMonth) {
              if (tasksByMonth.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Нет доступных задач',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Отображаем задачи по месяцам
                  ...tasksByMonth.map((monthGroup) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MonthLabel(monthGroup.monthYearLabel),
                        const SizedBox(height: 8),
                        _AvailableGrid(
                          children: monthGroup.tasks.map((task) {
                            return AvailableTaskCard(
                              imageUrl: task.logoUrl ?? task.imageUrl,
                              title: task.formattedTitle,
                              onPressed: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  TransparentPageRoute(
                                    builder: (_) => Run200kScreen(
                                      key: ValueKey('task_${task.id}'),
                                      taskId: task.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),

                  // Секция экспедиций (оставляем как есть)
                  const _SectionLabel('Экспедиции'),
                  const SizedBox(height: 8),
                  _ExpeditionGrid(
                    children: [
                      const AvailableExpeditionCard(
                        imageProvider: AssetImage('assets/Travel_velo.png'),
                        title: 'Путешествия на велосипеде',
                      ),
                      AvailableExpeditionCard(
                        imageProvider: const AssetImage(
                          'assets/Travel_swim.png',
                        ),
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
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) {
              // Логируем ошибку для отладки
              debugPrint('❌ AvailableContent: ошибка загрузки задач: $error');
              debugPrint('❌ AvailableContent: stackTrace: $stack');

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ошибка загрузки задач',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
  final String? imageUrl;
  final String title;
  final VoidCallback? onPressed;

  const AvailableTaskCard({
    super.key,
    this.imageUrl,
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
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: AppColors.getBorderColor(context),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.getBorderColor(context),
                        child: const Icon(Icons.image_not_supported),
                      ),
                    )
                  : Container(
                      color: AppColors.getBorderColor(context),
                      child: const Icon(Icons.fitness_center),
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
