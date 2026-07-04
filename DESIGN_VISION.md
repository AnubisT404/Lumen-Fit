# Fitness Tracker — Design Vision

> Inspired by MyFitnessPal's iOS app, but cleaner, faster, and with opinionated defaults.
> Single-user PWA. No ads, no paywall, no social features. Just the tool.

---

## Philosophy

### "Log fast, learn slow"
The #1 reason people quit tracking is friction. Every design decision optimizes for **speed of logging** first, then **depth of insight** second.

- **Surface**: Big numbers, clear progress, one-tap actions
- **Depth**: Tap into any card to see full breakdowns, history, trends
- **Trust**: Every food data point is tagged with its source and quality score

### Design Principles
1. **Two-tap rule** — Any core action (log food, log water, log workout) reachable in ≤2 taps
2. **Glanceable** — Dashboard tells you "how's my day going?" in under 3 seconds
3. **Progressive disclosure** — Simple surface, detailed expansion. Don't overwhelm.
4. **Consistency beats novelty** — Same card style, same spacing, same interactions everywhere
5. **Data you can trust** — Source labels on food data, quality scores, lab-tested preferred

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | FastAPI (Python 3.10), SQLAlchemy, SQLite |
| Frontend | Next.js 16, React 19, TypeScript, Tailwind CSS 4 |
| State | TanStack React Query v5 |
| Charts | Recharts |
| Icons | Lucide React |
| Food DB | 1.77M items (USDA SR Legacy + Foundation + Branded), OpenFoodFacts API fallback |
| Storage | All weights in kg internally, display converts per user preference |

---

## Navigation (5 Bottom Tabs)

```
┌──────────────────────────────────────────────┐
│  Home      Diary      Coach    Workouts  Menu │
│   ●         ○          ○         ○        ○   │
└──────────────────────────────────────────────┘
```

Hidden on: `/workouts/new` (full-screen immersive logging), `/setup`

---

## Screen-by-Screen Design

### 1. Home (Dashboard) — `/`

The command center. Answers: "How's my day?"

```
┌─────────────────────────────────────┐
│  ● ● ● ○ ○ ○ ○    Week Streak Dots │  ← NEW: 7 dots for Mon-Sun
├─────────────────────────────────────┤
│                                     │
│    ╭──────── Calorie Ring ────────╮ │  Circular progress ring
│    │    1,450 / 2,200 kcal        │ │  Remaining = Goal - Food + Exercise
│    │    750 remaining             │ │
│    ╰──────────────────────────────╯ │
│                                     │
│  ┌─ Macros ──────────────────────┐  │  Horizontal bars or arc segments
│  │ Protein   85/150g   ████░░░░  │  │  Clean, single-line per macro
│  │ Carbs    180/250g   █████░░░  │  │
│  │ Fat       45/70g    ████░░░░  │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─ Water ───────┐ ┌─ Weight ────┐  │  Side-by-side cards
│  │ 💧 1500/2500ml│ │ 154.3 lb    │  │  Water: glass viz + quick-add
│  │ [+250][+500]  │ │ ▼ 0.5 lb    │  │  Weight: today's + trend arrow
│  │ 60%   [Reset] │ │             │  │
│  └───────────────┘ └─────────────┘  │
│                                     │
│  ┌─ Today's Exercise ────────────┐  │  Summary card
│  │ Push Day — 45 min — 3.2k lb   │  │  Tap → /workouts
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Week Streak Dots** (borrowed from MFP):
- 7 dots across the top (Mon → Sun)
- Filled = logged food that day
- Visual streak motivation without gamification overload

**Macro Cards Redesign** (current: 2 separate cards → target: single clean block):
- One card, three horizontal bars
- Each bar: label, current/goal numbers, progress fill
- Color-coded: Protein=blue, Carbs=amber, Fat=pink
- No separate cards — reduces visual noise

**Quick Actions on Home**:
- Water: +250ml, +350ml, +500ml, +750ml buttons inline
- Weight: tap card → log weight modal (same as coach page)
- No floating action button — actions are contextual to cards

---

### 2. Diary — `/diary`

Food log organized by meals. Date navigation at top.

```
┌─────────────────────────────────────┐
│  ◄  Thursday, Mar 6, 2026  ►       │  Date nav
├─────────────────────────────────────┤
│                                     │
│  ┌─ Calorie Summary ────────────┐   │  Compact summary bar
│  │ 1,450 eaten · 750 remaining  │   │  (Goal - Food + Exercise = Remaining)
│  └──────────────────────────────┘   │
│                                     │
│  BREAKFAST                    +Add  │
│  ┌──────────────────────────────┐   │
│  │ Greek Yogurt     150cal  32p │   │  Swipe to delete
│  │ Banana            89cal   1p │   │
│  └──────────────────────────────┘   │
│                                     │
│  LUNCH                        +Add  │
│  ┌──────────────────────────────┐   │
│  │ Chicken Breast   240cal  45p │   │
│  │ Brown Rice       215cal   5p │   │
│  └──────────────────────────────┘   │
│                                     │
│  DINNER                       +Add  │
│  (empty — tap + to add)             │
│                                     │
│  SNACKS                       +Add  │
│  (empty)                            │
│                                     │
│  ┌─ Nutrition Summary ──────────┐   │  Bottom expandable
│  │ Calories  Protein  Carbs Fat │   │  Tap to see full breakdown
│  │ 1450     85g     200g   42g  │   │  (fiber, sugar, sodium, etc.)
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Add Food Page** (`/diary/add-food`):
- Search bar at top (auto-focus)
- **Source toggle**: Local DB | OpenFoodFacts pill switch
- Results show: name, brand, calories, protein — sorted by trust score
- Source badge on each result (USDA, OFF, manual)
- Tap result → serving size picker → add to meal
- All added foods cached to local DB for future instant search

**Nutrition Detail** (future):
- Tap nutrition summary → full micro/macro breakdown
- Fiber, sugar, sodium, vitamins (when available)
- Pie chart or bar chart of macro split

---

### 3. Coach — `/coach`

Goals, targets, and weight tracking intelligence.

```
┌─────────────────────────────────────┐
│  Your Goals                         │
├─────────────────────────────────────┤
│                                     │
│  ┌─ Weight Goal ────────────────┐   │
│  │ Current: 154.3 lb            │   │  From measurements
│  │ Target:  150.0 lb            │   │
│  │ Remaining: 4.3 lb            │   │
│  │ [Log Weight]                 │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Daily Targets ──────────────┐   │
│  │ Calories: 2,200 kcal         │   │  From profile goals
│  │ Protein:  150g               │   │
│  │ Carbs:    250g               │   │
│  │ Fat:      70g                │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Insights ───────────────────┐   │  Smart observations
│  │ Avg daily: 1,850 kcal        │   │
│  │ Protein avg: 120g (80%)      │   │
│  │ You're 200 cal under target  │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Weight History Chart ───────┐   │  Recharts line chart
│  │  ~~~~\____/~~~~\___          │   │  30-day trend
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

### 4. Workouts — `/workouts`

Date-navigable workout history with weekly stats strip.

```
┌─────────────────────────────────────┐
│  ◄  Thursday, Mar 6  ►             │
├─────────────────────────────────────┤
│  ┌─ Week Stats ─────────────────┐   │  Horizontal strip
│  │ 4 workouts · 3h 15m · 12k lb│   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Push Day ───────────────────┐   │  Workout card
│  │ Strength · 45 min            │   │
│  │                              │   │
│  │ Bench Press    3×10 @ 135lb  │   │  Inline sets
│  │ Incline DB     3×12 @ 50lb  │   │
│  │ Cable Fly      3×15 @ 30lb  │   │
│  │                              │   │
│  │ Volume: 8.1k lb             │   │
│  └──────────────────────────────┘   │
│                                     │
│  ╔═══════════════════════════════╗   │
│  ║       [ Log Workout ]        ║   │  Single CTA button
│  ╚═══════════════════════════════╝   │
└─────────────────────────────────────┘
```

**Log Workout Page** (`/workouts/new`) — full-screen dark theme:
- Header: [✕ Back] [Log Workout] [Save] (save in top-right)
- Strength/Cardio tab switcher
- Strength flow: Add Exercise → search → card with sets → "Next Exercise"
- Each exercise card: set rows with weight steppers (±1kg / ±2.5lb), reps input, optional duration
- "Last session" hints per exercise for progressive overload
- Cardio flow: activity picker, duration, distance, calories

---

### 5. Menu — `/menu`

Settings, profile, and app configuration.

```
┌─────────────────────────────────────┐
│  Profile Card                       │
│  ┌──────────────────────────────┐   │
│  │ 👤 User Name                 │   │
│  │ Goal: Lose weight            │   │
│  │ 2,200 kcal/day               │   │
│  └──────────────────────────────┘   │
│                                     │
│  Quick Links                        │
│  ┌──────────────────────────────┐   │
│  │ Goals & Targets          ›   │   │  → /coach
│  │ Measurements             ›   │   │  → /measurements
│  │ Food Database            ›   │   │  → /meals (browse/manage)
│  └──────────────────────────────┘   │
│                                     │
│  Preferences                        │
│  ┌──────────────────────────────┐   │
│  │ Weight Unit     [KG | LB]    │   │  Pill toggle
│  │ Water Goal      2500ml       │   │  Editable
│  │ Notifications   On/Off       │   │  Future
│  └──────────────────────────────┘   │
│                                     │
│  Measurements — `/measurements`     │
│  Weight history, body stats,        │
│  trend chart, log entries           │
└─────────────────────────────────────┘
```

---

## Visual Language

### Colors
```
Background:     #F8FAFC (slate-50)
Cards:          rgba(255,255,255,0.85) with backdrop-blur (glass-card)
Primary:        Indigo-600 (#4F46E5)
Accent:         Orange-500 (workout), Green-500 (cardio), Blue-500 (water)
Text Primary:   slate-900
Text Secondary: slate-500
Text Muted:     slate-400
```

### Cards
- `.glass-card`: `bg-white/85 backdrop-blur-xl border border-white/60 rounded-2xl shadow-sm`
- Consistent `p-4` or `p-5` padding
- `rounded-2xl` everywhere (not mixed radii)

### Typography
- Headers: `text-xl font-bold text-slate-900`
- Subheaders: `text-sm font-semibold text-slate-700`
- Body: `text-sm text-slate-600`
- Muted: `text-xs text-slate-400`

### Exception: Workout Log Page
- Full dark theme: `bg-gradient-to-b from-slate-900 to-slate-950`
- White text on dark cards
- Immersive, no bottom nav

---

## Data Architecture

### Food Data Pipeline
```
Search Request
    │
    ├── 1. Local USDA DB (1.77M items, instant, offline)
    │       └── FTS5 prefix search with AND/OR fallback
    │
    ├── 2. User's logged foods (fitness.db, trust=100)
    │
    └── 3. External APIs (if <5 local results)
            ├── USDA FoodData Central API
            └── OpenFoodFacts API (quality-filtered)

Every food logged → cached to local DB with source tag
```

### Source Tracking
| Source | Trust | Description |
|--------|-------|------------|
| `sr_legacy` | 97 | USDA lab-tested generic foods |
| `foundation` | 95 | USDA detailed reference foods |
| `branded` | 65 | Manufacturer-submitted (USDA) |
| `USDA_api` | 60-95 | Live USDA API results |
| `OpenFoodFacts` | 30-60 | Community data, quality-filtered |
| `local` | 100 | User's own verified entries |
| `manual` | — | User-entered custom foods |

### Weight Unit System
- **Internal storage**: Always kilograms
- **Display**: Converts via `kgToDisplay()` / `displayToKg()`
- **Increments**: 1 kg steps or 2.5 lb steps
- **Preference**: Stored in `UserSettings` table, toggled from Menu

---

## Planned Features

### Near-term
- [x] **Week streak dots** on dashboard (Mon-Sun, filled when food logged)
- [x] **Macro card redesign** — single card with 3 horizontal progress bars
- [x] **Nutrition detail view** — micronutrition page with 13 nutrients, FDA daily values
- [ ] **Quick-add from home** — contextual food logging shortcut
- [ ] **Goals page** — dedicated goal setting (weight target, daily macros, activity)
- [x] **Diary delete items** — trash icon on each food item

### Mid-term
- [x] **Meal templates** — My Meals tab with create/edit/log flow
- [ ] **Barcode scanning** — camera-based food lookup
- [ ] **Recipe builder** — combine foods into custom recipes with auto-calculated macros
- [ ] **Progress photos** — periodic body photos with date overlay
- [ ] **Export data** — CSV/JSON export of all tracking data

### Future
- [ ] **AI meal scanning** — photo → food identification
- [ ] **Voice logging** — "I had 2 eggs and toast for breakfast"
- [ ] **Apple Health sync** — bidirectional health data sync
- [ ] **Smart suggestions** — "You usually have coffee at 8am" auto-suggestions
- [ ] **Weekly reports** — food group insights, macro adherence trends

---

## References & Inspiration
- [MyFitnessPal iOS](https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718) — structure, goals, streak dots
- [Nutrio UI Kit (Figma)](https://www.figma.com/community/file/1405833265093338268) — card layouts, progress rings
- [MFP Redesign (Figma)](https://www.figma.com/community/file/1322449377822119745) — clean dashboard concepts
- [Dribbble: Calorie Counter](https://dribbble.com/tags/calorie-counter) — visual inspiration
- [Behance: Nutrition Apps](https://www.behance.net/search/projects/calorie%20counter%20app) — layout ideas
