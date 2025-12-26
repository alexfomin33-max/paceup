import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fcm_service.dart';

/// Provider для FCMService (singleton)
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});
