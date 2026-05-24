import 'package:flutter/material.dart';
import 'features/chat/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness: Brightness.dark,

        scaffoldBackgroundColor: const Color(0xFF020617),

        primaryColor: Colors.blueAccent,

        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.amber,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      home: const ChatScreen(),
    );
  }
}
