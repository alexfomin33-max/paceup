# 📁 Структура Flutter проекта после рефакторинга

## 🎯 Общая архитектура

Проект реорганизован по принципу **Feature-Based Architecture** с четким разделением на слои:

```
lib/
├── core/              # Общие компоненты (не зависят от features)
├── domain/           # Модели данных
├── features/          # Функциональные модули (feature-based)
├── providers/         # Riverpod провайдеры (глобальные)
├── routes.dart        # Маршрутизация
└── main.dart          # Точка входа
```

---

## 📂 Детальная структура

### 1️⃣ **`core/`** — Общие компоненты

Базовые компоненты, используемые во всем приложении:

```
core/
├── config/
│   ├── app_config.dart          # Конфигурация (API URLs, ключи, таймауты)
│   └── README.md                # Документация по конфигурации
│
├── database/
│   ├── app_database.dart        # Drift Database (offline-first кэш)
│   ├── app_database.g.dart      # Сгенерированный код
│   ├── type_converters.dart     # Конвертеры типов для БД
│   └── PERFORMANCE.md           # Документация по оптимизации БД
│
├── providers/
│   ├── form_state_provider.dart # Провайдер для форм
│   └── form_state.dart          # Состояние форм
│
├── services/
│   ├── api_service.dart         # ✅ Централизованный HTTP клиент
│   ├── auth_service.dart        # ✅ Сервис авторизации
│   └── cache_service.dart       # Сервис кэширования (Drift)
│
├── theme/
│   ├── app_theme.dart           # Основная тема приложения
│   ├── colors.dart              # Цветовая палитра
│   ├── radius.dart              # Радиусы скругления
│   ├── spacing.dart             # Отступы
│   └── text_styles.dart         # Стили текста
│
├── utils/
│   ├── activity_format.dart     # Форматирование активностей
│   ├── cache_cleaner.dart       # Очистка кэша
│   ├── db_optimizer.dart        # Оптимизация БД
│   ├── equipment_date_format.dart
│   ├── error_handler.dart       # Обработка ошибок
│   ├── feed_date.dart           # Форматирование дат в ленте
│   ├── image_cache_manager.dart # Менеджер кэша изображений
│   ├── image_picker_helper.dart # Выбор изображений
│   ├── image_precache.dart      # Предзагрузка изображений
│   └── local_image_compressor.dart # Сжатие изображений
│
└── widgets/
    ├── app_bar.dart             # Кастомный AppBar
    ├── app_bottom_nav_shell.dart # Оболочка нижней навигации
    ├── avatar.dart              # Аватар пользователя
    ├── error_display.dart       # Отображение ошибок
    ├── expandable_text.dart     # Раскрывающийся текст
    ├── form_error_display.dart  # Ошибки форм
    ├── full_screen_back_swipe.dart
    ├── image_crop_screen.dart   # Обрезка изображений
    ├── interactive_back_swipe.dart
    ├── more_menu_hub.dart       # Меню "Еще"
    ├── more_menu_overlay.dart
    ├── optimized_avatar.dart    # Оптимизированный аватар
    ├── primary_button.dart      # Основная кнопка
    ├── route_card.dart          # Карточка маршрута
    ├── segmented_pill.dart      # Сегментированные пилюли
    └── transparent_route.dart   # Прозрачный маршрут
```

**Ключевые файлы:**
- **`api_service.dart`** — Singleton HTTP клиент с connection pooling, retry logic, автоматическим добавлением токенов
- **`auth_service.dart`** — Управление авторизацией, токенами, userId
- **`app_config.dart`** — Все настройки приложения (API URLs, таймауты, ключи)

---

### 2️⃣ **`domain/`** — Модели данных

Доменные модели (не зависят от UI и сервисов):

```
domain/
└── models/
    ├── activity_lenta.dart      # Модель активности в ленте
    ├── club.dart                # Модель клуба
    ├── event.dart               # Модель события
    └── user_profile_header.dart # Заголовок профиля пользователя
```

---

### 3️⃣ **`features/`** — Функциональные модули

Каждая фича изолирована и содержит свои экраны, виджеты и провайдеры:

#### **`features/auth/`** — Авторизация

```
auth/
├── screens/
│   ├── splash_screen.dart       # Экран загрузки
│   ├── home_screen.dart         # Главный экран (выбор входа/регистрации)
│   ├── login_screen.dart        # Вход
│   ├── loginsms_screen.dart     # Вход по SMS
│   ├── createacc_screen.dart    # Создание аккаунта
│   ├── regstep1_screen.dart     # Регистрация шаг 1
│   ├── regstep2_screen.dart     # Регистрация шаг 2
│   ├── addaccsms_screen.dart    # Добавление аккаунта по SMS
│   └── auth_shell.dart          # Оболочка для экранов авторизации
└── widgets/
    ├── custom_text_field.dart   # Кастомное текстовое поле
    ├── phone_input_field.dart   # Поле ввода телефона
    ├── resend_code_button.dart  # Кнопка повторной отправки кода
    └── sms_code_input.dart      # Ввод SMS кода
```

#### **`features/lenta/`** — Лента активностей

```
lenta/
├── providers/
│   ├── lenta_state.dart         # Состояние ленты
│   ├── lenta_notifier.dart      # Бизнес-логика ленты
│   └── lenta_provider.dart      # Провайдер ленты
│
├── screens/
│   ├── lenta_screen.dart        # Главный экран ленты
│   │
│   ├── activity/               # Экраны активностей
│   │   ├── add_activity_screen.dart
│   │   ├── edit_activity_screen.dart
│   │   ├── description_screen.dart
│   │   ├── combining_screen.dart
│   │   ├── fullscreen_route_map_screen.dart
│   │   └── together/           # Совместные активности
│   │
│   ├── state/                  # Состояния ленты (вкладки)
│   │   ├── chat/               # Чат
│   │   ├── favorites/          # Избранное
│   │   ├── newpost/            # Новый пост
│   │   └── notifications/      # Уведомления
│   │
│   └── widgets/                # Виджеты ленты
│       ├── activity/           # Виджеты активностей
│       ├── post/               # Виджеты постов
│       ├── recommended/        # Рекомендации
│       └── comments_bottom_sheet.dart
│
└── widgets/
    ├── activity_route_carousel.dart
    └── user_header.dart
```

#### **`features/map/`** — Карта и события

```
map/
├── providers/
│   ├── events/                 # Провайдеры событий
│   │   ├── my_events_*.dart
│   │   ├── bookmarked_events_*.dart
│   │   └── add_official_event_*.dart
│   └── search/
│       └── clubs_search_provider.dart
│
└── screens/
    ├── map_screen.dart         # Главный экран карты
    ├── clubs/                  # Клубы
    │   ├── clubs_screen.dart
    │   ├── club_detail_screen.dart
    │   ├── create_club_screen.dart
    │   └── ...
    └── events/                 # События
        ├── events_screen.dart
        ├── event_detail_screen.dart
        ├── add_event_screen.dart
        └── ...
```

#### **`features/market/`** — Маркетплейс

```
market/
├── models/
│   └── market_models.dart
├── screens/
│   ├── market_screen.dart
│   ├── state/                 # Состояния маркета
│   ├── tabs/                  # Вкладки (slots, things)
│   └── widgets/
└── ...
```

#### **`features/profile/`** — Профиль пользователя

```
profile/
├── providers/
│   ├── profile_header_*.dart   # Провайдеры заголовка профиля
│   ├── user_clubs_provider.dart
│   ├── communication/
│   ├── search/
│   └── training/
│
└── screens/
    ├── profile_screen.dart
    ├── edit_profile_screen.dart
    ├── edit_profile/          # Редактирование профиля
    ├── tabs/                  # Вкладки профиля
    │   ├── main/
    │   ├── stats/
    │   ├── training_tab.dart
    │   ├── equipment/
    │   ├── clubs_tab.dart
    │   ├── photos_tab.dart
    │   └── ...
    ├── state/                 # Состояния профиля
    │   ├── search/
    │   ├── settings/
    │   └── subscribe/
    └── widgets/
```

#### **`features/tasks/`** — Задачи

```
tasks/
└── screens/
    ├── tasks_screen.dart
    ├── tabs/
    └── description/
```

---

### 4️⃣ **`providers/`** — Глобальные провайдеры

Riverpod провайдеры для глобального состояния:

```
providers/
├── services/
│   ├── api_provider.dart       # Провайдер ApiService
│   ├── auth_provider.dart      # Провайдер AuthService
│   └── cache_provider.dart     # Провайдер CacheService
├── theme_provider.dart         # Провайдер темы
├── avatar_version_provider.dart
└── README.md                   # Документация по Riverpod
```

**Использование:**
```dart
// В виджете
final api = ref.read(apiServiceProvider);
final auth = ref.read(authServiceProvider);
final theme = ref.watch(themeModeNotifierProvider);
```

---

### 5️⃣ **Корневые файлы**

- **`main.dart`** — Точка входа, инициализация БД, настройка темы
- **`routes.dart`** — Маршрутизация, генератор маршрутов

---

## 🔄 Миграция со старой структуры

### ✅ Старые пути (удалены):

1. **`lib/service/auth_service.dart`** → **`lib/core/services/auth_service.dart`**
   - ✅ Старый файл удален
   - Все импорты должны использовать новый путь: `lib/core/services/auth_service.dart`

2. **`lib/screens/lenta/`** → **`lib/features/lenta/screens/`**
   - ✅ Старая папка удалена

3. **`lib/screens/profile/`** → **`lib/features/profile/screens/`**
   - ✅ Старая папка удалена

### ✅ Новые пути:

- Все сервисы: `lib/core/services/`
- Все экраны: `lib/features/{feature}/screens/`
- Все виджеты: `lib/features/{feature}/widgets/` или `lib/core/widgets/`
- Все провайдеры: `lib/features/{feature}/providers/` или `lib/providers/`

---

## 🎨 Паттерны использования

### 1. **Использование ApiService**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../providers/services/api_provider.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiServiceProvider);
    
    // Использование
    Future<void> loadData() async {
      final data = await api.get('/endpoint');
    }
  }
}
```

### 2. **Использование AuthService**

```dart
import '../../providers/services/auth_provider.dart';

final userId = await ref.read(authServiceProvider).getUserId();
final isAuth = await ref.read(authServiceProvider).isAuthorized();
```

### 3. **Feature-based провайдеры**

```dart
// В features/lenta/providers/lenta_provider.dart
final lentaProvider = StateNotifierProvider.family<LentaNotifier, LentaState, int>(
  (ref, userId) => LentaNotifier(
    api: ref.watch(apiServiceProvider),
    userId: userId,
  ),
);
```

### 4. **Маршрутизация**

```dart
// В routes.dart
case '/lenta':
  screen = LentaScreen(userId: args['userId'] as int);
  break;
```

---

## 📝 Важные замечания

1. **Папка `php/` не изменялась** — все PHP файлы остались на месте
2. **Feature-based архитектура** — каждая фича изолирована
3. **Riverpod для state management** — используется везде
4. **Drift Database** — для offline-first кэширования
5. **Connection Pooling** — оптимизация HTTP запросов в ApiService

---

## 🔍 Поиск файлов

### Где найти экраны?
- Авторизация: `features/auth/screens/`
- Лента: `features/lenta/screens/`
- Карта: `features/map/screens/`
- Профиль: `features/profile/screens/`
- Маркет: `features/market/screens/`
- Задачи: `features/tasks/screens/`

### Где найти сервисы?
- `core/services/` — все сервисы (API, Auth, Cache)

### Где найти виджеты?
- Общие виджеты: `core/widgets/`
- Фича-специфичные: `features/{feature}/widgets/`

### Где найти провайдеры?
- Глобальные: `providers/`
- Фича-специфичные: `features/{feature}/providers/`

---

**Вопросы?** Изучите существующие файлы в соответствующих папках.

