import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/authentication/screens/login/login_screen.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize permission handler
  await Permission.camera.request();

  // Stop OneSignal Verbose Debugging
  OneSignal.Debug.setLogLevel(OSLogLevel.none);

  OneSignal.initialize("329b0b98-b961-4613-ae74-94e4c17dd44f");

  // The promptForPushNotificationsWithUserResponse function will show the iOS or Android push notification prompt. We recommend removing the following code and instead using an In-App Message to prompt for notification permission
  OneSignal.Notifications.requestPermission(true);
  await Supabase.initialize(
    url: 'https://bxcsazxrgkrslbqeworx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4Y3NhenhyZ2tyc2xicWV3b3J4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTk3NDQyODMsImV4cCI6MjAzNTMyMDI4M30.NcvtPsa_FC_3ozm4G43pDrY8XtO2zhtM2RVW1WFOy78',
  );

  // Registered ONCE here, permanently. Every screen must use Get.find()
  // instead of Get.put() for this controller — re-putting it wipes out
  // whatever's in the cart, which was silently breaking the issue flow.
  Get.put(ComponentController(), permanent: true);

  // In-memory cache layer registered ONCE as permanent singleton.
  // RealtimeInventoryService invalidates individual tables upon Postgres changes.
  final cacheController = Get.put(CacheController(), permanent: true);
  cacheController.prewarmCategories();

  // Load saved theme preference
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    if (isDark != null) {
      initialThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  } catch (_) {}

  runApp(MyApp(initialThemeMode: initialThemeMode));
}

class MyApp extends StatelessWidget {
  final ThemeMode initialThemeMode;

  const MyApp({super.key, this.initialThemeMode = ThemeMode.light});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CAppTheme.lightTheme,
      darkTheme: CAppTheme.darkTheme,
      themeMode: initialThemeMode,
      home: const LoginScreen(),
    );
  }
}
