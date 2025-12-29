// =========================== main_tab.dart ===========================
// Экран вкладки "Основное" в профиле.
// Здесь:
//   • загружаем данные по API (FutureBuilder),
//   • собираем сливер-ленту из простых презентеров/виджетов,
//   • используем вынесенные модели и секцию снаряжения.
//
// Важно: вся логика данных (парсинг JSON и модели) вынесена в main_tab_data.dart,
// а секция снаряжения — в gear_section_sliver.dart. Это упрощает поддержку и тестирование.
// Флаги видимости снаряжения (show_on_main) приходят из API.

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../equipment/viewing/viewing_equipment_screen.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🔹 Модели и парсинг данных
import 'models/main_tab_data.dart';
// 🔹 Виджет-секция "Снаряжение" как один sliver
import 'widgets/gear_section_sliver.dart';
// 🔹 График недельной активности
import 'widgets/weekly_activity_chart.dart';

class MainTab extends ConsumerStatefulWidget {
  final int userId; // ID пользователя, для которого показываем вкладку
  final VoidCallback? onTabActivated; // Callback при активации вкладки
  const MainTab({super.key, required this.userId, this.onTabActivated});

  @override
  ConsumerState<MainTab> createState() => _MainTabState();

  /// Публичный метод для принудительной проверки кэша (можно вызвать извне через GlobalKey)
  static void checkCache(GlobalKey<MainTabState>? key) {
    key?.currentState?.checkCache();
  }
}

/// Публичный класс состояния для доступа извне
abstract class MainTabState extends ConsumerState<MainTab> {
  /// Публичный метод для принудительной проверки кэша
  void checkCache();
}

class _MainTabState extends MainTabState
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // Храним будущий результат загрузки, чтобы не перезагружать при каждом build
  Future<MainTabData>? _future;
  bool _isCheckingCache =
      false; // Флаг для предотвращения параллельных проверок

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load(); // первая загрузка при открытии вкладки
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // При возврате приложения из фона обновляем данные
    if (state == AppLifecycleState.resumed) {
      _checkAndReload();
    }
  }

  @override
  void checkCache() {
    _checkAndReload();
  }

  /// Проверяет, нужно ли обновить данные (если кэш был очищен)
  /// Возвращает true, если данные были обновлены
  Future<bool> _checkAndReload() async {
    if (!mounted || _isCheckingCache) return false;

    _isCheckingCache = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'main_tab_${widget.userId}';
      final cachedJson = prefs.getString(cacheKey);

      // Если кэш был очищен, принудительно обновляем данные
      if (cachedJson == null) {
        // Проверяем, что Future уже завершен (чтобы не перезагружать во время загрузки)
        if (_future != null) {
          try {
            await _future!.timeout(const Duration(milliseconds: 100));
          } catch (e) {
            // Future еще выполняется - ничего не делаем, выходим
            return false;
          }
        }
        // Если Future завершен или его нет, обновляем данные
        if (mounted) {
          setState(() {
            _future = _load(forceRefresh: true);
          });
          return true;
        }
      }
      return false;
    } finally {
      _isCheckingCache = false;
    }
  }

  void _openShoesView() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewingEquipmentScreen(
          initialSegment: 0,
          userId: widget.userId,
        ),
      ),
    );
    // Обновляем данные после возврата (если кэш был очищен)
    if (mounted) {
      _checkAndReload();
    }
  }

  void _openBikesView() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewingEquipmentScreen(
          initialSegment: 1,
          userId: widget.userId,
        ),
      ),
    );
    // Обновляем данные после возврата (если кэш был очищен)
    if (mounted) {
      _checkAndReload();
    }
  }

  @override
  void didUpdateWidget(covariant MainTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если userId изменился (например, открыли профиль другого пользователя),
    // перезапускаем загрузку данных.
    if (oldWidget.userId != widget.userId) {
      _future = _load();
    } else {
      // Проверяем кэш при обновлении виджета (например, при возврате на вкладку)
      // Это нужно для обновления данных после очистки кэша из другой вкладки
      // Используем addPostFrameCallback, чтобы не блокировать didUpdateWidget
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndReload();
      });
    }
    // Если изменился callback, сохраняем его для использования
    if (oldWidget.onTabActivated != widget.onTabActivated) {
      // Callback изменился - это может означать, что вкладка активирована
      widget.onTabActivated?.call();
    }
  }

  // Запрос к API с offline-first кэшированием
  Future<MainTabData> _load({bool forceRefresh = false}) async {
    final cacheKey = 'main_tab_${widget.userId}';

    try {
      // Попытка загрузить с сервера
      final api = ref.read(apiServiceProvider);
      final jsonMap = await api.post(
        '/user_profile_maintab.php',
        body: {'userId': widget.userId.toString()},
      );

      if (jsonMap['ok'] == false) {
        throw Exception(jsonMap['error'] ?? 'API error');
      }

      // Сохраняем в кэш для offline режима
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(jsonMap));

      return MainTabData.fromJson(jsonMap);
    } catch (e) {
      // Если ошибка (нет интернета) - пробуем загрузить из кэша
      // Но только если это не принудительное обновление
      if (!forceRefresh) {
        if (kDebugMode) {
          debugPrint('⚠️ Ошибка загрузки main tab: $e, пробуем кэш...');
        }

        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(cacheKey);

        if (cachedJson != null) {
          if (kDebugMode) {
            debugPrint('✅ Загружены данные из кэша');
          }
          final jsonMap = jsonDecode(cachedJson) as Map<String, dynamic>;
          return MainTabData.fromJson(jsonMap);
        }
      }

      // Если кэша нет или принудительное обновление - пробрасываем ошибку
      rethrow;
    }
  }

  // Метод для обновления данных (pull-to-refresh)
  Future<void> _refresh() async {
    setState(() {
      _future = _load(forceRefresh: true);
    });
    await _future;
  }

  // Вкладка должна сохранять своё состояние (скролл, позиции и т.д.), когда мы перелистываем PageView
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // важно для AutomaticKeepAliveClientMixin

    // Проверяем кэш при каждом build (асинхронно, чтобы не блокировать UI)
    // Это нужно для обновления данных при переключении на вкладку из другого экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndReload();
    });

    return _buildContent();
  }

  Widget _buildContent() {
    return FutureBuilder<MainTabData>(
      future: _future ??= _load(), // повторная подстраховка
      builder: (context, snap) {
        // Всегда показываем CustomScrollView с pull-to-refresh
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───────────────── Pull-to-refresh ─────────────────
            CupertinoSliverRefreshControl(onRefresh: _refresh),

            // Состояние "ждём" (только при первой загрузке) — показываем индикатор
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              )
            // Состояние "ошибка" — показываем текст ошибки
            else if (snap.hasError && !snap.hasData)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Не удалось загрузить данные\n${ErrorHandler.format(snap.error!)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                ),
              )
            // Успешная загрузка — собираем сливеры
            else if (snap.hasData)
              ..._buildContentSlivers(snap.data!),
          ],
        );
      },
    );
  }

  // Метод для построения контента (вынесен для читаемости)
  List<Widget> _buildContentSlivers(MainTabData data) {
    // Определяем, является ли открытый профиль профилем текущего пользователя
    // для условного отображения иконки редактирования в карточках снаряжения
    final currentUserIdAsync = ref.read(currentUserIdProvider);
    final currentUserId = currentUserIdAsync.value;
    final isOwnProfile = currentUserId != null && currentUserId == widget.userId;

    return [
      // ───────────────── Активность (горизонтальный скроллер) ─────────────────
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      const SliverToBoxAdapter(child: _SectionTitle('Активность')),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Преобразуем модели активности в простые элементы для карточек
      // ───────────────── Временное скрытие первой карточки ─────────────────
      // Комментарий: на время задачи исключаем первый элемент через skip(1),
      // чтобы отображались только следующие три карточки.
      SliverToBoxAdapter(
        child: _ActivityScroller(
          items: data.activity
              .skip(1)
              .map((a) => _ActItem(a.asset, a.value, a.label))
              .toList(growable: false),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // ───────────────── Снаряжение (кроссовки / велосипеды) ─────────────────
      // Показываем только если флаг "На главном экране" включен (show_on_main=1)
      // и есть снаряжение с main=1
      // Кроссовки
      if (data.showShoesOnMain && data.shoes.isNotEmpty)
        GearSectionSliver(
          title: 'Кроссовки',
          items: data.shoes,
          isBike: false,
          isOwnProfile: isOwnProfile,
          onItemTap: _openShoesView,
        ),

      // Велосипеды
      if (data.showBikesOnMain && data.bikes.isNotEmpty)
        GearSectionSliver(
          title: 'Велосипед',
          items: data.bikes,
          isBike: true,
          isOwnProfile: isOwnProfile,
          onItemTap: _openBikesView,
        ),

      // ───────────────── Личные рекорды ─────────────────
      const SliverToBoxAdapter(child: _SectionTitle('Личные рекорды')),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(child: _PRRow(items: data.prs)),

      // ───────────────── Общая статистика ─────────────────
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      const SliverToBoxAdapter(child: _SectionTitle('Общая статистика')),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      
      // График недельной активности (блок внутри WeeklyActivityChart)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: WeeklyActivityChart(userId: widget.userId),
        ),
      ),
      
      // ───────────────── Показатели ─────────────────
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      const SliverToBoxAdapter(child: _SectionTitle('Показатели')),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(child: _MetricsCard(data: data.metrics)),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

/// ───────────────────── Мелкие презентеры (чистая верстка без логики) ─────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    // Заголовок секций внутри ленты
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

class _ActivityScroller extends StatelessWidget {
  final List<_ActItem>
  items; // список элементов активности (иконка + значение + подпись)
  const _ActivityScroller({required this.items});

  @override
  Widget build(BuildContext context) {
    // Горизонтальный список карточек активности (ходьба/бег/вел/плавание)
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, i) => _ActivityCard(items[i]),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

// Простой контейнер данных для карточки активности (UI-слой)
class _ActItem {
  final String asset; // путь к локальной картинке
  final String value; // числовое значение (например: "12 км")
  final String label; // подпись под числом (например: "Бег")
  _ActItem(this.asset, this.value, this.label);
}

class _ActivityCard extends StatelessWidget {
  final _ActItem item;
  const _ActivityCard(this.item);

  @override
  Widget build(BuildContext context) {
    // Одна карточка активности
    // Картинка занимает 2/3 верхней части, текст — нижнюю треть
    return SizedBox(
      width: 120,
      height: 120,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Картинка на всю ширину, занимает 2/3 высоты карточки
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
                child: Image.asset(
                  item.asset,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.getBorderColor(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            // Текст в нижней трети карточки
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Значение (крупный текст)
                    Text(
                      item.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Подпись (мелкий текст)
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PRRow extends StatelessWidget {
  final List<(PRAsset, String)> items; // список кортежей (иконка, время)
  const _PRRow({required this.items});

  @override
  Widget build(BuildContext context) {
    // Ряд из 4 бейджей с PR (5k/10k/21k/42k) и временем
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items
              .map((e) => _PRBadge(asset: e.$1.path, time: e.$2))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PRBadge extends StatelessWidget {
  final String asset; // путь к локальной картинке медали/дистанции
  final String time; // строка времени PR
  const _PRBadge({required this.asset, required this.time});

  @override
  Widget build(BuildContext context) {
    // Один бейдж из секции PR
    return Column(
      children: [
        Image.asset(asset, width: 72, height: 72, fit: BoxFit.contain),
        const SizedBox(height: 6),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final MetricsData data; // данные показателей (VO2max, темп, мощность и т.д.)
  const _MetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Готовим строки для отображения: иконка, подпись, значение справа
    final rows = <(IconData, String, String)>[
      (
        CupertinoIcons.arrow_right,
        'Среднее расстояние в неделю',
        data.avgWeekDistance,
      ),
      (CupertinoIcons.heart, 'МПК', data.vo2max),
      (CupertinoIcons.speedometer, 'Средний темп', data.avgPace),
      (CupertinoIcons.bolt, 'Мощность', data.power),
      (CupertinoIcons.waveform, 'Каденс', data.cadence),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: List.generate(rows.length, (i) {
            final r = rows[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(r.$1, size: 16, color: AppColors.brandPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.$2,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            // В темной теме используем цвет возраста и города из хэдера
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      Text(
                        r.$3,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.getDividerColor(context),
                    indent: 40,
                    endIndent: 10,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// Вспомогательный виджет: центрирует любой child в SliverFillRemaining (для экранов статуса)
class SliverFillRemainingCentered extends StatelessWidget {
  final Widget child;
  const SliverFillRemainingCentered({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
  }
}
