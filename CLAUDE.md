# Blaziq — Project Brief

## Overview
A cross-platform trivia game built with Flutter and Firebase.
- App name: Blaziq
- Package name: com.blaziq.blaziq
- Target platforms: iOS and Android (primary), Web (secondary)

## Tech Stack
- Flutter (Dart)
- Firebase Auth — Anonymous on first launch + Google Sign-In for account linking
- Cloud Firestore — database, leaderboard, user profiles, questions
- firebase_remote_config ^5.0.0 — feature gating (minimum version checks); see Remote Config section
- http — API calls (country detection; works on mobile and web)
- google_fonts ^8.0.0 — Fira Sans, weights w400–w800, used app-wide
- auto_size_text ^3.0.0 — question card and answer buttons in solo game
- flutter_native_splash ^2.4.1 — native splash screen (runtime dep)
- flutter_launcher_icons ^0.14.1 — app icon generation (dev dep)
- audioplayers ^6.0.0 — sound effects and background music
- shared_preferences ^2.3.0 — persisted settings (audio/haptics toggles, seen questions, language preference)
- flutter_svg ^2.0.0 — SVG icon rendering (assets/icons/)
- lottie ^3.3.3 — animated background (assets/animations/background.json)
- package_info_plus ^8.0.0 — app version at runtime (About screen); wrapped in try/catch with '1.0.0' fallback since PackageInfo can throw on Chrome debug
- url_launcher ^6.3.0 — mailto:/https:// links; use LaunchMode.platformDefault (not externalApplication) and skip canLaunchUrl for mailto (returns false on Chrome); Rate App uses LaunchMode.externalApplication to open the Play Store
- share_plus ^10.0.0 — native share sheet (Settings → Share App)
- State management: Provider or plain StatefulWidget — nothing heavier

## Design System

### Color Palette (light theme — AppTheme)
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

Corner radius: 12–16px rounded cards (16px question card, 14–16px buttons, 20px mode cards).
Status bar icons: dark (Brightness.dark) — app has a light background.
Android system navigation buttons must stay dark-icon; this is enforced at three layers (kSystemOverlayStyle in main.dart, an AnnotatedRegion re-asserting it every frame, and windowLightNavigationBar=true in styles.xml for v27/v31 light and dark) — update all three together if theming changes.

## Brand Identity
- App name: Blaziq
- Logo mark: lightning bolt with IQ dot accent
- Tagline: TRIVIA · BATTLE · WIN
- Tone: competitive sport, not classroom — fast, clean, light premium theme

## App Structure
5 bottom navigation tabs (left to right):
1. Profile
2. Rank
3. Home (default, center tab — larger circle button when selected)
4. Shop
5. Settings

Nav bar: floating 262×54px pill of 5 merged 54px circles, white fill, purple drop shadow (`0x4D4841C1`, blur 8.6), centered above the system nav inset. Selected tab: 44×44px electricBlue circle behind a white 20px icon. Unselected: black 20px icon, no circle, no labels. 250ms easeInOut fade on selection change.

## Screens

### Home
- Header bar: user avatar (electricBlue border), coins (star icon), XP progress bar with level number and title — all live from Firestore
- Center: Blaziq logo (80×80) + "SELECT A MODE"
- Developer cheat mode: tap the logo 7 times within 3 seconds → "DEV MODE" label appears and 5 cheat buttons become available in the solo game screen
- Swipeable carousel with 3 mode cards: Solo (functional) · Play with Friend (functional) · Play Online (COMING SOON ribbon, non-tappable)

### Solo Mode
- Entry: Solo card → bottom sheet with a language step (English/French, default English, persisted as `preferred_question_language`) → category grid (Firestore categories, HOT badge on `isHot`) → `SoloGameScreen(categoryId, language)`
- Endless time-based mode, starts at 30s, no fixed question count
- Correct answer time bonus, streak resets to 0 on any wrong answer: streak 1–2 → +4s · streak 3 → +6s · streak 4 → +8s · streak 5+ → +10s
- Wrong answer: −3s, streak resets to 0
- Difficulty pill follows the current question's own `difficulty` field; sessions arrive pre-ordered easy → medium → hard
- Quit (X button or Android back) shows a confirmation dialog; the timer keeps running while it's open
- Pre-game countdown (3, 2, 1, GO!) with a CANCEL button; Android back is blocked during it
- Scoring: see Scoring & Rewards
- Questions: 15-question sessions from QuestionService, auto-prefetched when fewer than 3 remain; see Question Architecture

#### Sound effects (SoundService)
- Background music loops at volume 0.4 once the countdown ends
- correct.wav / wrong.mp3 / gameover.wav on the relevant events
- At 8s remaining: background music stops, tictoc.wav loops; a streak bonus pushing time back above 8s resumes background music
- SFX players use `AndroidAudioFocus.none` so they never interrupt background music
- Respects `sounds_enabled` / `music_enabled` preferences

#### Haptics
- Correct: lightImpact · streak milestone (3rd/5th in a row): mediumImpact · wrong: heavyImpact · timer ≤8s: selectionClick once per second
- Requires VIBRATE permission (AndroidManifest.xml); respects `haptics_enabled`

### Profile
- The app always has a signed-in user (anonymous or Google) — a pure signed-out state never appears
- Guest: "SAVE YOUR PROGRESS" banner, `Guest_XXXXXX` name, stats grid (games played, best score, coins, XP level), Google Sign-In button (+200 coins reward on linking)
- Google: profile photo, username, email, stats grid, Sign Out (confirmation dialog; re-enters anonymous auth on confirm)

### Rank (Leaderboard)
- 3 filter tabs: Worldwide (all players, score desc) · Canada (client-side filter on `country == 'CA'`) · Friends (Coming Soon)
- Top 3 as a podium (2nd left, 1st center taller, 3rd right; only render players that exist), 4th+ as a scrollable list
- Current user's row is highlighted (electricBlue border + tint) in both podium and list
- Backed by the `leaderboard` collection, written by `saveGameResult()` using `effectiveBest = max(score, currentBest)`
- `leaderboardStream()` is capped at top 50; `getUserRank()` uses a Firestore count aggregation for rank outside the top 50, shown as a sticky "Your Rank" card

### Store
- Coming Soon placeholder; live coin balance shown via `userStream`; full store deferred to Phase 9

### Settings
- AUDIO & HAPTICS: Sound Effects / Background Music / Haptics toggles, persisted via shared_preferences, default true
- NOTIFICATIONS: Push / In-App toggles — UI only, not yet wired
- ACCOUNT:
  - Edit Profile → Profile tab
  - Sign Out — Google users get a confirmation dialog; guests get a SnackBar explaining there's no account to sign out of
  - Delete Account — available to all users; confirmation dialog warns data is permanent. `AuthService.deleteAccount()` → `UserService.deleteAccountData(uid)` batch-deletes `users/{uid}`, `leaderboard/{uid}`, and all `displayNames` docs for that uid, then attempts `user.delete()`; if that fails (e.g. requires-recent-login) it signs out instead with no error shown and re-enters anonymous auth. An empty Auth record may occasionally remain as a harmless dataless orphan.
- SUPPORT & INFORMATION: How To Play and About open as full-screen modals · Rate App opens the Play Store listing · Share App opens the native share sheet

## Firebase Structure (Firestore)

```
users/{uid}
  username: string            — legacy, frozen, never overwrite
  displayName: string         — canonical public name, always use this
  lastNameChange: timestamp | null
  email: string
  coins: number                — default 200 on first sign-in
  jokers: number                — default 0
  xp: number · level: number    — defaults 0 / 1
  gamesPlayed: number · bestScore: number
  country: string              — ISO 3166-1 alpha-2, via ip-api.com
  lastPlayedDate: string        — yyyy-MM-dd, for daily coin bonus
  createdAt: timestamp

displayNames/{lowercaseName}
  uid: string · displayName: string (original casing)
  reserved: bool                — true = old name, blocked but not deleted
  createdAt: timestamp

leaderboard/{uid}
  displayName: string           — falls back to username for legacy docs
  score: number · country: string · avatarUrl: string · updatedAt: timestamp

categories/{categoryId}
  (science, geography, history, general_knowledge, sports, entertainment,
   technology, nature_animals, world_cup)
  name: string · emoji: string · isHot: bool · totalQuestions: number
  enabled: bool · supportedLanguages: string[] (currently ['en','fr'])

questions/{categoryId}/items/{questionId}   (e.g. science_easy_0001)
  difficulty: 'easy'|'medium'|'hard' · category: string · createdAt
  en: { question, correct_answer, incorrect_answers[] }
  fr: { question, correct_answer, incorrect_answers[] }
  ⚠️ en/fr incorrect_answers are NOT index-aligned (fr is a shuffled
  translation) — only correct_answer maps cleanly at index 0.

rooms/{roomId}   (e.g. BLAZIQ-4829, friend mode)
  hostUid/hostName/hostAvatar/hostLevel/hostScore/hostCorrect/hostReady/hostConnected
  guestUid/guestName/guestAvatar/guestLevel/guestScore/guestCorrect/guestReady/guestConnected
  category: string · hostLanguage/guestLanguage: 'en'|'fr'
  status: 'waiting'|'lobby'|'countdown'|'playing'|'finished'
  currentQuestionIndex: number
  currentQuestion: { id, difficulty, translations: {en:{...}, fr:{...}}, answerOrder: int[] }
  phase: 'buzzer'|'answering'|'inherited'|'transition'|'sudden_death'|'finished'
  buzzerWinner: uid|null · buzzerWrongIndex: int|null (canonical) · winnerId: uid|null
  quitUid: uid|null              — cleared on resetForRematch
  hostGamesWon/guestGamesWon: number · hostTotalScore/guestTotalScore: number
  questions: array of 15 bilingual question maps (same shape as currentQuestion)
  totalQuestions: number
  gameStartedAt/buzzerPressedAt/nextQuestionAt/inheritedDeadlineAt: server timestamps
    used to keep both devices' phase timers in sync
  createdAt: timestamp
```

### Firestore Security Rules (deployed to blaziq-1822)
- `displayNames/{name}`: read open; create/update/delete require `request.auth.uid` to match the doc's `uid`
- `questions/{categoryId}/items` and `categories`: read requires `request.auth != null`; writes denied (content is seeded out-of-band)

## Display Name System
- `displayName` is the canonical public identity field; `username` is frozen legacy — never overwritten or deleted
- New anonymous users land on `WelcomeScreen` (Google / Guest); Google users without a `displayName` land on `NamePickerScreen` (mandatory, no back/dismiss); Guest users pick a name via a bottom sheet
- Name rules: 3–20 chars, `^[a-zA-Z0-9_]+$`, real-time availability check with suggestion chips on conflict
- `DisplayNameService.claimName()` writes `displayNames/{lowercase}` + `users/{uid}.displayName` atomically in a transaction; `releaseName()` marks the old name `reserved: true` instead of deleting it
- 7-day cooldown on name changes, enforced via `users/{uid}.lastNameChange`; changed from Profile via the edit icon
- Every leaderboard write uses `displayName`; leaderboard reads fall back to `username` for legacy docs

## Question Architecture
`QuestionService` (lib/services/question_service.dart) is the sole source of trivia questions — bilingual, Firestore-backed, with a local JSON fallback.

- `getSessionQuestions(categoryId, {language, excludeIds})` builds one 15-question session: 7 easy + 5 medium + 3 hard, shuffled within each tier, ordered easy → medium → hard. `language` ('en' default | 'fr') selects which language map the returned text comes from, falling back to 'en' then to flat legacy fields.
- Seen tracking: shared_preferences key `seen_{categoryId}` holds answered/timed-out question IDs; `seen_reset_date` auto-clears all seen lists every 60 days. A session excludes seen IDs, topping up with seen ones only if a difficulty tier runs out.
- `excludeIds` additionally excludes the current on-screen batch and any prefetched batch, so a single match can never repeat a question ID even if the seen-list write hasn't landed yet.
- `markSeen()` / `markSeenAll()` are called on answer, on timeout, and (friend mode) at game end for every question ID shown in the room document.
- Fallback: if Firestore is unreachable, loads `assets/data/questions_{category}.json` — English only, only the original 4 categories (science, geography, history, general_knowledge) ship as assets.
- Friend mode: the host fetches the 15-question session once and stores it in the room doc so both players see identical questions. Answers are matched by canonical index (0 = correct, 1–3 = incorrect, language-independent) rather than text, since the en/fr incorrect-answer arrays aren't index-aligned. Each player can select their own language in the lobby, stored as `hostLanguage`/`guestLanguage`.

Question generation script: C:\Users\user\Documents\blaziq_generator\bin\generate_questions_topup.dart — run from blaziq_generator directory (not bin subfolder).

## Scoring & Rewards

Three separate currencies are awarded at the end of every solo game.

### Solo — SCORE (leaderboard only, stored as `bestScore`)
```
base        = correct_answers × 100
streak      = highest_streak × 50
time        = remaining_seconds × 10
final_score = base + streak + time
```
Updated only if higher than the stored value. Does not appear in the home header bar.

### Solo — XP (level progression)
```
xp_earned = (correct_answers × 10) + 5 + (highest_streak × 3)
```
`level` is recalculated on every save via `xpThreshold(n) = round(100 × n × 1.5)` (Level 1 = 0 XP, Level 2 = 300 XP, Level 3 = 450 XP, ...).
Level titles: 1–4 ROOKIE · 5–9 CHALLENGER · 10–19 EXPERT · 20–49 MASTER · 50+ LEGEND.

### Solo — COINS (store currency)
```
coins_earned = 10 + (correct_answers × 2) + (highest_streak ≥ 5 ? 15 : 0) + (first_game_today ? 20 : 0)
```
`first_game_today` compares `lastPlayedDate` to today's date. Anonymous users see rewards on the results screen but nothing is saved — they see a sign-in prompt instead.

### Friend Mode scoring
- Buzzer winner: correct +3 pts, wrong −1 pt → inherited phase
- Inheritor: correct +2 pts, wrong/timeout 0 pts → transition phase
- Sudden death: correct wins the game; wrong hands the win to the other player
- `XP = correctAnswers × 8 + (winner ? 20 : 0)` · `Coins = correctAnswers × 2 + (winner ? 15 : 0)`

## Remote Config
`RemoteConfigService` initializes fire-and-forget in `main()` right after `Firebase.initializeApp` (never blocks or crashes startup); 1-hour minimum fetch interval, 10s fetch timeout.

Parameters on the blaziq-1822 template:
- `minimum_friend_mode_version` — wired. `FriendModeScreen` checks the app's build number against this before the nickname check; if below, Host/Join are replaced by an "Update Required" card linking to the Play Store. If the build number can't be read, the user is not blocked. Currently 8.
- `minimum_solo_mode_version`, `minimum_online_mode_version`, `minimum_app_version`, `app_maintenance_mode`, `app_maintenance_message` — exist on the template, not yet wired in-app.

## Country Detection
- Detected via `http://ip-api.com/json?fields=status,countryCode` on first user-doc write; Android allows cleartext HTTP to that host via `network_security_config.xml`
- `refreshCountryIfStale(uid)` runs fire-and-forget on launch and re-detects if `country == 'CA'` but the device locale isn't Canada (fixes legacy users who got the old hardcoded default)
- Falls back to an empty string on failure; never blocks app launch

## Web Builds (Chrome testing)
- Use `kIsWeb` from `flutter/foundation.dart` to detect web platform
- All features should work on both web and mobile

## Rules for Claude Code (IMPORTANT)
- Always read CLAUDE.md before writing any code
- Build one feature at a time — never scaffold everything at once
- Keep code simple and readable — no over-engineering
- Use Provider or StatefulWidget for state — nothing heavier
- Always ask before adding any new pub.dev package
- Never add payment or billing code unless explicitly asked
- Always handle loading states and errors gracefully
- Questions come from QuestionService (Firestore) only — never re-add Open Trivia DB; HTML entity decoding lives inside QuestionService
- Never hardcode user data — always check auth state first
- Always use AppTheme for colors and text styles — never hardcode colors
- Dispose all AnimationControllers and Timers in `dispose()`
- Use `if` statements, not `Visibility` widgets, for conditional rendering
- Streak indicator and floating feedback must use Stack/Positioned
- Haptic and sound calls must be synchronous — cache the preference once, never call async inside a timer tick. `_hapticsEnabled` is cached at game start in `_SoloGameScreenState`; `SoundService` caches `sounds_enabled`/`music_enabled` via `syncPreferences()` at game start and `applyPreferences()` whenever a Settings toggle fires (before the async disk write completes)
- Answer grid uses `GridView.count` with asymmetric `BorderRadius.only(...)` per cell position

## Flutter Code Standards
- Always use `const` constructors wherever possible
- Separate each screen into its own file in lib/screens/
- Use lib/theme/app_theme.dart for all colors and text styles
- Never hardcode colors inline — always reference AppTheme
- Always wrap scrollable content in SingleChildScrollView
- Use MediaQuery for responsive sizing, never hardcode pixel sizes
- Always dispose controllers in `dispose()`
- File naming: snake_case for all files

## Folder Structure (lib/)
```
lib/
├── main.dart                    ← app entry + BlaziQApp + _AppRouter (routes to shell or onboarding)
├── theme/
│   └── app_theme.dart           ← all colors, text styles, ThemeData
├── screens/
│   ├── main_shell.dart          ← MainShell + curved nav bar
│   ├── welcome_screen.dart      ← first-launch screen for anonymous users (Google / Guest)
│   ├── name_picker_screen.dart  ← mandatory display name picker
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   ├── rank_screen.dart
│   ├── store_screen.dart
│   ├── menu_screen.dart
│   ├── solo_game_screen.dart
│   ├── how_to_play_screen.dart  ← full-screen modal from Settings
│   └── about_screen.dart        ← full-screen modal from Settings
├── widgets/
│   ├── animated_background.dart ← Lottie background; on all 5 nav screens + welcome + name_picker,
│   │                               not on solo/friend game screens or lobby/host/join
│   └── hot_badge.dart           ← HOT 🔥 pill for isHot categories
└── services/
    ├── auth_service.dart          ← anonymous sign-in, Google Sign-In, account linking
    ├── user_service.dart          ← Firestore CRUD, level/XP math, country detection
    ├── display_name_service.dart  ← displayName claim/release/availability/cooldown
    ├── question_service.dart      ← Firestore question/category fetching, seen tracking, JSON fallback
    ├── remote_config_service.dart ← Firebase Remote Config wrapper (version gating)
    ├── room_service.dart          ← friend mode room lifecycle + game logic
    ├── sound_service.dart         ← audioplayers wrapper; SFX + background music
    └── preferences_service.dart   ← shared_preferences wrapper; sounds/music/haptics/language
```

## Current Status
Phases 1–6.5 complete. App live on Google Play. Next: Phase 7, Online matchmaking.

## Roadmap
- **Phase 7** — Online matchmaking: random opponent matching + online leaderboard ratings
- **Phase 8** — Kahoot mode: one host, multiple players join via room code, answer simultaneously in real time
- **Phase 9** — Store + in-app purchases
- **Phase 10** — Final polish, App Store (iOS) submission

## Links
- Privacy policy: https://doc-hosting.flycricket.io/blaziq-privacy-policy/11284ce3-7a2f-4a89-9d8b-33129af162b5/privacy
- Terms of use: https://doc-hosting.flycricket.io/blaziq-terms-of-use/7bd62b5d-fd5d-412d-992c-5b4105c59595/terms
- Account deletion form: https://docs.google.com/forms/d/e/1FAIpQLScGVXJ20ZXmBww-w7RjyhLkG_Cl8OaZJINS1In8Wq0AkwU26g/viewform?usp=header
