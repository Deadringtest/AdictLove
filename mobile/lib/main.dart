import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AdictLoveApp());
}

class AdictLoveApp extends StatelessWidget {
  const AdictLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdictLove',
      theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
