import 'package:flutter/material.dart';

import 'login_page.dart';

void main() {
  runApp(const AdictLoveApp());
}

class AdictLoveApp extends StatelessWidget {
  const AdictLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdictLove',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
