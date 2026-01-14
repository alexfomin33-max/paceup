import Flutter
import UIKit
import HealthKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ─────────────────────────────────────────────────────────────────────
    // РЕГИСТРАЦИЯ METHODCHANNEL ДЛЯ МАРШРУТОВ (iOS)
    // Аналог Android реализации в MainActivity.kt
    // ─────────────────────────────────────────────────────────────────────
    guard let controller = window?.rootViewController as? FlutterViewController else {
      // Если rootViewController еще не готов, регистрируем канал позже
      // Это может произойти при использовании UISceneDelegate
      DispatchQueue.main.async {
        self.setupRouteChannel()
      }
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    setupRouteChannel(controller: controller)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupRouteChannel(controller: FlutterViewController? = nil) {
    let flutterController: FlutterViewController
    if let controller = controller {
      flutterController = controller
    } else if let window = window, let controller = window.rootViewController as? FlutterViewController {
      flutterController = controller
    } else {
      return
    }
    
    let routeChannel = FlutterMethodChannel(
      name: "paceup/route",
      binaryMessenger: flutterController.binaryMessenger
    )
    
    routeChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getExerciseRoute" {
        self?.handleGetRoute(call: call, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────
  // ОБРАБОТКА ЗАПРОСА МАРШРУТА ИЗ FLUTTER
  // ─────────────────────────────────────────────────────────────────────
  private func handleGetRoute(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let startMs = args["start"] as? Int64,
          let endMs = args["end"] as? Int64 else {
      result(FlutterError(
        code: "bad_args",
        message: "Неверные параметры: требуется start и end (timestamp в миллисекундах)",
        details: nil
      ))
      return
    }
    
    let startDate = Date(timeIntervalSince1970: Double(startMs) / 1000.0)
    let endDate = Date(timeIntervalSince1970: Double(endMs) / 1000.0)
    
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(
        code: "healthkit_unavailable",
        message: "HealthKit недоступен на этом устройстве",
        details: nil
      ))
      return
    }
    
    let healthStore = HKHealthStore()
    let workoutType = HKObjectType.workoutType()
    let routeType = HKSeriesType.workoutRoute()
    let typesToRead: Set<HKObjectType> = [workoutType, routeType]
    
    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
      if let error = error {
        result(FlutterError(
          code: "permission_error",
          message: "Ошибка запроса разрешения: \(error.localizedDescription)",
          details: nil
        ))
        return
      }
      
      if !success {
        result(FlutterError(
          code: "no_permission",
          message: "Нет разрешения на чтение маршрутов. Проверьте настройки Health.",
          details: nil
        ))
        return
      }
      
      self.loadRoute(healthStore: healthStore, startDate: startDate, endDate: endDate, result: result)
    }
  }
  
  private func loadRoute(healthStore: HKHealthStore, startDate: Date, endDate: Date, result: @escaping FlutterResult) {
    let timePredicate = HKQuery.predicateForSamples(
      withStart: startDate,
      end: endDate,
      options: .strictStartDate
    )
    
    let workoutQuery = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: timePredicate,
      limit: 1,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    ) { [weak self] query, workouts, error in
      guard let self = self else { return }
      
      if let error = error {
        result(FlutterError(
          code: "query_error",
          message: "Ошибка запроса тренировок: \(error.localizedDescription)",
          details: nil
        ))
        return
      }
      
      guard let workouts = workouts, !workouts.isEmpty,
            let workout = workouts.first as? HKWorkout else {
        result([])
        return
      }
      
      self.loadRouteForWorkout(healthStore: healthStore, workout: workout, result: result)
    }
    
    healthStore.execute(workoutQuery)
  }
  
  private func loadRouteForWorkout(healthStore: HKHealthStore, workout: HKWorkout, result: @escaping FlutterResult) {
    // Сначала получаем маршрут из тренировки
    let routeType = HKSeriesType.workoutRoute()
    let predicate = HKQuery.predicateForObjects(from: workout)
    
    let routeQuery = HKSampleQuery(
      sampleType: routeType,
      predicate: predicate,
      limit: 1,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    ) { [weak self] query, routes, error in
      guard let self = self else { return }
      
      if let error = error {
        result(FlutterError(
          code: "route_error",
          message: "Ошибка загрузки маршрута: \(error.localizedDescription)",
          details: nil
        ))
        return
      }
      
      guard let routes = routes, !routes.isEmpty,
            let route = routes.first as? HKWorkoutRoute else {
        result([])
        return
      }
      
      // Теперь загружаем точки маршрута
      self.loadRoutePoints(healthStore: healthStore, route: route, result: result)
    }
    
    healthStore.execute(routeQuery)
  }
  
  private func loadRoutePoints(healthStore: HKHealthStore, route: HKWorkoutRoute, result: @escaping FlutterResult) {
    var allRoutePoints: [CLLocation] = []
    
    let routeQuery = HKWorkoutRouteQuery(route: route) { [weak self] query, routeData, done, error in
      guard let self = self else { return }
      
      if let error = error {
        result(FlutterError(
          code: "route_error",
          message: "Ошибка загрузки маршрута: \(error.localizedDescription)",
          details: nil
        ))
        return
      }
      
      if let routeData = routeData {
        allRoutePoints.append(contentsOf: routeData)
      }
      
      if done {
        if allRoutePoints.isEmpty {
          result([])
        } else {
          self.convertRouteToFlutterFormat(routeData: allRoutePoints, result: result)
        }
      }
    }
    
    healthStore.execute(routeQuery)
  }
  
  private func convertRouteToFlutterFormat(routeData: [CLLocation], result: @escaping FlutterResult) {
    var routePoints: [[String: Any]] = []
    
    for location in routeData {
      var point: [String: Any] = [
        "lat": location.coordinate.latitude,
        "lng": location.coordinate.longitude,
      ]
      
      if location.altitude >= 0 {
        point["alt"] = location.altitude
      } else {
        point["alt"] = -1.0
      }
      
      let timestamp = Int64(location.timestamp.timeIntervalSince1970 * 1000)
      point["t"] = timestamp
      
      routePoints.append(point)
    }
    
    result(routePoints)
  }
}
