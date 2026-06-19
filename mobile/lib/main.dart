import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/theme_service.dart';

void main() {
  runApp(const AdictLoveApp());
}

class AdictLoveApp extends StatefulWidget {
  const AdictLoveApp({super.key});

  @override
  State<AdictLoveApp> createState() => _AdictLoveAppState();
}

class _AdictLoveAppState extends State<AdictLoveApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ThemeService.instance.mode, ThemeService.instance.seedColor]),
      builder: (context, _) {
        final seed = ThemeService.instance.seedColor.value;
        return MaterialApp(
          title: 'AdictLove',
          themeMode: ThemeService.instance.mode.value,
          theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: seed, useMaterial3: true, brightness: Brightness.dark),
          home: const LoginScreen(),
        );
      },
    );
  }
}
