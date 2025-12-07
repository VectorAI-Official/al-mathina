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
  
  // Callback for showing in-app notifications
  Function(RemoteMessage)? onMessageReceived;

  /// Initialize Firebase and FCM
  Future<void> initialize() async {
    try {
      print('🚀 FCM: Starting initialization...');
      // Initialize Firebase
      await Firebase.initializeApp();
      print('✅ FCM: Firebase initialized');
      
      // Initialize messaging after Firebase is ready
      _messaging = FirebaseMessaging.instance;
      print('✅ FCM: Messaging instance created');
      
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
        print('🔑 FCM: Requesting token...');
        _fcmToken = await messaging.getToken();
        print('✅ FCM Token generated: $_fcmToken');
        
        // Save token to backend
        print('💾 FCM: Saving token to backend...');
        await _saveFCMTokenToBackend(_fcmToken!);
        
        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          _saveFCMTokenToBackend(newToken);
        });
        
        // Initialize local notifications for foreground messages
        print('🔔 FCM: Initializing local notifications...');
        await _initializeLocalNotifications();
        print('✅ FCM: Local notifications ready');
        
        // Handle foreground messages
        print('👂 FCM: Setting up message listeners...');
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background/terminated messages
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
        print('✅ FCM: All listeners registered');
        print('🎉 FCM: Initialization complete!');
        
      } else {
        print('❌ FCM: User declined notification permission');
        print('⚠️ FCM: Authorization status: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ FCM initialization error: $e');
      print('❌ FCM error stack trace: ${StackTrace.current}');
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
    print('\n🎯 ============ FOREGROUND MESSAGE RECEIVED ============');
    print('📩 Title: ${message.notification?.title}');
    print('📩 Body: ${message.notification?.body}');
    print('📩 Data: ${message.data}');
    print('📩 Message ID: ${message.messageId}');
    print('📩 Sent time: ${message.sentTime}');
    print('======================================================\n');
    
    // Trigger in-app notification callback
    if (onMessageReceived != null) {
      print('📲 FCM: Triggering in-app callback...');
      onMessageReceived!(message);
    } else {
      print('⚠️ FCM: No in-app callback registered');
    }
    
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

    try {
      print('🔔 FCM: Showing local notification...');
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Al-Mathina',
        message.notification?.body ?? '',
        notificationDetails,
        payload: message.data.toString(),
      );
      print('✅ FCM: Local notification displayed');
    } catch (e) {
      print('❌ FCM: Error showing notification: $e');
    }
  }

  /// Handle background/terminated messages (app is closed)
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('\n🎯 ============ BACKGROUND MESSAGE OPENED ============');
    print('📩 Title: ${message.notification?.title}');
    print('📩 Body: ${message.notification?.body}');
    print('📩 Data: ${message.data}');
    print('======================================================\n');
    // Navigate to orders screen or specific order
  }

  /// Save FCM token to backend
  Future<void> _saveFCMTokenToBackend(String token) async {
    try {
      print('💾 FCM: Preparing to save token...');
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone');
      print('📱 FCM: User phone: ${phone ?? "NOT FOUND"}');
      
      if (phone == null || phone.isEmpty) {
        print('❌ FCM: Cannot save token - no user phone in SharedPreferences');
        return;
      }

      // Use same base URL as ApiService
      const String baseUrl = 'https://al-mathina.onrender.com'; // Production
      // For local testing: 'http://127.0.0.1:8000' or 'http://10.0.2.2:8000' (Android emulator)
      
      final url = '$baseUrl/api/user/fcm-token';
      print('🌐 FCM: Sending to: $url');
      print('📦 FCM: Payload: {phone: $phone, fcm_token: ${token.substring(0, 20)}...}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'fcm_token': token,
        }),
      ).timeout(Duration(seconds: 10));

      print('📡 FCM: Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ FCM: Token saved successfully to backend!');
        print('✅ FCM: Response: ${response.body}');
      } else {
        print('❌ FCM: Failed to save token - Status ${response.statusCode}');
        print('❌ FCM: Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ FCM: Error saving token: $e');
      print('❌ FCM: Error type: ${e.runtimeType}');
    }
  }

  /// Manually refresh FCM token (call after login)
  Future<void> refreshToken() async {
    try {
      print('🔄 FCM: Refreshing token manually...');
      final token = await messaging.getToken();
      if (token != null) {
        print('✅ FCM: Token retrieved: ${token.substring(0, 20)}...');
        _fcmToken = token;
        await _saveFCMTokenToBackend(token);
      } else {
        print('⚠️ FCM: Token is null after refresh');
      }
    } catch (e) {
      print('❌ FCM: Error refreshing token: $e');
      print('❌ FCM: Error type: ${e.runtimeType}');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Background message: ${message.notification?.title}');
}
