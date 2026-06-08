# Blaziq — Design System

## Brand Identity

**App name:** Blaziq
**Tagline:** TRIVIA · BATTLE · WIN
**Package:** com.blaziq.blaziq
**Logo mark:** Lightning bolt with an IQ dot accent
**Tone:** Competitive sport, not classroom. Fast, intense, premium dark theme. Think esports arena, not quiz night at a pub.

---

## Color Palette

| Name | Hex | Usage |
|---|---|---|
| Arena Dark | `#1A1A2E` | Primary background — all screens |
| Card Surface | `#242440` | Cards, bottom sheets, input fields, modal surfaces |
| Void Black | `#0D0D1A` | Deep background, bottom nav bar |
| Blaze Gold | `#F0B429` | Primary CTA, correct answers, XP bar, coins, highlights, selected nav, streak |
| Spark Pink | `#E91E8C` | Wrong answers, toggles active state, live/urgent indicators |
| White Text | `#F5F5F5` | All primary body text |
| Muted Text | `#888888` | Subtitles, labels, unselected nav, placeholders |
| Divider | `#2A2A4A` | Subtle borders, separators |

### Usage Rules

- Never use a white or light background anywhere — the app is 100% dark-themed.
- Blaze Gold is the hero accent — use it for anything the user should tap or focus on first.
- Spark Pink signals urgency or error — wrong answers, danger states, timer urgency.
- Card Surface (#242440) always sits on top of Arena Dark (#1A1A2E) — never reverse these.
- Void Black is reserved for the bottom nav and deep overlay backgrounds.
- Muted Text (#888888) is never used for interactive elements.

---

## Typography

**Primary font:** New Amsterdam (Google Fonts) — all headings, screen titles, scores, nav labels, UI labels, coin counts, XP values, button text (non-answer), timer digits, result headlines.

**Secondary font:** Nunito (Google Fonts) — question text and answer button text only.

### Text Styles

| Style name | Font | Size | Weight | Case | Usage |
|---|---|---|---|---|---|
| Display | New Amsterdam | 48sp | Regular | UPPERCASE | App logo / hero title |
| Screen Title | New Amsterdam | 28sp | Regular | UPPERCASE | "LEADERBOARD", "SETTINGS", "SHOP" |
| Card Title | New Amsterdam | 22sp | Regular | UPPERCASE | Mode card headings, podium names |
| Score | New Amsterdam | 36sp | Regular | — | Final score, large stat values |
| Stat Value | New Amsterdam | 24sp | Regular | — | Header coin count, level number |
| Nav Label | New Amsterdam | 10sp | Regular | UPPERCASE | Unselected bottom nav labels |
| Button Label | New Amsterdam | 16sp | Regular | UPPERCASE | Primary/secondary buttons (not answer buttons) |
| Streak | New Amsterdam | 18sp | Regular | — | Streak indicator overlay (e.g. "🔥 x4") |
| Timer | New Amsterdam | 28sp | Regular | — | Circular countdown digits |
| Question Text | Nunito | 20sp | SemiBold (w600) | Sentence case | Trivia question body |
| Answer Text | Nunito | 16sp | SemiBold (w600) | Sentence case | Answer button labels |
| Body / Subtitle | New Amsterdam | 14sp | Regular | — | Card descriptions, meta info |
| Muted Caption | New Amsterdam | 12sp | Regular | — | Timestamps, secondary labels |

### Letter Spacing
- All New Amsterdam uppercase headings and titles: `letterSpacing: 1.5`
- Nav labels: `letterSpacing: 1.2`
- Body/subtitle: `letterSpacing: 0.5`

---

## Spacing & Layout

| Token | Value | Usage |
|---|---|---|
| xs | 4px | Icon-to-label gap, tight row padding |
| sm | 8px | Internal card padding, small gaps |
| md | 16px | Standard vertical gap, horizontal screen padding |
| lg | 24px | Section gap |
| xl | 32px | Large section gap, above titles |
| xxl | 48px | Hero spacing |

- Screen horizontal padding: **20px** left and right on all screens.
- Bottom nav height: **77px** (includes safe area). Actual icon+label area: **64px**.
- All content scrolls inside `SingleChildScrollView` — no fixed-height containers that clip.

---

## Border Radius

| Element | Radius |
|---|---|
| Mode cards, result panels | 16px |
| Answer buttons | 12px |
| Primary CTA buttons | 12px |
| Stat grid cells | 12px |
| Podium cards | 14px |
| Avatar circles | 50% (circular) |
| Snack bars / toasts | 8px |
| Tab pills / filters | 20px (fully rounded) |

---

## Shadows & Elevation

The app uses glow effects rather than material drop shadows, consistent with the dark neon aesthetic.

- **Gold glow** (selected elements, correct state): `BoxShadow(color: #F0B429 at 30% opacity, blurRadius: 12, spreadRadius: 2)`
- **Pink glow** (wrong state, urgent): `BoxShadow(color: #E91E8C at 30% opacity, blurRadius: 12, spreadRadius: 2)`
- **Card default**: No shadow. Border: `1px solid #2A2A4A`.
- **Card highlighted** (current user in leaderboard): Gold border `1.5px solid #F0B429` + subtle gold background tint (`#F0B429` at 8% opacity).
- **Modal overlays**: Background `#0D0D1A` at 80% opacity.

---

## Component Specs

### Mode Cards (Home Screen Carousel)
- Width: screen width − 48px (fills carousel with peek of adjacent cards)
- Height: ~220px
- Background: Card Surface (#242440)
- Border: 1px solid #2A2A4A
- Border radius: 16px
- Content: centered vertically — icon (40×40), title (Card Title style), short description (Body style, muted)
- Coming Soon ribbon: diagonal band across top-right corner, Spark Pink background, white "COMING SOON" text at 10sp, angled 45°
- Tap state: entire card is non-interactive for Coming Soon cards (no ripple, no nav)
- Active card (Solo): tap navigates to solo game screen

### Answer Buttons
- Width: full column width (two-column grid, 2px gap between columns)
- Height: ~70px minimum, expands for long question text
- Background: Card Surface (#242440)
- Border: 1.5px solid #2A2A4A (default)
- Border radius: 12px
- Text: Nunito 16sp w600, White Text (#F5F5F5), centered
- Correct state: background #F0B429 at 20% + border #F0B429, text #F0B429
- Wrong state: background #E91E8C at 20% + border #E91E8C, text #E91E8C
- Tap animation: brief scale-down (0.96) on press, returns on release

### Primary Button (Gold CTA)
- Background: Blaze Gold (#F0B429)
- Text: Void Black (#0D0D1A), New Amsterdam 16sp UPPERCASE
- Border radius: 12px
- Height: 52px
- Width: full-width or min 200px centered
- No border

### Secondary / Muted Button
- Background: transparent
- Text: Muted Text (#888888), New Amsterdam 14sp UPPERCASE
- Border: 1px solid #2A2A4A (optional)
- Border radius: 12px
- Height: 44px

### Circular Countdown Timer
- Size: 90×90px container
- Track: full circle, stroke width 5px, color #2A2A4A
- Progress arc: stroke width 5px, Blaze Gold (#F0B429) — normal state
- Progress arc: Spark Pink (#E91E8C) when ≤ 8 seconds remaining
- Center text: New Amsterdam 28sp, color matches arc color
- Animation: smooth arc shrinks clockwise as time decreases

### Streak Indicator
- Positioned absolutely between the circular timer and the question card
- Not part of the layout flow — uses Stack/Positioned to float
- Text: New Amsterdam 18sp, Blaze Gold (#F0B429), e.g. "🔥 x3"
- Background: none (transparent)
- Only visible when streak ≥ 2

### Header Bar (Home Screen)
- Height: ~60px, sits below status bar
- Left: circular avatar (36px), border 2px Blaze Gold for Google users / muted ring for guests
- Center: coins icon (star/coin, 16px) + coin count (New Amsterdam 18sp, Blaze Gold)
- Right: XP progress bar (width ~140px, height 10px, rounded, gold fill on dark track) with level number and title below in muted 11sp

### Bottom Navigation Bar
- Height: 77px total (64px content + safe area)
- Background: Void Black (#0D0D1A)
- Top border: 1px solid #2A2A4A
- 5 tabs — icons via SVG assets, labels via New Amsterdam 10sp UPPERCASE
- Selected tab: icon only (no label), icon color Blaze Gold
- Unselected tab: icon (muted, 24px) + label below (muted)
- Center tab (Home): 48×48 circle — gold fill when selected, Card Surface when not; icon is 26px
- Indicator: gold sliding circle behind selected icon (animates position on tab change)

### Profile Avatar
- Size: 80×80px on Profile screen, 36×36px in header
- Shape: perfect circle
- Google user: NetworkImage from photoUrl, gold border 2.5px
- Guest: person icon centered, border 2px muted (#888888)

### Stats Grid (Profile Screen)
- 2×2 grid
- Each cell: Card Surface background, border radius 12px, padding 16px
- Label: Muted Text 11sp UPPERCASE
- Value: New Amsterdam 24sp White Text

### Podium Cards (Rank Screen)
- 1st place (center): tallest card, slightly larger avatar (52px vs 44px)
- 2nd (left) and 3rd (right): flanking, same width
- Each card: Card Surface background, border radius 14px, avatar + rank badge + username + score
- Current user: gold border + gold background tint
- Rank badge: circular, gold (#F0B429) for 1st, silver (#C0C0C0) for 2nd, bronze (#CD7F32) for 3rd

### Leaderboard List Rows (4th+)
- Height: 56px
- Rank number: New Amsterdam 14sp muted, fixed width left column
- Avatar: 36px circle
- Username: New Amsterdam 16sp white
- Score: New Amsterdam 16sp gold, right-aligned
- Current user row: gold border + gold tint background (same as podium treatment)

### Settings Toggle (Switch)
- Active thumb/track color: Blaze Gold (#F0B429)
- Track active: Blaze Gold at ~47% opacity
- Inactive: system default dark

---

## Screen Layouts

### 1. Home Screen
```
┌─────────────────────────────────┐
│  [Avatar]  ★ 1,240   [XP bar]  │  ← Header bar (60px)
├─────────────────────────────────┤
│                                 │
│         [Blaziq logo 80×80]    │
│         SELECT A MODE           │
│         (DEV MODE — if active) │
│                                 │
│  ┌──────────────────────────┐  │
│  │   ← [CARD] [CARD] [CARD]→│  │  ← Swipeable carousel
│  └──────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
│ Profile │ Rank │ [●Home●] │ Shop │ Settings │  ← Nav bar
```

- Logo tap (×7 in 3s) activates DEV MODE label
- Carousel cards: Solo (tappable) | Play with Friend (Coming Soon) | Play Online (Coming Soon)
- Cards fill 85% of screen width with 8% peek on each side

### 2. Profile Screen
**Guest state:**
```
┌─────────────────────────────────┐
│ 🔒 SAVE YOUR PROGRESS           │  ← Gold banner
│    Link your Google account     │
├─────────────────────────────────┤
│           [Avatar]              │
│         Guest_ab1c2d            │
│          Guest account          │
│                                 │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │Games │ │ Best │ │Coins │   │  ← Stats grid (2×2)
│  │  12  │ │ 950  │ │ 200  │   │
│  └──────┘ └──────┘ └──────┘   │
│  ┌──────────────────────────┐  │
│  │  Level 3 · ROOKIE        │  │
│  └──────────────────────────┘  │
│                                 │
│  [ G  Continue with Google ]   │  ← Google Sign-In button
│  Reward: +200 coins for linking!│
└─────────────────────────────────┘
```

**Google signed-in state:**
```
┌─────────────────────────────────┐
│         [Google Avatar]         │  ← 80px circle, gold border
│         Allaa Ikhlef            │
│     allaaeddine@gmail.com       │
├─────────────────────────────────┤
│  Stats grid (games/best/coins/  │
│  level) — same layout as above  │
│                                 │
│  [ Sign Out ]                   │  ← Muted secondary button
└─────────────────────────────────┘
```

### 3. Rank Screen
```
┌─────────────────────────────────┐
│         LEADERBOARD             │  ← Screen title
├─────────────────────────────────┤
│  [ Worldwide ][ Canada ][ Friends ]  ← Tab pills
├─────────────────────────────────┤
│                                 │
│    [2nd]   [👑 1st]   [3rd]    │  ← Podium (3 cards)
│    Nico   Maria★     Alex      │
│    820     1,200      760      │
│                                 │
├─────────────────────────────────┤
│  4.  [Av]  Jordan           640│  ← Scrollable list
│  5.  [Av]  Sam              580│
│  6.  [Av]  ★ You ★          520│  ← Gold highlight for current user
│  ...                           │
└─────────────────────────────────┘
```

### 4. Store Screen (Coming Soon)
```
┌─────────────────────────────────┐
│            SHOP                 │
├─────────────────────────────────┤
│         ★ 1,240 coins          │  ← Live coin balance
│                                 │
│        [Blaziq logo 80×80]     │
│          COMING SOON            │  ← Blaze Gold, New Amsterdam 28sp
│    Great things are on the way  │  ← Muted subtitle
│                                 │
└─────────────────────────────────┘
```

### 5. Settings Screen
```
┌─────────────────────────────────┐
│           SETTINGS              │
├─────────────────────────────────┤
│  AUDIO & HAPTICS                │  ← Section header (muted 11sp UPPERCASE)
│  Sound Effects        [toggle] │
│  Background Music     [toggle] │
│  Haptics              [toggle] │
├─────────────────────────────────┤
│  NOTIFICATIONS                  │
│  Push Notifications   [toggle] │
│  In-App Notifications [toggle] │
├─────────────────────────────────┤
│  ACCOUNT                        │
│  Edit Profile              >   │
│  Sign Out                  >   │
├─────────────────────────────────┤
│  SUPPORT & INFORMATION          │
│  How To Play               >   │
│  About                     >   │
│  Rate App                  >   │
│  Share App                 >   │
└─────────────────────────────────┘
```

- Section headers: New Amsterdam 11sp, Muted Text, UPPERCASE, letterSpacing 1.5
- Row height: 52px, divider between rows: 1px #2A2A4A at 50% opacity
- Toggle active color: Blaze Gold

### 6. Solo Game Screen (full-screen, no nav bar)
```
┌─────────────────────────────────┐
│ [X]                    ⚙ icon  │  ← Top bar (quit button left)
│                                 │
│          [◯ Timer 90×90 ◯]    │  ← Circular countdown
│                                 │
│              🔥 x3             │  ← Streak indicator (floats, Stack/Positioned)
│                                 │
│  ┌──────────────────────────┐  │
│  │  In which country is the │  │  ← Question card (Nunito 20sp)
│  │  Eiffel Tower located?   │  │
│  └──────────────────────────┘  │
│                                 │
│  ┌─────────┐  ┌─────────┐     │  ← Answer grid (2 columns)
│  │ France  │  │ Germany │     │
│  └─────────┘  └─────────┘     │
│  ┌─────────┐  ┌─────────┐     │
│  │  Italy  │  │  Spain  │     │
│  └─────────┘  └─────────┘     │
│                                 │
└─────────────────────────────────┘
```

**Pre-game countdown overlay:**
- Full-screen overlay, Void Black background at 90% opacity
- Large countdown number (New Amsterdam 96sp, centered)
- "CANCEL" button below in Muted Text, hidden on "GO!"

---

## Animations

### Timer Pulse (bump animation)
- Triggered when floating feedback text reaches the timer circle
- Timer container scales: 1.0 → 1.12 → 1.0
- Duration: 200ms ease-out
- Border/arc flashes to Blaze Gold (correct) or Spark Pink (wrong) for 100ms

### Timer Color Transition (urgency)
- At ≤ 8 seconds: arc and center number transition from Blaze Gold to Spark Pink
- Transition: 300ms ease-in-out
- Haptic `selectionClick` fires once per second while urgent

### Floating Feedback Text (+4s / -3s)
- Starts at answer button center, floats upward to timer position
- Distance: ~200–250px vertical travel
- Duration: 800ms
- Easing: ease-out on position, fade-out on opacity (starts fading at 60% of travel)
- Scale: pops from 0.6 → 1.2 → 1.0 in first 150ms, then maintains 1.0

### Streak Indicator
- Appears when streak ≥ 2, disappears (fade out) when streak resets to 0
- Fade in: 200ms
- Shake animation on streak milestone (3rd, 5th): brief horizontal oscillation ±4px over 300ms

### Answer Button States
- Correct: border and background transition to gold — 150ms ease
- Wrong: border and background transition to pink — 150ms ease
- Buttons lock (disabled) immediately on any answer
- Unlocks on next question load

### Countdown Overlay (3, 2, 1, GO!)
- Each number: scale in from 0.5 → 1.0 + fade in over 200ms, holds for 700ms, fades out over 100ms
- "GO!" appears and holds for 400ms, then overlay slides up and off screen (300ms ease-in)

### XP Progress Bar (Results Screen)
- Animates from old XP position to new XP position over 1500ms
- Easing: ease-out
- If level-up occurs: bar fills to 100%, brief gold flash, resets to 0%, then fills to new XP in new level
- "LEVEL UP!" badge: scale-in from 0.5 + gold glow, appears after bar animation completes

### Count-up Animations (Results Screen)
- Score, coins, XP: count from 0 to final value
- Duration: 1200ms each, staggered by 200ms
- Easing: ease-out (fast at start, decelerates)

### Bottom Nav Sliding Circle
- Gold circle slides horizontally behind selected icon
- Duration: 250ms
- Easing: ease-in-out cubic

---

## Aesthetic Direction

**Dark premium esports:** Every screen should feel like the inside of a competitive gaming app — not a colorful trivia game. The dark palette creates tension; gold breaks it with reward.

**High contrast, low noise:** Background (#1A1A2E) vs cards (#242440) is a subtle step. Gold and pink are the only saturated colors. Everything else is dark or muted.

**Motion is reward:** Animations exist to reinforce scoring feedback (floating text, timer bump, count-up). They should feel snappy and satisfying — not decorative or slow.

**Typography is the visual hierarchy:** New Amsterdam gives every UI label a bold, branded feel even at small sizes. Nunito in the question/answer area signals a deliberate shift from "UI" to "content."

**No gradients on backgrounds.** Gradients may appear on progress bars or avatar rings only.

**No rounded corners larger than 16px.** Cards are firm, not bubbly.

**Buttons are rectangular with radius 12px** — not pill-shaped (except filter tabs at 20px, which are explicitly pill-style).
