import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Color scheme
// ---------------------------------------------------------------------------

// Backgrounds
const Color kBackground = Color(0xFFF0F4FF); // Blue-tinted off-white
const Color kSurface = Color(0xFFFFFFFF); // Card background

// Primary
const Color kPrimary = Color(0xFF3B82F6); // Blue
const Color kPrimaryLight = Color(0xFFEFF6FF); // Tinted blue (hover backgrounds, etc.)
const Color kPrimaryDark = Color(0xFF1D4ED8); // Button pressed state

// Accent Colors
const Color kSuccess = Color(0xFF22C55E); // Green (correct answer)
const Color kError = Color(0xFFEF4444); // Red (wrong answer)
const Color kWarning = Color(0xFFF59E0B); // Yellow (unfamiliar word marker)
const Color kWarningLight = Color(0xFFFFFBEB); // Warm yellow tint (tapped token)

// Text
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);
const Color kTextHint = Color(0xFFCBD5E1);

// Border / Divider
const Color kBorder = Color(0xFFE2E8F0);

// Memory-state dot gradient — 6 steps from low (red) to high (green).
// Indexed by MemoryState.index: redLow, redMedium, redHigh, yellowLow,
// yellowHigh, green.
const List<Color> kMemoryStateGradient = [
  Color(0xFFEF4444), // redLow     — kError
  Color(0xFFF97316), // redMedium  — orange
  Color(0xFFF59E0B), // redHigh    — kWarning
  Color(0xFFEAB308), // yellowLow  — amber
  Color(0xFF84CC16), // yellowHigh — lime
  Color(0xFF22C55E), // green      — kSuccess
];

// ---------------------------------------------------------------------------
// Global theme
// ---------------------------------------------------------------------------

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      surface: kSurface,
    ),
    scaffoldBackgroundColor: kBackground,
    textTheme: GoogleFonts.notoSansTextTheme(),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: kSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
    ),
  );
}
