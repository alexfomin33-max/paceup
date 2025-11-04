package com.example.paceup

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract

import kotlinx.coroutines.*
import java.time.Instant
import java.time.Duration

class MainActivity : FlutterFragmentActivity(), CoroutineScope by MainScope() {

    private val CHANNEL = "paceup/route"

    // HealthConnectClient может быть null, если Health Connect недоступен на устройстве
    private var healthClient: HealthConnectClient? = null
    private lateinit var routeRequestLauncher: ActivityResultLauncher<String>

    // pending ответ в канал (когда ждём одноразовый консент на конкретную сессию)
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ───────────────────────── Инициализация Health Connect ─────────────────────────
        // Проверяем доступность Health Connect перед инициализацией
        // Если сервис недоступен (не установлен или не активирован), healthClient останется null
        try {
            healthClient = HealthConnectClient.getOrCreate(this)
        } catch (e: IllegalStateException) {
            // Health Connect недоступен - приложение должно работать без него
            // Методы через MethodChannel вернут соответствующую ошибку
            healthClient = null
        }

        routeRequestLauncher =
            registerForActivityResult(ExerciseRouteRequestContract()) { route: ExerciseRoute? ->
                val res = pendingResult
                pendingResult = null
                if (res == null) return@registerForActivityResult

                if (route == null) {
                    res.error("consent_denied", "Пользователь не дал одноразовый доступ к маршруту", null)
                } else {
                    res.success(routeToMaps(route))
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        cancel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // старый метод по окну времени (оставляем на всякий случай)
                    "getExerciseRoute" -> {
                        val startMs = call.argument<Long>("start") ?: run {
                            result.error("bad_args", "Нет аргумента start (ms)", null); return@setMethodCallHandler
                        }
                        val endMs = call.argument<Long>("end") ?: run {
                            result.error("bad_args", "Нет аргумента end (ms)", null); return@setMethodCallHandler
                        }
                        getRouteForWindow(startMs, endMs, result)
                    }
                    // новый: ищем последнюю сессию ЗА N ДНЕЙ, у которой реально есть маршрут (Data или ConsentRequired)
                    "getLatestRoute" -> {
                        val days = call.argument<Int>("days") ?: 30
                        getLatestRoute(days, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ───────────────────────── core helpers ─────────────────────────

    private suspend fun ensureReadExercisePermission(): Boolean = withContext(Dispatchers.Main) {
        val client = healthClient ?: return@withContext false
        
        val needed: Set<String> = setOf(
            HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        )
        val granted: Set<String> = client.permissionController.getGrantedPermissions()
        if (granted.containsAll(needed)) return@withContext true

        val launcher: ActivityResultLauncher<Set<String>> =
            registerForActivityResult(
                PermissionController.createRequestPermissionResultContract()
            ) { grantedSet: Set<String> ->
                // no-op; результат вернём через continuation ниже
            }

        // suspendCoroutine: подождём результата
        return@withContext suspendCancellableCoroutine { cont ->
            val callbackLauncher: ActivityResultLauncher<Set<String>> =
                registerForActivityResult(
                    PermissionController.createRequestPermissionResultContract()
                ) { grantedSet: Set<String> ->
                    cont.resume(grantedSet.containsAll(needed), onCancellation = {})
                }
            callbackLauncher.launch(needed)
        }
    }

    private fun getLatestRoute(days: Int, result: MethodChannel.Result) {
        launch(Dispatchers.Main) {
            try {
                val client = healthClient
                if (client == null) {
                    result.error("health_connect_unavailable", "Health Connect недоступен на этом устройстве", null)
                    return@launch
                }

                if (!ensureReadExercisePermission()) {
                    result.error("no_permission", "Нет разрешения на чтение тренировок", null)
                    return@launch
                }

                val end = Instant.now()
                val start = end.minus(Duration.ofDays(days.toLong()))

                val sessions = withContext(Dispatchers.IO) {
                    client.readRecords(
                        ReadRecordsRequest(
                            ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(start, end)
                        )
                    ).records
                }

                if (sessions.isEmpty()) {
                    result.success(emptyList<Any>())
                    return@launch
                }

                // Самые свежие — первыми
                val ordered = sessions.sortedByDescending { it.endTime }

                // пройдёмся по сессиям и вернём первую, где маршрут доступен
                for (s in ordered) {
                    val full = withContext(Dispatchers.IO) {
                        client.readRecord(ExerciseSessionRecord::class, s.metadata.id).record
                    }
                    when (val rr = full.exerciseRouteResult) {
                        is ExerciseRouteResult.Data -> {
                            result.success(routeToMaps(rr.exerciseRoute))
                            return@launch
                        }
                        is ExerciseRouteResult.ConsentRequired -> {
                            // запросим одноразовый консент ровно для этой сессии
                            pendingResult = result
                            routeRequestLauncher.launch(s.metadata.id)
                            return@launch
                        }
                        is ExerciseRouteResult.NoData -> {
                            // просто идём дальше
                        }
                        else -> { /* игнор */ }
                    }
                }

                // дошли сюда — ни одна сессия не содержит маршрут
                result.success(emptyList<Any>())
            } catch (t: Throwable) {
                result.error("native_err", t.message, null)
            }
        }
    }

    private fun getRouteForWindow(startMs: Long, endMs: Long, result: MethodChannel.Result) {
        launch(Dispatchers.Main) {
            try {
                val client = healthClient
                if (client == null) {
                    result.error("health_connect_unavailable", "Health Connect недоступен на этом устройстве", null)
                    return@launch
                }

                if (!ensureReadExercisePermission()) {
                    result.error("no_permission", "Нет разрешения на чтение тренировок", null)
                    return@launch
                }

                val start = Instant.ofEpochMilli(startMs)
                val end = Instant.ofEpochMilli(endMs)
                val sessions = withContext(Dispatchers.IO) {
                    client.readRecords(
                        ReadRecordsRequest(
                            ExerciseSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(start, end)
                        )
                    ).records
                }

                if (sessions.isEmpty()) {
                    result.success(emptyList<Any>())
                    return@launch
                }

                val session = sessions.maxByOrNull { it.endTime } ?: run {
                    result.success(emptyList<Any>()); return@launch
                }
                val full = withContext(Dispatchers.IO) {
                    client.readRecord(ExerciseSessionRecord::class, session.metadata.id).record
                }

                when (val rr = full.exerciseRouteResult) {
                    is ExerciseRouteResult.Data -> result.success(routeToMaps(rr.exerciseRoute))
                    is ExerciseRouteResult.NoData -> result.success(emptyList<Any>())
                    is ExerciseRouteResult.ConsentRequired -> {
                        pendingResult = result
                        routeRequestLauncher.launch(session.metadata.id)
                    }
                    else -> result.success(emptyList<Any>())
                }
            } catch (t: Throwable) {
                result.error("native_err", t.message, null)
            }
        }
    }

    private fun routeToMaps(route: ExerciseRoute?): List<Map<String, Any>> {
        if (route == null) return emptyList()
        val out = ArrayList<Map<String, Any>>(route.route.size)
        for (loc in route.route) {
            out.add(
                mapOf(
                    "lat" to loc.latitude,
                    "lng" to loc.longitude,
                    "t" to (loc.time?.toEpochMilli() ?: 0L),
                    "alt" to (loc.altitude?.inMeters ?: -1.0)
                )
            )
        }
        return out
    }
}
