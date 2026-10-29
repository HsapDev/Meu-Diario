import 'package:flutter/material.dart';
import 'views/home/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeuDiarioApp());
}

class MeuDiarioApp extends StatelessWidget {
  const MeuDiarioApp({super.key});

  // Lilás/Lavanda suave e calmo para os olhos
  static const Color lilasCalmo = Color(0xFFB8A9D9);
  static const Color fundoEscuro = Color(0xFF15151C);
  static const Color cardEscuro = Color(0xFF1F1F29);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Diário',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fundoEscuro,
        colorScheme: const ColorScheme.dark(
          primary: lilasCalmo,
          onPrimary: Color(0xFF1E1B26),
          secondary: lilasCalmo,
          onSecondary: Color(0xFF1E1B26),
          surface: cardEscuro,
          onSurface: Color(0xFFEAE8F0),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: fundoEscuro,
          foregroundColor: Color(0xFFEAE8F0),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: cardEscuro,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: lilasCalmo.withValues(alpha: 0.18)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lilasCalmo,
            foregroundColor: const Color(0xFF1E1B26),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: lilasCalmo,
          foregroundColor: Color(0xFF1E1B26),
          elevation: 2,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: cardEscuro,
          selectedColor: lilasCalmo.withValues(alpha: 0.22),
          checkmarkColor: lilasCalmo,
          side: BorderSide(color: lilasCalmo.withValues(alpha: 0.25)),
          labelStyle: const TextStyle(color: Color(0xFFEAE8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardEscuro,
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lilasCalmo.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: lilasCalmo.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
