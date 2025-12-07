import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Firebase Cloud Messaging Service for push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize Firebase and FCM
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      
      // Initialize messaging after Firebase is ready
      _messaging = FirebaseMessaging.instance;
      
      // Request notification permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM: User granted notification permission');
        
        // Get FCM token
        _fcmToken = await messaging.getToken();
        print('✅ FCM Token: $_fcmToken');
        
        // Save token to backend
        await _saveFCMTokenToBackend(_fcmToken!);
        
        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          _saveFCMTokenToBackend(newToken);
        });
        
        // Initialize local notifications for foreground messages
        await _initializeLocalNotifications();
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background/terminated messages
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
        
      } else {
        print('❌ FCM: User declined notification permission');
      }
    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📱 Notification tapped: ${response.payload}');
        // Handle notification tap
      },
    );
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📩 Foreground message: ${message.notification?.title}');
    
    // Show local notification with Al-Mathina branding
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'orders_channel',
      'Order Notifications',
      channelDescription: 'Notifications for order updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color.fromARGB(255, 40, 167, 69), // Al-Mathina green
      playSound: true,
      enableVibration: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Al-Mathina',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Handle background/terminated messages (app is closed)
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📩 Background message opened: ${message.notification?.title}');
    // Navigate to orders screen or specific order
  }

  /// Save FCM token to backend
  Future<void> _saveFCMTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      
      if (phone == null || phone.isEmpty) {
        print('⚠️ FCM: No user phone found, cannot save token');
        return;
      }

      // Use same base URL as ApiService
      const String baseUrl = 'https://al-mathina.onrender.com'; // Production
      // For local testing: 'http://127.0.0.1:8000' or 'http://10.0.2.2:8000' (Android emulator)
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'fcm_token': token,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token saved to backend');
      } else {
        print('❌ Failed to save FCM token: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Manually refresh FCM token (call after login)
  Future<void> refreshToken() async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        await _saveFCMTokenToBackend(token);
      }
    } catch (e) {
      print('❌ Error refreshing FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Background message: ${message.notification?.title}');
}
