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
  
  // Callback for handling notification taps
  Function(String orderId, String userPhone)? onNotificationTap;

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
        
        // Check if app was opened from a notification (terminated state)
        print('🔍 FCM: Checking for initial message...');
        RemoteMessage? initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          print('📬 FCM: App opened from notification in terminated state');
          await _handleBackgroundMessage(initialMessage);
        } else {
          print('ℹ️ FCM: No initial message (normal app launch)');
        }
        
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

  /// Refresh FCM token and save to backend (called on app startup for logged-in users)
  Future<void> refreshToken() async {
    try {
      print('🔄 FCM: Refreshing token...');
      
      // Get current token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        print('✅ FCM: Token obtained: ${token.substring(0, 30)}...');
        
        // Save to backend
        await _saveFCMTokenToBackend(token);
        print('✅ FCM: Token saved to backend');
      } else {
        print('⚠️ FCM: No token available');
      }
    } catch (e) {
      print('❌ FCM: Token refresh failed: $e');
      rethrow;
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
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('📱 Notification tapped: ${response.payload}');
        await _handleNotificationTap(response.payload);
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
      // Encode order_id in payload
      final payload = jsonEncode(message.data);
      print('📦 FCM: Notification payload: $payload');
      
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Al-Mathina',
        message.notification?.body ?? '',
        notificationDetails,
        payload: payload,
      );
      print('✅ FCM: Local notification displayed');
    } catch (e) {
      print('❌ FCM: Error showing notification: $e');
    }
  }
  
  /// Handle notification tap (both foreground local notification and background)
  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) {
      print('⚠️ FCM: No payload in notification tap');
      return;
    }
    
    try {
      print('🔔 FCM: Processing notification tap payload...');
      final data = jsonDecode(payload) as Map<String, dynamic>;
      print('📦 FCM: Decoded data: $data');
      
      if (data.containsKey('order_id')) {
        final orderId = data['order_id'];
        print('🎯 FCM: Order ID from tap: $orderId');
        
        // Try to get user phone from notification data first, then from SharedPreferences
        String? userPhone = data['user_phone'];
        
        if (userPhone == null || userPhone.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          userPhone = prefs.getString('userPhone');
          print('📱 FCM: User phone from SharedPreferences: $userPhone');
        } else {
          print('📱 FCM: User phone from notification data: $userPhone');
        }
        
        if (userPhone != null && userPhone.isNotEmpty && onNotificationTap != null) {
          print('✅ FCM: Triggering navigation to OrderDetailsScreen');
          onNotificationTap!(orderId, userPhone);
        } else {
          print('⚠️ FCM: Cannot navigate - userPhone: $userPhone, callback: ${onNotificationTap != null}');
        }
      } else {
        print('⚠️ FCM: No order_id in notification data');
      }
    } catch (e) {
      print('❌ FCM: Error parsing notification payload: $e');
    }
  }  /// Handle background/terminated messages (app is closed)
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('\n🎯 ============ BACKGROUND MESSAGE OPENED ============');
    print('📩 Title: ${message.notification?.title}');
    print('📩 Body: ${message.notification?.body}');
    print('📩 Data: ${message.data}');
    print('======================================================\n');
    
    // Navigate to order details
    if (message.data.containsKey('order_id')) {
      final orderId = message.data['order_id'];
      print('🔔 FCM: Navigating to order: $orderId');
      
      // Try to get user phone from notification data first, then from SharedPreferences
      String? userPhone = message.data['user_phone'];
      
      if (userPhone == null || userPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        userPhone = prefs.getString('userPhone');
        print('📱 FCM: User phone from SharedPreferences: $userPhone');
      } else {
        print('📱 FCM: User phone from notification data: $userPhone');
      }
      
      if (userPhone != null && userPhone.isNotEmpty && onNotificationTap != null) {
        print('✅ FCM: Triggering navigation callback...');
        onNotificationTap!(orderId, userPhone);
      } else {
        print('⚠️ FCM: Cannot navigate - userPhone: $userPhone, callback: ${onNotificationTap != null}');
      }
    } else {
      print('⚠️ FCM: No order_id in notification data');
    }
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
