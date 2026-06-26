import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'package:truassets/core/app_export.dart';
import 'widgets/custom_error_widget.dart';

import 'services/auth_service.dart';
import 'presentation/dashboard_screen/dashboard_screen.dart';
import 'presentation/login_screen/login_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize auth state from SharedPreferences
  await AuthService.instance.initializeAuth();

  // 🌐 Allow GoogleFonts to fail gracefully on web (network issues)
  GoogleFonts.config.allowRuntimeFetching = true;

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]).then((value) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'TruAssets',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          routes: AppRoutes.routes,
          home: ValueListenableBuilder<bool>(
            valueListenable: AuthService.isDemoMode,
            builder: (context, isDemo, _) {
              if (isDemo) {
                return const DashboardScreen();
              }
              return StreamBuilder<User?>(
                stream: AuthService.instance.authStateChanges,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    );
                  }
                  if (snapshot.hasData) {
                    return const DashboardScreen();
                  }
                  return const LoginScreen();
                },
              );
            },
          ),
        );
      },
    );
  }
}
