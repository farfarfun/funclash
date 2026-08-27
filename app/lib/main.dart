import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_shell.dart';

void main() {
  runApp(const ProviderScope(child: FunclashApp()));
}

class FunclashApp extends StatelessWidget {
  const FunclashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'funclash',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const HomeShell(),
    );
  }
}
