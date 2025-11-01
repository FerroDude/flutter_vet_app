import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
/// This design system can be replicated in React for consistency across platforms
class AppTheme {
  // Primary Brand Colors (Ocean-Inspired Palette)
  static const Color primaryDarkBlue = Color(
    0xFF084C7B,
  ); // Strongest - Main brand color
  static const Color primaryBlue = Color(0xFF1172B0); // Secondary actions
  static const Color primaryTeal = Color(0xFF309CB0); // Appointments
  static const Color primaryMediumTeal = Color(0xFF57B4A4); // Medications
  static const Color primaryLightGreen = Color(
    0xFF85E7A9,
  ); // Health logs, success states

  // Legacy aliases for compatibility
  static const Color primaryNavy = primaryDarkBlue;
  static const Color primaryGreen = primaryMediumTeal;
  static const Color accentCoral = primaryLightGreen;
  static const Color accentAmber = Color(0xFFFFC107); // Keep amber for warnings

  // Neutral Colors - Proper gray scale for better visual hierarchy
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color neutralGray50 = Color(0xFFF8F9FA);
  static const Color neutralGray100 = Color(0xFFE9ECEF);
  static const Color neutralGray200 = Color(0xFFDEE2E6);
  static const Color neutralGray300 = Color(0xFFCED4DA);
  static const Color neutralGray400 = Color(0xFFADB5BD);
  static const Color neutralGray500 = Color(0xFF6C757D);
  static const Color neutralGray600 = Color(0xFF495057);
  static const Color neutralGray700 = Color(0xFF343A40);
  static const Color neutralGray800 = Color(0xFF212529);
  static const Color neutralGray900 = Color(0xFF000000);

  // Semantic Colors - Modern, accessible palette
  static const Color successGreen = Color(0xFF28A745);
  static const Color warningAmber = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFDC3545);
  static const Color infoBlue = Color(0xFF17A2B8);

  // Background Colors - Subtle layering for depth
  static const Color backgroundPrimary = neutralWhite;
  static const Color backgroundSecondary = neutralGray50;
  static const Color backgroundTertiary = neutralGray100;

  // Border Colors - Softer, more refined
  static const Color borderLight = neutralGray200;
  static const Color borderMedium = neutralGray300;
  static const Color borderDark = neutralGray400;

  // Text Colors - Better hierarchy and readability
  static const Color textPrimary = neutralGray800;
  static const Color textSecondary = neutralGray600;
  static const Color textTertiary = neutralGray500;
  static const Color textOnPrimary = neutralWhite;

  // Spacing (can be used as multipliers: spacing4 = 4.0)
  static const double spacing1 = 4.0;
  static const double spacing2 = 8.0;
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 20.0;
  static const double spacing6 = 24.0;
  static const double spacing8 = 32.0;
  static const double spacing10 = 40.0;
  static const double spacing12 = 48.0;
  static const double spacing16 = 64.0;
  static const double spacing20 = 80.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Shadows
  static BoxShadow get shadowSmall => BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 2,
    offset: const Offset(0, 1),
  );

  static BoxShadow get shadowMedium => BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 4),
  );

  static BoxShadow get shadowLarge => BoxShadow(
    color: Colors.black.withOpacity(0.15),
    blurRadius: 16,
    offset: const Offset(0, 8),
  );

  // Typography
  static const String fontFamily = 'System'; // Uses system font

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.25,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    height: 1.3,
  );

  // Button Styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: textOnPrimary,
    elevation: 0,
    padding: const EdgeInsets.symmetric(
      horizontal: spacing6,
      vertical: spacing4,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: labelLarge.copyWith(color: textOnPrimary),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue, width: 1.5),
    padding: const EdgeInsets.symmetric(
      horizontal: spacing6,
      vertical: spacing4,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: labelLarge.copyWith(color: primaryBlue),
  );

  static ButtonStyle get tertiaryButtonStyle => TextButton.styleFrom(
    foregroundColor: primaryBlue,
    padding: const EdgeInsets.symmetric(
      horizontal: spacing4,
      vertical: spacing3,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
    textStyle: labelLarge.copyWith(color: primaryBlue),
  );

  // Card Styles
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: backgroundPrimary,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(color: borderLight),
    boxShadow: [shadowSmall],
  );

  static BoxDecoration get cardDecorationElevated => BoxDecoration(
    color: backgroundPrimary,
    borderRadius: BorderRadius.circular(radiusMedium),
    boxShadow: [shadowMedium],
  );

  // Input Decoration
  static InputDecoration getInputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: borderMedium),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: borderMedium),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: primaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: const BorderSide(color: errorRed),
    ),
    filled: true,
    fillColor: backgroundSecondary,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: spacing4,
      vertical: spacing4,
    ),
    labelStyle: bodyMedium.copyWith(color: textSecondary),
    hintStyle: bodyMedium.copyWith(color: textTertiary),
  );

  // Icon Themes
  static const IconThemeData primaryIconTheme = IconThemeData(
    color: primaryBlue,
    size: 24,
  );

  static const IconThemeData secondaryIconTheme = IconThemeData(
    color: textSecondary,
    size: 20,
  );

  static const IconThemeData appBarIconTheme = IconThemeData(
    color: textPrimary,
    size: 24,
  );

  // AppBar Theme
  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: primaryNavy,
    foregroundColor: textOnPrimary,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: headingMedium.copyWith(color: textOnPrimary),
    iconTheme: const IconThemeData(color: textOnPrimary, size: 24),
    toolbarHeight: 56,
  );

  // Bottom Navigation Theme
  static BottomNavigationBarThemeData get bottomNavTheme =>
      BottomNavigationBarThemeData(
        backgroundColor: primaryDarkBlue, // Dark blue background
        selectedItemColor: primaryTeal, // Teal (#309CB0) for selected
        unselectedItemColor: Colors.white, // White for unselected
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: labelSmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: labelSmall,
      );

  // NavigationBar (Material 3) Theme for consistency
  static NavigationBarThemeData get navBarTheme => NavigationBarThemeData(
    backgroundColor: primaryDarkBlue, // Dark blue background
    indicatorColor: primaryTeal.withOpacity(0.2),
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
      final isSelected = states.contains(WidgetState.selected);
      return (isSelected
              ? labelSmall.copyWith(fontWeight: FontWeight.w600)
              : labelSmall)
          .copyWith(color: isSelected ? primaryTeal : Colors.white);
    }),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
      final isSelected = states.contains(WidgetState.selected);
      return IconThemeData(color: isSelected ? primaryTeal : Colors.white);
    }),
  );

  // Dark Mode Colors - Modern Premium Dark Palette
  static const Color darkBackgroundPrimary = Color(
    0xFF1A1B1E,
  ); // Warm charcoal (not harsh black)
  static const Color darkBackgroundSecondary = Color(
    0xFF23242A,
  ); // Navigation, cards
  static const Color darkBackgroundTertiary = Color(
    0xFF2C2D33,
  ); // Elevated surfaces
  static const Color darkBackgroundQuaternary = Color(
    0xFF35363C,
  ); // Interactive surfaces

  // Modern text hierarchy for excellent readability
  static const Color darkTextPrimary = Color(
    0xFFF5F5F7,
  ); // Soft white (iOS-inspired)
  static const Color darkTextSecondary = Color(
    0xFFC7C7CC,
  ); // Clear secondary text
  static const Color darkTextTertiary = Color(
    0xFF8E8E93,
  ); // Subtle hints/labels
  static const Color darkTextQuaternary = Color(
    0xFF6D6D70,
  ); // Very low contrast

  // Refined borders with better contrast
  static const Color darkBorderLight = Color(0xFF38383A); // Subtle separation
  static const Color darkBorderMedium = Color(0xFF48484A); // Clear definition
  static const Color darkBorderDark = Color(0xFF58585A); // Strong emphasis

  // Modern accent colors optimized for dark environments
  static const Color darkAccentGreen = Color(
    0xFF32D74B,
  ); // Vibrant iOS-style green
  static const Color darkAccentOrange = Color(
    0xFFFF9500,
  ); // Warm, friendly orange
  static const Color darkAccentPurple = Color(
    0xFFBF5AF2,
  ); // Premium purple accent
  static const Color darkAccentBlue = Color(
    0xFF007AFF,
  ); // Clear, trustworthy blue

  // Material Theme Data
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textOnPrimary,
      ),
    ),
    bottomNavigationBarTheme: bottomNavTheme,
    navigationBarTheme: navBarTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    textButtonTheme: TextButtonThemeData(style: tertiaryButtonStyle),
    iconTheme: primaryIconTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: borderLight),
      ),
      margin: const EdgeInsets.all(spacing2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: borderMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      filled: true,
      fillColor: backgroundSecondary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacing4,
        vertical: spacing4,
      ),
    ),
  );

  // Dark Mode Button Styles - Modern and Premium
  static ButtonStyle get darkPrimaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: darkAccentGreen,
    foregroundColor: Colors.white,
    elevation: 1,
    shadowColor: darkAccentGreen.withOpacity(0.3),
    padding: const EdgeInsets.symmetric(
      horizontal: spacing6,
      vertical: spacing4,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: labelLarge.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
  );

  static ButtonStyle get darkSecondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: darkAccentGreen,
    backgroundColor: darkBackgroundTertiary,
    side: BorderSide(color: darkAccentGreen, width: 1.5),
    padding: const EdgeInsets.symmetric(
      horizontal: spacing6,
      vertical: spacing4,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    ),
    textStyle: labelLarge.copyWith(color: darkAccentGreen),
  );

  static ButtonStyle get darkTertiaryButtonStyle => TextButton.styleFrom(
    foregroundColor: darkAccentOrange,
    backgroundColor: Colors.transparent,
    overlayColor: darkAccentOrange.withOpacity(0.12),
    padding: const EdgeInsets.symmetric(
      horizontal: spacing4,
      vertical: spacing3,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
    textStyle: labelLarge.copyWith(color: darkAccentOrange),
  );

  // Dark Theme Data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      surface: darkBackgroundPrimary,
      primary: primaryGreen,
      secondary: accentCoral,
      tertiary: accentAmber,
      error: errorRed,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    scaffoldBackgroundColor: darkBackgroundPrimary,

    // App Bar - Modern premium dark styling
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackgroundSecondary,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: headingMedium.copyWith(color: darkTextPrimary),
      iconTheme: IconThemeData(color: darkTextPrimary, size: 24),
      toolbarHeight: 56,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: darkBackgroundPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),

    // Bottom Navigation - Premium dark styling
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkBackgroundSecondary,
      selectedItemColor: darkAccentGreen,
      unselectedItemColor: darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: labelSmall.copyWith(
        fontWeight: FontWeight.w600,
        color: darkAccentGreen,
      ),
      unselectedLabelStyle: labelSmall.copyWith(color: darkTextTertiary),
    ),

    // Navigation Bar (Material 3) - Modern premium styling
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkBackgroundSecondary,
      indicatorColor: darkAccentGreen.withOpacity(0.2),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final isSelected = states.contains(WidgetState.selected);
        return (isSelected
                ? labelSmall.copyWith(fontWeight: FontWeight.w600)
                : labelSmall)
            .copyWith(color: isSelected ? darkAccentGreen : darkTextTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected ? darkAccentGreen : darkTextTertiary,
          size: 24,
        );
      }),
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(style: darkPrimaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: darkSecondaryButtonStyle,
    ),
    textButtonTheme: TextButtonThemeData(style: darkTertiaryButtonStyle),

    // Floating Action Button - Modern premium styling
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: darkAccentGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 6,
      hoverElevation: 6,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    ),

    // Cards - Modern flat design with subtle borders
    cardTheme: CardThemeData(
      elevation: 0,
      color: darkBackgroundTertiary,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: BorderSide(color: darkBorderLight, width: 1),
      ),
      margin: const EdgeInsets.all(spacing2),
    ),

    // Input Decoration - Modern, clean styling
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: darkBorderMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: darkBorderMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: darkAccentGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: errorRed, width: 2),
      ),
      filled: true,
      fillColor: darkBackgroundQuaternary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacing4,
        vertical: spacing4,
      ),
      labelStyle: bodyMedium.copyWith(color: darkTextSecondary),
      hintStyle: bodyMedium.copyWith(color: darkTextTertiary),
      prefixIconColor: darkTextTertiary,
      suffixIconColor: darkTextTertiary,
    ),

    // Icon Theme - Modern, clear contrast
    iconTheme: IconThemeData(color: darkTextSecondary, size: 24),
    primaryIconTheme: IconThemeData(color: darkAccentGreen, size: 24),

    // Chip Theme - Modern flat styling
    chipTheme: ChipThemeData(
      backgroundColor: darkBackgroundQuaternary,
      selectedColor: darkAccentGreen.withOpacity(0.2),
      disabledColor: darkBorderMedium,
      labelStyle: bodySmall.copyWith(color: darkTextPrimary),
      secondaryLabelStyle: bodySmall.copyWith(color: darkAccentGreen),
      brightness: Brightness.dark,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: spacing3,
        vertical: spacing2,
      ),
      side: BorderSide(color: darkBorderMedium, width: 1),
    ),

    // Drawer
    drawerTheme: DrawerThemeData(
      backgroundColor: darkBackgroundSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(radiusLarge),
          bottomRight: Radius.circular(radiusLarge),
        ),
      ),
    ),

    // Dialog Theme - Modern premium styling
    dialogTheme: DialogThemeData(
      backgroundColor: darkBackgroundTertiary,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: BorderSide(color: darkBorderMedium, width: 1),
      ),
      titleTextStyle: headingMedium.copyWith(color: darkTextPrimary),
      contentTextStyle: bodyMedium.copyWith(color: darkTextSecondary),
    ),

    // Bottom Sheet Theme - Clean modern design
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkBackgroundTertiary,
      elevation: 8,
      modalElevation: 12,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(radiusLarge),
          topRight: Radius.circular(radiusLarge),
        ),
        side: BorderSide(color: darkBorderMedium, width: 1),
      ),
    ),

    // Snackbar Theme - Modern styling
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkBackgroundQuaternary,
      contentTextStyle: bodyMedium.copyWith(color: darkTextPrimary),
      actionTextColor: darkAccentGreen,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // Divider Theme
    dividerTheme: DividerThemeData(
      color: darkBorderLight,
      thickness: 0.5,
      space: 1,
    ),

    // Progress Indicator Theme - Enhanced for dark mode
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: darkAccentGreen,
      linearTrackColor: darkBorderLight,
      circularTrackColor: darkBorderLight,
    ),
  );
}

/// Extension to add semantic color methods to BuildContext
extension AppThemeExtension on BuildContext {
  // Quick access to common theme properties
  Color get primaryColor =>
      isDarkMode ? AppTheme.primaryGreen : AppTheme.primaryBlue;
  Color get backgroundColor =>
      isDarkMode ? AppTheme.darkBackgroundPrimary : AppTheme.backgroundPrimary;
  Color get textColor =>
      isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get secondaryTextColor =>
      isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

  // Dark mode detection
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Semantic colors that adapt to theme
  Color get successColor => AppTheme.successGreen;
  Color get warningColor => AppTheme.warningAmber;
  Color get errorColor => AppTheme.errorRed;
  Color get infoColor => AppTheme.infoBlue;

  // Surface colors that adapt to theme
  Color get surfacePrimary =>
      isDarkMode ? AppTheme.darkBackgroundPrimary : AppTheme.backgroundPrimary;
  Color get surfaceSecondary => isDarkMode
      ? AppTheme.darkBackgroundSecondary
      : AppTheme.backgroundSecondary;
  Color get surfaceTertiary => isDarkMode
      ? AppTheme.darkBackgroundTertiary
      : AppTheme.backgroundTertiary;
  Color get surfaceQuaternary => isDarkMode
      ? AppTheme.darkBackgroundQuaternary
      : AppTheme.backgroundTertiary;

  // Border colors that adapt to theme
  Color get borderLight =>
      isDarkMode ? AppTheme.darkBorderLight : AppTheme.borderLight;
  Color get borderMedium =>
      isDarkMode ? AppTheme.darkBorderMedium : AppTheme.borderMedium;
  Color get borderDark =>
      isDarkMode ? AppTheme.darkBorderDark : AppTheme.borderDark;

  // Accent colors for highlights that adapt to theme
  Color get accentPrimary =>
      isDarkMode ? AppTheme.darkAccentGreen : AppTheme.primaryGreen;
  Color get accentSecondary =>
      isDarkMode ? AppTheme.darkAccentOrange : AppTheme.accentCoral;
  Color get accentTertiary =>
      isDarkMode ? AppTheme.darkAccentPurple : AppTheme.accentAmber;
  Color get accentInfo =>
      isDarkMode ? AppTheme.darkAccentBlue : AppTheme.infoBlue;
}
