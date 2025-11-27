import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'screens/splash_screen.dart';
import 'db/database_helper.dart';

final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: <String>[
    'https://www.googleapis.com/auth/drive.file',
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop initialization for SQFLite FFI
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Fixes access issues on Windows by changing the working directory
    final dir = await getApplicationSupportDirectory();
    Directory.current = dir.path;
  }

  // Ensure DB initialized before app starts
  await DatabaseHelper.instance.database;

  runApp(const AbitiImportApp());
}

class AbitiImportApp extends StatelessWidget {
  const AbitiImportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abiti Import',
      debugShowCheckedModeBanner: false,

      //----------------------------------------------------------------------
      // 🌈 LIGHT THEME — Modern Indigo Material 3
      //----------------------------------------------------------------------
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),

        //------------------------------------------------------------------
        // App Bar
        //------------------------------------------------------------------
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
        ),

        //------------------------------------------------------------------
        // Cards (Material 3)
        //------------------------------------------------------------------
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        //------------------------------------------------------------------
        // Text Fields (Form / Search / Dialogs)
        //------------------------------------------------------------------
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),

        //------------------------------------------------------------------
        // Buttons — Modern Material 3 behavior
        //------------------------------------------------------------------
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),

      //----------------------------------------------------------------------
      // 🌙 DARK THEME — Modern Indigo (Material 3 compliant)
      //----------------------------------------------------------------------
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      //----------------------------------------------------------------------
      // Follow system theme automatically
      //----------------------------------------------------------------------
      themeMode: ThemeMode.system,

      //----------------------------------------------------------------------
      home: const SplashScreen(),
    );
  }
}