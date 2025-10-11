import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lab_to_lab_admin/screens/onboarding_landing.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';
import 'package:lab_to_lab_admin/screens/control_panal_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_to_lab.dart';
import 'package:lab_to_lab_admin/screens/lab_results_patients_screen.dart';
import 'package:lab_to_lab_admin/screens/patients_screen.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'إشعارات مهمة',
  description: 'قناة لإشعارات ذات أولوية عالية',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('lab_notification'),
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can log or handle background data here
}

Future<void> _initLocationPermission() async {
  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return;
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permission denied forever');
      return;
    }

    print('Location permission granted');
  } catch (e) {
    print('Error requesting location permission: $e');
    // Don't throw error, just log it and continue
  }
}

Future<void> _initMessaging() async {
  // iOS permission (Android shows notifications by default)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Initialize local notifications
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidInit);
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );
  // Create channel on Android
  await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_defaultChannel);

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title ?? 'إشعار';
    final body = message.notification?.body ?? '';
    print('🔔 Received foreground message: $title - $body');
    print('📊 Message data: ${message.data}');
    
    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('lab_notification'),
          styleInformation: BigTextStyleInformation(
            body,
            htmlFormatBigText: false,
            contentTitle: title,
            htmlFormatContentTitle: false,
          ),
        ),
      ),
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  });

  // App opened from background via notification tap
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  });

  // App launched from terminated state via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationNavigation(initialMessage.data);
  }

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

// Handle notification tap
void _onNotificationTapped(NotificationResponse response) {
  print('🔔 Notification tapped - Payload: ${response.payload}');
  if (response.payload != null) {
    try {
      // Parse the payload data
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        Uri.splitQueryString(response.payload!)
      );
      print('📊 Parsed payload data: $data');
      _handleNotificationNavigation(data);
    } catch (e) {
      print('❌ Error parsing notification payload: $e');
    }
  } else {
    print('❌ No payload in notification response');
  }
}

// Handle navigation based on notification data
void _handleNotificationNavigation(Map<String, dynamic> data) {
  final String? topic = data['topic'];
  final String? labId = data['labId'];
  final String? labName = data['labName'];
  
  print('🔔 Notification navigation - Topic: $topic, LabId: $labId, LabName: $labName');
  
  if (topic == null) {
    print('❌ No topic found in notification data');
    return;
  }
  
  // Navigate based on topic
  switch (topic) {
    case 'new_patient':
    case 'lab_order':
      // Navigate to patients screen (control panel)
      print('📱 Navigating to patients screen');
      _navigateToScreen('/patients');
      break;
    case 'lab_order_received':
    case 'lab_order_reques':
      // Navigate to lab results patients screen
      if (labId != null && labName != null) {
        print('📱 Navigating to lab results patients screen');
        _navigateToScreen('/lab_results_patients', {
          'labId': labId,
          'labName': labName,
        });
      } else {
        print('❌ Missing labId or labName for lab results navigation');
      }
      break;
    case 'new_lab':
      // Navigate to lab to lab screen
      print('📱 Navigating to lab to lab screen');
      _navigateToScreen('/control_panel/labs');
      break;
    default:
      print('❌ Unknown topic: $topic');
  }
}

// Navigate to specific screen
void _navigateToScreen(String route, [Map<String, dynamic>? arguments]) {
  // Use a global navigator key
  final navigator = rootNavigatorKey.currentState;
  if (navigator != null) {
    print('🚀 Navigating to route: $route with arguments: $arguments');
    navigator.pushNamed(route, arguments: arguments);
  } else {
    print('❌ Navigator not available');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _initMessaging();
  // Don't await location permission to avoid blocking app startup
  _initLocationPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final prefs = snap.data!;
        final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        final bool hasContract = prefs.getBool('hasContract') ?? false;
        final String? labId = prefs.getString('lab_id');
        final String? labName = prefs.getString('labName');

        Widget home;
        if (isLoggedIn && labId != null && labName != null) {
          home = LabDashboardScreen(labId: labId, labName: labName);
        } else if (hasContract) {
          home = const LoginScreen();
        } else {
          home = const OnboardingLandingScreen();
        }

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          theme: ThemeData(
            textTheme: TextTheme(
              bodyMedium: TextStyle(fontFamily: 'Tajawal'),
              titleLarge: TextStyle(fontFamily: 'Tajawal'),
            )

          ),
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: home,
          routes: {
            '/control_panel': (_) => const ControlPanalScreen(),
            '/control_panel/labs': (_) => const LabToLab(),
            '/patients': (_) => const PatientsScreen(),
            '/lab_results_patients': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return LabResultsPatientsScreen(
                labId: args?['labId'] ?? '',
                labName: args?['labName'] ?? '',
              );
            },
          },
        );
      },
    );
  }
}