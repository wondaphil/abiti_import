import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart'; // or whatever your main screen file is called

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo_splash.png',
              width: 160,
              height: 160,
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: Colors.teal),
          ],
        ),
      ),
    );
  }
}