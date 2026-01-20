// lib/features/profile/screens/state/settings/hidden_content_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//                          Экран «Скрытые тренировки и посты»
//  Отображает список пользователей с переключателями для скрытия/показа
//  тренировок и постов
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../providers/services/api_provider.dart';

/// Модель пользователя со статусами скрытия
class _HiddenUser {
  final int id;
  final String name;
  final String? avatar;
  final bool isActivitiesHidden; // Тренировки скрыты
  final bool isPostsHidden; // Посты скрыты

  const _HiddenUser({
    required this.id,
    required this.name,
    this.avatar,
    required this.isActivitiesHidden,
    required this.isPostsHidden,
  });

  _HiddenUser copyWith({
    int? id,
    String? name,
    String? avatar,
    bool? isActivitiesHidden,
    bool? isPostsHidden,
  }) {
    return _HiddenUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      isActivitiesHidden: isActivitiesHidden ?? this.isActivitiesHidden,
      isPostsHidden: isPostsHidden ?? this.isPostsHidden,
    );
  }
}

class HiddenContentScreen extends ConsumerStatefulWidget {
  const HiddenContentScreen({super.key});

  @override
  ConsumerState<HiddenContentScreen> createState() =>
      _HiddenContentScreenState();
}

class _HiddenContentScreenState extends ConsumerState<HiddenContentScreen> {
  List<_HiddenUser> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHiddenUsers();
  }

  /// Загрузка списка пользователей со скрытым контентом
  Future<void> _loadHiddenUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      // Предполагаем, что endpoint называется /get_hidden_users.php
      // Если endpoint другой, его можно будет изменить
      final data = await api.get('/get_hidden_users.php');

      if (data['success'] == true) {
        final usersList = data['users'] as List<dynamic>? ?? [];
        setState(() {
          _users = usersList.map((item) {
            return _HiddenUser(
              id: item['id'] as int,
              name: item['name'] as String? ?? 'Пользователь',
              avatar: item['avatar'] as String?,
              // API возвращает: 1 = скрыто, 0 = видно
              // isActivitiesHidden: true = скрыто, false = видно
              isActivitiesHidden: (item['activities_hidden'] as int? ?? 0) == 1,
              isPostsHidden: (item['posts_hidden'] as int? ?? 0) == 1,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Ошибка при загрузке списка';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorHandler.format(e);
        _isLoading = false;
      });
    }
  }

  /// Обновление статуса скрытия тренировок
  Future<void> _updateActivitiesHidden(int userId, bool isHidden) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/hide_user_content.php',
        body: {
          'hidden_user_id': userId,
          'action': isHidden ? 'hide' : 'show',
          'content_type': 'activity',
        },
        timeout: const Duration(seconds: 10),
      );

      if (data['success'] == true) {
        // Обновляем состояние на основе ответа API
        final isHiddenFromApi = data['is_hidden'] as bool? ?? isHidden;
        setState(() {
          _users = _users.map((user) {
            if (user.id == userId) {
              return user.copyWith(isActivitiesHidden: isHiddenFromApi);
            }
            return user;
          }).toList();
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Не удалось обновить настройки',
            ),
          ),
        );
        // Откатываем изменение
        _loadHiddenUsers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.formatWithContext(
              e,
              context: 'обновлении настроек тренировок',
            ),
          ),
        ),
      );
      // Откатываем изменение
      _loadHiddenUsers();
    }
  }

  /// Обновление статуса скрытия постов
  Future<void> _updatePostsHidden(int userId, bool isHidden) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/hide_user_content.php',
        body: {
          'hidden_user_id': userId,
          'action': isHidden ? 'hide' : 'show',
          'content_type': 'post',
        },
        timeout: const Duration(seconds: 10),
      );

      if (data['success'] == true) {
        // Обновляем состояние на основе ответа API
        final isHiddenFromApi = data['is_hidden'] as bool? ?? isHidden;
        setState(() {
          _users = _users.map((user) {
            if (user.id == userId) {
              return user.copyWith(isPostsHidden: isHiddenFromApi);
            }
            return user;
          }).toList();
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Не удалось обновить настройки',
            ),
          ),
        );
        // Откатываем изменение
        _loadHiddenUsers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.formatWithContext(
              e,
              context: 'обновлении настроек постов',
            ),
          ),
        ),
      );
      // Откатываем изменение
      _loadHiddenUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Скрытые тренировки и посты'),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        onPressed: _loadHiddenUsers,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.eye_slash,
                        size: 48,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет скрытых пользователей',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ─── Единая таблица ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.getBorderColor(context),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // ─── Заголовок таблицы ───
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Пользователь',
                                        style: AppTextStyles.h13w5.copyWith(
                                          color:
                                              AppColors.getTextSecondaryColor(
                                                context,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Center(
                                      child: Text(
                                        'Тренировки',
                                        style: AppTextStyles.h13w5.copyWith(
                                          color:
                                              AppColors.getTextSecondaryColor(
                                                context,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Center(
                                      child: Text(
                                        'Посты',
                                        style: AppTextStyles.h13w5.copyWith(
                                          color:
                                              AppColors.getTextSecondaryColor(
                                                context,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ─── Разделитель после заголовка ───
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: AppColors.getBorderColor(context),
                              ),
                              // ─── Список пользователей ───
                              ...List.generate(_users.length, (index) {
                                final user = _users[index];
                                return Column(
                                  children: [
                                    _HiddenUserRow(
                                      user: user,
                                      onActivitiesChanged: (value) {
                                        // value = новое состояние переключателя
                                        // Если переключатель включен (true) → контент скрыт → isHidden = true
                                        // Если переключатель выключен (false) → контент виден → isHidden = false
                                        _updateActivitiesHidden(
                                          user.id,
                                          value,
                                        );
                                      },
                                      onPostsChanged: (value) {
                                        // value = новое состояние переключателя
                                        // Если переключатель включен (true) → контент скрыт → isHidden = true
                                        // Если переключатель выключен (false) → контент виден → isHidden = false
                                        _updatePostsHidden(
                                          user.id,
                                          value,
                                        );
                                      },
                                    ),
                                    // ─── Разделитель между строками (кроме последней) ───
                                    if (index < _users.length - 1)
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        color: AppColors.getBorderColor(
                                          context,
                                        ),
                                        indent:
                                            64, // Отступ для выравнивания с аватаром
                                      ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Строка таблицы с пользователем и переключателями
class _HiddenUserRow extends StatelessWidget {
  final _HiddenUser user;
  final ValueChanged<bool> onActivitiesChanged;
  final ValueChanged<bool> onPostsChanged;

  const _HiddenUserRow({
    required this.user,
    required this.onActivitiesChanged,
    required this.onPostsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
      child: Row(
        children: [
          // ─── Первая колонка: аватар и имя ───
          Expanded(
            child: Row(
              children: [
                Avatar(
                  image: user.avatar != null && user.avatar!.isNotEmpty
                      ? user.avatar!
                      : 'assets/avatar_0.png',
                  size: 40,
                  fadeIn: true,
                  gapless: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.name,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ─── Вторая колонка: переключатель "Тренировки" ───
          const SizedBox(width: 16),
          Center(
            child: Transform.scale(
              scale: 0.75,
              child: CupertinoSwitch(
                // Переключатель включен (true) = контент скрыт (isActivitiesHidden)
                // Переключатель выключен (false) = контент виден (!isActivitiesHidden)
                value: user.isActivitiesHidden,
                onChanged: onActivitiesChanged,
                activeTrackColor: AppColors.brandPrimary,
              ),
            ),
          ),

          // ─── Третья колонка: переключатель "Посты" ───
          const SizedBox(width: 16),
          Center(
            child: Transform.scale(
              scale: 0.75,
              child: CupertinoSwitch(
                // Переключатель включен (true) = контент скрыт (isPostsHidden)
                // Переключатель выключен (false) = контент виден (!isPostsHidden)
                value: user.isPostsHidden,
                onChanged: onPostsChanged,
                activeTrackColor: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
