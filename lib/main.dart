import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(LabbitApp());
}

class LabbitApp extends StatelessWidget {
  const LabbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFDF8),
        primaryColor: const Color.fromARGB(255, 136, 163, 176),
        fontFamily: "englebert",
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFCFD8DC),
          foregroundColor: Color(0xFF0D1B2A),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontFamily: "playpen",
            color: Color.fromARGB(255, 62, 97, 113)),
          headlineLarge: TextStyle(
            fontFamily: "englebert"
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 143, 184, 206),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 134, 168, 219),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/home': (_) => HomeScreen(),
      },
    );
  }
}
