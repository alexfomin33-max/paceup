import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        final dpr = MediaQuery.of(context).devicePixelRatio;
        (constraints.maxWidth * dpr).round();

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
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final cacheWidth = (MediaQuery.sizeOf(context).width * dpr)
                      .round();

                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                    width: double.infinity,
                    height: double.infinity,
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
    final provider = NetworkImage(url);
    imageCache.evict(provider);
  }

  Widget _buildVideoPreview(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(_videoPlaceholder, fit: BoxFit.cover),
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
