import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../domain/models/activity_lenta.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../features/lenta/screens/widgets/activity/activity_block.dart';
import '../../../../../features/lenta/screens/activity/description_screen.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../../core/widgets/error_display.dart';

/// Экран со списком всех тренировок пользователя
class AllTrainingScreen extends ConsumerStatefulWidget {
  final int userId;

  const AllTrainingScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<AllTrainingScreen> createState() => _AllTrainingScreenState();
}

class _AllTrainingScreenState extends ConsumerState<AllTrainingScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Activity> _activities = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  int? _currentUserId;
  static const int _limit = 20; // количество тренировок на странице

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadActivities(reset: true);

    // Автоматическая подгрузка при скролле
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_isLoadingMore || !_hasMore) return;

      final pos = _scrollController.position;
      // Подгружаем когда осталось 200px до конца
      if (pos.extentAfter < 200) {
        _loadActivities();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Загрузка текущего userId
  Future<void> _loadCurrentUserId() async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  /// Загрузка тренировок с сервера
  Future<void> _loadActivities({bool reset = false}) async {
    if (_isLoading && !reset) return;

    if (reset) {
      setState(() {
        _activities.clear();
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore && !reset) return;

    try {
      setState(() {
        if (reset) {
          _isLoading = true;
        } else {
          _isLoadingMore = true;
        }
      });

      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/activities_lenta.php',
        body: {
          'userId': '${widget.userId}',
          'limit': '$_limit',
          'page': '$_currentPage',
          'showTrainings': '1', // только тренировки
          'showPosts': '0', // без постов
          'showOwn': '1', // только свои
          'showOthers': '0', // без чужих
        },
        timeout: const Duration(seconds: 15),
      );

      // PHP API возвращает массив напрямую, а не в поле 'data'
      List<dynamic> rawList;
      if (response is List<dynamic>) {
        rawList = List<dynamic>.from(response as List);
      } else {
        // В этом ветке response гарантированно Map<String, dynamic>
        if (response.containsKey('data')) {
          final dataValue = response['data'];
          if (dataValue is List) {
            rawList = List<dynamic>.from(dataValue);
          } else {
            rawList = const <dynamic>[];
          }
        } else {
          rawList = const <dynamic>[];
        }
      }

      final newActivities = rawList
          .whereType<Map<String, dynamic>>()
          .map(Activity.fromApi)
          .where((a) => a.type != 'post') // дополнительная фильтрация постов
          .toList();

      // Сортировка по дате (новые сверху)
      newActivities.sort((a, b) {
        DateTime? dateA = a.dateStart ?? a.lentaDate;
        DateTime? dateB = b.dateStart ?? b.lentaDate;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          if (reset) {
            _activities = newActivities;
          } else {
            _activities.addAll(newActivities);
          }
          _currentPage++;
          _hasMore = newActivities.length >= _limit;
          _isLoading = false;
          _isLoadingMore = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = ErrorHandler.format(e);
        });
      }
    }
  }

  /// Pull-to-refresh обновление
  Future<void> _onRefresh() async {
    await _loadActivities(reset: true);
  }

  /// Открытие детального экрана тренировки
  Future<void> _openActivity(Activity activity) async {
    final authService = ref.read(authServiceProvider);
    final currentUserId = await authService.getUserId();
    if (currentUserId == null || !mounted) return;

    Navigator.of(context, rootNavigator: true).push(
      TransparentPageRoute(
        builder: (_) => ActivityDescriptionPage(
          activity: activity,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: PaceAppBar(
        title: 'Тренировки',
        showBottomDivider: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Показываем ошибку, если есть
    if (_error != null && _activities.isEmpty) {
      return ErrorDisplay.centered(
        error: _error,
        onRetry: () => _loadActivities(reset: true),
      );
    }

    // Показываем индикатор загрузки при первой загрузке
    if (_isLoading && _activities.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // Показываем пустую ленту
    if (_activities.isEmpty && !_isLoading) {
      return RefreshIndicator.adaptive(
        onRefresh: _onRefresh,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 12),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'Пока нет тренировок',
                style: AppTextStyles.h14w4,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    // Основной список тренировок
    return RefreshIndicator.adaptive(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _activities.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Индикатор загрузки в конце списка
          if (index == _activities.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          final activity = _activities[index];
          final currentUserId = _currentUserId ?? 0;

          return Column(
            children: [
              ActivityBlock(
                activity: activity,
                currentUserId: currentUserId,
                onOpenDescription: () => _openActivity(activity),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
