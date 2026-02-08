import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/segmented_pill.dart';
import '../../../../../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ЭКРАН РЕПОСТА МАРШРУТА В ЧАТ
// ─────────────────────────────────────────────────────────────────────────────
class RouteShareScreen extends StatefulWidget {
  final int routeId;
  final int userId;
  final String routeName;

  const RouteShareScreen({
    super.key,
    required this.routeId,
    required this.userId,
    required this.routeName,
  });

  @override
  State<RouteShareScreen> createState() => _RouteShareScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// ВНУТРЕННИЕ МОДЕЛИ ДЛЯ СПИСКОВ
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalChatTarget {
  final int chatId;
  final int userId;
  final String name;
  final String avatarUrl;

  const _PersonalChatTarget({
    required this.chatId,
    required this.userId,
    required this.name,
    required this.avatarUrl,
  });
}

class _ClubChatTarget {
  final int clubId;
  final String name;
  final String? logoUrl;

  const _ClubChatTarget({
    required this.clubId,
    required this.name,
    this.logoUrl,
  });
}

class _RouteShareScreenState extends State<RouteShareScreen> {
  // ────────────────────────────────────────────────────────────
  // 🔹 Сегмент: 0 — личные, 1 — клубы
  // ────────────────────────────────────────────────────────────
  int _segmentIndex = 0;

  // ────────────────────────────────────────────────────────────
  // 🔹 Состояние отправки
  // ────────────────────────────────────────────────────────────
  bool _isSending = false;
  int? _sendingTargetId;

  // ────────────────────────────────────────────────────────────
  // 🔹 Источники данных
  // ────────────────────────────────────────────────────────────
  final ApiService _api = ApiService();
  late final Future<List<_PersonalChatTarget>> _personalChatsFuture;
  late final Future<List<_ClubChatTarget>> _clubChatsFuture;

  @override
  void initState() {
    super.initState();
    // ──────────────────────────────────────────────────────────
    // 🔹 Загружаем чаты и клубы один раз
    // ──────────────────────────────────────────────────────────
    _personalChatsFuture = _loadPersonalChats();
    _clubChatsFuture = _loadClubChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: const PaceAppBar(
        title: 'Поделиться',
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ────────────────────────────────────────────────
            // 🔹 Переключатель сегментов
            // ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Center(
                child: SegmentedPill(
                  left: 'Личные',
                  right: 'Клубы',
                  value: _segmentIndex,
                  onChanged: (index) {
                    setState(() => _segmentIndex = index);
                  },
                ),
              ),
            ),
            // ────────────────────────────────────────────────
            // 🔹 Список по выбранному сегменту
            // ────────────────────────────────────────────────
            Expanded(
              child: _segmentIndex == 0
                  ? _buildPersonalChats(context)
                  : _buildClubChats(context),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Личные чаты
  // ────────────────────────────────────────────────────────────
  Widget _buildPersonalChats(BuildContext context) {
    return FutureBuilder<List<_PersonalChatTarget>>(
      future: _personalChatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            context,
            'Ошибка загрузки чатов: ${snapshot.error}',
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _buildEmptyState(context, 'Нет личных чатов');
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            final isSending = _isSending && _sendingTargetId == item.chatId;
            return _ShareListTile(
              title: item.name,
              imageUrl: item.avatarUrl,
              isSending: isSending,
              onTap: () => _sendRouteToPersonalChat(item),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Чаты клубов
  // ────────────────────────────────────────────────────────────
  Widget _buildClubChats(BuildContext context) {
    return FutureBuilder<List<_ClubChatTarget>>(
      future: _clubChatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState(
            context,
            'Ошибка загрузки клубов: ${snapshot.error}',
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _buildEmptyState(context, 'Нет клубов');
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            final isSending = _isSending && _sendingTargetId == item.clubId;
            return _ShareListTile(
              title: item.name,
              imageUrl: item.logoUrl,
              isSending: isSending,
              onTap: () => _sendRouteToClubChat(item),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Загрузка личных чатов
  // ────────────────────────────────────────────────────────────
  Future<List<_PersonalChatTarget>> _loadPersonalChats() async {
    final response = await _api.get(
      '/get_chats.php',
      queryParams: {
        'user_id': widget.userId.toString(),
        'offset': '0',
        'limit': '200',
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Ошибка загрузки чатов');
    }
    final list = response['chats'] as List<dynamic>? ?? [];
    return list
        .where((e) => e['chat_type'] == 'regular')
        .map((e) {
      final userId = (e['user_id'] as num?)?.toInt() ?? 0;
      final avatar = e['user_avatar'] as String?;
      return _PersonalChatTarget(
        chatId: (e['id'] as num).toInt(),
        userId: userId,
        name: (e['user_name'] as String?) ?? 'Пользователь',
        avatarUrl: _resolveAvatarUrl(userId, avatar),
      );
    }).toList();
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Загрузка клубов пользователя
  // ────────────────────────────────────────────────────────────
  Future<List<_ClubChatTarget>> _loadClubChats() async {
    final response = await _api.get(
      '/get_clubs.php',
      queryParams: {
        'detail': 'true',
        'member_user_id': widget.userId.toString(),
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Ошибка загрузки клубов');
    }
    final list = response['clubs'] as List<dynamic>? ?? [];
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return _ClubChatTarget(
        clubId: (map['id'] as num?)?.toInt() ?? 0,
        name: (map['name'] as String?) ?? 'Клуб',
        logoUrl: map['logo_url'] as String?,
      );
    }).toList();
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Отправка маршрута в личный чат
  // ────────────────────────────────────────────────────────────
  Future<void> _sendRouteToPersonalChat(_PersonalChatTarget target) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sendingTargetId = target.chatId;
    });
    try {
      final response = await _api.post(
        '/send_message.php',
        body: {
          'chat_id': target.chatId.toString(),
          'user_id': widget.userId.toString(),
          'route_id': widget.routeId.toString(),
        },
      );
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маршрут отправлен')),
        );
        Navigator.of(context).pop();
      } else {
        _showSendError(
          response['message']?.toString() ?? 'Не удалось отправить',
        );
      }
    } catch (e) {
      _showSendError('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendingTargetId = null;
        });
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Отправка маршрута в чат клуба
  // ────────────────────────────────────────────────────────────
  Future<void> _sendRouteToClubChat(_ClubChatTarget target) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sendingTargetId = target.clubId;
    });
    try {
      final response = await _api.post(
        '/send_club_chat_message.php',
        body: {
          'club_id': target.clubId.toString(),
          'user_id': widget.userId.toString(),
          'route_id': widget.routeId.toString(),
        },
      );
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маршрут отправлен')),
        );
        Navigator.of(context).pop();
      } else {
        _showSendError(
          response['message']?.toString() ?? 'Не удалось отправить',
        );
      }
    } catch (e) {
      _showSendError('Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendingTargetId = null;
        });
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Обработка ошибок отправки
  // ────────────────────────────────────────────────────────────
  void _showSendError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SelectableText.rich(
          TextSpan(
            text: message,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Пустое состояние
  // ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, String text) {
    return Center(
      child: Text(
        text,
        style: AppTextStyles.h14w4Sec.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Ошибка загрузки
  // ────────────────────────────────────────────────────────────
  Widget _buildErrorState(BuildContext context, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SelectableText.rich(
          TextSpan(
            text: text,
            style: const TextStyle(color: AppColors.error),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 URL аватара для личного чата
  // ────────────────────────────────────────────────────────────
  String _resolveAvatarUrl(int userId, String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return 'https://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) {
      return avatar;
    }
    return 'https://uploads.paceup.ru/images/users/avatars/'
        '$userId/$avatar';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ЭЛЕМЕНТ СПИСКА ДЛЯ ОТПРАВКИ
// ─────────────────────────────────────────────────────────────────────────────
class _ShareListTile extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool isSending;
  final VoidCallback onTap;

  const _ShareListTile({
    required this.title,
    this.imageUrl,
    required this.isSending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.getSurfaceColor(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: isSending ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _AvatarCircle(imageUrl: imageUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              if (isSending)
                const CupertinoActivityIndicator(radius: 8)
              else
                const Icon(
                  CupertinoIcons.paperplane,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// АВАТАР (ПЕРСОНАЛЬНЫЙ ИЛИ ЛОГО КЛУБА)
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  final String? imageUrl;

  const _AvatarCircle({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // 🔹 Плейсхолдер аватара
  // ────────────────────────────────────────────────────────────
  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.getSurfaceMutedColor(context),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.person,
        size: 18,
        color: AppColors.getIconSecondaryColor(context),
      ),
    );
  }
}
