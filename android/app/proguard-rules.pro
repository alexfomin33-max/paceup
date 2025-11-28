# ────────────────────────────────────────────────────────────────────────────
#  PROGUARD RULES для PaceUp
#
#  Правила обфускации для Flutter, Riverpod и Drift
#  Предотвращают удаление/обфускацию критически важных классов
# ────────────────────────────────────────────────────────────────────────────

# ────────────────────────── Flutter ──────────────────────────
# Сохраняем все классы Flutter, чтобы приложение работало корректно
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Engine
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ────────────────────────── Riverpod ──────────────────────────
# Сохраняем сгенерированные провайдеры Riverpod
-keep class * extends riverpod_annotation.GeneratedProvider { *; }
-keep @riverpod_annotation.Riverpod class * { *; }
-keep class * extends riverpod_annotation.Provider { *; }

# Сохраняем аннотации Riverpod
-keep @interface riverpod_annotation.** { *; }
-keepclassmembers class * {
    @riverpod_annotation.** *;
}

# Сохраняем провайдеры и их состояние
-keep class * extends flutter_riverpod.** { *; }
-keep class * implements flutter_riverpod.** { *; }

# ────────────────────────── Drift Database ──────────────────────────
# Сохраняем классы базы данных Drift
-keep class * extends drift.database.** { *; }
-keep class * extends drift.** { *; }
-keep class drift.** { *; }

# Сохраняем сгенерированные классы Drift
-keep class * extends drift.** { *; }
-keepclassmembers class * {
    @drift.** *;
}

# Сохраняем таблицы и DAO
-keep class * extends drift.** { *; }
-keep class * implements drift.** { *; }

# ────────────────────────── SQLite ──────────────────────────
# Сохраняем нативные библиотеки SQLite
-keep class sqlite3.** { *; }
-keep class sqlite3_flutter_libs.** { *; }
-dontwarn sqlite3.**

# ────────────────────────── Kotlin ──────────────────────────
# Сохраняем Kotlin классы и корутины
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**

# ────────────────────────── Android Health Connect ──────────────────────────
# Сохраняем классы Health Connect
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# ────────────────────────── Общие правила ──────────────────────────
# Сохраняем сериализацию (если используется)
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Сохраняем Parcelable (для передачи данных между компонентами)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Сохраняем R классы (ресурсы)
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Удаляем логи в release (опционально, для дополнительной оптимизации)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

