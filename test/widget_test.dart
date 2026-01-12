// ────────────────────────────────────────────────────────────────
// SMOKE TEST
//
// Простой smoke-тест для проверки работоспособности тестовой инфраструктуры
// ────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_utils.dart';
import 'helpers/fixtures/activity_fixtures.dart';
import 'helpers/fixtures/user_fixtures.dart';
import 'helpers/fixtures/api_response_fixtures.dart';
import 'helpers/mocks/mock_auth_service.dart';
import 'helpers/mocks/mock_api_service.dart';
import 'helpers/mocks/mock_cache_service.dart';

void main() {
  group('Smoke Tests', () {
    // ────────────────────────────────────────────────────────────
    // Простой smoke-тест: проверяем, что тестовый раннер запускается
    // ────────────────────────────────────────────────────────────
    test('test runner is alive', () {
      expect(true, isTrue);
    });

    // ────────────────────────────────────────────────────────────
    // Проверка доступности тестовых утилит
    // ────────────────────────────────────────────────────────────
    test('TestUtils доступны', () {
      final date = TestUtils.testDate();
      expect(date, isA<DateTime>());
      
      final json = TestUtils.createTestJson();
      expect(json, isA<Map<String, dynamic>>());
    });

    // ────────────────────────────────────────────────────────────
    // Проверка фикстур
    // ────────────────────────────────────────────────────────────
    test('ActivityFixtures работают', () {
      final activity = ActivityFixtures.createRunningActivity();
      expect(activity.id, greaterThan(0));
      expect(activity.type, 'running');
      
      final activities = ActivityFixtures.createActivityList(count: 3);
      expect(activities.length, 3);
    });

    test('UserFixtures работают', () {
      final user = UserFixtures.createUser();
      expect(user['id'], greaterThan(0));
      expect(user['name'], isNotEmpty);
    });

    test('ApiResponseFixtures работают', () {
      final success = ApiResponseFixtures.success();
      expect(success['success'], isTrue);
      
      final error = ApiResponseFixtures.error(message: 'Test error');
      expect(error['success'], isFalse);
    });

    // ────────────────────────────────────────────────────────────
    // Проверка моков
    // ────────────────────────────────────────────────────────────
    test('MockAuthService работает', () async {
      final mockAuth = MockAuthServiceFactory.authorized(userId: 1);
      final token = await mockAuth.getAccessToken();
      expect(token, isNotNull);
      
      final userId = await mockAuth.getUserId();
      expect(userId, 1);
    });

    test('MockApiService работает', () async {
      final mockApi = MockApiServiceFactory.successful();
      final response = await mockApi.get('/test');
      expect(response, isA<Map<String, dynamic>>());
    });

    test('MockCacheService работает', () async {
      final activities = ActivityFixtures.createActivityList(count: 2);
      final mockCache = MockCacheServiceFactory.withActivities(activities);
      
      final cached = await mockCache.getCachedActivities(userId: 1);
      expect(cached.length, 2);
    });
  });
}
