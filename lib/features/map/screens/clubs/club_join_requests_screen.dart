import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../profile/screens/profile_screen.dart';

/// ──────────────────────── Экран "Заявки" клуба ────────────────────────
class ClubJoinRequestsScreen extends ConsumerStatefulWidget {
  final int clubId;

  const ClubJoinRequestsScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubJoinRequestsScreen> createState() =>
      _ClubJoinRequestsScreenState();
}

class _ClubJoinRequestsScreenState
    extends ConsumerState<ClubJoinRequestsScreen> {
  // ──────────────────────── Состояние экрана ────────────────────────
  final List<_JoinRequestEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String _searchQuery = '';
  int _requestId = 0;

  static const int _limit = 15;

  @override
  void initState() {
    super.initState();
    // ───── Первичная загрузка данных ─────
    _loadRequests(reset: true);
    // ───── Подписка на скролл для пагинации ─────
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // ───── Освобождаем контроллер скролла ─────
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // ───── Очищаем ресурсы поиска ─────
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// ──────────────────────── Обработка прокрутки ────────────────────────
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.8 && !_isLoading && _hasMore) {
      _loadRequests();
    }
  }

  /// ──────────────────────── Применение фильтра поиска ────────────────────────
  void _applySearch(String query) {
    // ───── Сбрасываем список и перезагружаем данные ─────
    setState(() {
      _searchQuery = query;
    });
    _loadRequests(reset: true);
  }

  /// ──────────────────────── Обработка ввода в поле поиска ────────────────────────
  void _onSearchChanged(String value) {
    final query = value.trim();
    if (query == _searchQuery) return;

    // ───── Дебаунс, чтобы не слать запросы на каждый символ ─────
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applySearch(query);
    });
  }

  /// ──────────────────────── Обработка отправки поиска ────────────────────────
  void _onSearchSubmitted(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    if (query == _searchQuery) return;
    _applySearch(query);
  }

  /// ──────────────────────── Загрузка списка заявок ────────────────────────
  Future<void> _loadRequests({bool reset = false}) async {
    if (_isLoading) return;
    if (!mounted) return;
    if (reset) {
      setState(() {
        _entries.clear();
        _page = 1;
        _hasMore = true;
        _error = null;
      });
    }
    if (!_hasMore && !reset) return;

    // ───── Фиксируем запрос для защиты от устаревших ответов ─────
    final requestId = ++_requestId;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      // ───── Формируем параметры запроса с учетом фильтра ─────
      final queryParams = <String, String>{
        'club_id': widget.clubId.toString(),
        'page': _page.toString(),
        'limit': _limit.toString(),
      };
      if (_searchQuery.isNotEmpty) {
        queryParams['query'] = _searchQuery;
      }
      final data = await api.get(
        '/get_club_join_requests.php',
        queryParams: queryParams,
      );

      if (!mounted) return;
      if (requestId != _requestId) return;

      if (data['success'] == true) {
        final requests = data['requests'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;
        final newEntries = requests
            .map((item) => _JoinRequestEntry.fromApi(
                  item as Map<String, dynamic>,
                ))
            .toList();
        setState(() {
          _entries.addAll(newEntries);
          _hasMore = hasMore;
          _page++;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              data['message'] as String? ?? 'Ошибка загрузки заявок';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.formatWithContext(
          e,
          context: 'загрузке заявок',
        );
        _isLoading = false;
      });
    }
  }

  /// ──────────────────────── Принятие заявки ────────────────────────
  Future<void> _acceptRequest(_JoinRequestEntry entry) async {
    if (!mounted) return;
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/accept_club_join_request.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': entry.userId.toString(),
        },
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _entries.removeWhere((e) => e.userId == entry.userId);
        });
      } else {
        setState(() {
          _error =
              response['message'] as String? ?? 'Ошибка принятия заявки';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.formatWithContext(
          e,
          context: 'принятии заявки',
        );
      });
    }
  }

  /// ──────────────────────── Переход в профиль пользователя ────────────────────────
  void _openProfile(int userId) {
    Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  /// ──────────────────────── Форматирование даты подачи ────────────────────────
  String _formatRequestedDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  /// ──────────────────────── Поле фильтрации списка ────────────────────────
  Widget _buildFilterField() {
    // ───── Цвета и стили для поля поиска ─────
    final textColor = AppColors.getTextPrimaryColor(context);
    final placeholderColor = AppColors.getTextSecondaryColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final surfaceColor = AppColors.getSurfaceColor(context);
    final iconColor = AppColors.getIconSecondaryColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) {
          // ───── Состояние кнопки очистки ─────
          final hasText = value.text.trim().isNotEmpty;

          return CupertinoTextField(
            controller: _searchController,
            placeholder: 'Поиск по имени/фамилии',
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
            cursorColor: AppColors.brandPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: borderColor),
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: textColor,
            ),
            placeholderStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: placeholderColor,
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.xs,
              ),
              child: Icon(
                CupertinoIcons.search,
                size: 18,
                color: iconColor,
              ),
            ),
            suffix: hasText
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchSubmitted('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.xs,
                        right: AppSpacing.sm,
                      ),
                      child: Icon(
                        CupertinoIcons.clear_thick_circled,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  /// ──────────────────────── Пустое состояние списка ────────────────────────
  Widget _buildEmptyState() {
    // ───── Сообщение зависит от активного фильтра ─────
    final message = _searchQuery.isNotEmpty
        ? 'Ничего не найдено'
        : 'Заявок нет';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          message,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  /// ──────────────────────── Ошибка загрузки списка ────────────────────────
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SelectableText.rich(
          TextSpan(
            text: message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.error,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// ──────────────────────── Список с пагинацией и обновлением ────────────────────────
  Widget _buildListBody() {
    if (_isLoading && _entries.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 12),
      );
    }

    if (_error != null && _entries.isEmpty) {
      return _buildErrorState(_error!);
    }

    return RefreshIndicator(
      onRefresh: () => _loadRequests(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: _entries.isEmpty
            ? 1
            : _entries.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (_entries.isEmpty) {
            return _buildEmptyState();
          }

          if (index >= _entries.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: CupertinoActivityIndicator(radius: 12),
              ),
            );
          }

          final entry = _entries[index];
          return _JoinRequestCard(
            entry: entry,
            requestedAtLabel: _formatRequestedDate(entry.requestedAt),
            onUserTap: () => _openProfile(entry.userId),
            onAccept: () => _acceptRequest(entry),
          );
        },
      ),
    );
  }

  /// ──────────────────────── Основной контент ────────────────────────
  Widget _buildContent() {
    return Column(
      children: [
        _buildFilterField(),
        Expanded(
          child: _buildListBody(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Заявки'),
        body: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }
}

/// ──────────────────────── Модель заявки ────────────────────────
class _JoinRequestEntry {
  final int userId;
  final String name;
  final String avatarUrl;
  final DateTime? requestedAt;

  const _JoinRequestEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.requestedAt,
  });

  /// ──────────────────────── Создание из ответа API ────────────────────────
  factory _JoinRequestEntry.fromApi(Map<String, dynamic> json) {
    final requestedAtRaw = json['requested_at']?.toString();
    DateTime? requestedAt;
    if (requestedAtRaw != null && requestedAtRaw.isNotEmpty) {
      try {
        requestedAt = DateTime.parse(requestedAtRaw);
      } catch (_) {}
    }

    return _JoinRequestEntry(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Пользователь',
      avatarUrl: json['avatar_url'] as String? ?? '',
      requestedAt: requestedAt,
    );
  }
}

/// ──────────────────────── Карточка заявки ────────────────────────
class _JoinRequestCard extends StatelessWidget {
  final _JoinRequestEntry entry;
  final String requestedAtLabel;
  final VoidCallback onUserTap;
  final VoidCallback onAccept;

  const _JoinRequestCard({
    required this.entry,
    required this.requestedAtLabel,
    required this.onUserTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.twinchip),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onUserTap,
              child: ClipOval(
                child: Builder(
                  builder: (context) {
                    // ───── Подготовка размеров кэша для аватара ─────
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final cacheSize = (44 * dpr).round();

                    if (entry.avatarUrl.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: entry.avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: cacheSize,
                        memCacheHeight: cacheSize,
                        placeholder: (context, url) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.getBorderColor(context),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: 10,
                              color:
                                  AppColors.getIconSecondaryColor(context),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.getBorderColor(context),
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      );
                    }

                    return Container(
                      width: 44,
                      height: 44,
                      color: AppColors.getBorderColor(context),
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.getIconSecondaryColor(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onUserTap,
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Дата подачи: $requestedAtLabel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onAccept,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Принять',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
