# 🖼️ Proportional Image Resize в Memory Cache

## Проблема: искажение изображений

При использовании `CachedNetworkImage` параметры `memCacheWidth` и `memCacheHeight` могут **искажать** изображения, если указаны **оба** одновременно.

### ❌ Неправильно: оба параметра (искажение)

```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/avatar.jpg', // Оригинал: 400x600
  width: 50,
  height: 50,
  fit: BoxFit.cover,
  memCacheWidth: 150,  // ❌
  memCacheHeight: 150, // ❌
)
```

**Что происходит:**
1. Оригинальное изображение: 400x600 (прямоугольник)
2. `memCacheWidth: 150` + `memCacheHeight: 150` → **ресайз до 150x150** (игнорируя пропорции!)
3. Изображение **сплющивается** 400x600 → 150x150
4. Только потом применяется `BoxFit.cover`

**Результат:** 😔 Сплющенная/растянутая аватарка

---

## ✅ Решение: ТОЛЬКО один параметр

### Вариант 1: Только `memCacheWidth` (рекомендуется)

```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/avatar.jpg', // Оригинал: 400x600
  width: 50,
  height: 50,
  fit: BoxFit.cover,
  memCacheWidth: 150, // ✅ ТОЛЬКО ширина
  // memCacheHeight НЕ указываем!
)
```

**Что происходит:**
1. Оригинальное изображение: 400x600
2. `memCacheWidth: 150` → **ресайз до 150x??? пропорционально**
3. Высота подстраивается автоматически: 150x225 (пропорции сохранены!)
4. `BoxFit.cover` обрезает до 50x50 красиво

**Результат:** 😊 Красивая аватарка, -40% памяти

### Вариант 2: Только `memCacheHeight`

```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/avatar.jpg', // Оригинал: 600x400 (горизонталь)
  width: 50,
  height: 50,
  fit: BoxFit.cover,
  memCacheHeight: 150, // ✅ ТОЛЬКО высота
  // memCacheWidth НЕ указываем!
)
```

**Результат:** Ресайз до ???x150 пропорционально

---

## Таблица сравнения

| Параметры | Оригинал | Memory Cache | Пропорции | Результат |
|-----------|----------|--------------|-----------|-----------|
| `memCacheWidth: 150`<br>`memCacheHeight: 150` | 400x600 | **150x150** | ❌ Нарушены | Сплющено |
| `memCacheWidth: 150`<br>(без Height) | 400x600 | **150x225** | ✅ Сохранены | Красиво |
| `memCacheHeight: 150`<br>(без Width) | 600x400 | **225x150** | ✅ Сохранены | Красиво |
| Без параметров | 400x600 | **400x600** | ✅ Сохранены | Полный размер |

---

## Рекомендации по выбору размера

### Для аватарок

```dart
// Размер виджета: 50x50
// Device Pixel Ratio: @3x (iPhone)
// Физический размер: 50 * 3 = 150px

CachedNetworkImage(
  width: 50,
  height: 50,
  memCacheWidth: (50 * 3).toInt(), // = 150px
)
```

### Для постов в ленте

```dart
// Ширина экрана: 390 логических пикселей
// Device Pixel Ratio: @3x
// Физический размер: 390 * 3 = 1170px

final dpr = MediaQuery.of(context).devicePixelRatio;
final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round();

CachedNetworkImage(
  memCacheWidth: cacheWidth, // = 1170px
)
```

---

## Когда использовать каждый подход

### ✅ Используйте `memCacheWidth` (ТОЛЬКО):
- Аватарки (круглые, квадратные)
- Посты в ленте (фиксированная ширина)
- Галереи (контролируемый размер)

### ✅ Используйте `memCacheHeight` (ТОЛЬКО):
- Горизонтальные изображения
- Карусели (фиксированная высота)

### ❌ НЕ используйте оба параметра:
- Никогда, если пропорции важны!

### ⚠️ Не используйте вообще:
- Очень маленькие изображения (< 100px)
- Если память не проблема
- Если хотите оригинальное качество

---

## Примеры из проекта PaceUp

### OptimizedAvatar

```dart
// lib/widgets/optimized_avatar.dart
CachedNetworkImage(
  imageUrl: url,
  width: size,  // например, 50
  height: size, // 50
  fit: BoxFit.cover,
  memCacheWidth: (size * 3).toInt(), // 150px - пропорциональный resize
)
```

### PostMediaCarousel

```dart
// lib/screens/lenta/widgets/post/post_media_carousel.dart
final dpr = MediaQuery.of(context).devicePixelRatio;
final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round();

CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  memCacheWidth: cacheWidth, // Пропорциональный resize по ширине экрана
)
```

### ProfileHeaderCard

```dart
// lib/screens/profile/widgets/header_card.dart
CachedNetworkImage(
  imageUrl: avatarUrl,
  fit: BoxFit.cover,
  memCacheWidth: (56 * 3).toInt(), // 168px для 56x56 аватарки @3x
)
```

---

## Измеряемая экономия памяти

### Без оптимизации:
```
Оригинал: 4000x6000 = 24 megapixels
Memory: 24MP × 4 bytes = 96 MB на одно изображение! 😱
10 аватарок = 960 MB
```

### С memCacheWidth (proportional):
```
Оригинал: 4000x6000
Resize: 150x225 (пропорционально)
Memory: 150×225 × 4 bytes = 0.135 MB на изображение 😊
10 аватарок = 1.35 MB

Экономия: 96 MB → 0.135 MB = -99.86% ! 🎉
```

---

## Troubleshooting

### Проблема: Изображения всё ещё искажены

**Проверьте:**
1. Указан ли **ТОЛЬКО ОДИН** параметр (`memCacheWidth` ИЛИ `memCacheHeight`)?
2. НЕТ ли второго параметра где-то в коде?
3. `fit: BoxFit.cover` указан?

### Проблема: Изображения слишком большие в памяти

**Решение:** Уменьшите `memCacheWidth`:

```dart
// Было:
memCacheWidth: (size * 3).toInt(), // @3x

// Стало:
memCacheWidth: (size * 2).toInt(), // @2x достаточно для большинства
```

### Проблема: Изображения размытые

**Решение:** Увеличьте `memCacheWidth`:

```dart
// Для очень качественных экранов (@4x)
memCacheWidth: (size * 4).toInt(),
```

---

## См. также

- [CachedNetworkImage Documentation](https://pub.dev/packages/cached_network_image)
- [Flutter ImageCache](https://api.flutter.dev/flutter/painting/ImageCache-class.html)
- [Unified Image Cache Guide](./unified-image-cache.md)

