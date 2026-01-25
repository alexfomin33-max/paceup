import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';

/// Экран справочной информации
class HelpInfoScreen extends StatelessWidget {
  const HelpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(title: 'Справочная информация', backgroundColor: AppColors.twinBg, elevation: 0, scrolledUnderElevation: 0, showBottomDivider: false,),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Общая информация
              const _InfoSection(
                title: 'О приложении',
                children: [
                  _InfoItem(
                    title: 'Что такое PaceUp?',
                    content:
                        'PaceUp — это социальная сеть для спортсменов, где вы можете делиться своими тренировками, находить единомышленников, участвовать в событиях и отслеживать свой прогресс.',
                  ),
                  _InfoItem(
                    title: 'Как начать использовать?',
                    content:
                        'После регистрации вы можете начать добавлять тренировки, подписываться на других пользователей, создавать и участвовать в событиях, а также отслеживать свою статистику.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Тренировки
              const _InfoSection(
                title: 'Тренировки',
                children: [
                  _InfoItem(
                    title: 'Как добавить тренировку?',
                    content:
                        'Вы можете добавить тренировку вручную или импортировать её из подключённых трекеров (Apple Health, Google Fit, Garmin и др.).',
                  ),
                  _InfoItem(
                    title: 'Какие типы тренировок поддерживаются?',
                    content:
                        'Приложение поддерживает бег, велоспорт, плавание и ходьбу. Вы можете указывать дистанцию, время, пульс и другие параметры.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // События
              const _InfoSection(
                title: 'События',
                children: [
                  _InfoItem(
                    title: 'Что такое события?',
                    content:
                        'События — это организованные мероприятия (забеги, велозаезды, заплывы), в которых вы можете участвовать или создавать свои собственные.',
                  ),
                  _InfoItem(
                    title: 'Как создать событие?',
                    content:
                        'Перейдите на карту, нажмите кнопку создания события, заполните информацию о мероприятии и опубликуйте его.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Клубы
              const _InfoSection(
                title: 'Клубы',
                children: [
                  _InfoItem(
                    title: 'Что такое клубы?',
                    content:
                        'Клубы — это сообщества спортсменов по интересам. Вы можете создавать свои клубы или присоединяться к существующим.',
                  ),
                  _InfoItem(
                    title: 'Как найти клуб?',
                    content:
                        'Используйте карту для поиска клубов в вашем городе или используйте поиск по названию.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Подписка PacePro
              const _InfoSection(
                title: 'PacePro',
                children: [
                  _InfoItem(
                    title: 'Что даёт подписка PacePro?',
                    content:
                        'Подписка PacePro открывает доступ к расширенной статистике, приоритетной поддержке, эксклюзивным событиям и другим премиум-функциям.',
                  ),
                  _InfoItem(
                    title: 'Как оформить подписку?',
                    content:
                        'Перейдите в настройки и выберите "Управление подпиской PacePro" для оформления или управления подпиской.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Контакты поддержки
              const _InfoSection(
                title: 'Поддержка',
                children: [
                  _InfoItem(
                    title: 'Как связаться с поддержкой?',
                    content:
                        'Вы можете отправить предложение по улучшению через раздел "Предложения по улучшению" в настройках или написать нам на почту support@paceup.ru',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Секция информации
class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
            width: 0.7,
        ),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              title,
              style: AppTextStyles.h16w6.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Элемент информации
class _InfoItem extends StatelessWidget {
  final String title;
  final String content;
  const _InfoItem({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h14w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

