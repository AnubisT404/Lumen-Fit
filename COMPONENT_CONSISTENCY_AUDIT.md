# Component Consistency & Visual System Audit

**Date:** 2026-05-28  
**App:** Fitness Flutter App  
**Auditor:** Senior UI Systems Designer / Design QA  
**Scope:** All screens, widgets, tokens, and component patterns

---

## 1. Overall Component Consistency Summary

**Rating: 5/10 — Fragmented System**

This app has a well-defined design token system (`AppSpacing`, `AppRadius`, `AppColors`, `AppTextStyles`) that is frequently bypassed. The token system exists but is not enforced. Hardcoded values dominate actual screen implementations, creating drift between the design system's intent and the shipped product.

**Core problems:**
- **4 distinct card construction patterns** coexist instead of one unified component
- **Button heights vary from 32px to 56px** with no clear sizing taxonomy
- **Border radius values range from 2px to 44px** with at least 15 distinct values used, despite only 7 tokens defined
- **Spacing between sections varies randomly** (6, 8, 10, 12, 14, 16, 20, 22, 24, 28, 32px) without consistent rhythm
- **Typography is inlined in 90%+ of cases** — `AppTextStyles` tokens are almost never used in screen code
- **The setup screen uses a completely different visual language** from the rest of the app

The app feels like 3-4 designers worked independently. The diary, workouts, and coach tabs are reasonably cohesive. The setup screen, goals screen, and plan builder are from different visual universes.

---

## 2. Top Visual Inconsistencies

| # | Issue | Severity | Impact |
|---|-------|----------|--------|
| 1 | 4 competing card construction patterns | High | Fragmented visual identity |
| 2 | Button heights range 32-56px with no taxonomy | High | Unpredictable touch targets |
| 3 | 15+ hardcoded border radius values bypass 7 tokens | High | Visual incoherence |
| 4 | AppTextStyles tokens unused — inline styles everywhere | High | Typography drift |
| 5 | Setup screen is a completely different design language | Medium | Broken brand continuity |
| 6 | Section spacing has no consistent rhythm | Medium | Layout feels arbitrary |
| 7 | Two toolbar styles (PickerToolbar vs PickerIconToolbar) for same context | Medium | Interaction inconsistency |
| 8 | Icon sizes vary 13-48px without consistent contextual mapping | Medium | Visual noise |
| 9 | Field labels differ between screens (uppercase vs sentence, different sizes) | Medium | Cognitive inconsistency |
| 10 | Chips/pills use different styling per screen | Low | Polish deficit |

---

## 3. Button Audit

### 3.1 Button Types Inventory

| Type | Where Used | Height | Radius | Behavior |
|------|-----------|--------|--------|----------|
| `AppGlassButton` (AdaptiveButton) | Headers, CTAs, new workout, workouts | 36-44px | Stadium/glass | Primary action |
| `ElevatedButton` (theme-styled) | Auth screen | 50px | Stadium | Full-width CTA |
| `AdaptiveButton.plain` | Error retry (menu, measurements) | Auto | 20px | Ghost/text |
| `GestureDetector + Container` | Setup buttons, intensity selectors, chips | 32-56px | 12-16px | Custom tap areas |
| `CupertinoButton` | Water add/reset in diary | 44px | None | Icon buttons |
| `InkWell` | Settings rows, food items, list items | Variable | None/row-based | List taps |
| `AdaptiveButton.sfSymbol` | Close buttons, picker toolbars | 32-36px | Circle | Icon action |

### 3.2 Critical Button Issues

---

**Issue: Inconsistent primary CTA heights across screens**  
**Severity:** High  
**Component type:** Button  
**Screens:** Auth (50px), Workouts CTA (44px), New Workout "Add Exercise" (40px), Goals Picker Toolbar (36px), Setup Continue (implicit ~48px via padding:16 + text)  
**What is inconsistent:** The "main action" button on each screen is a different height. Auth uses 50px ElevatedButton, Workouts uses 44px AppGlassButton, New Workout uses 40px AppGlassButton, Chat uses 44px AppGlassButton.  
**Why it is a problem:** Users unconsciously learn button sizes as affordances. Varying heights signal different importance levels even when the semantic weight is identical.  
**User impact:** Reduced perceived quality; the app feels assembled rather than designed.  
**Design system impact:** No single "primary button" component exists that guarantees consistent behavior.  
**Recommended fix:** Define 3 button sizes in the token system: `small` (32px), `medium` (40px), `large` (48px). Map all CTAs to these sizes. All primary full-width CTAs must be `large`.  
**Scope:** Standardize globally.

---

**Issue: Setup screen builds custom buttons with GestureDetector instead of using button components**  
**Severity:** High  
**Component type:** Button  
**Screen:** Setup screen (lines 763-850)  
**What is inconsistent:** `_sexButton`, `_unitButton`, `_continueButton`, and `_navButtons` are all hand-built with `GestureDetector + AnimatedContainer`. They share no code with the app's button system (ElevatedButton, AppGlassButton, AdaptiveButton).  
**Why it is a problem:** These buttons have no press states, no accessibility semantics, no disabled opacity animation, and no haptic feedback. They also use `padding: EdgeInsets.symmetric(vertical: 14)` for sex/unit buttons but `padding: EdgeInsets.symmetric(vertical: 16)` for the continue button — different heights for buttons in the same step.  
**User impact:** Buttons feel dead on press (no visual feedback). VoiceOver/TalkBack users get no button role semantics.  
**Design system impact:** Entire screen is outside the component system.  
**Recommended fix:** Replace with `AdaptiveButton` variants or create a `SetupButton` that extends the theme's button styles with the gradient/dark background treatment.  
**Scope:** Standardize locally (setup screen), inform global button system.

---

**Issue: Touch targets below 44px minimum**  
**Severity:** High  
**Component type:** Button  
**Screens:** Picker toolbars (32×32 icon buttons), exercise search chips (32px height), nutrition detail filter buttons (32px height), workout_widgets set buttons (34×34)  
**What is inconsistent:** Apple HIG requires 44×44pt minimum touch targets. Multiple interactive elements are 32-34px.  
**Why it is a problem:** Users with motor impairments or large fingers will mis-tap these controls. Even dexterous users will need higher precision than necessary.  
**User impact:** Frustration, mis-taps, reduced speed.  
**Design system impact:** No enforced minimum size token.  
**Recommended fix:** Add `AppSize.minTouchTarget = 44` token. Wrap small-visual buttons with `SizedBox(width: 44, height: 44)` and use `padding: EdgeInsets.zero` for visual sizing while maintaining the hit area.  
**Scope:** Standardize globally.

---

**Issue: Inconsistent close/back button sizing and style**  
**Severity:** Medium  
**Component type:** Button  
**Screens:** New Workout (36×36 xmark), Exercise Search (36×36 chevron.left), Nutrition Detail (36×36), Picker toolbar (32×32 xmark), Goals screen (36×36 chevron.left), Chat (36×36 + 34×34 mixed in same screen)  
**What is inconsistent:** Close/dismiss buttons are 36×36 in most places but 32×32 in picker toolbars. Chat screen mixes 36×36 and 34×34 in the same header area.  
**Why it is a problem:** Even a 2px inconsistency is noticeable when buttons appear at the same visual layer. Picker toolbars feel tighter than screen headers for no semantic reason.  
**Recommended fix:** All header nav buttons should be 36×36. All embedded toolbar buttons should be 36×36. Remove the 32×32 and 34×34 variants.  
**Scope:** Standardize globally.

---

## 4. Card Audit

### 4.1 Card Construction Patterns Inventory

| Pattern | Usage | Padding | Radius | Shadow |
|---------|-------|---------|--------|--------|
| `AppCard` widget | Workouts CTA, workout history, plan banners, hydration, weight/exercise dashboard | 16 (default) or 12 | `AppRadius.lg` (16) | `cardShadow` or `cardShadowElevated` |
| `AppColors.cardDecoration` | Coach screen cards, new_workout exercise cards | 14 | `AppRadius.lg` (16) | `cardShadow` |
| Inline `Container + BoxDecoration` | Nutrition card (diary), Meal type cards, Menu settings group, Setup step cards, Plan builder | 12-20 | 6-16 (mixed) | Custom or none |
| `Container + _cardDecor` | Coach screen sections | 14 | `AppRadius.lg` (16) | `cardShadow` |

### 4.2 Critical Card Issues

---

**Issue: Four distinct card construction patterns for the same visual component**  
**Severity:** High  
**Component type:** Card  
**Screens:** All  
**What is inconsistent:** `AppCard`, `AppColors.cardDecoration`, `Container(decoration: BoxDecoration(...))`, and `_cardDecor`/`_dashCard` helper all produce visually similar cards but with subtly different behavior. `AppCard` uses `AppRadius.cardRadius` (16). Inline cards use hardcoded `BorderRadius.circular(16)`, `12`, or even mix values within one screen.  
**Why it is a problem:**
1. Bug risk: Changes to the design token won't propagate to inline cards
2. Inconsistency: `_NutritionCard` in diary uses `AppRadius.lg` + `cardShadow` but no border, while `AppCard` always adds a border
3. Maintenance burden: Fixing a shadow/radius value requires hunting through every screen  
**Design system impact:** The `AppCard` widget exists but isn't the exclusive way to make cards. It should be.  
**Recommended fix:** Migrate ALL card-like containers to `AppCard`. Add a `border` parameter (already exists as `showBorder`/`borderColor`). Delete `cardDecoration`, `cardDecorationElevated` static getters — they encourage bypassing the widget.  
**Scope:** Standardize globally — this is an architecture-level issue.

---

**Issue: Card padding varies from 10px to 20px for equivalent content**  
**Severity:** Medium  
**Component type:** Card  
**Screens:** Diary (nutrition card: 14, hydration: 12×10, weight/exercise: 12), Workouts (AppCard default: 16), New Workout (exercise card: 14), Coach (14), Menu settings (14×13)  
**What is inconsistent:** Cards containing structurally similar content (icon + label + value) use 10, 12, 14, or 16px padding depending on which screen they appear on. The hydration card uses asymmetric `EdgeInsets.symmetric(horizontal: 12, vertical: 10)` while adjacent weight/exercise cards use `EdgeInsets.all(12)`.  
**Why it is a problem:** Adjacent cards in the same scroll view have different internal visual density, making the layout feel janky.  
**Recommended fix:** Define 2 card padding tokens: `compact` (12) and `standard` (16). Use compact for data-dense dashboard cards and standard for everything else.  
**Scope:** Standardize globally.

---

**Issue: Meal type cards use different shadow from all other cards**  
**Severity:** Low  
**Component type:** Card  
**Screen:** Diary — `_MealTypeCard`  
**What is inconsistent:** Uses `BoxShadow(color: AppColors.shadowSubtle, blurRadius: 3)` + `BoxShadow(color: AppColors.shadowSubtle, blurRadius: 8)` while the rest of the app uses `AppColors.cardShadow` (which uses `shadowLight` not `shadowSubtle`).  
**Why it is a problem:** Meal cards appear visually flatter/ghostlier than dashboard cards directly above them in the same scroll.  
**Recommended fix:** Use `AppColors.cardShadow` consistently.  
**Scope:** Correct locally.

---

## 5. Spacing and Layout Audit

### 5.1 Section Spacing Inventory

Gaps between major sections in scrollable content:

| Screen | Between cards/sections | Values used |
|--------|----------------------|-------------|
| Diary | 8, 8, 8, 14, 10, 10, 10, 24 | Inconsistent |
| Workouts | 6, 10, 22, 10, 20 | Inconsistent |
| Coach | 14, 14, 14, 14 | ✓ Consistent |
| Menu | 32, 28, 28, 24 | Roughly consistent |
| New Workout | 12, 12, 12, 16, 16, 16 | Two rhythms |
| Setup | 20, 16, 16, 10, 20 | Mixed |

### 5.2 Critical Spacing Issues

---

**Issue: Diary screen section spacing is random**  
**Severity:** Medium  
**Component type:** Spacing  
**Screen:** Diary content  
**What is inconsistent:** `SizedBox(height: 10)` after week streak, `SizedBox(height: 8)` between nutrition→hydration, `SizedBox(height: 8)` between hydration→weight/exercise row, `SizedBox(height: 14)` before meals, `SizedBox(height: 10)` between meal cards. Five different gap values in one scroll view.  
**Why it is a problem:** The eye cannot identify a rhythm. The layout looks "off" without users being able to articulate why. Visual rhythm (consistent beat) creates perceived quality.  
**Recommended fix:** Use `AppSpacing.md` (12) between compact dashboard cards and `AppSpacing.lg` (16) before new content sections. Two values, predictable rhythm.  
**Scope:** Standardize globally — define "section gap" and "card gap" semantic spacing tokens.

---

**Issue: ListView padding inconsistent across screens**  
**Severity:** Medium  
**Component type:** Layout  
**Screens:** Diary (left:16, right:16, bottom:80), Workouts (left:16, right:16, bottom:100), Menu (16, 8, 16, 80), Measurements (16, 8, 16, 80), Coach (16, 10, 16, bottomPad)  
**What is inconsistent:** The bottom padding varies from 80 to 100+ and the top start differs (some 6, some 8, some 10). The content inset from left/right edges is consistently 16 — that's good. But vertical rhythms differ.  
**Why it is a problem:** Different screens "breathe" differently at top and bottom. The 80 vs 100 bottom padding is likely accounting for the nav bar but the values should be calculated from the actual nav bar height + safe area, not hardcoded differently per screen.  
**Recommended fix:** Create `AppSpacing.navBarSafeBottom` calculated token. Use consistent top padding start (e.g., always 8).  
**Scope:** Standardize globally.

---

**Issue: `AppSpacing` tokens defined but almost never imported in screen files**  
**Severity:** High  
**Component type:** Spacing  
**Screens:** All  
**What is inconsistent:** The theme defines `AppSpacing.xs(4), sm(8), md(12), lg(16), xl(20), xxl(28), xxxl(32)`. Searching across all screen files, raw numbers like `8`, `12`, `16`, `20` are used directly instead of the tokens. The tokens exist but have zero adoption.  
**Why it is a problem:** The tokens provide no value if they're not used. Any spacing change requires finding and updating dozens of hardcoded values across the codebase.  
**Design system impact:** The spacing system is decorative documentation, not an enforced system.  
**Recommended fix:** Lint rule or code review policy: no raw spacing values in screen code. All gaps must reference `AppSpacing.*`.  
**Scope:** Standardize globally — this is a process/tooling issue.

---

## 6. Typography and Icon Audit

### 6.1 Typography Issues

---

**Issue: AppTextStyles tokens unused — every screen creates inline TextStyles**  
**Severity:** High  
**Component type:** Typography  
**Screens:** All  
**What is inconsistent:** `AppTextStyles` defines `display(28/w800)`, `title(18/w700)`, `heading(20/w700)`, `subheading(15/w600)`, `body(14/w400)`, `bodyMedium(14/w500)`, `label(13/w500)`, `caption(12/w500)`, `small(12/w500/muted)`, `micro(11/w600/muted)`. In actual screens, these are recreated inline:
- `TextStyle(fontSize: 18, fontWeight: FontWeight.w700)` instead of `AppTextStyles.title`
- `TextStyle(fontSize: 13, fontWeight: FontWeight.w600)` instead of `AppTextStyles.label`
- `TextStyle(fontSize: 11, fontWeight: FontWeight.w600)` instead of `AppTextStyles.micro`  
**Why it is a problem:** Font sizes drift. The goals screen uses `fontSize: 16` for section headers while menu uses `fontSize: 15`. The workout screen uses `fontSize: 17` for the title while the coach screen uses `fontSize: 18`. Without enforced token usage, each dev picks "what looks right" and the system fragments.  
**Recommended fix:** Enforce token usage via code review. Consider making AppTextStyles the only way to get font sizes — e.g., a lint rule flagging raw `fontSize:` in TextStyle declarations.  
**Scope:** Standardize globally.

---

**Issue: Field labels styled differently across screens**  
**Severity:** Medium  
**Component type:** Typography  
**Screens:** New Workout `_FieldLabel` (11/w600/muted/letterSpacing:0.5), Setup `_fieldLabel` (11/w700/muted/letterSpacing:0.8/UPPERCASE), Goals screen settings rows (15/w500)  
**What is inconsistent:** The same semantic element — "label above a form field" — is:
- Uppercase 11px w700 in setup
- Lowercase 11px w600 in new workout
- Sentence case 15px w500 in goals  
**Why it is a problem:** Users cannot build a consistent mental model of "this is a label" across the app.  
**Recommended fix:** Create one `AppFieldLabel` widget that enforces consistent styling. Decide: uppercase micro or sentence-case label. Use one pattern everywhere.  
**Scope:** Standardize globally.

---

**Issue: Section header font sizes inconsistent**  
**Severity:** Medium  
**Component type:** Typography  
**Screens:** Menu group labels (11/w700/letterSpacing:0.8/uppercase), Workouts session count (11/w700/muted), Measurements "History" (16/w600), Coach section titles (16/w700), Diary has no explicit section headers  
**What is inconsistent:** "Section title" means 11px uppercase in one place and 16px title-case in another.  
**Recommended fix:** Define 2 levels: `sectionLabel` (small uppercase, like Menu) and `sectionTitle` (16px, like Measurements). Map consistently.  
**Scope:** Standardize globally.

---

### 6.2 Icon Issues

---

**Issue: Icon sizes vary without clear hierarchy**  
**Severity:** Medium  
**Component type:** Icon  
**Screens:** Multiple  
**What is inconsistent:** `AppIconSize` defines `small(14), base(16), medium(18), large(24), xlarge(32)` but usage shows: 13, 14, 16, 18, 20, 22, 24, 30, 32, 40, 48px icons used. Sizes like 13, 20, 22, 30, 40, 48 are not in the token system at all. Within the menu screen: settings row icons are 18px, chevrons are 20px, and trailing icons are 16px — three sizes in one list.  
**Why it is a problem:** The icon scale feels arbitrary. Tokens lose credibility when 8+ sizes exist outside the system.  
**Recommended fix:** Collapse to the 5 defined tokens. Map: inline/micro icons → `small(14)`, standard row icons → `medium(18)`, action icons → `large(24)`, hero/empty state → `xlarge(32)`. Remove the 20px/22px intermediate sizes.  
**Scope:** Standardize globally.

---

## 7. Design System Gaps

### 7.1 Missing Components That Should Exist

| Component | Current State | Why It Should Be Standardized |
|-----------|--------------|-------------------------------|
| `AppButton` (sized variants) | 6+ button construction patterns | One button, 3 sizes, 4 styles |
| `AppFieldLabel` | 3 different implementations | One label style for all forms |
| `AppSectionHeader` | Inline text everywhere | Consistent section separation |
| `AppChip` / `AppPill` | Built differently in exercise search, diary quick-add, coach suggestions, intensity selector | One chip component with active/inactive states |
| `AppListTile` / `AppSettingsRow` | Only exists privately in menu screen | Needed in goals, measurements, nutrition |
| `AppToolbar` (sheet header) | `PickerToolbar` and `PickerIconToolbar` coexist | One toolbar with text/icon variants |
| `AppProgressBar` | Inline in diary (calorie bar), setup (step progress), hydration (segment bar) | One component, configurable |
| `AppBadge` / `AppTag` | Built inline in diary (remaining/over), coach, add_food | One badge with color variants |

### 7.2 Tokens That Need to Be Added

| Token | Proposed Value | Rationale |
|-------|---------------|-----------|
| `AppSize.minTouchTarget` | 44 | Apple HIG / Android material minimum |
| `AppSize.buttonSmall` | 32 | Icon-only buttons in toolbars |
| `AppSize.buttonMedium` | 40 | Standard inline buttons |
| `AppSize.buttonLarge` | 48 | Primary full-width CTAs |
| `AppSpacing.cardGap` | 12 | Between adjacent cards |
| `AppSpacing.sectionGap` | 20 | Between distinct content sections |
| `AppSpacing.screenPaddingH` | 16 | Horizontal page margin (already 16 everywhere, make it a token) |
| `AppSpacing.listBottomSafe` | nav height + safe area | Bottom content padding |
| `AppRadius.chip` | 16 | Pill/chip radius |
| `AppRadius.badge` | 10 | Small badges/tags |
| `AppRadius.input` | 10 | Text input fields (currently hardcoded in cupertinoDecoration) |

### 7.3 Design System Enforcement Score

| Aspect | Token Exists? | Actually Used? | Score |
|--------|:---:|:---:|:---:|
| Colors | ✓ | ~80% adoption | Good |
| Spacing | ✓ | ~5% adoption | Failing |
| Radius | ✓ | ~20% adoption | Poor |
| Typography | ✓ | ~10% adoption | Failing |
| Icon sizes | ✓ | ~15% adoption | Poor |
| Button sizes | ✗ | N/A | Missing |
| Card component | ✓ (AppCard) | ~50% adoption | Moderate |
| Shadows | ✓ | ~60% adoption | Moderate |

---

## 8. Screen-Specific Consistency Findings

### 8.1 Setup Screen — Different Design Universe

**Severity:** Medium  
The setup screen uses:
- Full gradient background (no other screen does this)
- White text on dark gradient (unique to this screen)
- Custom `GestureDetector` buttons with no press feedback
- `BoxShadow` with `AppColors.textPrimary.withValues(alpha: 0.1)` instead of token shadows
- Decorative background circles (no other screen has decorative elements)
- Radio-style selection cards with unique styling
- Activity level "intensity bars" — a one-off micro visualization

**Assessment:** This is clearly an onboarding splash designed to feel premium, but it shares zero components with the main app. After setup completes, the user enters a completely different visual world. This creates a "bait and switch" feeling.

**Recommended fix:** Either bring the main app's quality up to match the setup polish, or simplify setup to use the same card/button/layout language as the rest of the app. A dramatic visual shift between onboarding and main app erodes trust.

### 8.2 Goals Screen — Settings List Pattern Differs From Menu

**Severity:** Low  
The goals screen uses plain `_settingsRow` with `InkWell` and `Divider`, while the menu screen uses `_buildGroup` with a rounded `Container`, `Border.all`, and internal dividers with `indent: 58`. They look related but are built differently with different visual density.

### 8.3 Measurements Screen — Uses AppBar When No Other Tab Screen Does

**Severity:** Medium  
The measurements screen is the ONLY screen that uses `AppBar(title: const Text('Weight & Measurements'))` with the standard Material app bar. All other screens use custom header rows (DateNavigator, goals header, new workout header). This makes the measurements screen look like it belongs to a different app.

**Recommended fix:** Replace AppBar with the same custom header pattern (back button + centered title) used in goals, nutrition detail, and new workout screens.

---

## 9. Radius / Border / Shadow Inconsistency Audit

### 9.1 Border Radius Values Found in Screen Code

| Value | Count | Token Equivalent | Assessment |
|-------|-------|-----------------|------------|
| 2 | 4 | None | Too many tiny radii |
| 3 | 3 | None | Not in system |
| 4 | 4 | `AppRadius.xs` | Rarely used token |
| 6 | 5 | None | Not in system |
| 7 | 4 | None | Not in system |
| 8 | 18 | `AppRadius.sm` | Used but not by name |
| 10 | 16 | None | **Most common non-token value** |
| 12 | 22 | `AppRadius.md` | Used but not by name |
| 16 | 25 | `AppRadius.lg` | Most common, often hardcoded |
| 17 | 1 | None | One-off |
| 18 | 2 | None | Not in system |
| 20 | 4 | `AppRadius.xl` | Used but not by name |
| 24 | 1 | None | Not in system |
| 44 | 3 | `AppRadius.xxl` | Used for sheets |

**Critical finding:** `10` is the most common non-token radius value (16 uses) and it has no corresponding token. This needs to be added to `AppRadius` or consolidated to 8 or 12.

### 9.2 Shadow Patterns

| Pattern | Usage | Issue |
|---------|-------|-------|
| `AppColors.cardShadow` | AppCard, _dashCard, cardDecoration | ✓ Correct |
| `AppColors.cardShadowElevated` | AppCard.elevated | ✓ Correct |
| `shadowSubtle` (custom) | Meal type cards | ✗ Different from all other cards |
| `BoxShadow(textPrimary * 0.1, blur: 20)` | Setup step cards | ✗ One-off |
| `BoxShadow(indigo * 0.3, blur: 8)` | Setup sex/unit buttons | ✗ One-off |
| `BoxShadow(textPrimary * 0.08, blur: 12)` | Setup goal target card | ✗ One-off |
| No shadow | Coach suggestion chips, menu toggle | Design choice |

**Assessment:** Setup screen uses 3 different shadow patterns that exist nowhere else in the app. The main app is reasonably consistent with `cardShadow` but the meal card exception creates a visible inconsistency in the diary view.

---

## 10. Chips, Tabs, and Selection Controls

---

**Issue: Category chips styled differently in every context**  
**Severity:** Medium  
**Component type:** Chip  
**Screens:** Exercise search (32px, orange active, radius:16, background: white@15%), Coach suggestions (glass-styled pills), Diary quick-add chips (34px), Nutrition detail date filters (32px)  
**What is inconsistent:** Active/inactive colors, heights, border styles, and radii differ in every usage of "horizontal scrollable options."  
**Why it is a problem:** Users must re-learn what "selected" looks like in each context.  
**Recommended fix:** Create `AppChip` with `selected`/`unselected` states, `compact`/`standard` sizes, and optional `color` parameter.  
**Scope:** Standardize globally.

---

**Issue: Segmented controls mixed with custom chip-bar patterns**  
**Severity:** Low  
**Component type:** Tab/Segmented  
**Screens:** New Workout uses `AdaptiveSegmentedControl` for Strength/Cardio. Menu uses custom `GestureDetector` toggles for theme/unit. Exercise search uses custom chips for category.  
**What is inconsistent:** Three patterns for "select one of N options." The AdaptiveSegmentedControl is the cleanest and most accessible, but it's only used once.  
**Recommended fix:** Use `AdaptiveSegmentedControl` for 2-3 options, `AppChip` horizontal scroll for 4+ options. Remove custom GestureDetector toggles.  
**Scope:** Standardize globally.

---

## 11. Form Input Consistency

---

**Issue: Two distinct input styling approaches coexist**  
**Severity:** Medium  
**Component type:** Input  
**Screens:** Setup uses `AdaptiveTextFormField` with no explicit decoration (relies on theme). New Workout/Measurements/AI Config use `AdaptiveTextField` with `cupertinoDecoration: BoxDecoration(color: surfaceAlt, borderRadius: 10)`. Theme defines `inputDecorationTheme` with radius 16.  
**What is inconsistent:** The theme says inputs have radius 16 with outline borders. The actual usage overrides to radius 10 with filled-no-border style. The theme is wrong (or unused).  
**Why it is a problem:** If a developer trusts the theme and uses a plain `TextField`, it'll look different from the `AdaptiveTextField` with `cupertinoDecoration`. Two visual languages for the same control.  
**Recommended fix:** Update `inputDecorationTheme` to match what's actually used (radius 10, filled, no visible border). Or create an `AppTextField` widget that wraps `AdaptiveTextField` with the correct decoration baked in.  
**Scope:** Standardize globally.

---

**Issue: Measurements add-sheet uses radius 20 for sheet container while picker_sheet uses radius 20 (matching), but showIconPickerSheet uses radius 44**  
**Severity:** Low  
**Component type:** Input/Sheet  
**Screens:** Measurements add sheet (radius: 20), Picker sheets (radius: 20), Icon picker sheets (radius: 44)  
**What is inconsistent:** Two different sheet corner radii for functionally identical bottom sheets.  
**Recommended fix:** Use `AppRadius.sheetRadius` (44) consistently for all bottom sheets. The token exists — use it.  
**Scope:** Correct locally in measurements screen.

---

## 12. Priority Fixes

### Fix Immediately (High UX risk)

1. **Set remove button renders as unrecognizable red dots (§13.0)**  
   The `SFSymbol('minus', size: 11)` at 28×28 renders as two red dots, not a button. Increase to 14pt, add background, or switch icon pattern. **Usability-breaking.**

2. **"Add Set" button invisible on dark theme (§13.0)**  
   Glass button with no accent/border is indistinguishable from card background. Add border or accent tint. **Core flow blocker.**

3. **Alert dialog uses system blue tint instead of app orange (§13.0)**  
   Set `CupertinoThemeData(primaryColor: AppColors.orange)` or build custom dialog. **Visual trust break.**

4. **SET column header text cramped / overlapping category label (§13.0)**  
   Increase spacing above SET/WEIGHT/REPS header from 10px to 16px. **Readability issue.**

5. **Add minimum touch target enforcement (44px)**  
   All 32px buttons (picker toolbars, exercise search chips) must expand their hit area to 44×44. This is an accessibility violation. **Also applies to the 26×26 stepper +/- buttons in routine builder** (see §13.2).

6. **Consolidate card patterns to `AppCard` only**  
   Delete `AppColors.cardDecoration`/`cardDecorationElevated` getters. Update the ~12 inline `Container(decoration: BoxDecoration(surface, radius, shadow))` instances to use `AppCard`. ~2 hours work.

7. **Fix setup screen button accessibility**  
   Replace `GestureDetector + Container` buttons with `Semantics(button: true)` wrapper or proper button widgets. Users with assistive tech currently cannot identify these as buttons.

8. **Unify close/dismiss buttons across all screens**  
   Replace all `InkWell+Container` close buttons and bare `CupertinoButton` icon buttons with `AppGlassButton(sfSymbol: 'xmark')`. 4 patterns → 1 (see §13.1).

### Standardize Next (1-2 sprint items)

5. **Create `AppChip` reusable component**  
   Unify the 4 different chip implementations into one widget with `active/inactive`, `compact/standard` size, and `color` parameter.

6. **Enforce `AppSpacing` token usage**  
   Replace all hardcoded `SizedBox(height: N)` spacing with semantic tokens. Add `cardGap(12)` and `sectionGap(20)` semantic tokens.

7. **Create `AppFieldLabel` widget**  
   One field label implementation (decide: uppercase 11px or sentence-case 13px) used across all forms.

8. **Standardize button heights**  
   Define and enforce `small(32)`, `medium(40)`, `large(48)` sizing. Map every existing button to one of these sizes. Specific focus on "Add" action buttons which currently use 30/34/40/44 (see §13.5).

9. **Replace measurements screen AppBar**  
   Use the same custom header pattern as all other screens.

10. **Add `AppRadius` token for value 10**  
    `10` appears 16 times in screen code with no token. Add `AppRadius.inputRadius = 10` or consolidate to `AppRadius.md(12)`.

11. **Unify secondary action patterns across cards**  
    Pick a consistent model for "delete/more" actions: visible icon buttons + context menu fallback. Remove reliance on undiscoverable-only patterns (see §13.3).

12. **Create `AppStepper` reusable component**  
    Replace the inline 26×26 GestureDetector +/- buttons with a proper stepper component that enforces 44px touch targets and uses AppGlassButton styling (see §13.2).

13. **Standardize toggle controls**  
    Replace custom menu screen toggles with `AdaptiveSegmentedControl` or create `AppToggle` component. One pattern for "pick one of N" (see §13.6).

### Polish Later (Nice-to-have)

14. **Harmonize setup screen with main app visual language**  
    The gradient onboarding is impressive but the brand disconnect with the main app is jarring.

15. **Standardize all inline `TextStyle` declarations to use `AppTextStyles` tokens**  
    This is a large-scale refactor (~200+ instances) that should be done incrementally.

16. **Unify toolbar patterns**  
    Merge `PickerToolbar` and `PickerIconToolbar` into one configurable widget.

17. **Add semantic spacing documentation**  
    Document when to use `cardGap` vs `sectionGap` vs `screenPadding` so future contributors maintain consistency.

18. **Consolidate shadow values**  
    Remove the `shadowSubtle` variant from meal cards. Fix setup screen's custom shadows. Everything should use `cardShadow` or `cardShadowElevated`.

19. **Normalize navigation chevron sizes**  
    All trailing chevrons should be 20px (currently varies 18-22px across screens, see §13.4).

20. **Add edit/navigate affordance to plan cards**  
    Plan cards are tappable to edit but show no chevron or "Edit" label. Users cannot tell they're interactive (see §13.4).

---

## 13. Close, Toggle, +/-, More, and Edit Button Audit

This section specifically examines action buttons that appear across plans, routines, workout history, and builder screens.

### 13.0 CRITICAL: Screenshot-Confirmed Bugs

#### Issue: Set Remove Button Renders as Two Red Dots — Unrecognizable as a Button
**Severity:** Critical  
**Component type:** Button / Icon rendering  
**Screen:** New Workout → Exercise Card (set rows)  
**What is wrong:** The set remove button (`AppGlassButton(sfSymbol: SFSymbol('minus', size: 11), color: AppColors.danger)` at 28×28) renders on-screen as **two tiny red/orange dots** rather than a recognizable minus "—" symbol. The SF Symbol `'minus'` at 11pt inside a glass button with the danger color creates a visual artifact that looks like a decorative indicator, not an interactive button.  
**Evidence:** Screenshot "15.42.33" clearly shows each set row ending with what appears to be two red dots aligned vertically/diagonally — not a button affordance.  
**Why it is a problem:** Users cannot identify this as a "remove set" button. It looks like a status indicator or decorative element. There is no recognizable icon shape, no button container visible at this size, and the dual-dot rendering makes it look broken.  
**User impact:** Users will not discover how to delete individual sets. They'll try swipe-to-delete (which removes the entire exercise, not a single set) or give up.  
**Design principle violated:** Affordance, recognition over recall, feedback  
**Recommended fix:**
1. Increase icon size from 11 to at least 14
2. Add a visible container/background (even subtle) so it reads as a button
3. Consider using `Icons.remove_circle_outline` as a Material fallback since the SF Symbol at tiny sizes is unreadable
4. Or switch to a visible "×" (xmark) pattern matching other close buttons in the app
5. Consider 32×32 minimum with danger-tinted background fill  
**Scope:** Fix immediately — this is a usability-breaking rendering issue.

---

#### Issue: "SET" Column Header Text Clipped / Overlapping with Category Label
**Severity:** High  
**Component type:** Layout / Spacing  
**Screen:** New Workout → Exercise Card  
**What is wrong:** The exercise card stacks: exercise name → category label ("arms") → SET/WEIGHT/REPS headers → set rows. The vertical spacing between the category text and the "SET" column header is too tight (`SizedBox(height: 10)` between the "previousSets" section or category and the header row). On device, the "SET" text appears cramped against the content above it, making the headers feel jammed/overlapping. When there is NO "LAST SESSION" box, the jump from "arms" directly to "SET WEIGHT REPS" header with minimal spacing creates a visual collision.  
**Evidence:** Screenshot "15.42.33" — "arms" text and "SET" header are very close with barely visible separation. In "15.43.03" the "Barbell Curls" card (without LAST SESSION data) shows the category "arms" running directly into "SET WEIGHT REPS" with insufficient breathing room.  
**Why it is a problem:** The column headers (SET, WEIGHT, REPS) are critical for understanding the data layout. When they're visually crushed against the content above, users' eyes skip over them, making the set rows harder to parse.  
**Code location:** `new_workout_screen.dart:1001-1018` — the spacing before the set header is only 10px (`SizedBox(height: 10)`) which is inadequate after the previous section (either category text at line 970-973 or the LAST SESSION box).  
**Recommended fix:**
1. Increase spacing before SET header to 14-16px
2. Add a subtle divider or stronger visual break between the exercise info zone and the data entry zone
3. Consider making SET/WEIGHT/REPS header sticky or more visually prominent (slightly larger font, or a background bar)  
**Scope:** Fix immediately.

---

#### Issue: Alert Dialog ("Discard Workout?") Not Consistent with App Theme
**Severity:** High  
**Component type:** Dialog / Visual consistency  
**Screen:** New Workout → X button → Discard confirmation  
**What is wrong:** The "Discard Workout?" dialog uses the native iOS `UIAlertController` via `IOS26AlertDialog` (platform view with `alertStyle: 'glass'`). This renders with:
- A **light/system blurred glass background** that clashes with the app's dark theme
- "Keep Editing" in **blue/purple** (system tint) — the app uses orange as its primary action color
- "Discard" in **red** — acceptable for destructive, but the overall dialog looks like it came from a different app
- The dialog font, spacing, and button layout follow iOS system conventions, not the app's design language  
**Evidence:** Screenshot "15.43.03" — the dialog sits on top of the dark-themed workout screen. The dialog has a clearly lighter background tone, the "Keep Editing" text is a blue-purple that appears nowhere else in the app (the app's cancel/secondary actions are typically grey/muted, not blue), and the visual weight of the native frosted glass doesn't match the custom glass buttons used elsewhere.  
**Why it is a problem:** The alert breaks the immersive dark theme. Every other element on screen follows the app's custom dark UI with orange accents. Then this system-native dialog pops up looking like iOS Settings interrupted the app. It signals "this app didn't fully implement its own UI" and breaks user trust in the design quality.  
**Technical root cause:** `AdaptiveAlertDialog.show()` on iOS 26+ uses a native `UiKitView` platform view (`ios26_alert_dialog.dart:171`). It passes `'isDark': _isDark` and a tint color from `CupertinoTheme.of(context).primaryColor`, but the app's `AppTheme` doesn't set `CupertinoThemeData.primaryColor` to orange — it likely falls back to the system blue.  
**Recommended fix:**
1. **Quick fix:** Set `CupertinoThemeData(primaryColor: AppColors.orange)` in the app's theme so the native dialog picks up the orange accent
2. **Better fix:** Build a custom in-app dialog using the app's own card style, button components, and color system — matching how the rest of the app looks
3. **Best fix:** If keeping the native dialog, override the tint explicitly: pass `iconColor` or modify the adaptive package to accept a custom tint parameter that overrides the system blue  
**Scope:** Fix immediately — this is visible every time a user tries to close an active workout.

---

#### Issue: "Add Set" Button Is Invisible (No Label Visible, Dark on Dark)
**Severity:** High  
**Component type:** Button / Contrast  
**Screen:** New Workout → Exercise Card → below set rows  
**What is wrong:** In Screenshot "15.42.33", below Set 4, there is a dark rectangular area that is the "Add Set" `AppGlassButton`. On the dark theme, this glass button has such low contrast that it's nearly invisible — it blends into the card background. There's no visible text label or border that distinguishes it from the card surface.  
**Evidence:** Screenshot "15.42.33" — below the 4 set rows, there's a dark rectangle with no visible text. This is the "Add Set" button (code: `AppGlassButton(label: 'Add Set', size: AdaptiveButtonSize.small)` at full-width × 34px). The glass effect on dark backgrounds makes the button label unreadable.  
**Why it is a problem:** The primary action for building a workout set list is invisible. Users cannot see how to add more sets. This defeats the entire purpose of the set-building UI.  
**Recommended fix:**
1. Add a visible border or slightly lighter fill to glass buttons on dark surfaces
2. Or use a subtle accent-tinted background (like the orange summary banner at 10-15% opacity)
3. Or add a "+" icon prefix to reinforce the label
4. Ensure minimum contrast ratio of 4.5:1 for button label text against button background  
**Scope:** Fix immediately — affects core workout logging flow.

---

### 13.1 Close / Dismiss / Delete Buttons — Complete Inventory

| Screen | Widget | Size | Construction | Icon | Feedback |
|--------|--------|------|-------------|------|----------|
| New Workout header | `AppGlassButton` | 36×36 | SF Symbol 'xmark' size 14 | ✓ Glass | ✓ Haptic |
| Workout History card | `AppGlassButton` | 28×28 | SF Symbol 'xmark' size 11 | ✓ Glass | ✓ Haptic |
| Exercise Form Card (workout_widgets) | `AppGlassButton` | 28×28 | SF Symbol 'xmark' size 11 | ✓ Glass | ✓ Haptic |
| Routine Builder exercise card | `InkWell + Container` | 28×28 | Material `Icons.close` size 14 | ✗ Custom fill | Ink ripple only |
| Routine Builder alternative remove | `InkWell + Container` | 24×24 | Material `Icons.close` size 12 | ✗ Custom fill | Ink ripple only |
| Picker Toolbar cancel | `AdaptiveButton` text | 80×36 | "Cancel" text label | ✓ Glass | ✓ Adaptive |
| Picker Icon Toolbar close | `AdaptiveButton.sfSymbol` | 32×32 | SF Symbol 'xmark' size 14 | ✓ Glass | ✓ Adaptive |
| Plans screen delete | `_ActionIcon` (CupertinoButton) | ~30×30 (padding:6) | Material `Icons.delete_outline` size 18 | ✗ No background | Cupertino opacity |
| Exercise search back | `AdaptiveButton.sfSymbol` | 36×36 | SF Symbol 'chevron.left' size 14 | ✓ Glass | ✓ Adaptive |

**Critical inconsistency:** The "close/remove" action is represented by **4 different component patterns**:
1. `AppGlassButton` with SF Symbol (new workout, workout history cards)
2. `InkWell + Container` with Material icon (routine builder)
3. `AdaptiveButton.sfSymbol` (picker toolbars)
4. `CupertinoButton` bare icon (plans screen `_ActionIcon`)

---

**Issue: Routine builder uses InkWell+Container close buttons while workout_widgets uses AppGlassButton**  
**Severity:** High  
**Component type:** Button  
**Screens:** Routine Builder vs Workout Widgets  
**What is inconsistent:** The routine builder exercise card (line 505-517) uses `InkWell` wrapping a `Container(width: 28, height: 28, decoration: BoxDecoration(color: CupertinoColors.systemFill, borderRadius: 8))` with `Icons.close`. The workout_widgets `ExerciseFormCard` (line 112-118) uses `AppGlassButton(sfSymbol: SFSymbol('xmark', size: 11))` at the same 28×28 size for the same semantic action ("remove this exercise").  
**Why it is a problem:** Two screens that serve essentially the same purpose (editing exercise lists) use visually different dismiss buttons. The routine builder looks Material/flat, the workout form looks iOS/glass. A user moving between these screens sees the same action rendered differently.  
**User impact:** Cognitive load; "is this the same action?" hesitation.  
**Recommended fix:** Replace all close/dismiss mini-buttons with `AppGlassButton(sfSymbol: 'xmark', size: 11)` at 28×28. One pattern, consistent across the app.  
**Scope:** Standardize globally — affects routine_builder, plan_builder add-routine sheet.

---

**Issue: Alternative remove button (24×24) is smaller than exercise remove button (28×28) in the same card**  
**Severity:** Medium  
**Component type:** Button  
**Screen:** Routine Builder (lines 634-648)  
**What is inconsistent:** The exercise close button is 28×28 in the header. The "remove alternative" button directly below it is 24×24. Both are `InkWell + Container` with `Icons.close`, but the alternative version is 4px smaller.  
**Why it is a problem:** Within the same card, two identical actions (remove something) have different button sizes. The 24×24 button is well below the 44px touch target minimum and is difficult to tap on mobile.  
**Recommended fix:** Both should be 28×28 minimum (visual), with a 44×44 hit area wrapper. Use the same component for both.  
**Scope:** Correct locally.

---

### 13.2 Stepper (+/-) Buttons

| Screen | Widget | Size | Construction | Icon Size | Touch Area |
|--------|--------|------|-------------|-----------|------------|
| Routine Builder sets/reps | `GestureDetector + Container` | 26×26 | Filled `CupertinoColors.systemFill`, radius 7 | `Icons.remove/add` size 14 | 26×26 ❌ |
| No other screen uses steppers | — | — | — | — | — |

---

**Issue: Stepper +/- buttons are 26×26 — dangerously small touch targets**  
**Severity:** High  
**Component type:** Button  
**Screen:** Routine Builder `_buildStepper` (lines 675-735)  
**What is inconsistent:** The +/- stepper buttons are `Container(width: 26, height: 26)` with `GestureDetector`. No padding expansion. The actual touch area is 26×26 pixels — barely larger than a fingertip's inaccuracy zone.  
**Why it is a problem:** These are high-frequency interaction targets. Users tap +/- repeatedly when setting target sets (1-10) and reps (1-50). With 26px targets and only 26px width for the number between them, users will frequently mis-tap the number or the wrong button.  
**User impact:** Frustration, mis-taps, accidental decrements when trying to increment.  
**Recommended fix:** 
1. Wrap in `SizedBox(width: 44, height: 44)` for the hit area
2. Keep the 26px visual size if desired, or grow to 32px for better visibility
3. Consider using the same picker wheel pattern as the workout screen (tap → wheel picker for the value) which is already proven  
**Scope:** Standardize — create `AppStepper` reusable component.

---

### 13.3 "More" / Action Menu Buttons

| Screen | Widget | Size | Construction | Trigger |
|--------|--------|------|-------------|---------|
| Plans screen (play/delete) | `_ActionIcon` | padding:6 around 18px icon | `CupertinoButton(padding: 6, minSize: 0)` | Direct tap |
| Workout History card | `AdaptiveContextMenu` | N/A (long press) | Context menu with destructive action | Long press |
| Diary food items | `AdaptiveContextMenu` | N/A (long press) | Context menu with edit + delete | Long press |
| Plan Routine Tile | `Dismissible` | N/A (swipe) | Swipe to delete | Swipe |
| Workout exercises | `Dismissible` (new_workout) | N/A (swipe) | Swipe to delete | Swipe |

---

**Issue: Three different "delete/action" patterns for cards — no consistent secondary action model**  
**Severity:** Medium  
**Component type:** Interaction pattern  
**Screens:** Plans, Workouts, Diary  
**What is inconsistent:**
1. Plans screen: Visible icon buttons (`_ActionIcon`) directly in the card — always visible, tap to act
2. Workout history: `AdaptiveContextMenu` on long-press — hidden action, discoverable only by guessing
3. Plan Routine Tile: `Dismissible` swipe-to-delete — another hidden gesture
4. Diary food items: Context menu AND swipe-to-delete AND visible delete after confirmation

The same semantic action ("delete this thing") requires different gestures depending on which screen you're on.  
**Why it is a problem:** Users learn one pattern (swipe) in workouts, then can't find the delete option in plans where it's a visible icon. Or they try long-pressing in plans (no context menu exists there).  
**User impact:** "How do I delete this?" confusion. Hidden affordances mean users never discover the action.  
**Recommended fix:** Pick one primary pattern and apply it consistently:
- **Visible actions** for primary cards (plans, workouts) — small icon button row
- **Context menu** as the discoverable secondary pattern everywhere
- **Swipe** as a shortcut that duplicates (never replaces) the visible/context menu action
Currently the plans screen does it best (visible icons). The workout history does it worst (context menu only — no visible hint that actions exist).  
**Scope:** Standardize globally.

---

**Issue: `_ActionIcon` in plans screen has no visual background — inconsistent with all other icon buttons**  
**Severity:** Medium  
**Component type:** Button  
**Screen:** Plans screen (lines 537-559)  
**What is inconsistent:** `_ActionIcon` is a bare `CupertinoButton(padding: 6, minSize: 0)` rendering just an icon with no background container. Every other icon button in the app (exercise search back, new workout close, picker toolbar buttons) uses `AppGlassButton` with a glass/frosted background fill.  
**Why it is a problem:** The play/pause and delete icons in plan cards look like decorative elements, not buttons. There's no visual affordance indicating they're tappable. The `hoverColor` parameter exists in the class but is never used (Cupertino buttons don't have hover states on mobile).  
**User impact:** Users may not realize these icons are tappable. Low discoverability.  
**Recommended fix:** Replace `_ActionIcon` with `AppGlassButton(sfSymbol: ..., size: small)` at 28×28 to match the workout card delete button pattern.  
**Scope:** Correct locally in plans_screen.

---

### 13.4 Edit / Navigate Buttons

| Screen | Widget | Action | Construction | Indicator |
|--------|--------|--------|-------------|-----------|
| Plan card | `GestureDetector` on entire card | Tap → edit plan | Full card tap | No chevron (implicit) |
| Plan Routine Tile | `GestureDetector` on entire tile | Tap → edit routine | Full tile tap | `Icons.chevron_right_rounded` size 18 |
| Routine Compact Card | `GestureDetector` on entire card | Tap → edit routine | Full card tap | `Icons.chevron_right_rounded` size 20 |
| Menu settings row | `InkWell` | Tap → navigate | Full row tap | `Icons.chevron_right_rounded` size 20 |
| Menu profile row | `GestureDetector` | Tap → setup | Full row tap | `Icons.chevron_right_rounded` size 22 |

---

**Issue: Chevron sizes inconsistent for the same "tap to navigate" affordance**  
**Severity:** Low  
**Component type:** Icon  
**Screens:** Plans (18px), Plans routine compact (20px), Menu settings (20px), Menu profile (22px)  
**What is inconsistent:** The trailing chevron that says "this row navigates somewhere" is 18, 20, or 22px depending on which list you're in. The Plan Routine Tile uses 18px while the nearly identical Routine Compact Card (same screen!) uses 20px.  
**Why it is a problem:** Inconsistent visual rhythm. The chevron is a system-level affordance — it should look identical everywhere.  
**Recommended fix:** All trailing navigation chevrons should be `Icons.chevron_right_rounded, size: 20, color: AppColors.iconMuted`. One size. Always.  
**Scope:** Standardize globally.

---

**Issue: Plan cards have no chevron but Routine tiles do — inconsistent navigate affordance**  
**Severity:** Low  
**Component type:** Interaction  
**Screen:** Plans screen  
**What is inconsistent:** `_UnifiedPlanCard` is tappable (goes to edit) but shows no chevron — the action icons (play/delete) visually dominate instead. `_PlanRoutineTile` and `_RoutineCompactCard` both show a trailing chevron. A user scanning the plans screen would assume plan cards are *not* tappable (no chevron) and routine rows *are* tappable (chevron present). But both are tappable.  
**Why it is a problem:** Visual affordance mismatch. The plan card's tap-to-edit is an invisible gesture.  
**Recommended fix:** Either add a chevron to plan cards or add an explicit "Edit" text button. The card is already tappable — users just can't tell.  
**Scope:** Correct locally.

---

### 13.5 "Add" Buttons in Builder Screens

| Screen | Label | Size | Construction | Position |
|--------|-------|------|-------------|----------|
| Plan Builder "Add Routine" | `AppGlassButton` | 110×30 | In section header row | Right of heading |
| Routine Builder "Add Exercise" | `AppGlassButton` | full-width × 40 | Below exercise list | Center |
| Routine Builder "Add alternative" | `AppGlassButton` | 130×30 | Inside exercise card | Left-aligned |
| New Workout "Add Exercise"/"Add More" | `AppGlassButton` | full-width × 40 | Below exercise list | Center |
| Workout widgets "Add Set" | `AppGlassButton` | full-width × 34 | Inside exercise card | Center |
| Plans screen "Create Custom Plan" | `AppGlassButton` | full-width × 44 | Bottom of list | Center |

---

**Issue: "Add" button heights vary (30, 34, 40, 44) across builder screens**  
**Severity:** Medium  
**Component type:** Button  
**Screens:** Plan builder, Routine builder, New Workout, Workout widgets, Plans screen  
**What is inconsistent:** The semantic action "add something to this list" uses 4 different button heights:
- 30px: Plan Builder "Add Routine", Routine Builder "Add alternative"
- 34px: Workout widgets "Add Set"
- 40px: Routine Builder "Add Exercise", New Workout "Add Exercise"
- 44px: Plans "Create Custom Plan"  
**Why it is a problem:** These are all the same pattern (add item to a list) but visual size suggests different importance levels. The user has no way to predict how big the next "add" button will be.  
**Recommended fix:** 
- Inline card actions (Add Set, Add alternative): `small` = 32px
- Section-level add buttons (Add Exercise): `medium` = 40px  
- Page-level primary CTAs (Create Plan): `large` = 44px
Map all instances to these 3 clear levels.  
**Scope:** Standardize globally.

---

### 13.6 Toggle / Segmented Controls

| Screen | Widget | Construction | Size | States |
|--------|--------|-------------|------|--------|
| New Workout Strength/Cardio | `AdaptiveSegmentedControl` | Platform-native segmented | Auto | 2 segments |
| Plan Builder Repeating/Fixed | `AdaptiveSegmentedControl` | Platform-native segmented | Auto | 2 segments |
| Menu theme toggle | `GestureDetector + AnimatedContainer` | Custom: 3 icon buttons in `surfaceAlt` row | ~(10+16+10)×(6+16+6) per option | 3 options (system/light/dark) |
| Menu unit toggle | `GestureDetector + AnimatedContainer` | Custom: 2 text buttons in `surfaceAlt` row | ~(14+text+14)×(6+text+6) per option | 2 options (kg/lb) |

---

**Issue: Toggle controls use two different patterns — AdaptiveSegmentedControl vs custom GestureDetector**  
**Severity:** Medium  
**Component type:** Tab/Segmented  
**Screens:** Menu (custom), New Workout + Plan Builder (AdaptiveSegmentedControl)  
**What is inconsistent:** "Pick one of N" is solved with the platform-appropriate `AdaptiveSegmentedControl` on builder screens but with custom pill toggles on the menu screen. The menu toggles have:
- Different radius (outer: 8, inner: 6) vs segmented control's native styling
- Different padding (10×6 for theme, 14×6 for unit — inconsistent even within menu)  
- No accessibility labels or roles
- Different animation timing (200ms manual vs native)  
**Why it is a problem:** Same interaction pattern, different visual treatment. The custom toggles also lack semantics — a screen reader user cannot identify them as radio groups.  
**Recommended fix:** Replace custom menu toggles with `AdaptiveSegmentedControl` or create an `AppToggle` component that wraps the same styling for icon-based options. Either way — one pattern, one component.  
**Scope:** Standardize globally.

---

### Summary Table: Action Button Inconsistencies

| Action | Patterns Found | Should Be |
|--------|---------------|-----------|
| Close/dismiss | 4 patterns | 1 (`AppGlassButton` xmark) |
| Remove from list | 3 patterns (InkWell+Container, AppGlassButton, CupertinoButton) | 1 (`AppGlassButton` xmark, 28×28) |
| Delete/destroy | 3 patterns (visible icon, context menu, swipe) | Visible + context menu + optional swipe |
| Navigate/edit | Chevron 18/20/22px + no-chevron cards | Chevron 20px everywhere |
| Add to list | 4 height variants (30, 34, 40, 44) | 3 sizes: inline(32), section(40), page(44) |
| Increment/decrement | 1 pattern but 26×26 (too small) | 32×32 visual, 44×44 hit area |
| Toggle selection | 2 patterns (native segmented vs custom) | 1 (`AdaptiveSegmentedControl` or `AppToggle`) |

---

## 14. Full Typography Size Audit

This section audits every text size used across the entire app — screens, sheets, pickers, alerts, popups, cards, labels — and evaluates whether the type scale is streamlined, consistent, and intentional.

### 14.1 Token System vs. Reality

**Defined `AppTextStyles` tokens (theme.dart):**

| Token | Size | Weight | Intended Role |
|-------|------|--------|---------------|
| `display` | 28 | w800 | Hero numbers, large displays |
| `heading` | 20 | w700 | Screen-level headings |
| `title` | 18 | w700 | Section titles |
| `subheading` | 15 | w600 | Sub-sections |
| `body` | 14 | w400 | Body text |
| `bodyMedium` | 14 | w500 | Emphasized body |
| `label` | 13 | w500 | Form labels |
| `caption` | 12 | w500 | Secondary info |
| `small` | 12 | w500 | Small text (duplicate of caption?) |
| `micro` | 11 | w600 | Badges, tiny labels |

**Actual usage: 9 references to `AppTextStyles` vs. 380 raw `fontSize:` declarations.**  
**Token adoption: 2.4%** — the type system is functionally dead.

---

### 14.2 Complete Font Size Census

| Size | Occurrences | Role Intended | Actually Used For |
|------|-------------|---------------|-------------------|
| **10** | 2 | ❌ Not in scale | Exercise search separator dots, "3×" count |
| **11** | 103 | `micro` token | Badges, column headers, metadata, category tags, timestamps, unit suffixes, EVERYTHING small |
| **12** | 68 | `caption`/`small` | Descriptions, secondary text, helper text, button labels, time displays |
| **13** | 51 | `label` | Form labels, body in coach, food names, error text, misc |
| **14** | 68 | `body`/`bodyMedium` | Primary content, exercise names, input text, row labels |
| **14.5** | 3 | ❌ Not in scale | Chat markdown body text only |
| **15** | 34 | `subheading` | Set data values, empty state titles, sheet titles, button labels |
| **16** | 17 | ❌ Not in scale | Sheet titles, rest timer, section labels, date navigator |
| **17** | 5 | ❌ Not in scale | Page titles (New Workout, Measurements), chat H2, AppBar |
| **18** | 14 | `title` token | Section headings, menu sections, workout card titles |
| **20** | 7 | `heading` token | Big stat values, food detail title, chat H1 |
| **21** | 7 | ❌ Not in scale | Picker wheel item text ONLY |
| **22** | 8 | ❌ Not in scale | Page titles (Plans, Routine Builder, Plan Builder, Menu), picker wheel |
| **24** | 2 | ❌ Not in scale | Setup screen title, Dev Tour title |
| **28** | 4 | `display` token | Auth title, diary calorie number, goals weight number |

**15 distinct font sizes in actual use. Token scale defines 8 unique sizes.**  
**7 sizes (10, 14.5, 16, 17, 21, 22, 24) are used without any token.**

---

### 14.3 Critical Typography Inconsistencies

#### Issue: Screen Page Titles Use 4 Different Sizes (17, 18, 22, 24, 28)
**Severity:** Critical  
**Component type:** Typography  
**What is inconsistent:** The exact same semantic element — "the screen title in the top navigation bar" — uses wildly different sizes:

| Screen | Title | Size | Weight |
|--------|-------|------|--------|
| Plans | "Workout Plans" | 22 | bold |
| Routine Builder | "Create Routine" | 22 | bold |
| Plan Builder | "Create Plan" | 22 | bold |
| Menu | User name | 22 | bold |
| Chat | "Set up AI Coach" | 22 | w700 |
| **New Workout** | "Log Workout" | **17** | w700 |
| **Measurements** | "Measurements" | **17** | w600 |
| **Workouts tab** | "Start Workout" | **18** | w700 |
| **Auth** | "Welcome Back" | **28** | w700 |
| **Setup** | Step title | **24** | bold |

**Why it is a problem:** The user navigates between screens and the page title (the biggest text in the header) jumps between 17, 18, 22, 24, and 28px. This creates:
- Uneven visual rhythm
- "Log Workout" at 17px looks cramped next to "Workout Plans" at 22px
- Users unconsciously perceive the 17px screens as "less important" or "subsidiary"

**User impact:** Visual inconsistency reduces perceived quality. The app feels assembled from different templates.  
**Recommended fix:** One page title size for all full-screen routes: **22px/bold** (already used by 5 screens). New Workout and Measurements must bump to 22. Auth can keep 28 as a hero/welcome state.  
**Scope:** Standardize globally.

---

#### Issue: Exercise Name Text Varies by Context (13 vs 14, w500 vs w600 vs w700)
**Severity:** High  
**Component type:** Typography  
**What is inconsistent:** The same data type — "exercise name displayed in a card/row" — uses different sizes and weights depending on which screen you're on:

| Context | Size | Weight | File |
|---------|------|--------|------|
| Workout History card (ExerciseFormCard) | 13 | w700 | workout_widgets.dart:105 |
| Workout History expanded row | 13 | w600 | workout_widgets.dart:481 |
| New Workout exercise card | 14 | w600 | new_workout_screen.dart:968 |
| Routine Builder exercise card | 14 | w600 | routine_builder_screen.dart:479 |
| Exercise Search results | 14 | w500 | exercise_search_sheet.dart:340 |
| Plan Routine Tile | 14 | w600 | plan_builder_screen.dart:736 |

**Why it is a problem:** The user sees the same exercise name (e.g., "Barbell Squats") rendered at different sizes and weights on different screens. The workout history uses 13/w700 while the logging screen uses 14/w600 — making the history feel denser/smaller even though it's showing the same data.  
**Recommended fix:** All exercise names = 14/w600. All workout titles = 14/w700. No exceptions.  
**Scope:** Standardize globally.

---

#### Issue: Secondary/Description Text Uses 3 Sizes Interchangeably (11, 12, 13)
**Severity:** High  
**Component type:** Typography  
**What is inconsistent:** Text that serves the role of "secondary information below a primary label" has no consistent size:

| Context | Size | Example |
|---------|------|---------|
| Exercise category tag | 11 | "arms", "chest" |
| Workout metadata | 11 | "3 exercises · 12 sets" |
| Plan duration info | 12 | "Repeating" |
| Routine exercise count | 12 | "5 exercises" |
| Coach insight body | 13 | Paragraph text |
| Food description | 13 | Nutrient info |
| Empty state subtitle | 13 | "Create a plan to schedule..." |
| Helper text (plan builder) | 12 | "Add routines to this plan..." |
| Error messages | 13 | Error description text |

Three sizes (11, 12, 13) all serve "supporting text below a title." There's no logic determining when 11 vs 12 vs 13 is used.

**Recommended fix:** Establish clear rules:
- **11px**: Badges, uppercase labels (SET/WEIGHT/REPS), metadata that's truly tertiary
- **12px**: Captions, timestamps, helper text  
- **13px**: Body-secondary (longer sentences, descriptions, error messages)

Then audit every instance and assign correctly.  
**Scope:** Standardize globally (~140 instances to review).

---

#### Issue: Section Headings Within Screens Use 16 or 18 (No Consistency)
**Severity:** Medium  
**Component type:** Typography  
**What is inconsistent:**

| Screen | Section Heading | Size | Weight |
|--------|----------------|------|--------|
| Plan Builder | "Plan Routines" | 18 | w600 |
| Plan Builder | "Weekly Schedule" | 18 | w600 |
| Routine Builder | "Exercises" | 18 | w600 |
| Menu | "AI Configuration" | 18 | w700 |
| Measurements | "Add Measurement" | 18 | w600 |
| Menu | "Complete Your Profile" | 16 | w600 |
| Routine Builder sheet | "Select Category" | 16 | w600 |
| Plan Builder sheet | "Add Routine to Plan" | 16 | w600 |
| Add Food | "Search for Foods" | 16 | w600 |

The pattern: **in-page section headings use 18**, **sheet/popup titles use 16**. This is actually reasonable but not documented or consistent — "Complete Your Profile" is in-page but uses 16.

**Recommended fix:** Enforce: in-page section headings = 18/w600, sheet titles = 16/w600. Fix "Complete Your Profile" to 18.  
**Scope:** Correct locally (1-2 instances).

---

#### Issue: Picker Wheel Text Size (21) Has No Token and Creates Orphan Scale
**Severity:** Low  
**Component type:** Typography  
**What is inconsistent:** Picker wheels (weight, reps, serving size) use fontSize 21/w400, which exists nowhere else in the type scale. The `AppTextStyles` token system jumps from `heading(20)` to `display(28)`. This 21px value is used 7 times exclusively in picker items.  
**Why it is a problem:** It's an orphan size that adds noise to the type inventory without serving a distinct role from 20.  
**Recommended fix:** Either use 20 (matches `heading` token) or add a `pickerItem = 21` token explicitly.  
**Scope:** Polish later.

---

#### Issue: Chat Screen Uses 14.5px — Not in Any Scale
**Severity:** Low  
**Component type:** Typography  
**Screen:** Chat/Coach  
**What is inconsistent:** The chat markdown renderer uses `fontSize: 14.5` for paragraph text (3 occurrences). This is the ONLY half-point size in the entire app and matches no token.  
**Why it is a problem:** It's a random value that doesn't align with the 14px body token. Likely a manual tweak for readability that should be either 14 or 15.  
**Recommended fix:** Round to 15 (matches `subheading` size, slightly more readable for long-form content) or 14 (matches `body` token).  
**Scope:** Polish later.

---

#### Issue: fontSize 10 Used in Exercise Search — Below Minimum Legibility
**Severity:** High  
**Component type:** Typography / Accessibility  
**Screen:** Exercise Search Sheet (exercise_search_sheet.dart:349-350)  
**What is wrong:** The separator dot "·" and frequency count "3×" use fontSize 10. This is:
- Below Apple's minimum recommended body text size (11pt)
- Below WCAG readability guidelines for interactive content
- The smallest text anywhere in the app
- Used on an interactive search results sheet where scanning speed matters

**User impact:** Users with even mildly reduced vision cannot read the exercise frequency data. On smaller iPhones (SE, Mini), 10px text is nearly invisible.  
**Recommended fix:** Minimum 11px for all text in the app. The "3×" count is useful information — don't make it unreadable.  
**Scope:** Fix immediately.

---

#### Issue: fontWeight Inconsistency for Same Semantic Role
**Severity:** Medium  
**Component type:** Typography  
**What is inconsistent:** The same semantic meaning uses different weights:

| Semantic Role | Weights Found | Should Be |
|---|---|---|
| Page title | w600, w700, bold | w700 |
| Section heading | w600, w700 | w600 |
| Item name in list | w500, w600, w700 | w600 |
| Column header (SET/WEIGHT) | w600, w700 | w700 |
| Body text | w400, w500 (none specified) | w400 |
| Metadata/caption | w500, w600, none | w500 |
| Uppercase badge | w500, w600, w700 | w700 |

**Most egregious:** "SET WEIGHT REPS" column headers use w700 in workout_widgets (history view) but w600 in new_workout_screen (logging view) — the user sees the same column headers at different boldness.

**Recommended fix:** Document weight rules per semantic role and enforce.  
**Scope:** Standardize globally.

---

### 14.4 Alert, Dialog, and Popup Typography Issues

#### Issue: Native Alert Dialog Text Doesn't Match App Typography
**Severity:** High (already noted in §13.0)  
**What is wrong:** The `IOS26AlertDialog` renders with native iOS system fonts (San Francisco at system sizes). The app uses custom font size/weight settings elsewhere. The dialog title, message, and button text sizes are controlled by iOS, not by the app's type scale. This means:
- Dialog title is at iOS default (~17pt bold) while the app's page titles are 22pt
- Dialog body is at iOS default (~13pt) which happens to match the app's label size
- Dialog button text follows iOS conventions (17pt blue/red) which clashes with the app's own button text (typically 13-15pt)

**Recommended fix:** If using native dialogs, accept the discrepancy. If visual consistency matters more, build custom dialogs with app typography.

---

#### Issue: Picker Sheet Title vs. Toolbar Text Sizing Mismatch
**Severity:** Medium  
**Screen:** Picker sheets (picker_sheet.dart)  
**What is inconsistent:**
- Picker title in `PickerToolbar`: 15/w600 (line 113)
- Picker buttons (Cancel/Done): managed by AdaptiveButton (no explicit size — platform default)
- Selected item labels in toolbar: 11/w600 (lines 192, 206)
- Wheel picker items: 22/w500 (line 237, 267) or 20/w500 (line 319)
- List picker item labels: 16/w600 (line 412, 478)
- List picker subtitle: 15/w500 (line 505)

**Why it is a problem:** Within one picker component, text jumps from 11 to 15 to 22. The wheel items at 22 are large (larger than page titles on some screens at 17), while the toolbar labels identifying what you're picking are tiny (11). The visual hierarchy is inverted — the most important context label ("Set 1") is smallest.  
**Recommended fix:** Picker title: 16/w600, Wheel items: 20/w500, Toolbar labels: 13/w600.  
**Scope:** Standardize in picker_sheet.dart.

---

### 14.5 Font Size Mapping by Screen (Full Inventory)

#### New Workout Screen (28 fontSize instances, 6 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 17 | 1 | Page title "Log Workout" ⚠️ Should be 22 |
| 16 | 1 | Rest timer countdown |
| 14 | 5 | Exercise names, input text, set data values |
| 13 | 2 | Category label, set number |
| 12 | 12 | Summary chips, suffixes ("min", "kg"), helper text, pace values |
| 11 | 7 | Column headers (SET/WEIGHT/REPS), category, LAST SESSION label |

**Issues:** Page title undersized (17 vs 22). Heavy reliance on 12px makes card interiors feel dense.

---

#### Diary Screen (29 fontSize instances, 6 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 28 | 1 | Calorie hero number |
| 20 | 2 | Stat values (weight, exercise minutes) |
| 14 | 1 | Food item name |
| 13 | 4 | Macro labels, section helper text |
| 12 | 3 | Unit labels, timestamps |
| 11 | 18 | Everything else (badges, metadata, macro grams, meal labels) |

**Issues:** 62% of all text is 11px. The screen is overwhelmingly dense with tiny text. Macro values (critical fitness data) are displayed at 11px — the same size as decorative badges.

---

#### Plans Screen (12 fontSize instances, 5 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 22 | 1 | Page title ✓ |
| 16 | 1 | Plan name |
| 14 | 1 | Routine name |
| 13 | 1 | Section header |
| 12 | 5 | Duration, day count, exercise count, metadata |
| 11 | 3 | Badges, preset label |

**Issues:** Plan name (16) is smaller than page title (22) — acceptable. But badge text at 11 in a 16px-radius pill is very cramped.

---

#### Routine Builder (20 fontSize instances, 7 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 22 | 1 | Page title ✓ |
| 18 | 1 | "Exercises" section heading ✓ |
| 16 | 1 | Sheet title "Select Category" |
| 15 | 1 | Button labels |
| 14 | 5 | Exercise names, reps values, category picker |
| 13 | 4 | Category chips, descriptions |
| 12 | 3 | Label text, helper text |
| 11 | 4 | Index numbers, category tags, alternatives label |

**Issues:** Relatively well-structured but uses 7 distinct sizes in one screen (should be max 4-5 per screen for clarity).

---

#### Menu Screen (14 fontSize instances, 7 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 22 | 1 | User name ✓ |
| 18 | 2 | Section headings ("AI Configuration") |
| 16 | 1 | "Complete Your Profile" ⚠️ Should be 18 |
| 15 | 1 | Greeting subtitle |
| 14 | 2 | Setting row labels |
| 13 | 4 | Description text, setting values |
| 12 | 2 | Toggle labels |
| 11 | 1 | Version text |

**Issues:** "Complete Your Profile" at 16 breaks the 18px section heading pattern.

---

#### Setup Screen (17 fontSize instances, 5 distinct sizes)
| Size | Count | Used For |
|------|-------|----------|
| 24 | 1 | Step title ⚠️ Unique to setup |
| 15 | 5 | Button labels, option text |
| 14 | 4 | Form labels |
| 13 | 3 | Helper text, descriptions |
| 12 | 3 | Small labels |
| 11 | 1 | Error text |

**Issues:** Step title at 24 is between the app's 22 (page title) and 28 (display). It's a one-off that makes setup feel like a different app. Should be 22 for consistency.

---

### 14.6 Typography Scale Recommendations

**Proposed streamlined scale (8 sizes, down from 15):**

| Token | Size | Weight | Role | Current Sizes It Replaces |
|-------|------|--------|------|---------------------------|
| `display` | 28 | w800 | Hero numbers (calories, weight) | 28 |
| `pageTitle` | 22 | w700 | All screen page titles | 22, 24, 17 |
| `sectionTitle` | 18 | w600 | In-page section headings | 18 |
| `sheetTitle` | 16 | w600 | Sheet/popup/dialog titles | 16 |
| `body` | 14 | w400 | Default body text, item names | 14, 14.5, 15 |
| `bodyStrong` | 14 | w600 | Emphasized items, exercise names | 14/w600, 13/w700 |
| `caption` | 12 | w500 | Secondary text, timestamps, helpers | 12, 13 |
| `micro` | 11 | w600 | Badges, column headers, tiny metadata | 11, 10 |

**Eliminated sizes:** 10 (→11), 14.5 (→14 or 15), 17 (→22 or 16), 21 (→20), 24 (→22)

---

### 14.7 Priority Typography Fixes

#### Fix Immediately

1. **Normalize page titles to 22px** — New Workout (17→22), Measurements (17→22). These screens look "smaller" than the rest of the app.

2. **Remove fontSize: 10** — Exercise search uses 10px text that's below legibility thresholds. Bump to 11.

3. **Fix diary screen density** — 62% of text at 11px makes critical fitness data (macros, calories per meal) unreadable. Promote macro values to 12-13px.

#### Standardize Next

4. **Establish item name consistency** — All exercise/food/routine names should be 14/w600. Currently varies 13-14 with weights w500-w700.

5. **Assign clear roles to 11/12/13** — Define what each means and audit all ~220 instances.

6. **Replace raw fontSize declarations with AppTextStyles tokens** — 380 raw vs 9 token-based. Even partial migration (screen titles, section headings, item names) would cover 40% of cases.

7. **Fix fontWeight inconsistencies** — Same column headers (SET/WEIGHT/REPS) shouldn't be w700 in one file and w600 in another.

#### Polish Later

8. **Eliminate orphan sizes** — 14.5 (chat), 21 (pickers), 24 (setup) should map to token-defined sizes.

9. **Add `pickerItem` token** — Codify the 20-22px picker wheel size.

10. **Document screen-level typography budgets** — Max 4-5 distinct sizes per screen. Routine builder (7 sizes) and menu (7 sizes) are too diverse.

---

## Appendix: Component Inventory Summary

### Buttons (6+ types → should be 1 with variants)
- `AppGlassButton` → Keep as primary
- `ElevatedButton` (theme) → Phase out, use glass
- `AdaptiveButton.plain` → Keep as ghost/text variant
- `GestureDetector + Container` → Remove, replace with real buttons
- `CupertinoButton` → Replace with `AppGlassButton` icon variant
- `InkWell` rows → Keep for list items (not buttons)

### Cards (4 patterns → should be 1)
- `AppCard` → Keep as sole card component
- `AppColors.cardDecoration` → Delete
- `AppColors.cardDecorationElevated` → Delete
- Inline `Container` cards → Migrate to `AppCard`

### Typography (inline → should be tokens)
- `AppTextStyles.display` → Used 0 times in screens
- `AppTextStyles.title` → Used 0 times in screens
- `AppTextStyles.heading` → Used 0 times in screens
- All other tokens → Used 0 times in screens
- Inline `TextStyle(fontSize: X, fontWeight: Y)` → Used 200+ times

### Spacing (hardcoded → should be tokens)
- `AppSpacing.*` imported in screens → ~0 times
- Hardcoded `SizedBox(height: N)` → 300+ instances

---

*End of audit. This app has good design intent and a well-structured token system, but the system is not enforced. The gap between "design system defined" and "design system adopted" is the primary consistency risk.*
