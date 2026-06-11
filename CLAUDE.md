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
- google_fonts ^8.0.0 for Fira Sans (w400–w800; all screens)
- auto_size_text ^3.0.0 for question card and answer buttons in solo game
- flutter_native_splash ^2.4.1 for native splash screen (runtime dep)
- flutter_launcher_icons ^0.14.1 for app icon generation (dev dep)
- audioplayers ^6.0.0 for sound effects and background music
- shared_preferences ^2.3.0 for persisting settings (sounds, music, haptics)
- State management: Provider or simple StatefulWidget — nothing heavier

## Design System

### Color Palette (light theme — implemented in AppTheme)
| Token            | Hex       | Usage                                          |
|------------------|-----------|------------------------------------------------|
| cloudWhite       | #F8F9FF   | App background (all screens)                   |
| softGrey         | #EEF0F8   | Card/surface background, pills, toggles        |
| deepGrey         | #E2E4F0   | Borders, dividers, track backgrounds           |
| electricBlue     | #2563EB   | Primary accent — CTA, XP, highlights, correct  |
| skyBlue          | #DBEAFE   | Blue tint background (correct answer state)    |
| blazeOrange      | #F97316   | Streak indicator, wrong answers, urgent timer  |
| softOrange       | #FFEDD5   | Orange tint background (streak pill bg)        |
| ink              | #1E1B4B   | Primary text                                   |
| steel            | #6B7280   | Muted/secondary text, icons                    |

Backward-compatible AppTheme aliases (screens may use these):
- `arenaBlack` = cloudWhite · `cardSurface` = softGrey · `voidBlack` = ink
- `blazeGold` = electricBlue · `sparkPink` = blazeOrange · `whiteText` = ink
- `mutedText` = steel · `divider` = deepGrey · `headerBar` = cloudWhite

Difficulty colors: easy = electricBlue · medium = #7C3AED (violet) · hard = blazeOrange
Mode card gradient: white → #F0F4FF (light blue tint)
Google brand colors and leaderboard avatar palette are unchanged.

### Typography (Fira Sans — all screens)
| Style token      | Size | Weight | Usage                                         |
|------------------|------|--------|-----------------------------------------------|
| screenTitle      | 28sp | w800   | Screen titles — LEADERBOARD, SETTINGS         |
| storeTitle       | 28sp | w800   | Store / results headlines                     |
| appBarTitle      | 20sp | w800   | App bar / game mode title                     |
| subheading       | 24sp | w800   | Profile username, section headings            |
| modeTitle        | 28sp | w800   | Mode card title — SOLO                        |
| buttonLabel      | 16sp | w800   | CTA buttons (white text on colored bg)        |
| sectionHeader    | 12sp | w700   | Settings section labels, result row labels    |
| rowLabel         | 15sp | w500   | Settings row text                             |
| bodyMuted        | 14sp | w400   | Descriptions, sub-labels                      |
| statValue        | 14sp | w700   | Header bar coins, score pills                 |
| caption          | 11sp | w500   | XP counter, small labels                      |
| questionText     | 19sp | w500   | Solo game question card (AutoSizeText)        |
| answerText       | 15sp | w600   | Solo game answer buttons (AutoSizeText)       |
| timerText        | 28sp | w800   | Circular countdown number (ink color)         |
| streakText       | 15sp | w700   | Streak pill (blazeOrange)                     |
| difficultyBadge  | 13sp | w700   | Difficulty pill label                         |

Corner radius: 12–16px rounded cards (16px question card, 14–16px buttons, 20px mode cards)
Status bar icons: dark (Brightness.dark) — app has light background
Navigation bar: floating 5-circle pill, white fill, purple drop shadow; electricBlue 44px circle behind selected icon; icons white (selected) / black (unselected); 250ms easeInOut fade

## Brand Identity
- App name: Blaziq
- Logo mark: lightning bolt with IQ dot accent
- Tagline: TRIVIA · BATTLE · WIN
- Tone: competitive sport, not classroom — fast, clean, light premium theme

## Design References
All screen mockups are in the /designs folder:
- designs/home_screen.png — Home screen with carousel and header stats
- designs/profile_screen.png — Profile / sign-in screen
- designs/rank_screen.png — Leaderboard screen
- designs/store_screen.png — Store/shop screen
- designs/menu_screen.png — Settings/menu screen

Always refer to these images when building or modifying each screen.
Note: the /designs images reflect the original dark-theme mockups; the live app now uses the light theme described above.

## App Structure
5 bottom navigation tabs (left to right):
1. Profile
2. Rank
3. Home (default, center tab — larger circle button when selected)
4. Shop
5. Settings

Bottom nav bar: floating 262×54px pill of 5 merged circles (54px diameter, 2px overlap), white fill.
Drop shadow: BoxShadow(color: Color(0x4D4841C1), blurRadius: 8.6, offset: Offset(0,0)).
Positioned: centered horizontally, sits above system nav area (MediaQuery.padding.bottom gap below it).
Selected tab: 44×44px electricBlue circle (#2563EB) behind a white icon (20px).
Unselected tab: black icon (20px), no circle. Fade animation 250ms easeInOut on selection change.
No labels. Implementation: CustomPainter (_NavShapePainter) + AnimatedOpacity in lib/main.dart.

## Screen Details

### Home Screen
- Header bar: user avatar (circle, top left, electricBlue border), coins count with star icon,
  XP progress bar with level number and title — all live from Firestore
- Center: Blaziq logo (assets/images/inapp_logo.png, 80×80) + "SELECT A MODE" text
- Developer cheat mode: activated by tapping the logo 7 times within 3 seconds;
  counter resets if no tap within 3 seconds; DEV MODE label appears below SELECT A MODE
- Swipeable horizontal carousel with 3 mode cards (gradient: white → #F0F4FF):
  1. Solo — play alone vs the clock (fully functional)
  2. Play with Friend — diagonal blazeOrange "COMING SOON" ribbon, non-tappable
  3. Play Online — diagonal blazeOrange "COMING SOON" ribbon, non-tappable
- Each card has icon, title, short description, centered content
- Grid texture overlay on mode cards: subtle deepGrey lines

### Solo Mode Game Screen (not in nav bar)
- Background: cloudWhite full screen
- Top bar: white background, X quit button left, difficulty pill center
  (small colored dot + difficulty label in ink, softGrey pill bg), score right
  (softGrey pill, orange star icon + blazeOrange score text). No elevation.
- Endless time-based mode — no fixed question limit
- Timer: 90×90px circular arc inside a 110×110px white card with soft shadow.
  Track color: deepGrey. Arc color: electricBlue (normal), blazeOrange (≤8s).
  Center number: ink color, Fira Sans w800.
- Pre-game countdown overlay: 3, 2, 1, GO! on cloudWhite background
  - Shows a muted steel 'CANCEL' button below the number (hidden on GO!)
  - Tapping CANCEL returns to home screen immediately
  - Android back button is blocked during countdown (PopScope canPop: false)
- Quit button: X icon top left — tapping shows a confirmation dialog;
  timer keeps running while dialog is open (do NOT pause it);
  dialog: 'Quit Game?' / 'Your progress will be lost' /
  electricBlue 'Keep Playing' button + steel muted 'Quit' button
- Android back button during game: triggers the same quit confirmation dialog
- Correct answer time bonus (streak resets to 0 on wrong answer):
  - Streak 1–2: +4s
  - Streak 3: +6s
  - Streak 4: +8s
  - Streak 5+: +10s
- Wrong answer: -3s, streak resets to 0 (next correct is back to +4s)
- Difficulty escalation: Easy → Medium (5 correct) → Hard (10 correct)
- Floating feedback: '+4s'/'+6s'/'+8s'/'+10s' in electricBlue, '-3s' in blazeOrange.
  Text flies upward with scale pop + fade, then timer bumps (scale + color flash).
- Streak indicator: softOrange pill, blazeOrange text "🔥 x3", Fira Sans 15sp w700.
  Floats as Stack/Positioned overlay between timer and question card.
  Bouncing animation: TweenSequence scales 1.0 → 1.15 → 1.0 every 1.25s.
  Appears at streak 2+; disappears on wrong answer.
- Question card: white background, border-radius 16px, soft shadow.
  Expanded (fills remaining vertical space). AutoSizeText, 13–19sp, max 5 lines.
- Answer buttons: 2×2 GridView.count, asymmetric corner radii per position:
  - Top-left: topLeft=16px   Top-right: topRight=16px
  - Bottom-left: bottomLeft=16px   Bottom-right: bottomRight=16px
  Idle: white bg, deepGrey border. Correct: skyBlue bg, electricBlue border/text.
  Wrong: softOrange bg, blazeOrange border/text.
  Tap animation: AnimatedScale 0.97 on press, 120ms ease.
  AutoSizeText, 11–15sp, max 2 lines.
- Scoring formula at game end:
  - base_points = correct_answers × 100
  - streak_bonus = highest_streak × 50
  - time_bonus = remaining_seconds × 10
  - final_score = base_points + streak_bonus + time_bonus
- Results screen: headline based on performance, final score, correct count,
  highest streak, accuracy %, score/coins/XP earned with count-up animations,
  XP progress bar, LEVEL UP! badge if threshold crossed
- API: fetches 50 questions per batch; auto-prefetch when <3 remain; auto-retry once
  after 5s on HTTP 429
- Use kIsWeb with corsproxy.io prefix for web builds
- Always decode HTML entities in questions and answers

#### Sound effects (SoundService)
- Background music starts when countdown ends, loops at volume 0.4
- correct.wav on correct answer
- wrong.mp3 on wrong answer
- gameover.wav on game over
- At 8 seconds remaining: background music stops, tictoc.wav loops
- Streak bonus pushing time back above 8s: tic-toc stops, background music resumes
- SFX players use AndroidAudioFocus.none so they never interrupt background music
- All sounds respect the sounds_enabled / music_enabled preferences

#### Haptics (HapticFeedback — no package needed)
- Correct answer: lightImpact
- Streak milestone (3rd or 5th in a row): mediumImpact
- Wrong answer: heavyImpact
- Timer ≤ 8 seconds: selectionClick once per second
- _hapticsEnabled cached at game start — checked synchronously (no async delay)
- Requires VIBRATE permission in AndroidManifest.xml

### Profile Screen
- Background: cloudWhite (flat, no gradient)
- The app always has a signed-in user (anonymous or Google) — a pure signed-out
  state never appears
- If anonymous (guest):
  - electricBlue "SAVE YOUR PROGRESS" banner at top (lock icon + subtitle)
  - Guest avatar (person icon, steel muted ring)
  - Guest_XXXXXX username + "Guest account" subtitle read from Firestore
  - Stats grid: games played, best score, coins, XP level — live from Firestore
  - Google Sign-In button (white bg + deepGrey border — visible on light theme)
  - "Reward: +200 coins for linking!" note
- If signed in with Google:
  - Google profile photo avatar (electricBlue ring), username, email — live from Firestore
  - Stats grid: games played, best score, coins, XP level
  - Sign out button (blazeOrange tint) — shows confirmation dialog before signing out;
    on confirm, signs out and immediately re-enters anonymous auth

### Rank Screen
- Background: cloudWhite
- Title: "LEADERBOARD"
- 3 filter tabs: Worldwide | Canada | Friends (softGrey pill container, electricBlue active)
- Worldwide: all players ordered by score desc (live from Firestore leaderboard collection)
- Canada: client-side filter where country == 'CA'; shows empty state if none
- Friends: "Coming Soon" placeholder
- Top 3 as podium: 2nd left, 1st center (taller card), 3rd right
  If fewer than 3 players exist, render only those that exist (no empty slots)
  Each podium card: avatar (NetworkImage if avatarUrl set, else initials), name, score, rank badge
- Players 4th+ as scrollable list below; each row: rank, avatar, username, score
- Current user's row highlighted: electricBlue border + subtle tint (both podium and list)
- leaderboard collection updated by saveGameResult() using effectiveBest = max(score, currentBest)
- When online mode is added later, leaderboard will switch to online ratings

### Store Screen
- Background: cloudWhite
- Title: "SHOP"
- Header: softGrey coin balance pill (star icon + amount), live from Firestore via userStream
- Center: inapp_logo.png + "COMING SOON" in electricBlue + muted subtitle
- Bundle cards and purchase buttons removed — placeholder until Phase 9

### Menu/Settings Screen
- Background: cloudWhite
- Title: "SETTINGS"
- Section AUDIO & HAPTICS:
  - Sound Effects toggle — persisted via shared_preferences (sounds_enabled)
  - Background Music toggle — persisted via shared_preferences (music_enabled)
  - Haptics toggle — persisted via shared_preferences (haptics_enabled)
  - All toggles load saved state on screen init; default true
  - Toggle colors driven by SwitchThemeData in AppTheme.theme (electricBlue active)
- Section NOTIFICATIONS:
  - Push Notifications toggle (UI only, not yet wired)
  - In-App Notifications toggle (UI only, not yet wired)
- Section ACCOUNT:
  - Edit Profile — navigates to Profile tab (index 0) via MainShell callback
  - Sign Out — confirmation dialog, only functional when signed in with Google;
    guests see a SnackBar: "You are playing as a guest — no account to sign out of"
- Section SUPPORT & INFORMATION:
  - How To Play / About / Rate App / Share App — each shows "Coming Soon" SnackBar

## Leaderboard Strategy
- Phase 3-5: Leaderboard shows solo mode best scores only
- Phase 6+: Leaderboard will show online match ratings
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
    - country: string (ISO 3166-1 alpha-2, detected via ip-api.com on first write)
    - lastPlayedDate: string (yyyy-MM-dd, for daily bonus)
    - createdAt: timestamp

Collection: leaderboard
  Document: {uid}
    - username: string
    - score: number (solo best score for now, online rating later)
    - country: string (ISO 3166-1 alpha-2)
    - avatarUrl: string
    - updatedAt: timestamp

## Country Detection
- Country is detected via `http://ip-api.com/json?fields=status,countryCode` on first doc creation
- Android allows cleartext HTTP to ip-api.com via `android/app/src/main/res/xml/network_security_config.xml`
- `refreshCountryIfStale(uid)` is called fire-and-forget on app launch:
  if country == 'CA' AND device locale is not Canada, re-detects and updates Firestore
  (handles legacy users who got the old hardcoded 'CA' default)
- Fall back to empty string if detection fails; do not block app launch

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
- Always use AppTheme for colors and text styles — never hardcode colors
- Dispose all AnimationControllers and Timers in dispose()
- Use if statements not Visibility widgets for conditional rendering
- Streak indicator and floating feedback must use Stack/Positioned
- Haptic calls must be synchronous — cache preference, never call async inside timer ticks
- Answer grid uses GridView.count with asymmetric BorderRadius.only(...) per cell position

## Flutter Code Standards
- Always use const constructors wherever possible
- Separate each screen into its own file in lib/screens/
- Use lib/theme/app_theme.dart for all colors and text styles
- Never hardcode colors inline — always reference AppTheme
- Always wrap scrollable content in SingleChildScrollView
- Use MediaQuery for responsive sizing, never hardcode pixel sizes
- Always dispose controllers in dispose() method
- File naming: snake_case for all files

## Folder Structure (lib/)
lib/
├── main.dart               ← app entry + MainShell + _BottomNav
├── theme/
│   └── app_theme.dart      ← all colors, text styles, ThemeData (light theme)
├── screens/
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   ├── rank_screen.dart
│   ├── store_screen.dart
│   ├── menu_screen.dart
│   └── solo_game_screen.dart
└── services/
    ├── auth_service.dart         ← anonymous sign-in, Google Sign-In, account linking
    ├── user_service.dart         ← Firestore CRUD, level/XP math, country detection
    ├── sound_service.dart        ← audioplayers wrapper; SFX + background music
    └── preferences_service.dart  ← shared_preferences wrapper; sounds/music/haptics

## Project Status

### Completed
- Flutter project created (com.blaziq.blaziq)
- Phase 1: App shell — navigation bar and all 5 screen layouts
- Phase 2: Solo game mode (Open Trivia DB API + game logic) — COMPLETE
  - ✅ Question fetching with HTML entity decoding
  - ✅ Endless time-based gameplay with auto-prefetch (<3 questions remaining)
  - ✅ Circular countdown timer with pulse animation
  - ✅ Pre-game countdown overlay (3, 2, 1, GO!)
  - ✅ Difficulty escalation (Easy → Medium at 5 correct → Hard at 10 correct)
  - ✅ Floating feedback animations (+4s / -3s flies upward with scale pop + fade)
  - ✅ Timer bump animation (scale + color flash when floating text arrives)
  - ✅ Streak indicator as Stack/Positioned overlay (never shifts layout)
  - ✅ Developer cheat mode (7 rapid taps on logo within 3s, 5 cheat buttons in game)
  - ✅ Results screen with full 3-currency rewards (score, XP, coins)
- Phase 3: Firebase Auth + Google Sign-In + Anonymous Auth — COMPLETE
  - ✅ firebase_core, firebase_auth, cloud_firestore, google_sign_in packages added
  - ✅ Firebase project blaziq-1822 configured
  - ✅ auth_service.dart — anonymous sign-in, Google Sign-In with account linking,
       migration fallback, sign-out re-enters anonymous auth
  - ✅ user_service.dart — ensureUserDoc, upgradeToGoogle, mergeAnonData, saveGameResult
  - ✅ profile_screen.dart — anonymous and Google states; signed-out state never shown
  - ✅ Three-currency scoring system: score, XP (with level-up), coins (with daily bonus)
  - ✅ Home header bar: avatar + coins + XP bar, live from Firestore
  - ✅ Results screen saves to Firestore after every game
  - ✅ Bottom nav bar: floating 5-circle pill (262×54px), white, purple drop shadow, electricBlue selected circle, fade animation
- Phase 4: Solo Leaderboard — COMPLETE
  - ✅ leaderboard Firestore collection — written by saveGameResult() after every game
  - ✅ effectiveBest = max(score, currentBest) seeds existing users immediately
  - ✅ leaderboardStream() — live ordered query powering Rank screen
  - ✅ Rank screen: podium (top 3) + scrollable list (4th+), current user highlighted
  - ✅ Worldwide / Canada / Friends tabs
  - ✅ Pre-game countdown: CANCEL button + Android back button blocked (PopScope)
  - ✅ Android back button during game: triggers quit confirmation dialog
  - ✅ OpenTDB HTTP 429 auto-retry after 5s
- App icon + splash screen — COMPLETE
  - ✅ flutter_launcher_icons: adaptive icon (foreground + #1A1A2E background)
  - ✅ flutter_native_splash: #1A1A2E background, Android 12 uses launcher icon
  - ✅ Splash preserved until Firebase + anonymous auth ready, then removed
  - ✅ Home screen logo: assets/images/inapp_logo.png (80×80)
- Phase 5: Polish — COMPLETE
  - ✅ Sound effects + background music (audioplayers ^6.0.0, SoundService)
  - ✅ Haptics via HapticFeedback (no package); VIBRATE permission added
  - ✅ Settings screen: audio/haptic toggles persist via shared_preferences
  - ✅ Settings → Edit Profile navigates to Profile tab
  - ✅ Settings → Sign Out: confirmation dialog for Google users; SnackBar for guests
  - ✅ Settings → support rows show "Coming Soon" SnackBar
  - ✅ Store screen replaced with Coming Soon placeholder (live coin balance kept)
  - ✅ Developer cheat mode: 7 rapid taps on logo activates 5 in-game cheat buttons
  - ✅ Google Sign-In username fix: displayName captured before credential creation,
       _ensureDisplayName() writes it back after signInWithCredential (prevents 'Player' bug)
  - ✅ Country detection: ip-api.com IP lookup on doc creation, Android cleartext config,
       refreshCountryIfStale() on launch fixes legacy 'CA' default for non-Canadian users
  - ✅ Full light theme redesign — app-wide:
       New palette (cloudWhite/electricBlue/blazeOrange/ink/steel — see Design System)
       All fonts → Fira Sans w400–w800 (replaced New Amsterdam + Nunito)
       auto_size_text ^3.0.0 for question card + answer buttons
       Solo game: white top bar, timer white card, orange streak bounce pill,
       AutoSizeText question card, 2×2 answer grid with asymmetric corner radii + scale press
       All screens: light backgrounds, profile gradient removed, status bar dark icons

- Phase 6: Friend Mode — COMPLETE
  - ✅ Question JSON assets: assets/data/ — 4 categories, 100 questions each:
       questions_science.json · questions_geography.json · questions_history.json · questions_general_knowledge.json
       Fields: id, difficulty, question, correct_answer, incorrect_answers
       Order: shuffled within each difficulty group (easy → medium → hard preserved)
  - ✅ room_service.dart — full Firestore room lifecycle + game logic:
       RoomService.createRoom / joinRoom / setReady / setUnready / updateCategory
       pressBuzzer (first-write-wins; works for both 'buzzer' and 'sudden_death' phases)
       submitAnswer (answering → transition; inherited → transition; sudden_death correct → finish,
         wrong → other player wins)
       nextQuestion (pre-loads asset JSON outside transaction)
       _endGameWithTieCheck → sudden_death or endGame
       endGame / updateHeartbeat / leaveRoom / saveFriendGameResult
  - ✅ friend_mode_screen.dart — entry screen with HOST / JOIN buttons
  - ✅ host_screen.dart — 4-category picker (Science 🔬 / Geography 🌍 / History 📜 / General Knowledge 🧠) in 2×2 grid + CREATE ROOM
  - ✅ join_screen.dart — room code entry with UpperCaseTextFormatter + BLAZIQ- prefix auto-add
  - ✅ lobby_screen.dart — waiting room: room code banner, player slots, category chips,
       READY TO START / LEAVE ROOM, 3-s countdown overlay, PopScope back-button guard
  - ✅ friend_game_screen.dart — full game screen:
       3-min game timer, per-phase answer timers (3 s answering, 10 s inherited / sudden_death)
       Buzzer button: pulsing red glow when active, green on win, grey/locked on loss
       Phase state machine: buzzer → answering → inherited → transition → sudden_death → finished
       Get-ready 3-s overlay between questions (host calls nextQuestion after countdown)
       Sudden Death banner overlay when tied scores trigger sudden_death
       Disconnection detection via heartbeat timestamps + 20 s countdown to auto-end
       Answer grid: 2×2, asymmetric BorderRadius.only, greyed/active/correct/wrong/crossed states
       Score cards: live scores side by side, winning player highlighted in electricBlue
       Results screen with XP + coins rewards; HOME button returns to root
  - ✅ home_screen.dart — Friend card (index 1) now tappable → FriendModeScreen;
       COMING SOON ribbon removed; PLAY button added; Online card (index 2) still ribboned

### Firestore rooms collection (Phase 6)
  Document: {roomId}  (e.g. BLAZIQ-4829)
    - hostUid / hostName / hostAvatar / hostLevel / hostScore / hostCorrect / hostReady / hostConnected
    - guestUid / guestName / guestAvatar / guestLevel / guestScore / guestCorrect / guestReady / guestConnected
    - category: 'science' | 'geography' | 'history' | 'general_knowledge'
    - status: 'waiting' | 'lobby' | 'countdown' | 'playing' | 'finished'
    - currentQuestionIndex: number
    - currentQuestion: { id, difficulty, question, correctAnswer, shuffledAnswers[] }
    - phase: 'buzzer' | 'answering' | 'inherited' | 'transition' | 'sudden_death' | 'finished'
    - buzzerWinner: uid | null
    - buzzerWrongAnswer: string | null
    - winnerId: uid | null
    - quitUid: uid | null  (set when a player confirms quit mid-game; cleared on resetForRematch)
    - hostGamesWon / guestGamesWon: number (cumulative session wins)
    - hostTotalScore / guestTotalScore: number (cumulative session scores)
    - totalQuestions: 20 (default)
    - createdAt: timestamp

### Friend Mode scoring (Phase 6)
  Buzzer winner correct: +3 pts · wrong: -1 pt → inherited phase
  Inheritor correct: +2 pts · wrong/timeout: 0 pts → transition phase
  Sudden death: correct → game over (winner) · wrong → other player wins automatically
  XP = correctAnswers × 8 + (winner ? 20 : 0)
  Coins = correctAnswers × 2 + (winner ? 15 : 0)

### Friend Mode UX details (Phase 6 polish)
  - Difficulty pill hidden from game screen — category label shown only
  - Answer buttons show idle (white/normal) style during buzzer phase — non-tappable, not greyed
  - Correct answer NOT revealed when buzzer winner answers wrong — only revealed as a 1-second
    flash at end of inherited phase, before the "Get ready" overlay
  - Floating score animations: +3/+2/−1 text flies upward toward the scorer's card (800ms,
    scale pop 1.0→1.4→1.0, fade out); plays before Get Ready countdown, not simultaneously
  - Buzzer shake animation: ±3px rapid left-right shake while waiting for press; stops on press
  - Buzzer countdown: once winner presses, countdown in tenths of second shown inside buzzer
    circle (electricBlue, 28sp bold); loser sees grey lock icon + "Too slow!" label below
  - Host badge: blazeOrange pill at top-right corner of player card in lobby (not on avatar)
  - Nickname picker: anonymous users without a valid username see a dialog before accessing
    friend mode; username saved to Firestore users/{uid}.username
  - Quitter flow: confirming quit calls quitGame() then shows _QuitResultsScreen with
    "GO TO LOBBY" (calls resetForRematch → LobbyScreen) and "GO HOME" buttons
  - Opponent sees quit overlay: "[Name] has left the game. You win!" with gold pulse animation;
    auto-navigates to results after 3 seconds as winner
  - Session scoreboard in lobby: shown after ≥1 game completed; displays wins + cumulative
    score per player; persisted in hostGamesWon/guestGamesWon/hostTotalScore/guestTotalScore
  - Results screen has 3 buttons: PLAY AGAIN / LEAVE TO LOBBY (both → lobby) / HOME

### Next
- Phase 7: Online matchmaking (random opponent + online leaderboard)

### Pending
- Phase 7: Online matchmaking (random opponent + online leaderboard)
- Phase 8: Kahoot mode (host + join + manual questions)
- Phase 9: Store + in-app purchases
- Phase 10: Final polish, App Store (iOS) submission

Privacy link: https://doc-hosting.flycricket.io/blaziq-privacy-policy/11284ce3-7a2f-4a89-9d8b-33129af162b5/privacy
Terms of use link: https://doc-hosting.flycricket.io/blaziq-terms-of-use/7bd62b5d-fd5d-412d-992c-5b4105c59595/terms
Account deletion form: https://docs.google.com/forms/d/e/1FAIpQLScGVXJ20ZXmBww-w7RjyhLkG_Cl8OaZJINS1In8Wq0AkwU26g/viewform?usp=header
