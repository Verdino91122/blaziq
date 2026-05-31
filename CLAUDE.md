# Blaziq — Project Brief

## What this app is
A cross-platform trivia game built with Flutter and Firebase.
App name: Blaziq
Package name: com.blaziq.blaziq
Target platforms: iOS and Android (primary), Web (secondary)

## Tech stack
- Flutter (Dart)
- Firebase Auth (Anonymous on first launch + Google Sign-In for account linking)
- Firebase Firestore (database + leaderboard + user profiles)
- Open Trivia DB API (https://opentdb.com/api.php) for questions
- http package for API calls (handles both mobile and web)
- flutter_svg ^2.0.0 for SVG nav icons
- google_fonts ^8.0.0 for New Amsterdam font
- flutter_native_splash ^2.4.1 for native splash screen (runtime dep)
- flutter_launcher_icons ^0.14.1 for app icon generation (dev dep)
- State management: Provider or simple StatefulWidget — nothing heavier

## Design System
- Background color: #1A1A2E (Arena Dark)
- Card/surface color: #242440 (Card Surface)
- Deep background: #0D0D1A (Void Black)
- Gold accent: #F0B429 (Blaze Gold) — correct answers, XP, highlights, primary CTA
- Pink accent: #E91E8C (Spark Pink) — wrong answers, toggles, live/active states
- White text: #F5F5F5
- Muted text: #888888
- Corner radius: 12–16px rounded cards
- Headings: bold, uppercase, wide letter spacing
- Font: Google Font "New Amsterdam" for all text (google_fonts ^8.0.0)
- Bottom nav bar: dark background, gold sliding circle indicator for selected tab

## Brand Identity
- App name: Blaziq
- Logo mark: lightning bolt with IQ dot accent
- Tagline: TRIVIA · BATTLE · WIN
- Tone: competitive sport, not classroom — fast, intense, premium dark theme

## Design References
All screen mockups are in the /designs folder:
- designs/home_screen.png — Home screen with carousel and header stats
- designs/profile_screen.png — Profile / sign-in screen
- designs/rank_screen.png — Leaderboard screen
- designs/store_screen.png — Store/shop screen
- designs/menu_screen.png — Settings/menu screen

Always refer to these images when building or modifying each screen.

## App Structure
5 bottom navigation tabs (left to right):
1. Profile
2. Rank
3. Home (default, center tab, slightly larger icon when selected)
4. Shop
5. Settings

Bottom nav bar: 77px height, SVG icons, sliding gold circle behind selected tab.
Selected tab: icon only (no label). Unselected: icon + label below.

## Screen Details

### Home Screen (designs/home_screen.png)
- Header bar: user avatar (circle, top left), coins count with star icon,
  XP progress bar with level number and title — all live from Firestore
- Center: Blaziq logo (assets/images/inapp_logo.png, 80×80) + "SELECT A MODE" text
- Invisible GestureDetector same size as logo, to the right of it —
  toggles developer cheat mode in solo game screen
- Swipeable horizontal carousel with 3 mode cards:
  1. Solo — play alone vs the clock (fully functional)
  2. Play with Friend — diagonal "COMING SOON" ribbon, non-tappable
  3. Play Online — diagonal "COMING SOON" ribbon, non-tappable
- Each card has icon, title, short description, centered content

### Solo Mode Game Screen (not in nav bar)
- Endless time-based mode — no fixed question limit
- Timer starts at 30 seconds, displayed as circular countdown
- Pre-game countdown overlay: 3, 2, 1, GO! before game starts
  - Shows a muted 'CANCEL' button below the number (hidden on GO!)
  - Tapping CANCEL returns to home screen immediately
  - Android back button is blocked during countdown (PopScope canPop: false)
- Quit button: X icon (top left) — tapping shows a confirmation dialog;
  timer keeps running while dialog is open (do NOT pause it);
  dialog: 'Quit Game?' / 'Your progress will be lost' /
  gold 'Keep Playing' button (dismisses) + muted 'Quit' button (navigates back)
- Android back button during game: triggers the same quit confirmation dialog
- Correct answer time bonus (streak resets to 0 on wrong answer):
  - Streak 1–2: +4s
  - Streak 3: +6s
  - Streak 4: +8s
  - Streak 5+: +10s
- Wrong answer: -3s, streak resets to 0 (next correct is back to +4s)
- Difficulty escalation: Easy → Medium (5 correct) → Hard (10 correct)
- Floating feedback animation: '+4s', '+6s', '+8s', '+10s', or '-3s' flies up to timer on answer
- Timer bump animation when floating text arrives at timer
- Streak indicator floats above layout using Stack/Positioned
- Developer cheat mode: toggled by invisible button right of logo
- Scoring formula at game end (see Scoring & Rewards System section for full detail):
  - base_points = correct_answers × 100
  - streak_bonus = highest_streak × 50
  - time_bonus = remaining_seconds × 10
  - final_score = base_points + streak_bonus + time_bonus
- Results screen: headline based on performance, final score, correct count,
  highest streak, accuracy %, score/coins/XP earned with count-up animations,
  XP progress bar, LEVEL UP! badge if threshold crossed
- API rate limit: auto-retry once after 5s on HTTP 429 (OpenTDB rate limit)
- Use kIsWeb with corsproxy.io prefix for web builds:
  final baseUrl = 'https://opentdb.com/api.php?amount=10&type=multiple';
  final url = kIsWeb ? 'https://corsproxy.io/?$baseUrl' : baseUrl;
- Always decode HTML entities in questions and answers

### Profile Screen (designs/profile_screen.png)
- The app always has a signed-in user (anonymous or Google) — a pure signed-out
  state never appears
- If anonymous (guest):
  - Gold "SAVE YOUR PROGRESS" banner at top (lock icon + subtitle)
  - Guest avatar (person icon, muted ring)
  - Guest_XXXXXX username + "Guest account" subtitle read from Firestore
  - Stats grid: games played, best score, coins, XP level — live from Firestore
  - Google Sign-In button (styled, not plain default)
  - "Reward: +200 coins for linking!" note
- If signed in with Google:
  - Google profile photo avatar (gold ring), username, email — live from Firestore
  - Stats grid: games played, best score, coins, XP level
  - Sign out button — shows confirmation dialog before signing out; on confirm,
    signs out and immediately re-enters anonymous auth

### Rank Screen (designs/rank_screen.png)
- Title: "LEADERBOARD"
- 3 filter tabs: Worldwide | Canada | Friends
- Worldwide: all players ordered by score desc (live from Firestore leaderboard collection)
- Canada: client-side filter where country == 'CA'; shows empty state if none
- Friends: "Coming Soon" placeholder
- Top 3 as podium: 2nd left, 1st center (taller card), 3rd right
  If fewer than 3 players exist, render only those that exist (no empty slots)
  Each podium card shows: avatar (NetworkImage if avatarUrl set, else initials), name, score, rank badge
- Players 4th+ as scrollable list below
  Each row: rank number, avatar, username, score
- Current user's row highlighted: gold border + subtle gold background tint (both podium and list)
- leaderboard collection updated by saveGameResult() using effectiveBest = max(score, currentBest)
  so existing users are seeded immediately even if current game doesn't beat their personal best
- When online mode is added later, leaderboard will switch to online ratings

### Store Screen (designs/store_screen.png)
- Title: "SHOP"
- Dark navy background matching rest of app (#1A1A2E)
- Header shows current coin balance with gold star icon
- 3 bundle cards with dark card surface, gold border:
  - Mini Bundle: 600 coins + 5 jokers — $12.99
  - Medium Bundle: 1000 coins + 10 jokers + power-ups — $22.99
    (show "BEST OFFER" red ribbon badge)
  - Large Bundle: 1600 coins + 20 jokers + more power-ups — $38.99
- Price buttons: gold background, dark text
- Purchase buttons visible but non-functional (placeholder)

### Menu/Settings Screen (designs/menu_screen.png)
- Title: "SETTINGS"
- Section AUDIO & HAPTICS:
  - Sound Effects toggle (default on)
  - Background Music toggle (default on)
  - Haptics toggle (default on)
- Section NOTIFICATIONS:
  - Push Notifications toggle (default on)
  - In-App Notifications toggle (default on)
- Section ACCOUNT:
  - Edit Profile row (navigates to profile)
  - Sign Out row
- Section SUPPORT & INFORMATION:
  - How To Play
  - About
  - Rate App
  - Share App
- Toggle active color: AppTheme.blazeGold

## Leaderboard Strategy
- Phase 3-5: Leaderboard shows solo mode best scores only
- Phase 6+: Leaderboard will show online match ratings
- Two separate concepts: solo best score vs online competitive rating
- Worldwide tab: all players globally
- Canada tab: players filtered by country field in Firestore
- Friends tab: players the user follows (Phase 6+)

## Firebase Structure (Firestore)
Collection: users
  Document: {uid}
    - username: string
    - email: string
    - coins: number (default 200 on first sign-in)
    - jokers: number (default 0)
    - xp: number (default 0)
    - level: number (default 1)
    - gamesPlayed: number
    - bestScore: number (solo mode best score)
    - country: string (default 'CA' — will be locale-detected in a future phase)
    - lastPlayedDate: string (yyyy-MM-dd, for daily bonus)
    - createdAt: timestamp

Collection: leaderboard
  Document: {uid}
    - username: string
    - score: number (solo best score for now, online rating later)
    - country: string (default 'CA')
    - avatarUrl: string
    - updatedAt: timestamp

## Scoring & Rewards System

Three separate currencies are awarded at the end of every solo game.

### SCORE (leaderboard only)
```
base        = correct_answers × 100
streak      = highest_streak × 50
time        = remaining_seconds × 10
final_score = base + streak + time
```
Score is stored as `bestScore` in Firestore (updated only if higher than stored value).
It does NOT appear in the home header bar.

### XP (level progression)
```
xp_earned = (correct_answers × 10) + 5 + (highest_streak × 3)
```
The flat +5 is the per-game completion reward. XP accumulates in the `xp` field;
`level` is recalculated on every save using:
- `xpThreshold(n) = round(100 × n × 1.5)` — cumulative XP to reach level n
- Level 1 = 0 XP, Level 2 = 300 XP, Level 3 = 450 XP, etc.

Level titles: 1–4 ROOKIE · 5–9 CHALLENGER · 10–19 EXPERT · 20–49 MASTER · 50+ LEGEND

### COINS (store currency)
```
coins_earned = 10 + (correct_answers × 2) + (highest_streak ≥ 5 ? 15 : 0) + (first_game_today ? 20 : 0)
```
`first_game_today` is determined by comparing `lastPlayedDate` to today's date.

### Results Screen
Shows all three rewards with count-up animations. XP section includes an animated
progress bar showing movement within the current level, plus a "LEVEL UP!" badge if
a level threshold was crossed. Anonymous users see rewards displayed but nothing is
saved — they see a sign-in prompt instead.

### Home Header Bar
Shows only: user avatar · coins (live from Firestore) · XP progress bar with level
number and title. Power-ups and jokers are reserved for a later phase.

## Kahoot Mode (Phase 8 — planned last)
A live quiz mode where one user hosts a session and multiple players
join via a room code and answer simultaneously in real time.
Host features:
- Manually enter custom questions and answers
- Control question pacing
- See live results as players answer
Player features:
- Join via room code
- Answer on timer
- See live leaderboard after each question
This is the most complex feature — build after friend and online modes are complete.

## Web Builds (Chrome testing)
- Use kIsWeb from flutter/foundation.dart to detect web platform
- Prefix Open Trivia DB API URL with https://corsproxy.io/? on web
- All features should work on both web and mobile

## Rules for Claude Code (IMPORTANT)
- Always read CLAUDE.md and relevant design images before writing any code
- Build one feature at a time — never scaffold everything at once
- Keep code simple and readable — no over-engineering
- Use Provider or StatefulWidget for state — nothing heavier
- Always ask before adding any new pub.dev package
- Never add payment or billing code unless explicitly asked
- Always handle loading states and errors gracefully
- Always decode HTML entities from Open Trivia DB API responses
- Never hardcode user data — always check auth state first
- Always use AppTheme for colors and text styles — never hardcode
- Dispose all AnimationControllers and Timers in dispose()
- Use if statements not Visibility widgets for conditional rendering
- Streak indicator and floating feedback must use Stack/Positioned

## Flutter Code Standards
- Always use const constructors wherever possible
- Separate each screen into its own file in lib/screens/
- Separate reusable widgets into lib/widgets/
- Use lib/theme/app_theme.dart for all colors and text styles
- Never hardcode colors inline — always reference AppTheme
- Always wrap scrollable content in SingleChildScrollView
- Use MediaQuery for responsive sizing, never hardcode pixel sizes
- Always dispose controllers in dispose() method
- File naming: snake_case for all files

## Folder Structure (lib/)
lib/
├── main.dart               ← app entry + MainShell + _BottomNav (SVG, sliding circle)
├── theme/
│   └── app_theme.dart
├── screens/
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   ├── rank_screen.dart
│   ├── store_screen.dart
│   ├── menu_screen.dart
│   └── solo_game_screen.dart
└── services/
    ├── auth_service.dart
    └── user_service.dart

## Project Status

### Completed
- Flutter project created (com.blaziq.blaziq)
- CLAUDE.md written and placed in project root
- Designs folder with 5 Figma screen references added
- Brand identity defined (colors, logo concept, typography)
- Phase 1: App shell — navigation bar and all 5 screen layouts
- Phase 2: Solo game mode (Open Trivia DB API + game logic) — COMPLETE
  - ✅ Question fetching with HTML entity decoding
  - ✅ Endless time-based gameplay
  - ✅ Circular countdown timer with pulse animation
  - ✅ Pre-game countdown overlay (3, 2, 1, GO!)
  - ✅ Difficulty escalation (Easy → Medium at 5 correct → Hard at 10 correct)
  - ✅ Floating feedback animations (+4s / -3s flies upward with scale pop + fade)
  - ✅ Timer bump animation (scale + color flash when floating text arrives)
  - ✅ Streak indicator as Stack/Positioned overlay (never shifts layout)
  - ✅ Developer cheat mode (invisible tap zone on home logo, 5 cheat buttons in game)
  - ✅ Results screen with full 3-currency rewards (score, XP, coins)
- Phase 3: Firebase Auth + Google Sign-In + Anonymous Auth — COMPLETE
  - ✅ firebase_core, firebase_auth, cloud_firestore, google_sign_in packages added
  - ✅ Firebase project blaziq-1822 configured (firebase_options.dart + google-services.json)
  - ✅ Google Services Gradle plugin applied (Kotlin DSL .kts files)
  - ✅ auth_service.dart — anonymous sign-in on first launch, Google Sign-In with account linking,
       migration fallback (credential-already-in-use → merge anon data → sign in as Google user),
       sign-out re-enters anonymous auth so app always has a UID
  - ✅ user_service.dart — ensureUserDoc handles anon (Guest_XXXXXX) and Google users,
       upgradeToGoogle (updates doc + awards 200 coin linking bonus),
       mergeAnonData (migrates XP/games/best score to Google account),
       saveGameResult, level helpers
  - ✅ profile_screen.dart — anonymous users see stats + SAVE YOUR PROGRESS banner + Google sign-in;
       Google users see full signed-in profile; signed-out state never shown
  - ✅ Three-currency scoring system: score, XP (with level-up), coins (with daily bonus)
  - ✅ Home header bar: avatar + coins + XP bar, live from Firestore
  - ✅ Results screen saves rewards to Firestore after every game (anon and Google)
  - ✅ Font: New Amsterdam (google_fonts ^8.0.0)
  - ✅ Nav labels: Shop, Settings
  - ✅ X quit button + confirmation dialog (timer runs during dialog)
  - ✅ Sign-out confirmation dialog on profile screen
  - ✅ Bottom nav bar: SVG icons, 77px, sliding gold circle, selected = icon only
- Phase 4: Solo Leaderboard — COMPLETE
  - ✅ leaderboard Firestore collection — written by saveGameResult() after every game
  - ✅ effectiveBest = max(score, currentBest) seeds existing users immediately
  - ✅ updateLeaderboard() guards against unnecessary writes (only writes on new best)
  - ✅ leaderboardStream() — live ordered query powering Rank screen
  - ✅ Rank screen: StreamBuilder, podium (top 3) + scrollable list (4th+)
  - ✅ Worldwide tab: all players; Canada tab: country == 'CA'; Friends: coming soon
  - ✅ country defaults to 'CA' for all new docs; existing users seeded with 'CA' on next game
  - ✅ Current user highlighted: gold border + tint in both podium and list rows
  - ✅ Avatar: NetworkImage when avatarUrl set, initials fallback with deterministic color
  - ✅ Loading spinner, empty state, coming-soon state all handled
  - ✅ Pre-game countdown: CANCEL button + Android back button blocked (PopScope)
  - ✅ Android back button during game: triggers quit confirmation dialog
  - ✅ OpenTDB HTTP 429 auto-retry after 5s (handles rapid game restarts)
- App icon + splash screen — COMPLETE
  - ✅ flutter_launcher_icons: adaptive icon (foreground + #1A1A2E background), Android + iOS
  - ✅ flutter_native_splash: full-screen #1A1A2E with gold bolt logo, Android 12 splash API supported
  - ✅ Splash preserved until Firebase + anonymous auth are ready, then removed
  - ✅ Home screen logo replaced with assets/images/inapp_logo.png (Image.asset, 80×80)

### Next
- Phase 5: Polish + Google Play Store submission

### Pending
- Phase 6: Friend mode (room codes + real-time Firestore)
- Phase 7: Online matchmaking (random opponent + online leaderboard)
- Phase 8: Kahoot mode (host + join + manual questions)
- Phase 9: Store + in-app purchases
- Phase 10: Final polish, sounds, haptics, App Store (iOS) submission
