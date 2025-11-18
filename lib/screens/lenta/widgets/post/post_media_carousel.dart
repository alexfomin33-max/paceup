import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../theme/app_theme.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> videoUrls;

  const PostMediaCarousel({
    super.key,
    required this.imageUrls,
    required this.videoUrls,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  late final PageController _pc;
  int _index = 0;

  static const _dotsBottom = 10.0;
  static const _dotsPad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  // Картинка-заглушка для видео
  static const _videoPlaceholder =
      'http://uploads.paceup.ru/defaults/video_placeholder.jpg';

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length + widget.videoUrls.length;
    if (total == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pc,
              itemCount: total,
              allowImplicitScrolling: false,
              physics: const PageScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _index = i);
                final evictIndex = i - 2;
                if (evictIndex >= 0 && evictIndex < widget.imageUrls.length) {
                  _evictNetworkImage(widget.imageUrls[evictIndex]);
                }
              },
              itemBuilder: (context, i) {
                final isImage = i < widget.imageUrls.length;
                if (isImage) {
                  final url = widget.imageUrls[i];

                  // ✅ Используем дефолтный CacheManager для offline поддержки
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final screenW = constraints.maxWidth;
                  final targetW = (screenW * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: url,
                    // НЕ передаем cacheManager - используется DefaultCacheManager с offline support
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.low,
                    memCacheWidth: targetW,
                    maxWidthDiskCache: targetW,
                    placeholder: (context, url) => Container(
                      color: AppColors.disabled,
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.disabled,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Изображение недоступно',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final vIndex = i - widget.imageUrls.length;
                  final url = widget.videoUrls[vIndex];
                  return _buildVideoPreview(url);
                }
              },
            ),
            Positioned(
              bottom: _dotsBottom,
              left: 0,
              right: 0,
              child: _buildDots(total),
            ),
          ],
        );
      },
    );
  }

  void _evictNetworkImage(String url) {
    // Удаляем изображение из обоих кешей (memory и disk)
    CachedNetworkImage.evictFromCache(url);
  }

  Widget _buildVideoPreview(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ✅ Дефолтный cache для video placeholder
        Builder(
          builder: (context) {
            final dpr = MediaQuery.of(context).devicePixelRatio;
            final screenW = MediaQuery.of(context).size.width;
            final targetW = (screenW * dpr).round();
            return CachedNetworkImage(
              imageUrl: _videoPlaceholder,
              fit: BoxFit.cover,
              memCacheWidth: targetW,
              maxWidthDiskCache: targetW,
              errorWidget: (context, url, error) => Container(
                color: AppColors.disabled,
                child: const Icon(
                  CupertinoIcons.video_camera,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
            );
          },
        ),
        Container(color: AppColors.scrim20),
        const Center(
          child: Icon(
            CupertinoIcons.play_circle_fill,
            size: 64,
            color: AppColors.surface,
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: () {}),
          ),
        ),
      ],
    );
  }

  Widget _buildDots(int total) {
    if (total <= 1) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: _dotsPad,
        decoration: BoxDecoration(
          color: AppColors.scrim20,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(total, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? AppColors.brandPrimary : AppColors.skeletonBase,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            );
          }),
        ),
      ),
    );
  }
}
