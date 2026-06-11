import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Blaziq — light theme.
/// All colors, text styles, and ThemeData live here.
/// Screens must import this file — never hardcode colors or text styles.
class AppTheme {
  AppTheme._();

  // ── New light-theme color palette ────────────────────────────────────────

  /// App background (all screens)
  static const Color cloudWhite = Color(0xFFF8F9FF);

  /// Card / surface background
  static const Color softGrey = Color(0xFFEEF0F8);

  /// Borders / dividers
  static const Color deepGrey = Color(0xFFE2E4F0);

  /// Primary accent — electric blue
  static const Color electricBlue = Color(0xFF2563EB);

  /// Blue tint / selected-item background
  static const Color skyBlue = Color(0xFFDBEAFE);

  /// Secondary accent — streaks, wrong answers, urgent states
  static const Color blazeOrange = Color(0xFFF97316);

  /// Orange tint background
  static const Color softOrange = Color(0xFFFFEDD5);

  /// Primary text
  static const Color ink = Color(0xFF1E1B4B);

  /// Muted / secondary text
  static const Color steel = Color(0xFF6B7280);

  // ── Background gradient ───────────────────────────────────────────────────

  static const Color gradientLeft = Color(0xFFCFEDDB);
  static const Color gradientRight = Color(0xFFDEEACD);
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFCFEDDB), Color(0xFFDEEACD)],
  );

  // ── Backward-compatible aliases (used throughout existing screens) ────────

  /// = cloudWhite
  static const Color arenaBlack = cloudWhite;

  /// = softGrey
  static const Color cardSurface = softGrey;

  /// = ink (deep navy; used as nav bar bg and text-on-bright-bg)
  static const Color voidBlack = ink;

  /// = electricBlue (primary CTA, XP, highlights)
  static const Color blazeGold = electricBlue;

  /// = blazeOrange (wrong answers, urgent)
  static const Color sparkPink = blazeOrange;

  /// = ink (primary text)
  static const Color whiteText = ink;

  /// = steel (muted text)
  static const Color mutedText = steel;

  /// = deepGrey (borders / separators)
  static const Color divider = deepGrey;

  /// = cloudWhite (header bar background)
  static const Color headerBar = cloudWhite;

  // ── Semantic aliases ──────────────────────────────────────────────────────

  static const Color powerUpBlue = electricBlue;
  static const Color bestOfferRed = blazeOrange;

  // Difficulty colours — solo game
  static const Color difficultyEasy = electricBlue;
  static const Color difficultyMedium = Color(0xFF7C3AED); // violet
  static const Color difficultyHard = blazeOrange;

  // Mode card gradient (light cards)
  static const Color modeCardStart = Color(0xFFFFFFFF);
  static const Color modeCardEnd = Color(0xFFF0F4FF);

  // Google Sign-In brand colours (unchanged)
  static const Color googleButtonText = Color(0xFF3C4043);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  // Leaderboard rank medal colours
  static const Color rankSilver = Color(0xFF90A4AE);
  static const Color rankBronze = Color(0xFFB87333);

  /// Avatar colours for leaderboard entries
  static const List<Color> leaderboardAvatars = [
    Color(0xFF5B6FA8),
    Color(0xFFC49A3A),
    Color(0xFF9B6B4A),
    Color(0xFF4A6A8A),
    Color(0xFF6A4A8A),
    Color(0xFF4A8A6A),
    Color(0xFF8A6A4A),
    Color(0xFF8A4A6A),
    Color(0xFF4A7A8A),
    Color(0xFF7A8A4A),
  ];

  // ── Text Styles (Fira Sans throughout) ───────────────────────────────────

  /// Screen titles — LEADERBOARD, SETTINGS
  static TextStyle get screenTitle => GoogleFonts.firaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 3.0,
  );

  /// Store screen title
  static TextStyle get storeTitle => GoogleFonts.firaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 3.0,
  );

  /// App bar / game mode title
  static TextStyle get appBarTitle => GoogleFonts.firaSans(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 2.0,
  );

  /// Section heading — SAVE YOUR PROGRESS
  static TextStyle get subheading => GoogleFonts.firaSans(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 1.5,
  );

  /// "SELECT A MODE" label
  static TextStyle get selectModeLabel => GoogleFonts.firaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: steel,
    letterSpacing: 2.5,
  );

  /// Mode card title — SOLO
  static TextStyle get modeTitle => GoogleFonts.firaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 3.0,
  );

  /// CTA button label — always on a coloured background → white text
  static TextStyle get buttonLabel => GoogleFonts.firaSans(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 1.5,
  );

  /// Settings section header — AUDIO & HAPTICS
  static TextStyle get sectionHeader => GoogleFonts.firaSans(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: steel,
    letterSpacing: 1.5,
  );

  /// Settings row label
  static TextStyle get rowLabel => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: ink,
  );

  /// Body / muted description text
  static TextStyle get bodyMuted => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: steel,
    height: 1.5,
  );

  /// Header bar stat chip values
  static TextStyle get statValue => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Small caption — XP counter, sub-labels
  static TextStyle get caption => GoogleFonts.firaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: steel,
  );

  /// Bottom nav labels
  static TextStyle get navLabel => GoogleFonts.firaSans(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// Leaderboard filter tab
  static TextStyle get filterTab => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  /// Rank badge inside podium cards
  static TextStyle get rankBadge => GoogleFonts.firaSans(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  /// Podium player name
  static TextStyle get podiumName => GoogleFonts.firaSans(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Podium score
  static TextStyle get podiumScore => GoogleFonts.firaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: electricBlue,
  );

  /// Rank number in list rows
  static TextStyle get rankNumber => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: steel,
  );

  /// Player name in list rows
  static TextStyle get playerName => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: ink,
  );

  /// Score value in list rows
  static TextStyle get score => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: electricBlue,
  );

  /// Store bundle / item name
  static TextStyle get bundleName => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 1.5,
  );

  /// Store price button text
  static TextStyle get priceText => GoogleFonts.firaSans(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: ink,
  );

  /// Store item quantity label
  static TextStyle get itemLabel => GoogleFonts.firaSans(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Coin balance in header
  static TextStyle get coinBalance => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: ink,
  );

  /// Ribbon label (Coming Soon strip)
  static TextStyle get ribbonLabel => GoogleFonts.firaSans(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 1.0,
  );

  /// Reward / highlight note
  static TextStyle get rewardText => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: electricBlue,
    letterSpacing: 0.3,
  );

  /// Footer link
  static TextStyle get footerLink => GoogleFonts.firaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: steel,
    decoration: TextDecoration.underline,
    decorationColor: steel,
  );

  /// Snack bar message
  static TextStyle get snackText => GoogleFonts.firaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ink,
  );

  /// Solo game — streak counter pill text
  static TextStyle get streakText => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: blazeOrange,
  );

  /// Solo game — difficulty badge
  static TextStyle get difficultyBadge => GoogleFonts.firaSans(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: ink,
  );

  /// Solo game — question card text
  static TextStyle get questionText => GoogleFonts.firaSans(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: ink,
    height: 1.5,
  );

  /// Solo game — circular countdown number
  static TextStyle get timerText => GoogleFonts.firaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ink,
  );

  /// Solo game — answer button text
  static TextStyle get answerText => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );

  /// Sign-in button label
  static TextStyle signInLabel(Color color) => GoogleFonts.firaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 0.2,
  );

  // ── ThemeData ────────────────────────────────────────────────────────────

  static ThemeData get theme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: cloudWhite,
      colorScheme: const ColorScheme.light(
        primary: electricBlue,
        secondary: blazeOrange,
        surface: softGrey,
      ),
      textTheme: GoogleFonts.firaSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: ink, displayColor: ink),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : Colors.grey.shade400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? electricBlue
              : Colors.grey.shade300,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: softGrey,
        contentTextStyle: GoogleFonts.firaSans(fontSize: 14, color: ink),
      ),
    );
  }
}
