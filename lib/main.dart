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
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'إشعارات مهمة',
  description: 'قناة لإشعارات ذات أولوية عالية',
  importance: Importance.max,
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
  await _localNotifications.initialize(initSettings);
  // Create channel on Android
  await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_defaultChannel);

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.notification?.title ?? 'إشعار';
    final body = message.notification?.body ?? '';
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
    final title = message.notification?.title ?? 'إشعار';
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('فتح من الإشعار: $title')),
    );
  });

  // App launched from terminated state via notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final title = initialMessage.notification?.title ?? 'إشعار';
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('فتح بالتنبيه: $title')),
    );
  }

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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