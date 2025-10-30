# 🔄 RIVERPOD STATE MANAGEMENT

Этот проект использует **Riverpod 2.x** для управления состоянием.

## 📁 СТРУКТУРА

```
lib/providers/
├── services/          # Providers для сервисов (ApiService, AuthService)
│   ├── api_provider.dart
│   └── auth_provider.dart
├── lenta/             # State management для ленты активностей
│   ├── lenta_state.dart      # Модель состояния
│   ├── lenta_notifier.dart   # StateNotifier (бизнес-логика)
│   └── lenta_provider.dart   # Provider (связь с виджетами)
└── README.md
```

---

## 🎯 ОСНОВНЫЕ КОНЦЕПЦИИ

### 1️⃣ **Provider** (Singleton сервисы)

Для singleton-сервисов (AuthService, ApiService):

```dart
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});
```

**Использование в виджетах:**

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiServiceProvider);
    // ...
  }
}
```

---

### 2️⃣ **FutureProvider** (Асинхронные данные)

Для одноразовой асинхронной загрузки:

```dart
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  final auth = ref.watch(authServiceProvider);
  return await auth.getUserId();
});
```

**Использование:**

```dart
final userIdAsync = ref.watch(currentUserIdProvider);

userIdAsync.when(
  data: (userId) => Text('User ID: $userId'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

---

### 3️⃣ **StateNotifierProvider** (Комплексное состояние)

Для экранов с изменяемым состоянием (Lenta, Profile, Cart и т.д.):

**Структура:**
1. **State** — неизменяемая модель данных
2. **Notifier** — бизнес-логика (загрузка, обновление)
3. **Provider** — связь между Notifier и виджетами

**Пример для Lenta:**

```dart
// 1. State (lenta_state.dart)
class LentaState {
  final List<Activity> items;
  final bool isLoading;
  // ...
}

// 2. Notifier (lenta_notifier.dart)
class LentaNotifier extends StateNotifier<LentaState> {
  Future<void> loadInitial() async {
    // логика загрузки
  }
}

// 3. Provider (lenta_provider.dart)
final lentaProvider = StateNotifierProvider<LentaNotifier, LentaState>(
  (ref) => LentaNotifier(api: ref.watch(apiServiceProvider)),
);
```

**Использование в виджетах:**

```dart
class LentaScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LentaScreen> createState() => _LentaScreenState();
}

class _LentaScreenState extends ConsumerState<LentaScreen> {
  @override
  void initState() {
    super.initState();
    // Начальная загрузка
    Future.microtask(() {
      ref.read(lentaProvider(userId).notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lentaState = ref.watch(lentaProvider(userId));

    return ListView.builder(
      itemCount: lentaState.items.length,
      itemBuilder: (context, index) {
        return ActivityCard(activity: lentaState.items[index]);
      },
    );
  }
}
```

---

## 🔧 МИГРАЦИЯ С `StatefulWidget` → `ConsumerStatefulWidget`

### **Было (StatefulWidget):**

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final api = ApiService();
    final data = await api.get('/items');
    setState(() => _items = data);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) => ItemCard(_items[index]),
    );
  }
}
```

### **Стало (ConsumerStatefulWidget + Riverpod):**

```dart
class MyScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  void initState() {
    super.initState();
    // Загрузка через провайдер
    Future.microtask(() {
      ref.read(itemsProvider.notifier).loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsProvider);

    return ListView.builder(
      itemCount: itemsState.items.length,
      itemBuilder: (context, index) {
        return ItemCard(itemsState.items[index]);
      },
    );
  }
}
```

---

## 📚 ГДЕ ИСПОЛЬЗОВАТЬ

| Тип виджета | Когда использовать |
|---|---|
| `ConsumerWidget` | Stateless-виджет, который читает провайдеры |
| `ConsumerStatefulWidget` | StatefulWidget с доступом к провайдерам |
| `Consumer` | Локальный rebuild части дерева |

---

## ✅ ПРЕИМУЩЕСТВА RIVERPOD

1. **Типобезопасность** — ошибки на этапе компиляции
2. **Testability** — легко тестировать без контекста
3. **No BuildContext** — провайдеры доступны везде
4. **Compile-safe** — нельзя забыть `ref.watch`
5. **Auto-dispose** — автоматическая очистка ресурсов

---

## 🔍 ДЕБАГ

Для отладки Riverpod можно использовать `ProviderObserver`:

```dart
class MyObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    print('${provider.name ?? provider.runtimeType} updated');
    print('  Previous: $previousValue');
    print('  New: $newValue');
  }
}

void main() {
  runApp(
    ProviderScope(
      observers: [MyObserver()],
      child: MyApp(),
    ),
  );
}
```

---

## 📖 РЕСУРСЫ

- [Riverpod Docs](https://riverpod.dev/)
- [Riverpod Examples](https://github.com/rrousselGit/riverpod/tree/master/examples)
- [Flutter & Riverpod Best Practices](https://codewithandrea.com/articles/flutter-state-management-riverpod/)

---

**Вопросы?** Изучите существующие провайдеры в `lib/providers/`

