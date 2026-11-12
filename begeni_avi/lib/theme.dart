import 'package:material_ui/material_ui.dart';

class AppColors {
  static const bg = Color(0xFF0E0E14);
  static const card = Color(0xFF1A1A24);
  static const cardHi = Color(0xFF252533);
  static const pink = Color(0xFFFF3D7F);
  static const cyan = Color(0xFF2DE2E6);
  static const yellow = Color(0xFFFFD23F);
  static const green = Color(0xFF3DDC84);
  static const muted = Color(0xFF9A9AB0);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.pink,
      brightness: Brightness.dark,
      primary: AppColors.pink,
      secondary: AppColors.cyan,
      surface: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, elevation: 0, centerTitle: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.pink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppColors.cardHi, width: 2),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
  );
}
