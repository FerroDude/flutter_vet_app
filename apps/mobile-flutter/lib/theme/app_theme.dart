import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Navy/Slate professional palette
  static const Color neutral50 = Color(0xFFFFFFFF);  // Pure white - backgrounds
  static const Color neutral100 = Color(0xFFF8F9FA); // Off-white - secondary surfaces
  static const Color neutral200 = Color(0xFFCCC9DC); // Light lavender gray - borders, subtle accents
  static const Color neutral300 = Color(0xFFA8A5B8); // Medium light gray - secondary borders
  static const Color neutral400 = Color(0xFF324A5F); // Medium slate blue - accents
  static const Color neutral500 = Color(0xFF1B2A41); // Dark navy blue - primary accents
  static const Color neutral600 = Color(0xFF152233); // Darker navy - hover states
  static const Color neutral700 = Color(0xFF0C1821); // Very dark navy - strong accents
  static const Color neutral800 = Color(0xFF08111A); // Almost black navy
  static const Color neutral900 = Color(0xFF000000); // Pure black - primary text

  // Color assignments for better contrast
  static const Color primary = neutral500;        // Dark navy blue for primary actions
  static const Color primaryDark = neutral600;    // Darker navy for hover states
  
  static const Color success = neutral500;        // Dark navy (unified)
  static const Color warning = neutral500;        // Dark navy (unified)
  static const Color error = neutral900;          // Black for errors
  
  static const Color textPrimary = neutral900;    // Pure black for main text
  static const Color textSecondary = neutral700;  // Very dark navy for secondary text
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFFC7C7CC);
  static const Color borderLight = neutral200;
  static const Color darkBackgroundPrimary = Color(0xFF000000);
  
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
      primary: primary,              // Dark navy
      secondary: neutral400,         // Medium slate blue
      surface: neutral50,            // Pure white
      error: neutral900,             // Black
    ),
    scaffoldBackgroundColor: neutral50,  // Pure white background
    
    appBarTheme: AppBarTheme(
      backgroundColor: neutral50,        // Pure white - no transparency
      foregroundColor: neutral900,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: neutral900,                // Black
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: neutral900, size: 22.sp),  // Black icons
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: neutral50,       // Pure white
      selectedItemColor: neutral500,    // Dark navy when selected
      unselectedItemColor: neutral400,  // Medium slate when not selected
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w400, letterSpacing: -0.2),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: neutral50,                                 // Very light mint/white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius3),
        side: BorderSide(color: neutral200, width: 1),  // Very light mint border
      ),
      margin: EdgeInsets.all(spacing2),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: neutral500,      // Dark navy
        foregroundColor: neutral50,       // White text
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius2)),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: neutral500,      // Dark navy text
        side: BorderSide(color: neutral500, width: 1.5),  // Dark navy border
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius2)),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neutral500,      // Dark navy
        padding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing2),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutral50,             // White
      contentPadding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral200, width: 1),  // Light lavender border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral200, width: 1),  // Light lavender border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral500, width: 2),  // Dark navy focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral900, width: 2),  // Black for errors
      ),
      labelStyle: GoogleFonts.inter(fontSize: 14.sp, color: neutral900),  // Black labels
      hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: neutral400),   // Medium slate hints
    ),

    iconTheme: IconThemeData(color: neutral900, size: 22.sp),  // Black for icons
    dividerTheme: DividerThemeData(color: neutral200, thickness: 1, space: 1),  // Light lavender dividers
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.dark(
      primary: neutral400,
      secondary: neutral500,
      surface: Color(0xFF1C1C1E),
      error: neutral600,
    ),
    scaffoldBackgroundColor: Color(0xFF000000),
    
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF1C1C1E).withOpacity(0.85),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: neutral400, size: 22.sp),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1C1C1E).withOpacity(0.85),
      selectedItemColor: Colors.white,
      unselectedItemColor: neutral500,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w400, letterSpacing: -0.2),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius3),
        side: BorderSide(color: Color(0xFF2F2F2F), width: 1),
      ),
      margin: EdgeInsets.all(spacing2),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: neutral900,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius2)),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: neutral600, width: 1),
        padding: EdgeInsets.symmetric(horizontal: spacing4, vertical: spacing3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius2)),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w500, letterSpacing: -0.3),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: neutral300,
        padding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing2),
        textStyle: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w500, letterSpacing: -0.3),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1C1C1E),
      contentPadding: EdgeInsets.symmetric(horizontal: spacing3, vertical: spacing3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: Color(0xFF2F2F2F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: Color(0xFF2F2F2F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius2),
        borderSide: BorderSide(color: neutral600),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 14.sp, color: Color(0xFFC7C7CC)),
      hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: Color(0xFF6C757D)),
    ),

    iconTheme: IconThemeData(color: Color(0xFFC7C7CC), size: 22.sp),
    dividerTheme: DividerThemeData(color: Color(0xFF2F2F2F).withOpacity(0.5), thickness: 0.5, space: 1),
  );
}

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  Color get surface => isDark ? Color(0xFF1C1C1E) : AppTheme.neutral50;        // White
  Color get background => isDark ? Color(0xFF000000) : AppTheme.neutral50;     // White
  Color get textPrimary => isDark ? Colors.white : AppTheme.neutral900;        // Black for main text
  Color get textSecondary => isDark ? AppTheme.darkTextSecondary : AppTheme.neutral700;  // Very dark navy for secondary
  Color get border => isDark ? Color(0xFF2F2F2F) : AppTheme.neutral200;        // Light lavender borders
  
  Color get textColor => isDark ? AppTheme.darkTextPrimary : AppTheme.neutral900;        // Black
  Color get secondaryTextColor => isDark ? AppTheme.darkTextSecondary : AppTheme.neutral400;  // Medium slate
  Color get surfacePrimary => isDark ? Color(0xFF1C1C1E) : AppTheme.neutral50;  // White
  Color get surfaceSecondary => isDark ? Color(0xFF2C2C2E) : AppTheme.neutral100;  // Off-white
  Color get borderLight => isDark ? Color(0xFF2F2F2F) : AppTheme.neutral200;    // Light lavender
  Color get borderMedium => isDark ? Color(0xFF404040) : AppTheme.neutral300;   // Medium light gray
  Color get primaryColor => isDark ? AppTheme.neutral400 : AppTheme.neutral500;  // Dark navy
  Color get accentPrimary => isDark ? AppTheme.neutral400 : AppTheme.primary;    // Dark navy
}

