# Structured UI/UX Framework Audit

**App:** Fitness (Flutter + FastAPI)  
**Date:** 2026-05-28  
**Method:** 5-Layer Evaluation Stack  
**Lenses:** Nielsen's 10 Heuristics × WCAG 2.2 × Apple HIG × Tognazzini Principles × Design System QA

---

## Executive Summary

This audit applies a formal evaluation framework rather than ad-hoc issue spotting. The app is evaluated against established standards to identify **classes of problems** that must be systematically prevented, not individually patched.

**Verdict:** The app has strong visual ambition and sensible information architecture, but it fails at the systems level. There is no enforced design system, no accessibility layer, no state resilience model, and no feedback consistency. The result is an app that looks polished in screenshots but breaks down under real-world conditions: interruptions, errors, accessibility needs, repeated rapid use, and edge cases.

**Root cause of recurring issues:** The absence of a formal review framework and design system. Individual screens are designed in isolation, producing drift that compounds across features.

---

## Layer 1: Nielsen's 10 Heuristics Evaluation

### H1: Visibility of System Status
**Rating: 4/10 — Major gaps**

| What Should Happen | What Actually Happens |
|---|---|
| Every action shows immediate feedback | Save buttons show "..." or "Saving..." text — no spinner, no progress bar |
| Users always know where they are | No breadcrumbs, no step indicators in multi-step flows (setup has dots but plans/routines don't) |
| Loading states communicate progress | 38 loading indicators exist — acceptable on paper, but workouts_screen (6 API calls, 0 loading indicators) and diary_screen (5 API calls, 0 loading indicators) have ZERO |
| Success states confirm completion | After saving a workout, the app just pops back. No success toast, no celebration, no "Workout logged ✓" confirmation. 14 pop-backs happen with no success feedback |
| Network state is visible | Zero connectivity awareness. No offline indicator. No retry on failure |

**Critical failures:**
- Workout save: User taps "Save" → brief "..." → screen disappears. Did it save? User has no confirmation. For an action that captures 5-15 minutes of manual data entry, this is unacceptable.
- Diary API calls: 5 service calls with no loading indicator. If the server is slow, the diary looks frozen.
- Draft status: The workout screen auto-saves drafts silently (good), but never tells the user drafts exist or were restored (bad).

**HIG violation:** Apple requires "Provide feedback" — every user-initiated action must have perceptible acknowledgment within 100ms.

---

### H2: Match Between System and Real World
**Rating: 7/10 — Acceptable with gaps**

| Strength | Issue |
|---|---|
| "Sets", "Reps", "Weight" match gym vocabulary | "Duration Type: Repeating / Fixed" is developer language. Users think "ongoing" vs "has an end date" |
| "Strength" / "Cardio" segmented control | "Log Workout" title is vague — "Start Workout" (on the tab) is better but they're different screens with the same purpose |
| Day names (Mon–Sun) in schedule | "Plan Routines" section heading is confusing — does "Plan" refer to the workout plan or the action of planning? |

**Fitness-specific concern:** The app uses "exercise" and "workout" interchangeably in some places. A workout contains exercises. When the app says "Add Exercise" at the screen level vs "Add Exercise" inside a workout card, the hierarchy is unclear.

---

### H3: User Control and Freedom
**Rating: 5/10 — Partial**

| Good | Bad |
|---|---|
| New Workout has PopScope exit protection with "Discard?" dialog | Only 1 screen (New Workout) protects against accidental back navigation |
| Draft persistence in workout logging | No undo after deleting a workout from history |
| Dismissible swipe-to-delete on exercises | Dismissible fires immediately — no "undo" snackbar appears |
| Plan Builder has edit mode | No way to duplicate a plan or routine (must rebuild from scratch) |

**Critical failures:**
- **Swipe-to-delete has no undo.** User accidentally swipes an exercise with 4 sets of entered data → it's gone. No recovery. This violates both Nielsen H3 and Tognazzini's "Protect Users' Work."
- **Routine Builder has no exit protection.** If you accidentally tap back while building a routine with 8 exercises, all work is lost. Only New Workout has PopScope.
- **Plan Builder has no exit protection.** Same issue — `context.pop()` destroys all unsaved state.
- **Delete workout from history has no confirmation on some paths.** The `AdaptiveContextMenu` fires `onDelete` directly.

---

### H4: Consistency and Standards
**Rating: 3/10 — Systemic failure**

This is the app's weakest area. Documented extensively in the Component Consistency Audit, but summarized through the heuristic lens:

- **Page titles:** 5 different sizes (17, 18, 22, 24, 28)
- **Close buttons:** 4 different implementations
- **Cards:** 4 different construction patterns
- **Delete actions:** 3 different interaction models (icon, swipe, context menu)
- **Add buttons:** 4 different heights
- **Section headings:** 2 sizes (16, 18) with no clear rule
- **Typography tokens:** 2.4% adoption rate (9/380 declarations)
- **Border radius tokens:** ~20% adoption (15+ raw values vs 7 tokens)

**Platform standard violation:** Apple HIG states "Adopt standard UI components — don't reinvent patterns users already understand." The app uses AppGlassButton AND InkWell+Container AND CupertinoButton AND GestureDetector+Container for the same semantic action.

---

### H5: Error Prevention
**Rating: 4/10 — Weak**

| Error Type | Prevention Exists? |
|---|---|
| Double-tap on save | ✓ Yes (41 `_saving`/loading guards) |
| Invalid number input in workout | ✗ No — `int.parse()` crashes on non-numeric input |
| Empty workout save | ✓ Partially — `_canSave` checks for data |
| Accidental back during data entry | ✗ Only New Workout has PopScope (1/6 builder screens) |
| Saving with network down | ✗ No connectivity check — silent failure or crash |
| Duplicate food logging | ✗ No duplicate detection |
| Setting impossible values (e.g., 0 sets) | ✓ Stepper has min/max bounds |
| Entering future dates for workouts | ✗ No date validation |
| Session expiry during long workout | ✗ No token refresh during use |

**Critical:** The app has 71 "validation" related code points but most are `int.tryParse` null checks, not proactive form validation with user-facing messages. There is no `Form` widget with `GlobalKey<FormState>` pattern used properly — validation is ad-hoc, scattered, and inconsistent.

---

### H6: Recognition Rather Than Recall
**Rating: 6/10 — Moderate**

| Good | Bad |
|---|---|
| Previous session data shown in exercise cards | Users must remember exercise names to search (no recent/favorites list in search) |
| Day circles show schedule at a glance | Users must remember which routine has which exercises (no preview from plan view) |
| Category colors provide visual memory aids | Coach tab is empty unless AI is configured — user must recall where to set it up |
| Active plan is badged with "Active" | No "last used" indicator on routines — which one did I do last? |

**Fitness-specific concern:** The app shows "LAST SESSION" data inside exercise cards (excellent), but doesn't show "last time this routine was performed" on the routine list. Users can't tell if a routine is stale.

---

### H7: Flexibility and Efficiency of Use
**Rating: 5/10 — Adequate for beginners, weak for power users**

| For Beginners | For Power Users |
|---|---|
| Setup wizard guides initial configuration | No keyboard shortcuts |
| Add Exercise search is accessible | No batch operations (can't copy last workout, can't duplicate sets) |
| Preset plans available | No templates system |
| One-tap to log from scheduled plan | No quick-log for repeated meals |
| | No "repeat yesterday's workout" shortcut |
| | No rest timer customization per exercise |
| | Tab bar re-tap scroll-to-top is undiscoverable |

**Tognazzini principle violated:** "Reduce latency" — common repeated tasks should be faster on subsequent uses. The app treats every workout logging session as a fresh start.

---

### H8: Aesthetic and Minimalist Design
**Rating: 6/10 — Visually ambitious but noisy in places**

| Clean | Cluttered |
|---|---|
| Workout history cards are well-structured | Diary screen: 62% of text at 11px creates a wall of tiny text |
| Plan Builder has clear card sections | New Workout exercise card packs: name + category + LAST SESSION + column headers + sets + duration input — too much in one card |
| Coach screen (when active) is focused | Menu screen mixes profile, settings, AI config, and actions in one scroll with inconsistent card patterns |

**Specific noise issue:** The New Workout exercise card contains 7 visual zones (header, category, previous data, column headers, set rows, add button, duration). This should be 4 maximum. Duration should be at the workout level, not per-exercise.

---

### H9: Help Users Recognize, Diagnose, and Recover from Errors
**Rating: 2/10 — Nearly absent**

| What Should Exist | What Actually Exists |
|---|---|
| Clear error messages in user language | Raw error states ("Failed to load") with no explanation |
| Specific field-level validation messages | No inline validation — errors only appear after submit attempt |
| Guidance on how to fix the error | "Enter a valid duration" — but doesn't say what's valid (min? max? format?) |
| Retry mechanisms | ErrorState widget has `onRetry` — used in 3 places only |
| Network error recovery | Zero connectivity handling. API failures propagate as raw exceptions |
| Expired session recovery | No token refresh. Expired auth = crash, not "please log in again" |

**Critical gap:** The service layer (auth_service, workouts_service, nutrition_service, etc.) has **zero error handling**. Every API call can throw an unhandled exception. When it does, the user sees either nothing (swallowed error) or a red Flutter error screen (crash).

---

### H10: Help and Documentation
**Rating: 2/10 — Minimal**

- No onboarding walkthrough after setup (user drops into empty diary)
- No tooltips on complex UI (what does the fire icon mean? what's "volume"?)
- No help section in menu
- No contextual hints on empty states (EmptyState widget exists but messages are generic)
- Coach tab is supposed to help but requires AI configuration first — circular dependency
- No "what's new" or feature discovery
- 4 total tooltip/help instances in entire codebase

---

## Layer 2: WCAG 2.2 Compliance Audit

### 2.1 Perceivable

| Criterion | Status | Evidence |
|---|---|---|
| **1.1.1 Non-text Content** | ❌ FAIL | 13 total `Semantics` labels in entire app. Hundreds of icons, images, and decorative elements have no alt text. Screen readers cannot interpret most UI. |
| **1.3.1 Info and Relationships** | ❌ FAIL | No semantic structure. Headers are not marked as headers. Lists are not marked as lists. Form fields have no associated labels in accessibility tree. |
| **1.3.4 Orientation** | ✓ PASS | App works in portrait. No forced orientation. |
| **1.4.1 Use of Color** | ⚠️ PARTIAL | Category colors (chest=orange, legs=green) convey meaning without text alternative in some contexts. ~20 color-only meaning instances. |
| **1.4.3 Contrast (Minimum)** | ⚠️ PARTIAL | `AppColors.textMuted` on dark background is light gray on dark gray — likely passes 4.5:1. But `.withAlpha(80)` patterns reduce contrast below thresholds. 30+ instances of `withAlpha(100-150)` on text. |
| **1.4.4 Resize Text** | ❌ FAIL | 0 references to `textScaleFactor` or `TextScaler`. App does not respond to system Dynamic Type settings. All text is fixed-size. |
| **1.4.11 Non-text Contrast** | ⚠️ PARTIAL | Glass buttons on dark backgrounds have insufficient contrast (screenshot-confirmed: "Add Set" button invisible). |
| **1.4.12 Text Spacing** | ✓ PASS | No custom letter-spacing restrictions that would break with user overrides. |

### 2.2 Operable

| Criterion | Status | Evidence |
|---|---|---|
| **2.1.1 Keyboard** | ❌ FAIL | 6 total FocusNode references. No keyboard navigation support. No tab order management. |
| **2.4.3 Focus Order** | ❌ FAIL | No explicit focus order. Tab key would land on elements in DOM order, not logical order. |
| **2.4.6 Headings and Labels** | ❌ FAIL | Headings are visual-only (Text widgets with large font). Not marked as semantic headings. |
| **2.4.7 Focus Visible** | ❌ FAIL | No focus ring styling. Focused elements are indistinguishable from unfocused. |
| **2.5.5 Target Size** | ❌ FAIL | 59+ interactive elements below 44×44pt minimum. Stepper buttons 26×26, picker toolbar buttons 32×32, set remove buttons 28×28. |
| **2.5.8 Target Size (Minimum)** | ⚠️ PARTIAL | Most buttons are 36+ px (Apple minimum is 44pt). The 26px steppers are severe violations. |

### 2.3 Understandable

| Criterion | Status | Evidence |
|---|---|---|
| **3.2.1 On Focus** | ✓ PASS | No unexpected context changes on focus. |
| **3.2.2 On Input** | ✓ PASS | Form inputs don't trigger navigation. |
| **3.3.1 Error Identification** | ❌ FAIL | Errors are not programmatically identified. Snackbar errors disappear. No persistent error display on fields. |
| **3.3.2 Labels or Instructions** | ⚠️ PARTIAL | Form fields have placeholder text but lose context once filled. Required fields marked with "*" but not semantically. |
| **3.3.3 Error Suggestion** | ❌ FAIL | "Enter a valid duration" — doesn't say what's valid. No suggestions. |
| **3.3.4 Error Prevention** | ⚠️ PARTIAL | Destructive actions (delete workout) mostly have confirmations. But swipe-to-delete has no confirmation. |

### 2.4 Robust

| Criterion | Status | Evidence |
|---|---|---|
| **4.1.2 Name, Role, Value** | ❌ FAIL | Custom widgets (GestureDetector buttons, Container cards) have no accessible name, role, or value. Only `Semantics`-wrapped elements (13 total) are accessible. |

**WCAG 2.2 Overall: ~30% compliance.** The app would fail any formal accessibility audit.

---

## Layer 3: Apple Human Interface Guidelines Evaluation

### Navigation and Structure

| HIG Principle | Compliance | Issue |
|---|---|---|
| Use standard navigation patterns | ⚠️ Partial | Tab bar is standard. But full-screen routes bypass tab structure without clear navigation model |
| Prefer system-provided controls | ❌ Fail | Custom GestureDetector buttons replace UIButton, custom containers replace UITableViewCell, custom sheets miss standard handle and gesture behavior |
| Provide clear back navigation | ✓ Pass | Chevron-left back buttons on all sub-screens |
| Don't force modality | ✓ Pass | Sheets and dialogs are dismissible |
| Support standard gestures | ⚠️ Partial | Swipe-to-delete exists but is inconsistent (some cards, not others) |

### Feedback and Responsiveness

| HIG Principle | Compliance | Issue |
|---|---|---|
| Provide haptic feedback for significant actions | ⚠️ Partial | `HapticFeedback.selectionClick()` on steppers (routine builder). Missing on saves, deletes, errors. |
| Show activity indicators for operations > 1s | ❌ Fail | Workouts_screen and diary_screen have 0 loading indicators despite 5-6 API calls each |
| Use appropriate animation duration (250-400ms) | ✓ Pass | AnimatedContainer transitions use 200-300ms |
| Acknowledge destructive actions visually | ❌ Fail | Swipe-delete has no undo bar. Delete confirmation exists for plans but not for exercises within a workout |

### Typography (HIG)

| HIG Principle | Compliance | Issue |
|---|---|---|
| Support Dynamic Type | ❌ Fail | 0 TextScaler references. All text is fixed. |
| Use SF Pro with standard weights | ⚠️ Partial | System font is used but 15 arbitrary sizes instead of Apple's recommended type scale |
| Minimum body text 11pt | ⚠️ Partial | 10pt text exists in exercise search (2 instances) |
| Maintain consistent type scale | ❌ Fail | 15 distinct sizes. Apple recommends 7-9 sizes max in a type scale |

### Components (HIG)

| HIG Principle | Compliance | Issue |
|---|---|---|
| Use standard button styles | ❌ Fail | 6+ button implementations instead of UIButton variants |
| Standard cell heights (44pt minimum) | ❌ Fail | List rows and buttons frequently below 44pt |
| Standard sheet presentation | ⚠️ Partial | `showAppSheet` uses bottom sheet correctly, but internal layout varies wildly |
| Use SF Symbols consistently | ⚠️ Partial | Mix of SF Symbols and Material Icons in same screens |

---

## Layer 4: Tognazzini Interaction Design Principles

### Anticipation
**Rating: 3/10**

The app does not anticipate user needs:
- No pre-filled values based on history (only "LAST SESSION" data shown, not auto-filled)
- No suggested exercises based on routine/plan
- No auto-detection of workout completion
- No proactive rest timer (only starts after a set is logged)
- No "you usually log at this time" prompts

### Autonomy
**Rating: 6/10**

Users have reasonable freedom to choose, but:
- Cannot reorder exercises during a workout (no drag-and-drop in new_workout)
- Cannot skip exercises in a routine (must complete in order or manually manage)
- Cannot customize the dashboard/diary layout
- Can choose strength/cardio toggle freely ✓
- Can add custom exercises ✓

### Discoverability
**Rating: 4/10**

**Hidden features that users will never find without being told:**
1. Tab bar re-tap scrolls to top (no visual hint)
2. Context menu on workout history cards (no "..." indicator)
3. Swipe-to-delete on exercises (no visual affordance)
4. Plan card is tappable to edit (no chevron, no "Edit" label)
5. Set row is tappable to open picker (no "tap to edit" hint on "—" placeholder)
6. Draft auto-save in workout logging (no "draft saved" indicator)
7. Alternative exercises exist as a dropdown on the exercise name (no visual distinction from static text)

**Tognazzini's Law:** "If a feature is important, it must be visible."

### Fitts's Law
**Rating: 5/10**

Fitts's Law states: Time to reach target = f(distance/size). Targets should be large and close to the cursor/finger.

**Violations:**
- Stepper +/- buttons: 26×26px with 26px spacing = high error rate
- Set remove button: 28×28 at the far right edge of the card (maximum distance from thumb zone)
- Picker toolbar buttons: 32×32 at top of sheet (thumb must stretch)
- "Add Set" button is full-width (good) but 34px tall (below comfortable tap zone)
- Plan action icons (play/delete): ~30px touch area at top-right corner (far from natural thumb position)

**Well-applied:**
- "Add Exercise" button: full-width × 40px (comfortable)
- Save button: always top-right, 72-90px wide (easy to find and hit)
- Segmented control: full-width, tall segments (good)

### Protect Users' Work
**Rating: 3/10**

| Protection | Exists? |
|---|---|
| Auto-save draft during workout | ✓ (new_workout only) |
| Confirm before discarding workout | ✓ (PopScope + dialog) |
| Confirm before discarding routine | ✗ No protection |
| Confirm before discarding plan edits | ✗ No protection |
| Undo after delete | ✗ Never |
| State restoration after app kill | ✗ 0 RestorableProperty usage |
| Prevent accidental navigation during input | ✗ Only 1/6 builder screens |

**Most critical gap:** If the app is killed by iOS (background memory pressure) during workout logging, the draft is in SharedPreferences but there's no "resume workout" prompt on next launch. The user must discover it themselves.

### Readability
**Rating: 5/10**

- 10px text exists (below minimum)
- 62% of diary text is 11px (too dense)
- No Dynamic Type support (fails users with low vision)
- Low contrast on `.withAlpha()` text (calculated: ~2.5:1 for alpha=100 on dark background)
- Good: Font family (system SF Pro) is highly legible
- Good: Most body text at 14px is comfortable

### Visible Navigation
**Rating: 7/10**

- Tab bar always visible with 4 clear icons ✓
- Current tab is highlighted ✓
- Sub-screens show back button consistently ✓
- But: No indication of "depth" (how many screens deep am I?)
- But: Plan Builder → Routine Builder → Exercise Search = 3 levels deep with no breadcrumb

---

## Layer 5: Design System QA

### Token Adoption Scorecard

| Token Category | Defined | Used | Adoption Rate |
|---|---|---|---|
| Colors (`AppColors`) | 40+ | ~80% of screens | **80%** |
| Spacing (`AppSpacing`) | 7 values | ~5% of spacing | **5%** |
| Radius (`AppRadius`) | 7 values + 3 named | ~20% of radii | **20%** |
| Typography (`AppTextStyles`) | 10 styles | 9 references (theme.dart only) | **2.4%** |
| Icon sizes (`AppIconSize`) | 5 values | ~15% of icons | **15%** |
| Shadows (`AppColors.cardShadow`) | 2 defined | ~40% of cards | **40%** |

**Diagnosis:** The design system exists on paper but is not enforced in practice. Only colors have meaningful adoption. The type system is entirely unused by screen code.

### Component Standardization Score

| Component | Patterns Found | Should Exist | Standardized? |
|---|---|---|---|
| Primary button | 6+ patterns | 1 (AppGlassButton) | ❌ No |
| Card container | 4 patterns | 1 (AppCard) | ❌ No |
| Close/dismiss button | 4 patterns | 1 | ❌ No |
| Section heading | 3 styles | 1 | ❌ No |
| Form label | 4 styles | 1 | ❌ No |
| Chip/badge | 4+ patterns | 1 (AppChip needed) | ❌ No |
| Stepper control | 1 inline pattern | 1 (AppStepper needed) | ❌ No |
| Empty state | 1 (EmptyState widget) | 1 | ✓ Yes |
| Error state | 1 (ErrorState widget) | 1 | ✓ Yes |
| Loading skeleton | Inline per screen | 1 (AppSkeleton needed) | ❌ No |

**2 out of 10 common components are properly standardized.**

### Missing Design System Documentation

- [ ] Design principles document
- [ ] Component library / catalog
- [ ] Design tokens specification (defined but undocumented)
- [ ] Accessibility checklist
- [ ] Screen QA checklist
- [ ] Flow QA checklist
- [ ] Copy/content guidelines
- [ ] Interaction/state rules
- [ ] Pre-release audit template
- [ ] UX bug taxonomy

**None of these 10 minimum documents exist.**

---

## Flow-Based Audit

### Flow 1: Workout Logging (Critical Path)

**Steps:** Tab "Workouts" → "Log Workout" or scheduled routine → Add Exercise → Search → Select → Enter Sets → Save

| Step | Heuristic | Issue | Severity |
|---|---|---|---|
| 1. Tap "Log Workout" | H1 Feedback | No transition animation to full-screen | Low |
| 2. Search exercise | H6 Recognition | No "Recent" or "Favorites" section — must recall exercise name | Medium |
| 3. Add exercise | H1 Feedback | Exercise appears in list — acceptable | Pass |
| 4. Tap set row | H5 Error Prevention | Placeholder shows "—" with no "tap to edit" hint. Picker opens — good once discovered | Medium |
| 5. Enter weight/reps | H1 Feedback | Picker wheel is smooth but picker title says "Set 1" in tiny text (11px) — hard to confirm which set you're editing | Low |
| 6. Remove a set | H3 Control | 28px red dot button. After tap, set is gone immediately. No undo. No confirmation. | High |
| 7. Swipe exercise | H3 Control | Entire exercise + all sets disappear. No undo. No "are you sure?" | Critical |
| 8. Tap Save | H1 Feedback | Button shows "..." briefly. Screen pops. No success confirmation. User wonders "did it save?" | High |
| 9. App killed mid-workout | H7 Efficiency | Draft exists in SharedPreferences but no "Resume?" prompt on relaunch | Medium |

**Flow score: 5/10** — Functional but fragile. No undo, no success state, poor discoverability of tap-to-edit.

---

### Flow 2: Meal/Food Logging

**Steps:** Tab "Diary" → Date → Tap meal "+" → Search food → Select → Adjust serving → Log

| Step | Issue | Severity |
|---|---|---|
| Food search | No loading indicator during API search | Medium |
| Select food | Opens food detail — good | Pass |
| Adjust serving | Custom picker for serving size — works | Pass |
| Log | Taps confirm → returns to diary. No visible success. Item just appears in list | Medium |
| Delete food | Context menu → "Delete" → immediate removal, no undo | High |

**Flow score: 6/10** — Mostly smooth but silent on success/failure.

---

### Flow 3: Plan/Routine Building

**Steps:** Workouts tab → Plans → Create Plan → Name + Duration → Add Routine → Add Exercises → Assign to Days → Save

| Step | Issue | Severity |
|---|---|---|
| Navigate to plans | Requires knowing plans exist under Workouts tab | Medium (discoverability) |
| Create plan form | No required field indication until save attempt | Medium |
| Add Routine sheet | GestureDetector buttons with no accessibility | High |
| Routine Builder nested | 3 screens deep with no exit protection on routine builder | Critical |
| Back from routine → plan | State restoration works via provider invalidation | Pass |
| Save plan | "Saving..." text, then pop. No success state | Medium |

**Flow score: 4/10** — Deep nesting, no protection against accidental back, complex multi-screen flow with no guidance.

---

### Flow 4: Onboarding

**Steps:** Auth → Setup (6 steps) → Diary (empty)

| Step | Issue | Severity |
|---|---|---|
| Setup completion | Goes directly to empty diary with no "what to do next" guidance | High |
| First empty diary | Shows EmptyState but no "quick start" actions | Medium |
| Finding features | No walkthrough, tooltips, or onboarding hints | Medium |
| Coach tab | Empty unless AI configured — user must discover this in Menu first | High |

**Flow score: 4/10** — Setup itself is polished (gradient, animations) but dumps user into void afterward.

---

## Recurring Checklist Evaluation

| Check | Status | Notes |
|---|---|---|
| **Clarity** (3-5 second comprehension) | ⚠️ | Most screens clear. Routine Builder and Plan Builder complex. |
| **Primary action obvious** | ⚠️ | Save button always visible. But "Add Set" is invisible (contrast). |
| **Hierarchy** (most important dominates) | ⚠️ | Diary calorie number dominates well. Exercise cards are flat/uniform. |
| **Consistency** | ❌ | Systemically inconsistent (documented in Component Audit) |
| **Navigation** (always know where you are) | ✓ | Tab bar + back buttons work |
| **Feedback** (every tap acknowledged) | ❌ | Saves have no success state. Deletes have no undo. |
| **Error prevention** | ❌ | Only 1/6 builders have exit protection. Parse crashes exist. |
| **Recovery** | ❌ | No undo anywhere. No retry on network failure. |
| **Discoverability** | ❌ | 7+ hidden gestures/features with no visual hint |
| **Efficiency** | ⚠️ | Adequate for beginners. No power-user shortcuts. |
| **Accessibility** | ❌ | ~30% WCAG compliance. No Dynamic Type. 13 semantic labels. |
| **Empty/loading/error/success states** | ⚠️ | Empty: 4 screens. Loading: 38 indicators (unevenly applied). Error: 3 screens. Success: 0 dedicated states. |
| **Content quality** | ⚠️ | Most labels clear. Some developer language. No microcopy system. |
| **Layout system** | ❌ | Token system exists but 5% adoption. |
| **Component quality** | ❌ | 2/10 components standardized. |
| **State consistency** | ❌ | No hover/focus/disabled states documented or consistently applied. |
| **Data resilience** | ❌ | No offline, no retry, no stale data handling. |
| **Trust** | ⚠️ | Looks polished in happy path. Breaks down at edges. |
| **Performance feel** | ⚠️ | Generally smooth. But unprotected API calls can freeze UI. |

---

## Priority Action Plan

### Fix Immediately (Blocks Production Quality)

| # | Action | Principle Violated | Impact |
|---|---|---|---|
| 1 | **Add success feedback after save actions** | H1, H9 | Users don't know if their workout/meal/plan saved |
| 2 | **Add undo for swipe-to-delete** | H3, Tognazzini Protect Work | Data loss with no recovery on most-used features |
| 3 | **Add PopScope exit protection to Routine Builder and Plan Builder** | H3, H5 | Minutes of work destroyed by accidental back tap |
| 4 | **Fix all crash-path validations** (`int.parse`, null access) | H5, H9 | App crashes on bad input |
| 5 | **Add loading indicators to diary_screen and workouts_screen** | H1 | Screens appear frozen during API calls |
| 6 | **Fix set remove button rendering** (red dot → visible button) | H4, H6, Fitts | Users cannot identify or use the remove action |
| 7 | **Fix "Add Set" button contrast** on dark theme | WCAG 1.4.11, H1 | Core action is invisible |
| 8 | **Enforce 44pt minimum touch targets** | WCAG 2.5.5, HIG | 59+ violations. Stepper buttons barely usable. |

### Fix Soon (Reduces Systemic Drift)

| # | Action | Principle Violated | Impact |
|---|---|---|---|
| 9 | **Normalize page title size to 22px** | H4 | Visual inconsistency across all screens |
| 10 | **Consolidate card, button, and close patterns** | H4, HIG | 4 card patterns → 1. 6 button patterns → 1. |
| 11 | **Add Semantics labels to all interactive elements** | WCAG 4.1.2 | Screen readers cannot use the app |
| 12 | **Add network error handling to service layer** | H9, H5 | Silent failures, crashes, frozen UI |
| 13 | **Support Dynamic Type** | WCAG 1.4.4, HIG | Fixed text excludes low-vision users |
| 14 | **Build component library** (AppChip, AppStepper, AppFieldLabel, AppSectionHeader) | H4, Design System | Prevents future inconsistency |
| 15 | **Add onboarding hints after setup** | H10, H6 | New users land in empty void |
| 16 | **Make hidden actions discoverable** (context menus, swipe) | Tognazzini Discoverability | 7+ features users will never find |

### Improve Later (Polish and Prevention)

| # | Action | Principle Violated | Impact |
|---|---|---|---|
| 17 | **Migrate all inline TextStyle to AppTextStyles tokens** | H4, Design System | 380 raw declarations → type system |
| 18 | **Add state restoration** (RestorableProperty) | H7, Tognazzini | App kill during workout loses context |
| 19 | **Add offline mode / queue** | H9, Robustness | Network loss = dead app |
| 20 | **Build pre-release audit checklist** | Process | Prevents new issues entering product |
| 21 | **Add "Recent" and "Favorites" to exercise search** | H6, H7 | Reduces recall burden for repeat users |
| 22 | **Add analytics tracking** (rage taps, drop-offs, error rates) | Measurement | Catches UX issues design reviews miss |
| 23 | **Create copy/content guidelines** | H2, H10 | Prevents inconsistent language |
| 24 | **Document interaction state rules** (hover, pressed, disabled, error) | H4, Design System | Prevents state drift |

---

## What Class of Issues Must Be Prevented

Instead of fixing issues one by one, the app needs **systemic gates:**

| Class of Issue | Prevention Mechanism |
|---|---|
| Inconsistent components | Enforced design system with lint rules |
| Missing feedback states | Pre-release checklist: every action must show result |
| Accessibility violations | Automated accessibility testing in CI |
| Typography drift | Lint rule: ban raw `fontSize:` — require token |
| Crash on bad input | Unit test for every `parse()` and `.fromJson()` |
| Data loss on back/kill | Default: all builders get PopScope + draft save |
| Hidden gestures | Rule: every action must have a visible trigger |
| Contrast failures | Automated contrast checker in CI |
| Missing loading states | Code review rule: every `await Service.x()` needs a loading indicator |
| Platform standard violations | Review against HIG/Material checklist per PR |

---

## Summary Scorecard

| Evaluation Layer | Score | Grade |
|---|---|---|
| H1: Visibility of System Status | 4/10 | D |
| H2: Match Real World | 7/10 | B |
| H3: User Control and Freedom | 5/10 | C |
| H4: Consistency and Standards | 3/10 | F |
| H5: Error Prevention | 4/10 | D |
| H6: Recognition vs Recall | 6/10 | C+ |
| H7: Flexibility and Efficiency | 5/10 | C |
| H8: Aesthetic Minimalism | 6/10 | C+ |
| H9: Error Recovery | 2/10 | F |
| H10: Help and Documentation | 2/10 | F |
| WCAG 2.2 Compliance | ~30% | F |
| Apple HIG Compliance | ~50% | D |
| Tognazzini Principles | ~40% | D |
| Design System Enforcement | ~15% | F |
| **Overall UX Quality** | **4.2/10** | **D** |

**The app's real problem is not any single UI bug. It is the absence of a formal review framework and an enforced design system. Until those exist, the same classes of issues will keep appearing with every new feature.**

---

## Recommended Minimum Documentation (Create These)

1. **Design principles** — 5-7 rules that guide all design decisions
2. **Component library** — Visual catalog of every approved component with usage rules
3. **Design tokens spec** — Colors, spacing, radius, typography, shadows, icon sizes — with enforcement
4. **Accessibility checklist** — Per-component and per-screen requirements
5. **Screen QA checklist** — States (empty/loading/error/success), contrast, targets, labels
6. **Flow QA checklist** — Entry, exit protection, success feedback, error recovery, undo
7. **Copy guidelines** — Voice, tone, label patterns, error message format, button text rules
8. **Interaction state rules** — What hover/pressed/disabled/selected/loading looks like for each component
9. **Pre-release audit template** — Repeatable checklist run before every release
10. **UX bug taxonomy** — Categories, severities, SLA for each class

---

*End of Framework Audit*
