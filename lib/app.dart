import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/chess_controller.dart';
import 'state/engine_controller.dart';
import 'ui/main_menu.dart';

class ChessDesktopApp extends StatelessWidget {
  const ChessDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F3B52),
      brightness: Brightness.light,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChessController()),
        ChangeNotifierProvider(create: (_) => EngineController()),
      ],
      child: MaterialApp(
        title: 'Chess Desktop',
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F7FB),
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        home: const MainMenu(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
