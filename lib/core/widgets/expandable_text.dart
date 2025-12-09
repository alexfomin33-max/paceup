// lib/widgets/expandable_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Виджет для отображения текста с возможностью раскрытия
/// Показывает 3 строки, остальное скрывает с кнопкой "Показать ещё"
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final int maxLines;

  const ExpandableText({
    super.key,
    required this.text,
    this.textStyle,
    this.maxLines = 3,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseStyle = widget.textStyle ?? AppTextStyles.h14w4;
        final textColor = AppColors.getTextPrimaryColor(context);
        final moreText = ' Показать ещё';
        
        // Определяем, нужно ли раскрытие текста
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: baseStyle,
          ),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        final needsExpansion = textPainter.didExceedMaxLines;

        if (!needsExpansion || _isExpanded) {
          // Если текст помещается или уже раскрыт — показываем полностью
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: baseStyle.copyWith(color: textColor),
                maxLines: _isExpanded ? null : widget.maxLines,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (_isExpanded && needsExpansion) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  child: Text(
                    'Скрыть',
                    style: baseStyle.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        // Находим позицию, где нужно обрезать текст, чтобы " Показать ещё" поместилось
        String truncatedText = widget.text;
        int start = 0;
        int end = widget.text.length;
        
        while (start < end) {
          final mid = (start + end) ~/ 2;
          final testText = widget.text.substring(0, mid);
          
          final testPainter = TextPainter(
            text: TextSpan(
              text: testText + moreText,
              style: baseStyle,
            ),
            maxLines: widget.maxLines,
            textDirection: TextDirection.ltr,
          );
          testPainter.layout(maxWidth: constraints.maxWidth);
          
          if (testPainter.didExceedMaxLines) {
            end = mid;
          } else {
            start = mid + 1;
          }
        }
        
        truncatedText = widget.text.substring(0, start - 1);

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: truncatedText,
                style: baseStyle.copyWith(color: textColor),
              ),
              TextSpan(
                text: moreText,
                style: baseStyle.copyWith(color: AppColors.brandPrimary),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    setState(() {
                      _isExpanded = true;
                    });
                  },
              ),
            ],
          ),
          maxLines: widget.maxLines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

