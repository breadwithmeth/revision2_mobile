import 'package:flutter/material.dart';
import 'features/inventory/documents_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Инвентаризация',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DocumentsScreen(),
    );
  }
}

// Removed the boilerplate counter page. The app now starts at DocumentsScreen.
