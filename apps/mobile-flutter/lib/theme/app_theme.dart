import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Navy/Slate professional palette
  static const Color neutral50 = Color(0xFFFFFFFF); // Pure white - backgrounds
  static const Color neutral100 = Color(
    0xFFF8F9FA,
  ); // Off-white - secondary surfaces
  static const Color neutral200 = Color(
    0xFFCCC9DC,
  ); // Light lavender gray - borders, subtle accents
  static const Color neutral300 = Color(
    0xFFA8A5B8,
  ); // Medium light gray - secondary borders
  static const Color neutral400 = Color(
    0xFF324A5F,
  ); // Medium slate blue - accents
  static const Color neutral500 = Color(
    0xFF1B2A41,
  ); // Dark navy blue - primary accents
  static const Color neutral600 = Color(
    0xFF152233,
  ); // Darker navy - hover states
  static const Color neutral700 = Color(
    0xFF0C1821,
  ); // Very dark navy - strong accents
  static const Color neutral800 = Color(0xFF08111A); // Almost black navy
  static const Color neutral900 = Color(
    0xFF000000,
  ); // Pure black - primary text

  // Brand Colors & Dark Mode Specifics
  static const Color brandBlue = Color(0xFF1172B0);
  static const Color brandBlueLight = Color(
    0xFF64B5F6,
  ); // Lighter blue for dark mode accents
  static const Color brandTeal = Color(
    0xFF57B4A4,
  ); // Teal for medications/secondary
  static const Color brandMint = Color(0xFF85E7A9);
  static const Color brandErrorDark = Color(
    0xFFCF6679,
  ); // Readable error for dark mode

  // Gradient colors for more subtle transitions
  static const Color gradientStart = Color(0xFF1B2A41); // Dark navy
  static const Color gradientMid1 = Color(0xFF1E3147); // Slightly lighter
  static const Color gradientMid2 = Color(0xFF21374D); // More lighter
  static const Color gradientEnd = Color(0xFF243D53); // Lightest navy

  // Color assignments for better contrast
  static const Color primary = neutral500; // Dark navy blue for primary actions
  static const Color primaryDark = neutral600; // Darker navy for hover states

  static const Color success = Color(0xFF10B981); // Green for success
  static const Color warning = Color(0xFFF59E0B); // Orange for warnings
  static const Color error = Color(0xFFEF4444); // Red for errors

  static const Color textPrimary = neutral900; // Pure black for main text
  static const Color textSecondary =
      neutral700; // Very dark navy for secondary text
  static const Color darkBackgroundPrimary = Color(
    0xFF0B1120,
  ); // Deep Blue Background
  static const Color darkBackgroundSecondary = Color(
    0xFF151E2C,
  ); // Slightly lighter blue for cards
  static const Color darkTextPrimary = Color(
    0xFFE2E8F0,
  ); // High contrast off-white
  static const Color darkTextSecondary = Color(
    0xFF94A3B8,
  ); // Slate grey for secondary text

  static double spacing1 = 4.0.w;
  static double spacing2 = 8.0.w;
  static double spacing3 = 12.0.w;
  static double spacing4 = 16.0.w;
  static double spacing5 = 20.0.w;
  static double spacing6 = 24.0.w;
  static double spacing8 = 32.0.w;
  static double spacing12 = 48.0.w;

  static double radius1 = 4.0.r;
  static double radius2 = 8.0.r;
  static double radius3 = 12.0.r;
  static double radius4 = 16.0.r;

  static double radiusSmall = 8.0.r;
  static double radiusMedium = 12.0.r;
  static double radiusLarge = 16.0.r;

  // Gradient for background with multiple color stops for subtle transitions
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      gradientStart,
      gradientMid1,
      gradientMid2,
      gradientEnd,
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );

  // Enhanced box shadows for white cards
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  // Elevated shadow for interactive cards
  static List<BoxShadow> get cardShadowElevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 32,
      offset: const Offset(0, 12),
      spreadRadius: -6,
    ),
  ];

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.light(
      primary: primary, // Dark navy
      secondary: neutral400, // Medium slate blue
      surface: neutral50, // Pure white
      error: neutral900, // Black
    ),
    scaffoldBackgroundColor: Colors.transparent, // Transparent - gradient applied per-page

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent, // Transparent - gradient extends to top
      foregroundColor: Colors.white, // White text/icons on gradient
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white, // White text
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 22.sp), // White icons
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: primary, // Dark navy background
      selectedItemColor: Colors.white, // White when selected
      unselectedItemColor: Colors.white.withValues(alpha: 0.6), // White with 60% opacity
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 6,
      color: neutral50, // Pure white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius4), // 16px radius
        side: BorderSide.none, // No border for cleaner look
      ),
      margin: EdgeInsets.all(spacing2),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: neutral500, // Dark navy
        foregroundColor: neutral50, // White text
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: neutral500, // Dark navy text
        side: BorderSide(color: neutral500, width: 1.5), // Dark navy border
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neutral500, // Dark navy
        padding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing2),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutral50, // White
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing3,
        vertical: spacing3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(
          color: neutral200,
          width: 1,
        ), // Light lavender border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(
          color: neutral200,
          width: 1,
        ), // Light lavender border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral500, width: 2), // Dark navy focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral900, width: 2), // Black for errors
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14.sp,
        color: neutral900,
      ), // Black labels
      hintStyle: GoogleFonts.inter(
        fontSize: 14.sp,
        color: neutral400,
      ), // Medium slate hints
    ),

    iconTheme: IconThemeData(color: neutral900, size: 22.sp), // Black for icons
    dividerTheme: DividerThemeData(
      color: neutral200,
      thickness: 1,
      space: 1,
    ), // Light lavender dividers
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.dark(
      primary: brandBlueLight,
      secondary: brandBlue,
      surface: darkBackgroundSecondary,
      error: brandErrorDark,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: darkTextPrimary,
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: darkBackgroundPrimary,

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackgroundSecondary.withValues(alpha: 0.9),
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: brandBlueLight, size: 22.sp),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkBackgroundSecondary.withValues(alpha: 0.9),
      selectedItemColor: brandBlueLight,
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 10.sp,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: darkBackgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius3),
        side: BorderSide(
          color: Color(0xFF1E293B),
          width: 1,
        ), // Slate-800 border
      ),
      margin: EdgeInsets.all(spacing2),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandBlueLight,
        foregroundColor: neutral900, // Black text on bright button
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandBlueLight,
        side: BorderSide(color: brandBlueLight, width: 1),
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandBlueLight,
        padding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing2),
        textStyle: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBackgroundSecondary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing3,
        vertical: spacing3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: brandBlueLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: brandErrorDark),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 14.sp, color: darkTextSecondary),
      hintStyle: GoogleFonts.inter(
        fontSize: 14.sp,
        color: Color(0xFF64748B),
      ), // Slate-500
    ),

    iconTheme: IconThemeData(color: darkTextSecondary, size: 22.sp),
    dividerTheme: DividerThemeData(
      color: Color(0xFF1E293B),
      thickness: 1,
      space: 1,
    ),
  );
}

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get surface =>
      isDark ? AppTheme.darkBackgroundSecondary : AppTheme.neutral50; // White
  Color get background =>
      isDark ? AppTheme.darkBackgroundPrimary : AppTheme.neutral50; // White
  Color get textPrimary => isDark
      ? AppTheme.darkTextPrimary
      : AppTheme.neutral900; // Black for main text
  Color get textSecondary => isDark
      ? AppTheme.darkTextSecondary
      : AppTheme.neutral700; // Very dark navy for secondary
  Color get border => isDark
      ? Color(0xFF1E293B)
      : AppTheme.neutral200; // Light lavender borders

  Color get textColor =>
      isDark ? AppTheme.darkTextPrimary : AppTheme.neutral900; // Black
  Color get secondaryTextColor =>
      isDark ? AppTheme.darkTextSecondary : AppTheme.neutral400; // Medium slate
  Color get surfacePrimary =>
      isDark ? AppTheme.darkBackgroundSecondary : AppTheme.neutral50; // White
  Color get surfaceSecondary => isDark
      ? Color(0xFF1E293B)
      : AppTheme.neutral100; // Slightly lighter than background
  Color get borderLight =>
      isDark ? Color(0xFF1E293B) : AppTheme.neutral200; // Light lavender
  Color get borderMedium =>
      isDark ? Color(0xFF334155) : AppTheme.neutral300; // Medium light gray
  Color get primaryColor =>
      isDark ? AppTheme.brandBlueLight : AppTheme.neutral500; // Dark navy
  Color get accentPrimary =>
      isDark ? AppTheme.brandBlueLight : AppTheme.primary; // Dark navy
}
