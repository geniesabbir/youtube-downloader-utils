import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xff06080d);
  static const Color panel = Color(0xff111723);
  static const Color panelAlt = Color(0xff172031);
  static const Color stroke = Color(0xff233047);
  static const Color cyan = Color(0xff61d7ff);
  static const Color mint = Color(0xff7bffb2);
  static const Color cloud = Color(0xffecf2ff);
  static const Color muted = Color(0xff7f90aa);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.mint,
      surface: AppColors.panel,
      error: Color(0xffff6b6b),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerColor: AppColors.stroke,
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.mint,
        labelColor: AppColors.mint,
        unselectedLabelColor: AppColors.muted,
        dividerColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.stroke),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.mint,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cloud,
          side: const BorderSide(color: AppColors.stroke),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panelAlt.withOpacity(0.96),
        contentTextStyle: const TextStyle(color: AppColors.cloud),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.mint;
          }
          return Colors.blueGrey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.mint.withOpacity(0.4);
          }
          return Colors.blueGrey.withOpacity(0.35);
        }),
      ),
    );
  }
}
