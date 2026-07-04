# Changelog

All notable changes to the Fitness Tracker app are documented here.

> Changes before March 4, 2026 are not tracked (pre-existing codebase).

---

## [2026-05-28] — Exercise Search Full-Screen Conversion & Platform View Fixes

### Changed — Exercise Search → Full-Screen Page
- Converted exercise search from bottom sheet (`showModalBottomSheet`) to full-screen page (`Navigator.push` with `MaterialPageRoute(fullscreenDialog: true)`)
- Eliminates glass button bleed-through from underlying screen (UiKitView compositor layer issue)
- Eliminates gesture conflicts with AdaptiveTextField in bottom sheet context
- Close button: `AdaptiveButton.sfSymbol` (glass, 36×36px) with `xmark` icon
- Search field: `AdaptiveTextField` with capsule `cupertinoDecoration` (borderRadius 18, CupertinoColors.systemFill, 36px height)
- Category chips: scrollable horizontal `ListView` with `BouncingScrollPhysics` and glass border styling
- **Swipe-to-switch categories**: horizontal drag on exercise list area switches between All/Chest/Back/Shoulders/Legs/Arms/Core/Cardio
- Exercise result rows: custom glass-styled containers (NOT AdaptiveListTile — causes 4.5px overflow with subtitles)
- "Add as custom" row: glass `AdaptiveButton`

### Fixed — AdaptiveListTile Overflow in Plan Builder
- Replaced 2 `AdaptiveListTile` instances (with subtitle) in `plan_builder_screen.dart` with custom glass-styled `GestureDetector` containers
- AdaptiveListTile internal padding constrains text Column to ~27.5px height; title+subtitle exceeds this by 4.5px

### Fixed — Native Button Sizing Across App
- Reduced water buttons from 36×36 → 28×28 (icon 14→11) to prevent overlap during Liquid Glass animation
- Reduced Add Exercise/Save Workout button heights (44-50 → 40-44) for capsule proportions
- All SFSymbol icon sizes standardized to `size: 14` (down from 24pt default) to fit 32-36px glass circles
- GestureDetector count reduced from 77 → 45 by replacing with native glass buttons

### Changed — Exercise Search Category Display
- Replaced `AdaptiveSegmentedControl` (can't handle 8 items) with scrollable horizontal chip row
- Chips: 32px height, 16px borderRadius, orange when active, glass border when inactive

---

## [2026-05-28] — Platform View Transition Fix & Native Button Safety

### Fixed — Page Transition Bleed-Through (Critical)
- **Root cause**: `adaptive_platform_ui` renders iOS 26 controls (segmented controls, buttons, tab bar, switches) as native `UiKitView` platform views on a separate iOS compositor layer — they don't participate in Flutter's render tree and visually "stick" during page transitions
- **Solution**: `_NativeViewTransitionObserver` toggles `nativeViewSafe` flag during transitions; all native views switch to Flutter-rendered fallback for ~250ms during the fade
- Replaced `CupertinoRouteTransitionMixin` with plain `PageRoute` + `FadeTransition` (250ms) — new page is full-screen from frame 1
- Added `scheduleFrameCallback` in observer to avoid setState-during-build crash
- Added `NoTransitionPage` on `StatefulShellRoute.indexedStack` to prevent secondary animation on shell

### Fixed — Native Button Bleed-Through in Popups
- Removed `nativeViewSafe` toggling from `showAppSheet`/`showAppAlert` — popups no longer disable native views (they're the topmost layer)
- `nativeViewSafe` flag now ONLY toggles during page-to-page transitions (observer-managed)
- Buttons inside popups render native glass at all times

### Fixed — Raw AdaptiveButton Cleanup
- Replaced all raw `AdaptiveButton` usages across 7 files with modal-safe `AppGlassButton`
- Affected: `add_food_widgets.dart`, `picker_sheet.dart`, `exercise_search_sheet.dart`, `error_state.dart`, `measurements_screen.dart`, `menu_screen.dart`, `auth_screen.dart`
- All buttons now respect `nativeViewSafe` flag during transitions

### Fixed — CupertinoSlidingSegmentedControl Overflow
- Internal thumb height is fixed at ~32px; any child padding > 2px causes overflow
- Reduced vertical padding from 8→2 in `_buildCupertinoFallback()`
- Added `ClipRect` wrapper to suppress remaining pixel overflow warnings
- Increased `SizedBox` height from 32→40 for all segmented control containers

### Fixed — Macros Picker Wheel Overflow
- Added `ConstrainedBox(maxHeight: 55% of screen)` around picker Column
- Increased `CupertinoPicker` itemExtent from 32→36
- Reduced magnification from 2.35→1.1, squeeze to 1.3
- Changed picker text style from `title` (18pt) to `titleMedium` (16pt)

---

## [2026-05-27] — Accessibility, Error Handling & Offline Queue

### Added — Network Error Interceptor
- Global Dio interceptor (`network_error_interceptor.dart`) for user-friendly network error feedback
- Classifies errors: timeout, connection refused, no internet, server error

### Added — Offline Request Queue
- `offline_queue.dart` with `OfflineQueueInterceptor` — queues failed requests and retries on connectivity restore
- Processes queue on app resume via `WidgetsBindingObserver` in main.dart

### Added — Reusable Components Library
- `app_components.dart`: `AppSectionHeader`, `AppStepper`, `AppChip`, `AppFieldLabel`
- `first_time_hint.dart`: one-time dismissible hint banner (SharedPreferences-backed)

### Added — UX Analytics Tracker
- `ux_analytics.dart` for tracking task success rate, drop-off, rage taps, dead taps, backtrack rate

### Added — Documentation
- `PRE_RELEASE_CHECKLIST.md`: Per-screen and per-flow QA checklist
- `COPY_GUIDELINES.md`: Content/copy guidelines
- `INTERACTION_STATE_RULES.md`: Interaction and state rules
- `UX_REVIEW.md` (35KB): Full UI/UX audit — 16 review angles, screen-by-screen analysis, accessibility
- `ENGINEERING_AUDIT.md` (40KB): Engineering/QA audit — bugs, architecture, security, testing gaps
- `COMPONENT_CONSISTENCY_AUDIT.md` (75KB): Component consistency + full typography size audit

### Fixed — Accessibility (Semantics)
- Added `Semantics` to: set remove button, skip timer, set row tap, nutrition/weight/exercise cards in diary, category picker in routine builder, stepper controls
- `FirstTimeHint` on diary screen for first-time users
- Routine builder: overflow fix (ConstrainedBox on category chip), Semantics on steppers

---

## [2026-05-26] — UX Audit Integration & Architecture Fixes

### Added — Comprehensive Audit Reports
- `UX_REVIEW.md` (35KB) — Full UI/UX audit: 16 review angles, screen-by-screen analysis, accessibility
- `ENGINEERING_AUDIT.md` (40KB) — Engineering/QA audit: bugs, architecture, security, testing gaps
- `COMPONENT_CONSISTENCY_AUDIT.md` (75KB) — Component consistency + full typography size audit

### Added — SafeAction Utility
- `safe_action.dart`: Standardized error handling for async actions in screens
- `api_result.dart`: `ApiResult` sealed class with `ApiError`, `ApiErrorType`, `safeApiCall` wrapper

### Changed — Navigation Architecture
- Replaced `ShellRoute` with `StatefulShellRoute.indexedStack` (4 `StatefulShellBranch` entries)
- `AppShell` changed from `Widget child` to `StatefulNavigationShell navigationShell`
- Tab switching uses `navigationShell.goBranch(index)` — preserves per-tab state

### Changed — Typography System
- Added `headline` (22pt/w700) and `titleMedium` (16pt/w600) tokens to `AppTextStyles`
- Page titles standardized to 22pt across all screens
- Column headers updated: w600→w700 + letter spacing

### Changed — Component Consistency Pass
- All screens migrated to `AppCard` (diary, coach, new_workout, workouts, plans)
- Removed duplicate card decoration patterns across 6 screens
- All segmented controls → `AppSegmentedControl` (modal-safe wrapper)
- All popup menus → `AppPopupMenu` (modal-safe wrapper)
- All alert dialogs → `showAppAlert` (modal-safe wrapper)

### Changed — Button Audit
- Menu screen pill toggles → `AdaptiveSegmentedControl`
- New workout SET column width 28→34px, spacing 10→16px
- Set remove button → GestureDetector + styled Container (from AppGlassButton)
- Add Set button → visible accent-tinted Container with + icon
- Stepper buttons → circular 26px with CupertinoIcons
- Plans screen actions → `AppGlassButton` with SF Symbol mapping

### Fixed — Engineering Critical Fixes
- Cardio save: `tryParse` + validation (prevents FormatException crash)
- `PopScope` + unsaved data detection on new_workout and plan_builder screens
- Auth token persistence: null-checks all fields before saving
- Plan builder: routine removal with undo snackbar
- Exercise search sheet: `CupertinoPageRoute` for native iOS transition

### Fixed — Theme Persistence
- Load theme from `SharedPreferences` before `runApp`
- Pass initial ThemeMode to `ThemeModeNotifier` via provider override
- Eliminates flash-of-wrong-theme on app start

### Fixed — Contrast & Accessibility
- `textHint` and `iconMuted` light mode colors: #94A3B8 → #6B7A8D (WCAG AA compliant)
- Setup screen: validation on age/height/weight/targetWeight, error text widget
- Menu screen: shimmer loading states (replaced CircularProgressIndicator)

---

## [2026-05-25] — Exercise Search Revamp & UI Polish + Workout Rest Timer

### Added — Workout Rest Timer
- Auto-starts on set completion (tap ✓ checkmark on any set row)
- Mini-bar slides up showing: mini ring progress + time + [-30s] [Skip] [+30s]
- Tap mini-bar to expand into full bottom sheet with 180px circular countdown ring
- Preset duration chips: 30s, 1:00, 1:30, 2:00, 3:00, 5:00
- Pause/Resume support in expanded view
- Ring transitions orange → red at 10s remaining with haptic warning
- Heavy haptic + pulse animation on completion, auto-dismiss after 3s
- Per-exercise rest duration remembered via SharedPreferences
- Wakelock keeps screen on during entire workout session
- New files: `rest_timer_provider.dart`, `rest_timer_bar.dart`, `rest_timer_sheet.dart`
- Packages added: `audioplayers`, `wakelock_plus`

### Removed — Workout Rest Timer
- Fully reverted per user request — all timer files, packages, and set checkmarks removed

### Added — Set Completion Checkmarks
- Each set row now has a ✓ checkmark (replaces plain set number)
- Tap to mark set as completed (orange highlight + check icon)
- Completing a set automatically triggers the rest timer

### Removed — Set Completion Checkmarks
- Reverted alongside timer removal

### Added — Unified Exercise Search Sheet
- Created shared `ExerciseSearchSheet` widget (`lib/widgets/exercise_search_sheet.dart`)
- Swipeable category pages: All, Chest, Back, Shoulders, Legs, Arms, Core, Cardio
- TabBar + PageView with synced swipe/tap navigation
- Removed "Recent" section for cleaner UX
- Static `ExerciseSearchSheet.show(context)` method for easy invocation

### Fixed — Dark Mode Text Inputs
- **Root cause**: `_buildTheme()` captured `AppTextStyles` values AFTER restoring brightness — lazy getters used wrong brightness
- Fix: capture all text style locals WHILE brightness is correctly set, before restoring
- Added `textSelectionTheme` for proper cursor/selection colors in dark mode
- Added explicit `TextStyle(color: AppColors.textPrimary)` to all TextFields across: routine_builder, plan_builder, add_food, new_workout, measurements

### Fixed — Edge-to-Edge Layout
- All secondary screens now use `SafeArea(bottom: false)` + `backgroundColor: AppColors.background`
- Eliminates visible "cap" at bottom of sub-screens
- Affected: plans, plan_builder, routine_builder, new_workout, measurements, nutrition_detail, goals, add_food

### Fixed — Navigation
- Plans screen back button changed from `context.go('/')` to `context.pop()` — fixes "page not found" error

### Changed — Workout Screen Toggle
- Strength/Cardio toggle restyled: subtle tinted background instead of heavy `surfaceAlt`
- Active tab uses its own color (orange at 15% / green at 15%) with colored border
- Fixed selector height not filling container properly

### Added — Native iOS 26 Component Migration
- Integrated `adaptive_platform_ui` package for native iOS 26 liquid glass widgets
- `IOS26NativeTabBar` replaces custom glass nav bar in `app_shell.dart`
- `AdaptiveSegmentedControl` replaces custom pill toggles (source toggle, category tabs)
- `AdaptivePopupMenuButton` replaces `PopupMenuButton` (meal dropdown, cardio type)
- `AdaptiveButton` (glass/plain/bordered/filled) replaces all ElevatedButton/TextButton/CupertinoButton across 8 screens
- `AdaptiveTextField`/`AdaptiveTextFormField` replaces Material text fields
- `AdaptiveCard` replaces Container-based cards
- Exercise search converted to full-screen page with capsule search field and glass-styled rows

### Added — Auth System
- `backend/auth.py` — JWT auth module with feature flag, bcrypt hashing, token creation/verification
- `backend/routers/auth.py` — Register, login, refresh, status endpoints
- `fitness_flutter/lib/services/auth_service.dart` — Token storage, login/register/refresh/logout
- `fitness_flutter/lib/screens/auth/auth_screen.dart` — Login/Register UI screen
- Router redirect gate: if auth enabled and not logged in, redirect to `/auth`

### Added — Chat UI Redesign
- Chat screen completely rewritten (ChatGPT-style): gradient user bubbles, surface AI bubbles, status dot
- System prompt rewritten from data dump to expert behavior activator (6 domains, response standards, safety)
- Chat sessions support: `session_id` on messages, session list/create/switch endpoints
- Streaming throttled to 15fps for smooth bubble updates
- `endDrawer` for session history (opens from right)
- Empty state with suggestion chips (separate display labels + real prompts)

### Added — Backend Safety & DRY
- Rate limiter on `/chat` (20/min) and `/daily-insight` (5/min)
- Water logging: daily 10,000ml cap validation
- Measurements: race condition fix with `with_for_update()` on upsert
- Coach knowledge: division by zero guard on `profile.current_weight_kg`
- CORS tightened: specific methods/headers instead of wildcard
- Fernet key: loads from env → falls back to `.fernet_key` file with warning
- Shared `date_utils.dart` with `todayDateString()` and `formatDateString()`

### Added — Reusable Widgets
- `app_card.dart` — Unified AppCard widget (16px radius, consistent shadow, border option)
- `error_state.dart` — Shared ErrorState widget with message + retry
- `empty_state.dart` — Shared EmptyState widget with icon + title + subtitle
- `date_navigator.dart` — Shared date navigation header with chevrons + CupertinoDatePicker

### Changed — God Screen Splitting
- Extracted `workout_data.dart` — `SetData`, `ExerciseData` classes + design tokens
- Extracted `workout_widgets.dart` — 9 widget classes from workouts_screen
- Extracted `add_food_widgets.dart` — 14 widget classes from add_food_screen
- Extracted `goals_widgets.dart` — WeightRuler, MacroGoalsPage, NutrientGoalsPage + shared header

### Changed — Plans Unified View
- Removed tab system (Plans/Routines toggle)
- Unified view: plan cards + library section + create button
- Simplified plan card (header + duration + day circles)
- Routines show as compact cards below plans

### Changed — Chat & Coach Backend
- Query classifier expanded: ~19 → ~80+ science keywords
- Scholar search enabled for evergreen_science category
- Recent foods endpoint: fixed source field, added calorie density sanity check, improved deduplication

### Fixed — Exercise Deletion
- Auto-remove exercise when last set deleted via ✕
- Added `Dismissible` swipe-to-delete on exercise cards
- Workout history: filters out exercises with 0 sets, deletes workout if no exercises remain

### Fixed — Codebase Cleanup
- Removed dead code: `_NutrientBar`, `_ProgressRingPainter`, unused `textSecondary` variable, `chat_provider.dart`
- Removed: empty databases, .DS_Store, WAL/SHM temp files, `.idea/`, `.vscode/`, `web/` target
- Organized `backend/scripts/` for one-off tools
- Total freed: ~1.5GB (build artifacts, enrichment source zips, old screenshots)

---

## [2026-05-24] — Dark Mode Fix & E2E Test Suite

### Fixed — Dark Mode (Critical)
- **Root cause**: `_buildTheme()` mutated the global `AppColors._brightness` static as a side effect, leaving brightness in an inconsistent state when `lightTheme`/`darkTheme` getters were called during widget build
- `_buildTheme()` now saves and restores `_brightness` instead of corrupting it
- All 7 main screens now call `AppColors.updateBrightness(Theme.of(context).brightness)` at top of build — guarantees correct colors regardless of rebuild order
- All screens `ref.watch(themeModeProvider)` to trigger rebuild when theme mode changes
- `AppShell` calls `Theme.of(context)` to register as Theme-dependent — gradient background updates instantly
- Fixed stale `_cardShadow` in workouts_screen: converted from top-level `final` to getter (was caching light-mode shadow permanently)

### Added — E2E Integration Test Suite
- **`integration_test/helpers.dart`** — shared utilities (settle, goToTab, goBack, enableDarkMode, launchApp)
- **`integration_test/dashboard_test.dart`** — 6 tests: greeting, scroll, date nav, water controls, macro cards, empty state
- **`integration_test/diary_test.dart`** — 7 tests: add food flow, unit picker, servings picker, meal selector, log food, date nav, no results
- **`integration_test/exercise_test.dart`** — 9 tests: tab load, toggle, exercise picker, search, fill sets, add set, save workout, discard, cardio mode
- **`integration_test/coach_test.dart`** — 6 tests: load, scroll, chat open, send message, topics, back navigation
- **`integration_test/menu_test.dart`** — 9 tests: load, dark toggle, persistence across tabs, AI config, measurements, plans, goals, scroll, theme options
- Run with: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<test>.dart --no-pub`

### Fixed — QA Issues (from visual audit)
- Removed duplicate drag handles from 5 bottom sheets
- Touch targets increased to ≥44px: water buttons, chat send, back button, workout action buttons
- Contrast fixes: plan builder save button, duration toggle text
- Text overflow fix: menu profile name row
- AI config sheet wrapped in SingleChildScrollView (keyboard-safe)
- Bottom sheet corners set to 44px radius matching iPhone physical curves

---

## [2026-04-28] — Design System Overhaul & Inline Coach Chat

### Added — Centralized Design System
- **AppSpacing** tokens — xs(4), sm(8), md(12), lg(16), xl(20), xxl(28), xxxl(32)
- **AppRadius** tokens — xs(4), sm(8), md(12), lg(16), xl(20), full(999); prebuilt `cardRadius`, `buttonRadius`, `sheetRadius`
- **AppIconSize** tokens — small(14), base(16), medium(18), large(24), xlarge(32)
- **AppTextStyles** expansion — display(28), title(18), heading(20), bodyMedium(14w500), label(13), caption(12), small(11), micro(10)
- **Meal color tokens** — `mealBreakfast`(amber), `mealLunch`(emerald), `mealDinner`(indigo), `mealSnack`(red)
- **Shared `categoryColors` map** — single source for exercise category colors
- **Card decoration presets** — `cardDecoration`, `cardDecorationElevated`, `cardShadow`, `cardShadowElevated`

### Changed — Hardcoded Colors → Theme Tokens
- Replaced **200+ hardcoded `Color(0x...)` values** across all 15 screen files with `AppColors` tokens
- Replaced all `Colors.white` (124), `Colors.black` (12), `Colors.grey` (9), `Colors.red` (3) with semantic tokens
- **1041 `AppColors` usages** across codebase; only 5 truly unique one-off colors remain (nutrient-specific)

### Changed — Deduplication
- **`_categoryColors`** — deduplicated 3 identical maps (workouts, new_workout, routine_builder) → single `AppColors.categoryColors`
- **`_cardShadow`** — removed duplicate definitions from diary_screen and menu_screen → `AppColors.cardShadow`
- **`_cardContainer`** — home_screen uses `AppColors.cardDecorationElevated`
- **Meal colors** — diary + nutrition_detail use `AppColors.mealBreakfast/Lunch/Dinner/Snack`

### Fixed — Semantic Color Collision
- `AppColors.danger` changed from rose-500 (`#F43F5E`) to red-500 (`#EF4444`), now distinct from `macroProtein` (`#F43F5E`)

### Changed — Coach Tab → Inline Chat
- **Inline expanding chat** — tapping the input bar or quick actions opens a live chat view in-place (no page navigation)
- Chat header with back button, AI Coach status indicator, and clear chat action
- Full streaming chat with markdown rendering, bouncing dots animation, and source chips
- Dashboard ↔ Chat animated crossfade transition (300ms)
- **Quick Actions** now send prompts directly to inline chat instead of navigating to `/chat`
- **Recent Chat "View all"** opens inline chat view instead of bottom sheet
- Removed old `_buildChatEntry` card and `_showFullHistory` bottom sheet
- Removed greeting/heading section from coach screen

### Changed — AI Coach & Chat Creative Overhaul
- **Coach tab (landing page)** — complete rewrite: AI greeting with avatar, daily insight card with gradient header strip, horizontal scrollable quick-action cards with real prompts, embedded chat input with "Open Full Chat" link
- **Removed**: old Today's Focus card (hardcoded data), fake chat preview bubbles, heavy gradient hero, weight goal card (already in Menu)
- **Recent chat history** section with `_loadRecentChats()` and full-history bottom sheet
- **Chat screen (conversation page)** — complete rewrite: `AppColors.background` backdrop, gradient user bubbles, surface AI bubbles with subtle border, status dot (green/yellow/gray), `canPop`-aware back button
- **Empty chat state** — suggestion chips with separate display labels and real prompts
- **Clear chat** confirmation dialog before wiping history
- Source chips now use `surfaceAlt` background

### Changed — Dashboard Spacing
- Increased ListView padding (horizontal 16→18px, vertical 8→12px)
- Increased card gaps (8→12px), streak gap (8→12px), post-streak (10→14px)
- Increased macro card column gaps (8→12px), inline macro label/bar/value gaps (4→6px, text 10→11px)
- Hydration card padding (12×10→14×12), glass gap (5→7px)
- Weight/exercise cards: padding (10→12px), header→value gap (6→10px), row gap (8→10px)

### Changed — Navigation
- **"Menu" tab renamed to "More"** in bottom nav bar

### Housekeeping
- Archived old web frontend to `frontend_backup.zip` (638MB); removed `frontend/` folder
- Migrated MCP config from `.vscode/mcp.json` → `.mcp.json`

---

## [2026-04-27] — Part 2: Workout Deep Overhaul

### Changed — Unified Workout Page
- **Merged Log Workout into Workouts tab** — eliminated navigation to separate `new_workout_screen`; the workouts page now serves as both the logging form and history viewer (~1900 lines)
- Changed from `ConsumerWidget` to `ConsumerStatefulWidget` with full state management (`_activeTab`, `_exercises` list, cardio controllers, `_saving`)
- **Draft clears on date change**; post-save cleanup clears form, invalidates providers, shows snackbar
- `new_workout_screen.dart` retained only for editing existing workouts and plan-based workouts

### Changed — Workout Visual Redesign
- **Strength/Cardio toggle** — compact pill toggle with tinted active state, replaces old FAB + type chooser and inline action cards
- **Exercise form cards** — colored header strip with numbered badge, history row with clock icon, category-tinted "Add Set" button
- **Set editing** — replaced weight/rep steppers with tappable "weight × reps" cell that opens dual CupertinoPicker wheel sheet
- **Add Exercise button** — gradient icon, contextual text, centered layout
- **Save button** — gradient fill, check icon, deeper shadow; shows when exercises present or cardio active
- **Grouped workouts** — all strength exercises merged into one card per workout; cardio kept individual
- **Composer summary** — gradient background with separated stats and dot dividers, replacing old stat pills

### Changed — Layout & Exercise Management
- **Logged workouts shown first** — reordered layout so previously logged workouts appear above the composer section
- **"Sessions today" header** above logged workouts
- **Per-exercise delete** — red ✕ button on each exercise row in saved workout cards, calls `DELETE /workouts/exercise/$exerciseId`
- **Exercise search redesign** — header with search bar in card, category icons via `_categoryIcon()` map, gradient custom entry, history indicators, letter badges for results, subtle category color tints on pills

### Changed — Workout Card Redesign
- **Always-expanded cards** — converted `_WorkoutCard` from StatefulWidget to StatelessWidget, exercises always visible (removed expand/collapse toggle)
- **Per-set inline editing** — tappable set pills open `_openEditSetSheet()` bottom sheet with dual CupertinoPicker for weight/reps; saves updated payload to API
- **Swipe-to-delete exercises** — each exercise row wrapped in `Dismissible`
- **Toned-down colors** — card border `_accent.withAlpha(10)`, icon badge subtle accent background, meta info as plain muted text (removed `_MetaChip`), delete button simple gray
- **Exercise row styling** — unified accent color for index badges and set pills instead of per-category coloring
- **Header delete button** — ✕ on card header replaces swipe-to-delete on whole card

### Changed — Saved Workout Table Layout
- **Table-style exercise rows** — replaced wrapped set pills with clean columns: SET | WEIGHT | × | REPS | VOLUME | ✕ delete
- **Set deletion** — ✕ button on each set row removes via update API and renumbers remaining sets

### Changed — Cardio Form Overhaul
- **Wheel picker tiles** — replaced all text fields with tappable value tiles showing current value or "—" placeholder
- **Top row**: Duration (0–180 min), Distance (0–100 km, 0.5 km steps), Calories (0–1000, 5 cal steps)
- **Bottom row**: Avg HR (60–200 bpm), Intensity (tap-to-cycle: low/moderate/high/extreme)
- **Pace auto-calculated** when both duration and distance are set
- **"More details" expandable section** — Max HR, Elevation, Notes (restored after initial removal)
- Cardio detail chips changed from green to neutral gray
- Fixed `_intensity` RangeError crash — changed `!= null` to `.isNotEmpty` check

### Added — Routine Builder Screen
- **New `routine_builder_screen.dart`** (~600 lines) — full routine creation and editing with exercise management, search, sets/reps steppers, category display, and alternative exercises
- **Service methods** — added `createRoutine()` and `updateRoutine()` to `workouts_service.dart`
- **Router** — added `/routines/new` route with edit query parameter support

### Changed — Plans & Routines Redesign
- **Routines tab** — replaced 2-column grid (`_RoutineCard`) with full-width `_RoutineListCard` list showing exercise previews
- **Navigation wired** — "Create Custom Routine" → `/routines/new`, edit button → `/routines/new?edit={id}`
- **Plan builder fix** — fixed `DropdownButton` assertion crash by validating `routine_id` exists in items before passing to widget; removed disabled header items causing null duplicates

### Changed — New Workout Screen Cleanup
- Restored strength/cardio tab toggle (hidden when editing or using plan)
- Removed blue left accent strip from exercise cards
- Removed unused `_borderColor` getter and `_TabButton` class
- Improved save flow: 200ms delay after invalidation, `context.pop(true)`, success SnackBar
- Fixed set validation: changed `||` to `&&` (require both reps AND weight)

---

## [2026-04-27] — Workouts Redesign, Nav Bar & Picker Fixes

### Changed — Workouts Screen
- **Seamless date header** — replaced glass blur header with clean diary-style header (chevron arrows, CupertinoDatePicker popup on tap, calendar icon)
- **Quick action cards** — two always-visible cards: "Workout Plan" (calendar icon, indigo) and "Log Workout" (dumbbell icon, green), replacing single gradient button
- **Compact weekly stats** — single-row card with "This Week" label, inline stats (workouts/time/calories) with dividers, no accent strip
- **Removed "Getting Started" section** — deleted `_GetStartedSection` and `_GetStartedItem` classes
- **Unified layout** — single code path for empty and populated states; plan banner and workout cards always in layout flow
- **Today's Plan banner** — removed icon box, now shows just plan name, subtitle, and Start button

### Changed — Bottom Navigation Bar
- **iOS 26 Liquid Glass nav bar** — complete rewrite as floating pill (`_IslandNavBar`): 52px height, 48px side margins, 26px radius, blur 24, ultra-transparent white gradient (28%→14%)
- **Active tab highlight** — circular glass background (white 35%) behind icon with indigo color; inactive = grey icon only, no labels
- **Content behind nav bar** — `extendBody: true` on Scaffold; all 4 screens set to `backgroundColor: Colors.transparent` and `SafeArea(bottom: false)`
- Removed old `_GlassNavBar`, `_ActiveTab`, `_InactiveTab` classes

### Fixed — CupertinoPicker Tick Sound
- **Root cause**: `onSelectedItemChanged` callbacks called `setState()`, which rebuilt widgets and created new `FixedExtentScrollController` instances inline, orphaning the scroll listener (attached in `initState`) — tick sound only fired once
- **Fix**: Stored 4 controllers (`_gramCtrl`, `_decCtrl`, `_fracWholeCtrl`, `_fracPartCtrl`) as `late final` fields in `_ServingsPickerSheetState`, initialized in `initState`, disposed in `dispose`
- Removed `setState` from all `onSelectedItemChanged` callbacks — picker handles its own display
- Removed all redundant `HapticFeedback.selectionClick()` calls from both `add_food_screen.dart` and `goals_screen.dart` (9 pickers total) — CupertinoPicker has built-in haptic + `SystemSound.tick`
- Added `selectionOverlay` with `Color(0x1A787880)` to all pickers for consistent styling

### Fixed — Exercise Search
- **Bug**: `WorkoutsService.searchExercises()` read `data['results']` but backend returns `data['exercises']` — search always returned empty list
- **Fix**: Updated to read `data['exercises']` with fallback to `data['results']`

### Changed — Route Transitions
- `/new-workout`, `/plans`, and `/plans/new` routes now use `BottomSlidePageTransition` (slide from bottom) instead of `AdaptivePageTransition` (slide from right)
- Added `BottomSlidePageTransition` class to `adaptive_page_transition.dart`

---

## [2026-04-26] — Compact Diary Cards & Picker Polish

### Changed
- **Compact diary meal cards** — reduced vertical padding and spacing for denser layout
- **CupertinoPicker styling** — consistent selection overlay across all picker sheets
- **Serving size picker height** — 200 → 180px to match goals screen
- **Calorie picker font** — fontSize 20 → 21 w400 for consistency

---

## [2026-04-26] — Home & Diary Screen Merge

### Changed
- **Merged home and diary into single dashboard** — removed separate home screen; diary is now the main tab with all dashboard widgets (calorie ring, macros, water, meals)
- **`home_screen.dart` is now dead code** — no longer imported anywhere

---

## [2026-04-26] — Home Page Compact Redesign

### Changed
- **Compact home layout** — reduced card sizes and spacing for more content visible without scrolling
- **Streamlined dashboard** — tighter calorie/macro section, smaller water card

---

## [2026-04-26] — Stacked Bar Charts with Y-Axis

### Added
- **Stacked bar charts** on nutrition overview with proper Y-axis labels
- **fl_chart integration** for nutrition data visualization

---

## [2026-04-25] — Goals Screen & Nutrition Overview

### Added
- **Goals screen** (`goals_screen.dart`) — CupertinoPicker wheels for calorie target, weight goal, and macro percentages (protein/carbs/fat)
- **Nutrition overview dashboard** — daily/weekly nutrition summary with macro breakdown, calorie trends
- **Macro goal editing** — percentage-based with automatic gram calculation from calorie target

### Changed
- **Nutrition detail screen** polish — fixed header overflow, bar chart overflow issues

---

## [2026-04-24] — UI Polish & Interaction Fixes

### Fixed
- Various UI polish items across screens
- Interaction and tap target improvements

---

## [2026-04-23] — Web App Visual Alignment

### Changed
- Aligned Flutter web app visuals with iOS simulator appearance
- Consistent styling across web and mobile platforms

---

## [2026-04-22] — UI/UX Data Trust & Polish

### Changed
- Data trust indicators and source quality badges in food search
- General UI polish across screens

---

## [2026-04-21] — Comprehensive Flutter UI Redesign

### Changed
- **Complete visual overhaul** of all Flutter screens to match design vision
- **Gradient mesh backgrounds** across all pages
- **Glass-morphic cards** with backdrop blur and subtle shadows
- **Consistent typography** — SF Pro / system font, refined weight hierarchy
- **Color system** — indigo primary, warm accents, proper text color hierarchy

---

## [2026-04-21] — Flutter Migration: API Fixes

### Fixed
- **Type cast errors** across all API response parsing — added null-safe casts for `num`, `int`, `double`, `String` throughout all model `fromJson` factories
- **API response format handling** — services now handle both `Map` and `List` response shapes from backend

---

## [2026-04-21] — Flutter Migration: All Screens Built

### Added
- **5 main screens**: Diary/Dashboard, Coach, Workouts, Menu, Measurements
- **Sub-screens**: Add Food (with search, recent, serving picker), New Workout (strength + cardio), Goals, Nutrition Detail, Chat, Plans, Plan Builder, Setup
- **App shell** with tab navigation and go_router routing
- **13 service classes** connecting to FastAPI backend
- **Riverpod state management** with providers for all data domains
- **Models**: Workout, WorkoutExercise, WorkoutSet, FoodItem, Meal, etc.

### Infrastructure
- Flutter 3.41.7, Dart 3.11.5
- Dependencies: flutter_riverpod, go_router, dio, fl_chart, flutter_markdown, intl
- iOS Simulator target: iPhone 16 Pro, iOS 18.6

---

## [2026-04-20] — Full Codebase Audit: Security, Performance & UX

### Security
- **Encryption key hardcoded** → now read from `FERNET_KEY` env var with file fallback; added to `.gitignore`
- **Gemini API key in URL** → moved to `x-goog-api-key` header
- **USDA API key hardcoded** → now from `USDA_API_KEY` env var (falls back to `DEMO_KEY`)
- **Unrestricted file uploads** → coach endpoint now enforces extension whitelist + 10 MB size limit
- **CORS wildcard** → origins loaded from `ALLOWED_ORIGINS` env var
- **Frontend security headers** — added X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy in `next.config.ts`
- Created `.env.example` with all required env vars and `.gitignore` for secrets/build artifacts

### Fixed — Critical Bugs
- **Shared FoodItem mutation** — `update_meal_item` was modifying the shared FoodItem row, corrupting every meal referencing it; introduced per-MealItem override columns (`override_calories`, `override_protein_g`, etc.) with `effective_*` fallback properties
- **Water route conflict** — `/today/reset` was unreachable because `/{log_id}` matched "today" first; reordered route definitions
- **Division by zero** — guarded measurements weight-change percentage and water log percentage calculations
- **Negative carb targets** — when protein + fat goals exceeded calorie budget, carbs went negative; now scales protein/fat proportionally to fit
- **Orphaned meals & race conditions** — `quick_add_meal` rewritten with single-transaction get-or-create pattern and rollback on failure
- **Cascade deletes missing** — added `ON DELETE CASCADE` to MealItem → FoodItem and `ON DELETE SET NULL` to MealTemplateItem → FoodItem

### Fixed — UI/UX
- **"Remaining" showed 0 when over target** — nutrition detail page now shows overage in red (e.g., `+200`) matching dashboard behavior
- **Serving index out of bounds** — added bounds clamping on `selectedServingIdx` in add-food page
- **No loading skeleton** — diary page now shows animated placeholder cards while data loads
- **No delete confirmation** — workout delete buttons now prompt for confirmation
- **Missing aria-labels** — added to all icon-only buttons (navigation, delete, add)
- **Escape key** — pressing Escape now closes bottom sheets and modals
- **Small touch targets** — delete buttons enlarged to ≥44×44px for mobile
- **Refresh button** — added manual refresh in diary header

### Added
- **`backend/serving_utils.py`** — unit conversion utilities (weight/volume/count units, food presets, normalize/calculate helpers)
- **`backend/constants.py`** — all magic numbers extracted (AI_MAX_TOKENS, WATER_GLASS_ML, defaults, limits, cache TTLs)
- **`frontend/src/hooks/useDateNavigation.ts`** — shared date navigation hook (selectedDate, prev/next day, isToday, display string)
- **`frontend/src/components/MeasurementChart.tsx`** — extracted recharts into dynamic component with SSR disabled
- **PUT `/api/profile/`** — profile updates now auto-recalculate TDEE and macro targets
- **`goals_configured` flag** — dashboard response includes whether the user has set up goals
- **Pydantic response models** — full typed models for dashboard and water endpoints
- **Pagination** — added offset/limit to measurements history and water history endpoints

### Performance
- **Coach settings cached** — in-memory cache with 5-min TTL instead of DB query per chat message; invalidated on settings save
- **PR stats query** — replaced triple-nested Python loop with single SQL `GROUP BY` aggregate
- **Recharts dynamic import** — chart library loaded only when measurements page is visited (SSR disabled)
- **Dashboard prefetch** — home page prefetches diary data for faster navigation
- **Coach query staleTime** — set to 5 minutes to avoid redundant refetches
- **Embedding model preload** — RAG model now warms up in background thread at startup instead of blocking first coach request

### Infrastructure
- **Next.js 16.1.0 → 16.2.4** — resolved 8 npm audit vulnerabilities (picomatch ReDoS, Next.js DoS/CSRF); 0 vulnerabilities remaining
- **npm scripts** — added `lint:fix` and `type-check` to `package.json`
- **README rewritten** — project overview, setup instructions, env vars, architecture notes
- **Scraper paths** — `mfp_scraper_v3.py` now uses relative DB paths instead of hardcoded absolute paths

---

## [2026-04-20] — Serving Data Quality & Codebase Audit

### Fixed — Data Quality
- **MFP portions stored as multipliers, not grams** — `_load_portions_for_foods()` was serving raw MFP `gram_weight` (which are multipliers, e.g., 100 = 1 serving) directly to the frontend; applied `GROUP BY MAX` dedup so correct gram values (always larger) win over multiplier values
- **Deterministic unit weight correction** — added `_fix_portion_weights()` function: known units (oz, lb, kg, cup, tbsp, tsp) with wildly wrong gram weights are recomputed from the unit name (e.g., "4 oz" → 4 × 28.35 = 113.4g)
- **Frontend serving label cleaning** — built `stripNums`/`cleanUnit` pipeline to fix garbled labels like "100.0 100.0 1 lb(s)" → "1 serving (150g)"; added `UNIT_RANGES` validation to catch impossible conversions (e.g., "1 lb" at 150g)
- **Double gram annotation** — fixed regex to match "(252.00 gram)" pattern alongside "(252g)", preventing "1 container (252.00 gram) (252g)" display
- **True duplicate cleanup** — removed 46K true duplicates (same mfp_id + portion_description), 18K NULL food_name orphans, 377 absurd weight rows (>50kg); VACUUM'd DB from 1,668 MB → 1,532 MB

### Fixed — Bugs
- **"Remaining" showed 0 when over target** — nutrition detail page `Math.max(0, ...)` now shows overage in red (e.g., `+200 cal`) matching dashboard behavior

### Added — Full Codebase Audit (80 issues identified, 72 fixed)
- See separate "Full Codebase Audit: Security, Performance & UX" entry below for all 72 fixes

### Performance
- **React Query tuning** — staleTime 60s→5min, gcTime 10min, retry config
- **Search debounce** — 300ms debounce on food search input
- **Memoization** — `useMemo` for `getServingOptions()` (156 lines) and `calculateNutrition()`
- **React.memo** — wrapped BottomNav and WheelColumn components
- **Toast system** — replaced all `alert()` calls with non-blocking toast notifications
- **SQLite WAL mode** — journal_mode=WAL, synchronous=NORMAL, busy_timeout=5000
- **Database indexes** — 6 new indexes (meal_items.meal_id, meal_items.food_id, food_items.name, exercises.workout_id, exercise_sets.exercise_id, meals date+type composite)
- **Connection pooling** — `_get_food_db()` context manager for food_database.db connections

---

## [2026-04-19] — MFP-Style Nutrition UI & Add-Food Redesign

### Added
- **MFP-style donut chart** — replaced macro grid with SVG calorie donut ring showing consumed vs. goal with macro % breakdown
- **Tabbed nutrition page** — complete rewrite with 4 tabs: Overview (donut + macro bars), Calories (meal-type pie chart), Nutrients (FDA micronutrient bars), Macros (macro pie chart)
- **DonutChart component** — reusable SVG donut with customizable segments, center text, and size
- **Serving size bottom sheet** — replaced native `<select>` dropdown with MFP-style slide-up picker
- **MFP-style scroll wheel picker** — `WheelColumn` component with snap scrolling, opacity/scale transitions; `ServingsPickerSheet` with DEC/FRAC toggle for fraction servings (¼, ½, ¾)
- **MFP form-row layout** — restructured food detail section: tappable "Serving Size" row, inline ± buttons for "Number of Servings", tappable "Meal" row

### Changed
- **Add-food page** — complete restyle to MFP-inspired form rows (from card-based layout)

---

## [2026-04-18] — AI Coach Phase 2: RAG Evidence System

### Added
- **RAG evidence pipeline** — docs-only, local-first retrieval system for research-backed coach responses
  - `vector_store.py` — FAISS + FTS5 hybrid retrieval with Reciprocal Rank Fusion, using all-MiniLM-L6-v2 embeddings
  - `scholar_search.py` — 4 scholarly API connectors (PubMed, Europe PMC, OpenAlex, Crossref) with TTL caching and parallel fetch
  - `query_classifier.py` — deterministic query routing (general fitness, nutrition, training, medical, etc.)
  - `seed_knowledge.py` + `knowledge_corpus/core.json` — 12 curated research-backed evidence passages seeded on startup
- **Knowledge management** — coach knowledge CRUD endpoints: upload documents (PDF/TXT/MD), add text passages, list, delete
- **Evidence-backed responses** — chat endpoint now retrieves relevant evidence passages and scholar results, injects as context, includes source citations in responses
- **Frontend evidence UI** — source chips in ChatOverlay showing cited passages; knowledge management + scholar search toggle in Menu settings
- **New database tables** — `KnowledgeDocument`, `KnowledgePassage`, `EvidenceCache`

### Fixed
- **Micronutrient double-conversion** — `meals.py` was multiplying raw DB values (already in mg/mcg) by DV factors again; removed conversion, now passes through correct absolute values; verified with Cheerios calcium (130mg matches label)
- **Deprecated `get_sentence_embedding_dimension()`** → `get_embedding_dimension()` in vector_store.py
- **Scholar search errors** — made provider calls parallel with `asyncio.gather` + per-provider error isolation

---

## [2026-04-17] — AI Coach Phase 1: Chat & Providers

### Added
- **AI-powered Coach** — full chat interface with streaming SSE responses
  - 6 AI provider adapters: OpenAI, Claude, Gemini, Ollama, HuggingFace, Custom endpoint (all streaming via httpx)
  - `ai_providers.py` — unified streaming interface across all providers
  - `coach_knowledge.py` — research-backed system prompt (~6000 tokens) with specific study citations (Morton 2018, Schoenfeld 2017, Krieger 2010, Helms 2014, etc.)
  - `build_user_context()` — gathers real user data (profile, goals, recent meals, workouts, weight history) for personalized responses
- **Coach UI** — card-based page with Daily Insight, Quick Chat prompt, Weight Goal, Daily Goals
  - `ChatOverlay.tsx` — full-screen slide-up chat with SSE streaming, message history, suggestion chips, clear history, markdown rendering
  - Rule-based daily insight fallback when AI provider not configured
- **AI settings** — provider selection, model, API key (encrypted with Fernet), endpoint URL; connection test button
- **Smart bottom nav** — double-tap Coach tab opens chat overlay, Diary tab goes to add-food, Workouts tab starts new workout
- **Backend models** — `CoachMessage`, `CoachMemory` tables for chat history and persistent memory
- **User settings expansion** — `ai_provider`, `ai_model`, `ai_api_key_enc`, `ai_endpoint`, `scholar_search_enabled` columns
- **Target weight** — `target_weight_kg` added to UserProfile model and persisted

### Changed
- **Coach page** — completely rebuilt from hardcoded UI shell to functional AI coach with live data

---

## [2026-03-23] — Serving Fixes, MFP Data Quality & USDA Micronutrients

### Fixed
- **Garbled serving unit labels** — OFF foods showed "250.0 1 serving (112 g) (250g)" in dropdown; rewrote `getServingOptions()` with source-aware logic that handles USDA, MFP, and OpenFoodFacts serving conventions correctly
- **OFF calorie calculation** — portion detail showed "tbsp (100g)" at 714 cal instead of "tbsp (14g)" at 100 cal; now extracts embedded gram weights from `serving_description` (e.g., "(14 g)") and uses them for display and calculation
- **"Number of 1 servings" label** → "Number of servings" — stripped redundant leading "1" from serving labels
- **MFP portion gram_weight misinterpretation** — discovered `gram_weight` in `food_portions` is a multiplier (100 = 1 serving), not actual grams; built `_convert_mfp_portions()` backend helper to convert multipliers to real grams with auto-correction via "1 g" portion formula (`corrected_sg = 100 / gram_weight_of_1g`) and 2–2000g guardrails
- **33,061 MFP entries with missing macros** — re-fetched from live MFP API via CDP across 3 runs (2,179 verified + 12,425 unverified + 18,457 unverified); ~80% fix rate, remaining are genuine zeros (user only entered calories)
- **Garbage MFP portions filtered** — duplicate scraping runs left some portions with 100× inflated gram weights (e.g., "1 tbsp" at 1418g); added unit-aware sanity limits to `_convert_mfp_portions()` that drop obviously wrong values

### Added
- **Source badges on search results** — USDA (green), ✓ MFP (blue for verified), MFP (grey for unverified), OFF (amber)
- **USDA micronutrient enrichment** — added 11 micronutrient columns to `food_items` from FoodData Central CSVs: cholesterol, potassium, calcium, iron, vitamins A/C/D, saturated/mono/poly/trans fats (coverage: calcium 61%, iron 60%, saturated fat 58%, potassium 41%, vitamin D 4%)
- **MFP data quality system** — `data_quality` column on `mfp_foods` with 3 tiers: `good` (354K), `suspect` (24.5K — macro-calorie mismatch >25% or zero macros), `bad` (7.7K — zero calories); bad entries excluded from search, suspect entries downranked

### Changed
- **Serving dropdown is now source-aware** — USDA uses `serving_description`, MFP finds matching portion by weight, OFF uses `serving_unit`; portions deduplicated by weight, "1 g" entries hidden
- **MFP search results** — backend now converts all MFP portion multipliers to actual grams and auto-corrects `serving_size` when "1 g" portion data is available

### Removed
- `backend/mfp_scraper.py` — replaced by `mfp_smart_scraper.py`
- `backend/enrich_food_db.py` — one-time enrichment script, no longer needed
- `backend/import_food_db.py` — old USDA import script
- `backend/serving_utils.py` — unused serving helper functions
- `backend/enrich_usda_micros.py` — temporary micronutrient enrichment script

---

## [2026-03-21] — Workout Plans & Programs

### Added
- **Workout Plans system** — two-layer architecture for structured training programs
  - **Routines** (templates): Blueprint for a single session with exercises, target sets×reps, and exercise alternatives
  - **Plans** (schedules): Map routines to weekdays with repeating or fixed-duration cycles
  - Exercise alternatives: each slot can have multiple options (e.g., Bench Press OR Dumbbell Press), user picks when starting
- **Backend: 5 new models** — `workout_routines`, `workout_routine_exercises`, `workout_routine_exercise_options`, `workout_plans`, `workout_plan_days`
- **Backend: full CRUD API** — `/workouts/routines` and `/workouts/plans` with create, read, update, delete
- **Plan activation** — `/plans/{id}/activate` and `/plans/{id}/deactivate` (only one active at a time)
- **Today's plan API** — `/plans/active/today` returns current routine with exercises and week number
- **4 preset plans seeded on startup** — Push/Pull/Legs (6-day), Upper/Lower (4-day), Full Body (3-day), Bro Split (5-day)
- **12 preset routines** — Push Day, Pull Day, Leg Day, Upper Body, Lower Body, Full Body A/B/C, Chest Day, Back Day, Shoulder Day, Arms Day
- **Plans management page** (`/workouts/plans`) — browse presets + custom plans, activate/deactivate, edit, delete
- **Routines tab** — view all routines with exercise summaries, edit, delete (presets protected)
- **Routine builder** (`/workouts/routines/new`) — create/edit routines with exercise search, alternatives, target sets×reps
- **Plan builder** (`/workouts/plans/new`) — create/edit plans with routine-per-day assignment, duration type selection
- **Today's plan banner** on workouts page — shows "Today: Leg Day (Week 1)" with one-tap Start button
- **Plan pre-fill** — starting from plan auto-populates all exercises with target reps + last session weights (progressive overload)
- **Exercise search category tabs** — horizontal swipeable tabs (All | Chest | Back | Shoulders | Legs | Arms | Core | Cardio) filtering results
- **Calendar icon** in workouts header linking to plans management page

---

## [2026-03-20] — Workout Edit, Add-Food Restyle & Calorie Display

### Added
- **Workout edit functionality** — full edit support for existing workouts
  - Backend: `GET /workouts/{id}`, `PUT /workouts/{id}`, `PUT /workouts/{id}/cardio` endpoints
  - Frontend: Pencil edit button on workout cards, navigates to edit form pre-populated with existing data (exercises, sets, weights, cardio fields)
  - StrengthForm and CardioForm both support `editData` prop with auto-initialization
  - Mutations auto-switch between create (POST) and update (PUT) based on `edit` URL param
- **"Add another workout" button** on workouts page — was completely missing when workouts existed for the day, preventing cardio addition after strength
- **Smart portion display** on add-food search results and recent foods
  - `formatPortion()` with 3-tier logic: portions array → serving_description parsing → gram fallback
  - Backend `_load_portions_for_foods()` helper loads `food_portions` table data
  - Preferred portions list (slice, bar, cup, serving, piece) with grammar fixes ("1 slices" → "1 slice")
- **Source-aware calorie calculation** — `calForGrams()` handles USDA (per 100g) vs MFP/local (per serving) conventions correctly across search results, food detail, and meal builder
- **UI/UX Pro Max skill** installed (`.github/prompts/ui-ux-pro-max/`) — AI design system generator with 161 industry rules, 67 styles, color palettes, typography pairings

### Changed
- **Add-food page complete restyle** — 92 gray→slate replacements, gradient-mesh background, glass sticky header, `.card` classes throughout
- **Compact food cards** — search results and recent foods now single-line items with `px-4 py-3`, portion label + calories on right
- **Removed P/C/F macros from search results** — cleaner cards showing only food name, brand, calories, and portion
- **`calculateNutrition()` and `addToBuild()` multipliers** updated to be source-aware (USDA: `totalGrams/100`, MFP/local: `totalGrams/serving_size`)
- **`quickCardio` API type** updated to include missing fields (avg_heart_rate, max_heart_rate, elevation_m, intensity)

### Fixed
- Calorie display mismatch between shown calories and portion label on search/recent cards
- Missing ability to add workouts after first workout of the day

---

## [2026-03-11] — Goals Modal, Bottom Nav & Measurements Restyle

### Added
- **Inline goals edit modal** on coach page — iOS-style wheel pickers for macro targets
  - WheelPicker component with snap scrolling, closest-value finder for non-step-aligned values
  - GoalsEditModal bottom sheet with calorie input + 3 macro wheel columns showing percentages and calorie breakdowns
  - `snap5()` helper rounds initial values to nearest step of 5
- **`scrollbar-hide` CSS utility** in globals.css

### Changed
- **Bottom nav bar** — changed from hardcoded exclusion list to whitelist of 5 main tabs (`/`, `/diary`, `/coach`, `/workouts`, `/menu`); hidden on all subpages since they have back buttons
- **Measurements page full restyle** — replaced old purple gradient with `gradient-mesh` + `glass sticky` header + `card` components; chart colors purple→indigo; single card with dividers for history list
- **Removed weight history from coach page** — duplicated measurements page; replaced with "View History" link
- Goals card "Edit" changed from `<Link>` to inline `<button>` that opens modal

### Fixed
- WheelPicker `indexOf` crash for non-step-aligned values (e.g., 344 with step 5)
- Goals modal buttons hidden behind nav — added `max-h-[85vh] overflow-y-auto` and `pb-24`

### Removed
- Unused exercise page (`app/exercise/`) — dead code, not linked from anywhere
- Unused water page — home page has its own inline WaterCard component
- 3 empty orphan database files (`./fitness.db`, `./food_data.db`, `backend/food_data.db`)
- Redundant `coach/nutrition/` directory (moved to `diary/nutrition/`)

---

## [2026-03-10] — Meal Builder Editing, Tab Redesign & Project Cleanup

### Added
- **Meal builder item editing** — click any item in the builder to edit its portion (opens food detail pre-filled with current grams)
- **"Add Food" button** in meal builder to add more items to an existing meal
- **"Update Item" vs "Add to Meal"** button text distinction when editing vs adding

### Changed
- **Tab navigation redesign** — replaced pill-style toggle with inline text headers ("Recent" / "My Meals") using underline indicator on active tab
- **Moved nutrition page** from `coach/nutrition/` to `diary/nutrition/` (updated all route references)

### Removed
- **Unused exercise page** (`app/exercise/`) — dead code, not linked from anywhere
- **Unused water page** (`app/water/`, moved to `app/menu/water/`, then removed) — home page has its own inline water card
- **Empty database files** — removed 3 zero-byte orphan `.db` files (`./fitness.db`, `./food_data.db`, `backend/food_data.db`)
- Duplicate "Recent" heading that appeared when tab was already labeled "Recent"

---

## [2026-03-09] — Meal Templates, Micronutrition Page & Diary Editing

### Added
- **Meal Templates ("My Meals")** — create reusable meals by searching and combining foods with portions
  - Backend: `MealTemplate` + `MealTemplateItem` models, 5 CRUD+log API endpoints
  - Frontend: My Meals tab on add-food page with create meal flow, template list, expand/collapse, one-tap logging
- **Micronutrition detail page** (`/diary/nutrition`) — day/week toggle, date navigation, 13 nutrient bars across 4 sections (Fats, Minerals, Carb Breakdown, Vitamins) with FDA daily values
  - Added 10 micronutrient columns to FoodItem model (saturated_fat, poly/monounsaturated_fat, trans_fat, cholesterol, potassium, calcium, iron, vitamin A/C)
  - Added `GET /nutrition-detail` backend endpoint with RDI reference values
- **Diary item editing** — tap any food item to edit via add-food page (`?edit=itemId`), with "Save Changes" mode
  - Added `PUT /meals/items/{item_id}` backend endpoint
  - Meal type dropdown on add-food page for changing meal type
- **Micronutrition link card** on diary page with chevron arrow

### Changed
- **Diary calorie bar** — replaced macro rings with meal-segment colored bar (Breakfast/Lunch/Dinner/Snacks)
- **Weekly micronutrition view** — shows raw totals with goals ×7 (not daily averages)
- Removed color-coded meal legend from diary bar, kept P/C/F macro summary

---

## [2026-03-08] — Diary Improvements, Cardio Fields & Light Theme

### Added
- **MFP foods in search** — added `mfp_foods` query to search endpoint, verified items get trust_score=90
- **Better search ranking** — exact name match +20, partial name +10, brand match +10 boost logic
- **Macro progress rings** on diary page (protein/carbs/fat with goal progress, red when over)
- **Delete diary items** — trash icon on each food item with optimistic UI refresh
- **Recent/frequent foods** — `GET /meals/recent-foods` endpoint, RecentFoods component on add-food page
- **MFP portions in search results** — batch load from `food_portions` table, deduplicated by description
- **Cardio workout enhancements** — added avg/max heart rate, elevation, intensity (easy/moderate/hard/interval) to exercise sets
  - Auto-calculated pace display (min/km, min/mi, km/h)
- **USDA sugar data fix** — mapped nutrient ID 2000 ("Total Sugars"), updated 1.41M rows

### Changed
- **Workout form light theme** — converted entire `workouts/new` page from dark to light theme
- **Text contrast fix** — bumped workout form label colors from slate-200/300 to slate-400/500
- Removed redundant "Log Workout" button from workouts list page
- OpenFoodFacts search filtered to USA-only products

---

## [2026-03-07] — MFP Database Enrichment & Smart Scraping

### Added
- **66,360 MyFitnessPal foods** scraped via MFP's internal v2 JSON API using Playwright browser automation
  - 28,815 verified foods (43%), 20,716 unique brands, 260,268 serving portions
  - Full nutrient profiles: calories, protein, carbs, fat, fiber, sugar, sodium, cholesterol, potassium, calcium, iron, vitamin A/C/D, saturated/mono/polyunsaturated/trans fat, net carbs
  - Serving sizes with gram weights and nutrition multipliers per food
  - Taxonomy data (MFP's food category tree) and health labels (vegan, gluten_free, etc.)
  - Barcode indicator field (`branded_with_barcode`)
- **Automated scraper script** (`/tmp/mfp_smart_scraper.py`) with batch query generation, JS injection, chunked extraction, and DB save pipeline
  - Generates brand×category search queries (1,348 combos from 230+ brands × 100 categories)
  - 500ms delay between API calls, token refresh every 40 calls, 150 queries per batch
  - Full field capture including all 17 nutrient fields, taxonomy, and health labels
- **11 new nutrient columns** on `mfp_foods` table: calcium, iron, vitamin_c, vitamin_d, saturated_fat, monounsaturated_fat, polyunsaturated_fat, net_carbs, trans_fat, vitamin_a, branded_with_barcode
- **MFP v2 API discovery**: `https://api.myfitnesspal.com/v2/nutrition?q=...` with auth via `MFP.User.getAuthToken()`
  - Supports `max_items` up to 100, `offset` pagination
  - Returns complete serving_sizes with gram_weight and nutrition_multiplier
  - No server-side filters for verified/taxonomy (client-side only)
- **Query efficiency analysis**: "brand+food" combos yield 92% verified foods vs 16% for generic searches

### Scraping Waves Summary
- Waves 1-7: Everyday foods, grocery brands (Walmart, Costco, Kroger, Aldi, Target, Trader Joe's, etc.), frozen meals, snacks, beverages, restaurant chains (McDonald's, Chipotle, Starbucks, etc.), home cooking, plant-based, alcohol, international foods
- Wave 8: Indian/South Asian, Middle Eastern, Latin American, African brands
- Waves 9-13: Expanded coverage across all categories with dedup optimization
- Wave 14: Brand-focused scraping with max_items=50 (30,594 foods from 620 searches)
- Batch 1 (smart scraper): 6,529 foods with full nutrient field capture

---

## [2026-03-07] — MFP Serving Picker & Data Pipeline

### Added
- **MFP-style serving size picker** in add-food page — dropdown with food-native units (cup, tbsp, fl oz, slice, piece) instead of just grams
  - `getServingOptions(food)` generates options from DB portions, plus smart defaults (grams, ounces)
  - Amount input with quick presets, smart unit switching preserves total grams
- **Food database enrichment pipeline** (`backend/enrich_food_db.py`, ~750 lines)
  - Supports 7 data sources: USDA portions, OpenNutrition, Open Food Facts, Kaggle MFP, CalorieNinjas API, SMU/LARC
  - CLI flags: `--all`, `--source X`, `--list`, `--status`
- **25,127 USDA portions imported** for 9,850 foods (SR Legacy + Foundation)
  - Cleaned "N undetermined, " prefix from 14,444 portion descriptions
- **Batch portions API** — search endpoint returns portions per food (USDA by fdc_id, MFP by food_name)
  - Indexes on `food_portions(food_name)`, `food_portions(source)`, `food_portions(mfp_id)`
- **Standalone MFP scraper** (`backend/mfp_scraper.py`) with CLI (`--scrape`, `--search`, `--resume`, `--stats`)

### Changed
- `backend/routers/meals.py`: Portions batch lookup queries both USDA (by fdc_id) and MFP (by food_name, case-insensitive)
- `frontend/src/app/diary/add-food/page.tsx`: Complete serving system rewrite — MFP-style dropdown replaces old Serving/Grams toggle
- FoodItem interface updated: added `fdc_id`, `portions[]`, `category`; removed `suggested_unit`/`suggested_amount`

---

## [2026-03-06] — UI Cleanup & Design Refinement

### Changed
- **Removed page heading titles** (Dashboard, Food Diary, Workouts) — content speaks for itself
- **Removed colored accent headers** — Dashboard (indigo gradient) and Workouts (orange-red gradient) replaced with plain backgrounds
- **All icons changed to outline strokes** — removed colored background boxes across Dashboard, Coach, Menu, Diary, and Workouts pages
- **Calorie card compacted** — removed duplicate "Food/eaten" display, kept just Goal + Left alongside the ring
- **Food search improvements**: FTS5 prefix matching (`breast*` matches "Breasts"), OR fallback when AND returns no results
- **Search source toggle** — pill toggle between "Local DB" and "OpenFoodFacts" on add-food page
- OpenFoodFacts quality filtering improved: skip items with `data_quality_errors_tags`, require completeness ≥ 0.5
- USDA + OFF API calls run in parallel with `asyncio.gather`

### Added
- **Week streak dots on Dashboard** — 7 dots (M-S) showing which days have food logged, green glow for logged days
- **Workout form simplification** — removed workout name input, moved duration field into each ExerciseCard
- **"Next Exercise" button** — shows "Next Exercise" instead of "Add Exercise" when exercises exist
- **Duration pill input** — input (rounded-left) + "min" label (rounded-right) styling

### Fixed
- **Streak dots not showing logged days** — `Meal.date` string vs Python `date` comparison mismatch
- **Date off-by-one in Diary** — `new Date('2026-03-06')` parsed as UTC midnight, shifted to `new Date(year, month-1, day)` for local time

---

## [2026-03-06] — Workout Page Redesign & UX Improvements

### Changed
- Unified `/workouts` page with date navigation, day summary, workout cards with inline sets
- Full-screen `/workouts/new` page with strength/cardio tabs
- Searchable exercise autocomplete (user history + built-in library)
- Weight input with dynamic steppers (±1kg or ±2.5lb based on unit preference)
- "Last session" hints per exercise for progressive overload
- New backend endpoints: `GET /exercises/search`, `GET /exercises/previous`, `GET /by-date`
- Merged `/exercise` page into `/workouts` (removed duplicate page)
- Replaced two Strength/Cardio add buttons with single "Log Workout" button
- Changed exercise card label from "minutes" to "duration" with formatted display (e.g., "1h 30m")
- Moved "Save Workout" button from bottom of form to top-right header for better UX
- Removed `#` prefix from set numbers in workout list
- WeekStrip shows formatted duration with separate number/unit sizing

### Added
- **Weight unit preference system**: Backend `UserSettings` model + `/settings/` API; frontend toggle on Menu page (KG/LB pill button)
- **Unit-aware displays**: All weight values across Dashboard, Coach, Measurements, and Workouts pages respect kg/lb preference
- **Unit conversions**: Store in kg internally, convert for display via `kgToDisplay()`/`displayToKg()` utilities
- **Water controls on home**: Quick-add buttons (+250ml, +350ml, +500ml, +750ml) directly on dashboard water card
- **Water reset**: Reset button + `DELETE /water/today/reset` backend endpoint
- **Water percentage uncapped**: Displays above 100% when exceeding daily goal

### Fixed
- **Timezone bug (workouts)**: `formatDate()` used UTC via `toISOString()`, causing workouts to appear on wrong dates; fixed to use local time
- **Timezone bug (diary)**: Same UTC issue in selectedDate init, date navigation, and isToday check
- **Timezone bug (add-food)**: Same UTC issue in date fallback
- **Water reset endpoint**: Was filtering by `logged_at` (UTC timestamp) instead of `date` field, causing reset to miss entries

---

## [2026-03-06] — UI Polish & Fixes

### Fixed
- **Coach page floating points**: Weight values like `68.90000000000006` now display as `68.9`; macro goals (carbs, fats) rounded to whole numbers
- **Workout log page contrast**: Bumped input backgrounds, placeholder text, and button borders for better visibility on dark background
- **Workout log page**: Replaced light `glass-card` with dark card style matching the dark-themed logging experience
- **Workout log page**: Hidden bottom navigation bar for full-screen immersive experience

### Changed
- **Diary page**: Removed hydration/water section — water tracking now only on Home dashboard
- **Home page**: Exercise card now links to `/workouts` instead of old `/exercise` page
- **Bottom nav**: Updated "Exercise" → "Workouts" label and link

---

## [2026-03-05] — Local Food Database

### Added
- **1.77 million food items** imported from USDA FoodData Central into local SQLite
  - SR Legacy: 7,756 foods (lab-tested, trust=97)
  - Foundation: 135 foods (lab-tested, trust=95)
  - Branded: 1,759,423 foods (manufacturer-reported, trust=65)
- FTS5 full-text search index for instant queries (5–45ms vs 1–5s API calls)
- Multi-word FTS query support (`"chicken AND breast"`)
- `food_database.db` (543 MB) with indexes on name, data_type, trust_score, category
- `import_food_db.py` — USDA CSV → SQLite importer script

### Changed
- **Food search is now local-first**: searches local DB → user entries → USDA API → OpenFoodFacts
- External APIs only queried when local results < 5 (massive speed improvement)
- Cleaned up WAL/SHM files, switched food DB to DELETE journal mode
- Deleted raw CSV data files (saved 3.4 GB)
- Deleted old `fitness.db.backup` from November

---

## [2026-03-05] — Food Search Trust Ranking

### Added
- Trust-based ranking system for food data sources
  - Local user entries: trust=100
  - USDA SR Legacy/Foundation: trust=95–97
  - USDA Branded: trust=60
  - OpenFoodFacts: trust=30–65 (scored by completeness + macro sanity)
- Macro sanity filter: skips foods where macros differ from calories by >50%
- Deduplication by name similarity + calorie range
- Each search result includes `trust_score` and `source_quality` fields
- `truststore` package for macOS Python SSL certificate verification

### Fixed
- SSL certificate verification failures on USDA and OpenFoodFacts APIs
  - Root cause: Python 3.10 on macOS can't verify SSL certs
  - Fix: `truststore` uses macOS Keychain; falls back to `certifi`

---

## [2026-03-04] — Backend Tier 1 Improvements

### Added
- **Input validation**: Pydantic enums (`SexEnum`, `MealTypeEnum`, `WorkoutTypeEnum`, `ExerciseCategoryEnum`, `ActivityLevelEnum`, `GoalEnum`) + `Field()` constraints on all numeric inputs
- **Database indexes** on date columns for meals, water_logs, workouts, body_measurements
- **CHECK constraints** on numeric fields (calories, protein, weight, etc.)
- **Logging**: Replaced all `print()` with `logging` module, added request timing middleware, global exception handler
- **`name` column** on UserProfile with auto-migration on startup
- `GoalsUpdate` Pydantic model — `update_goals` now uses request body instead of query params
- `GoalsResponse` model for consistent API responses

### Changed
- `update_goals` endpoint: query params → request body (`PUT /profile/goals`)
- Frontend `api.ts`: `updateGoals` sends body instead of query params
- Profile `get_profile` returns serializable response

---

## [2026-03-04] — Frontend Visual Overhaul

### Added
- Complete CSS theme system in `globals.css` (CSS custom properties, utility classes)
- Glassmorphic floating pill BottomNav with backdrop-blur
- Gradient headers on all pages
- `CalorieRing` SVG component on dashboard
- Animated macro progress bars with color coding
- Water bubble animations on water page
- Bento grid layout on dashboard
- Shimmer skeleton loading states
- Staggered entrance animations across all pages
- Full-screen gradient wizard for setup page

### Changed
- All emojis replaced with Lucide React icons across 6 files
- Every page redesigned: dashboard, diary, water, meals, workouts, exercise, coach, menu, setup, measurements

---

## [2026-03-04] — Bug Fixes (66 issues)

### Fixed — Backend (22 issues, 8 files)
- **CRITICAL**: `dashboard.py` — `exercise_type` → `workout_type` field name, `None` duration crash, division by zero in averages
- `dashboard.py` — N+1 query problem, added `joinedload`
- `meals.py` — Orphaned meals (food validation before commit), `.dict()` → `.model_dump()`
- `water.py` — Default goal 5000 → 2000ml, 200 → 404 on not found
- `profile.py` — Negative carbs calculation in macro split
- `workouts.py` — `joinedload` + `.limit()` bug → `subqueryload`
- `database.py` — Deprecated `declarative_base` import
- `models.py` — `datetime.utcnow` → timezone-aware `_utcnow` helper
- `measurements.py` — `.dict()` → `.model_dump()`

### Fixed — Frontend (44 issues, 10 files)
- **CRITICAL**: `page.tsx` (dashboard) — Division by zero guards on progress calculations
- `diary/page.tsx` — Meal field mapping (`protein` vs `protein_g`)
- `diary/add-food/page.tsx` — Missing Suspense boundary for `useSearchParams`
- `api.ts` — Environment variable for API URL, `quickCardio` field fix
- `coach/page.tsx` — ProfileResponse interface aligned with backend
- `menu/page.tsx` — Dead links fixed, profile interface aligned
- Removed duplicate BottomNav from: water, meals, workouts, measurements pages
- Removed unused imports across multiple files

### Infrastructure
- `.vscode/mcp.json` — Added `--no-sandbox` to fix Playwright MCP localhost access
- Installed `truststore` via pip for SSL cert verification

---

## Pre-March 2026 (Original Codebase)

### Architecture
- **Backend**: Python FastAPI + SQLAlchemy + SQLite (`fitness.db`), single-user, no auth
- **Frontend**: Next.js 16 + React 19 + TypeScript + Tailwind CSS 4 + TanStack React Query + Recharts + Lucide icons
- **6 backend routers**: dashboard, meals, water, profile, workouts, measurements
- **9 SQLAlchemy models**: UserProfile, Goals, Meal, MealItem, FoodItem, WaterLog, Workout, Exercise, ExerciseSet, BodyMeasurement
- **11 frontend pages**: dashboard, diary, add-food, meals, water, workouts, exercise, coach, menu, setup, measurements
