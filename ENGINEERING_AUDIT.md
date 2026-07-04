# Fitness App — Engineering & QA Audit Report

> **Date**: May 28, 2026  
> **Reviewer**: Senior Software Architect / QA Engineer  
> **Stack**: Flutter (Riverpod) + FastAPI (Python) + SQLite  
> **Review Method**: Full source code analysis — backend routes, DB models, Flutter services, models, providers, screens, widgets, tests

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Top Critical Findings](#2-top-critical-findings)
3. [Feature-by-Feature Review](#3-feature-by-feature-review)
4. [Code Quality & Architecture Review](#4-code-quality--architecture-review)
5. [OOP / SOLID / DRY Analysis](#5-oop--solid--dry-analysis)
6. [Duplicate Code & Reuse Opportunities](#6-duplicate-code--reuse-opportunities)
7. [Bug & Defect List](#7-bug--defect-list)
8. [QA & Testing Gaps](#8-qa--testing-gaps)
9. [Performance / Security / Scalability Risks](#9-performance--security--scalability-risks)
10. [Priority Action Plan](#10-priority-action-plan)

---

## 1. Executive Summary

### Architecture Overview
- **Backend**: FastAPI with SQLAlchemy ORM, single SQLite database, optional JWT auth
- **Frontend**: Flutter with Riverpod state management, Dio HTTP client, GoRouter navigation
- **Communication**: REST API with JSON payloads, SSE for AI chat streaming

### Overall Assessment

The app is **functional for a single-user scenario** but has serious structural issues that would break in production:

| Category | Grade | Key Issue |
|----------|-------|-----------|
| **Security** | D | Auth disabled by default; no endpoint-level authorization; any client can CRUD all data |
| **Error Handling** | D+ | Service layer has ZERO error handling; any malformed API response crashes the app |
| **Data Safety** | C- | No workout draft persistence; no optimistic UI with rollback; destructive actions lack undo |
| **Architecture** | B- | Clean separation of concerns exists but SRP violations in router layer; god-screen files |
| **Code Quality** | B | Consistent patterns, good token system, but unsafe casts and swallowed errors throughout |
| **Test Coverage** | D | ~20-30% happy-path integration tests only; zero unit tests; zero service/model tests |
| **Performance** | B+ | Shimmer skeletons, debounced search, provider auto-dispose; minor issues with IntrinsicHeight |

### Critical Risk Summary
1. **`_saveTokens()` crashes on null** — if backend omits any token field, `!` operator crashes the app
2. **Cardio save uses `int.parse()` / `double.parse()`** — invalid input throws unhandled FormatException → crash
3. **Auth bypass in production** — `AUTH_ENABLED=false` means all endpoints are unprotected by default
4. **DashboardData.fromJson crashes on missing nested keys** — `as Map<String, dynamic>` without null check
5. **No service-layer error handling** — every service method can throw unhandled Dio exceptions to UI

---

## 2. Top Critical Findings

### 2.1 Auth Service Null-Safety Crash

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🔴 Critical |
| **Area** | `lib/services/auth_service.dart:99-108` |
| **Type** | Bug — crash |
| **Problem** | `_saveTokens()` uses `!` operator on `data['access_token']`, `data['refresh_token']`, `data['user_id']`, `data['email']`. If backend response omits ANY of these fields, the app crashes with `Null check operator used on a null value`. |
| **Reproduction** | Backend returns `{"access_token": "abc"}` without `refresh_token` → immediate crash |
| **Root Cause** | Unsafe assertion that API response always contains all fields |
| **Fix** | Null-check each field before assignment. Only persist non-null values. Guard `prefs.setString` calls. |

```dart
// Current (crashes):
_accessToken = data['access_token'];
await prefs.setString(_accessTokenKey, _accessToken!); // 💥 if null

// Fixed:
_accessToken = data['access_token'] as String?;
if (_accessToken != null) await prefs.setString(_accessTokenKey, _accessToken!);
```

---

### 2.2 Cardio Save — FormatException Crash

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🔴 Critical |
| **Area** | `lib/screens/new_workout/new_workout_screen.dart:260-270` |
| **Type** | Bug — unhandled exception |
| **Problem** | `_saveCardio()` uses `int.parse(_durationCtrl.text)` and `double.parse(...)` on text controller values. If user enters non-numeric text (e.g., "30min", "1.2.3", or empty string that passes `isNotEmpty` check), app throws `FormatException` which propagates through `_save()` catch but only shows a generic "Failed to save" snackbar — the real issue (invalid input) is hidden. |
| **Reproduction** | Enter "abc" in distance field → tap Save → crash in try block, generic error shown |
| **Root Cause** | No input validation before parsing; text fields accept any input |
| **Fix** | Use `int.tryParse` / `double.tryParse` with null checks. Add `TextInputType.number` + input formatters. Validate before save. |

```dart
// Current (throws):
data['distance_km'] = double.parse(_distanceCtrl.text);

// Fixed:
final distance = double.tryParse(_distanceCtrl.text);
if (distance != null && distance > 0) data['distance_km'] = distance;
```

---

### 2.3 DashboardData.fromJson Crash on Partial Response

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🔴 Critical |
| **Area** | `lib/models/dashboard_data.dart:134-144` |
| **Type** | Bug — crash on malformed API response |
| **Problem** | `DashboardData.fromJson` casts nested fields directly: `json['nutrition'] as Map<String, dynamic>`. If backend returns partial data (e.g., `nutrition: null` or omits the key), this throws `TypeError: type 'Null' is not a subtype of type 'Map<String, dynamic>'`. |
| **Reproduction** | Backend returns `{"date": "2026-05-28", "meals_logged": 0}` without nutrition/water/exercise/weight keys → crash |
| **Root Cause** | No null-safe access for required nested objects |
| **Fix** | Add null-safe fallbacks: |

```dart
// Current (crashes):
nutrition: NutritionData.fromJson(json['nutrition'] as Map<String, dynamic>),

// Fixed:
nutrition: NutritionData.fromJson(
  (json['nutrition'] as Map<String, dynamic>?) ?? const {}
),
```

---

### 2.4 Zero Error Handling in Service Layer

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🔴 Critical |
| **Area** | ALL files in `lib/services/` (except auth_service.dart) |
| **Type** | Architecture defect — fragile client layer |
| **Problem** | Every service method is a raw `await ApiConfig.dio.get/post/put/delete(...)` with NO try-catch, NO error typing, NO retry logic, and NO response validation. Any network error, timeout, 4xx, or 5xx propagates as an untyped DioException to the UI layer. |
| **User Impact** | When network drops, server errors, or responses are malformed, users see either generic errors or app crashes depending on whether the calling screen has a try-catch. |
| **Evidence** | `MealsService` (118 lines, 0 try-catch), `WorkoutsService` (150 lines, 1 try-catch in `getTodayPlan` only), `MeasurementsService` (25 lines, 0), `WaterService` (16 lines, 0), `DashboardService` (14 lines, 0) |
| **Fix** | Create a `BaseService` or wrapper with: (a) standard try-catch, (b) error typing (NetworkError, ServerError, ParseError), (c) response validation, (d) optional retry for GET requests. |

---

### 2.5 Backend Auth Bypass — No Endpoint Protection

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🔴 Critical (for multi-user / production) |
| **Area** | `backend/auth.py:52-77`, all `routers/*.py` |
| **Type** | Security — authorization bypass |
| **Problem** | `AUTH_ENABLED` defaults to `false`. When false, `get_current_user_id()` returns hardcoded `1`. **No router uses `Depends(get_current_user_id)` to scope data to the authenticated user.** All data is global — any request reads/writes the same records. |
| **User Impact** | In multi-user deployment: any user can read/modify/delete ANY other user's meals, workouts, weight, and settings. |
| **Evidence** | `routers/measurements.py` — DELETE endpoint accepts any `measurement_id` with no ownership check. `routers/meals.py` — all queries operate on the global record set. |
| **Fix** | (a) Add `user_id` foreign key to all data tables. (b) Add `Depends(get_current_user_id)` to all router endpoints. (c) Filter all queries by `user_id`. (d) Set `AUTH_ENABLED=true` as production default. |

---

### 2.6 TextEditingController Created in Build Method

| Attribute | Detail |
|-----------|--------|
| **Severity** | 🟠 High |
| **Area** | `new_workout_screen.dart` (exercise duration field, ~line 844-850), `plan_builder_screen.dart` (duration weeks, ~line 400-406) |
| **Type** | Bug — state loss + memory churn |
| **Problem** | `TextEditingController(text: value.toString())` created inside `build()` method. Every rebuild creates a new controller, losing cursor position, selection state, and any in-progress edits. Also creates garbage for GC on every frame. |
| **Reproduction** | Start typing in duration field → trigger any rebuild (e.g., setState elsewhere) → text resets to previous value, cursor jumps |
| **Root Cause** | Controller should be created in `initState` or stored in state class |
| **Fix** | Store controllers as instance variables in the State class. Update text via `controller.text = newValue` only when the data source changes, not on every build. |

---

## 3. Feature-by-Feature Review

### 3.1 Food Logging (Diary + Add Food)

**Happy Path**: Search → Select → Adjust serving → Save ✓

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| Search race condition | Medium | `foodSearchProvider` uses `.family<List<FoodItem>, String>` keyed on query string. Rapid typing creates multiple concurrent requests. Riverpod's auto-dispose handles cleanup, but stale results can briefly flash before newer results arrive. |
| `response.data['results'] as List?` fallback | Medium | `MealsService.searchFood` line 12: `response.data['results'] as List? ?? response.data as List? ?? []` — if response is a String or int (malformed), `as List?` won't crash but won't work either. No error thrown, just empty results. |
| Delete item — no optimistic UI | Low | `_deleteItem()` calls service, waits, then invalidates. User sees no immediate feedback during the async call. |
| Template ID parsing | High | `MealTemplate.fromJson`: `id: json['id'] as int` — if backend returns `id` as String (e.g., "5"), this crashes. Should use `(json['id'] as num).toInt()`. |

**Missing Test Coverage**:
- No test for malformed search results
- No test for concurrent search race
- No test for delete failure recovery
- No test for edit-mode prefill with missing meal data

---

### 3.2 Workout Logging (New Workout)

**Happy Path**: Select exercise → Log sets → Save ✓

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| `int.parse` crash in cardio save | 🔴 Critical | See Finding 2.2 |
| No draft persistence | High | Mid-workout crash = total data loss. No auto-save to local storage. |
| `_populatePlanData` race with `mounted` | Medium | Calls `WorkoutsService.getPreviousSession()` for EACH exercise sequentially in a loop. If user navigates away mid-loop, `mounted` check only happens at the end. setState on unmounted widget won't crash (checked), but wasted network calls occur. |
| Volume calculation includes incomplete sets | Low | `_totalVolume` multiplies `reps ?? 0` by `weightKg ?? 0`. Sets where only reps OR weight are filled contribute 0 — correct, but may confuse users who see "0 lb volume" while entering data. |
| Dismissible index mutation | Medium | Exercise cards use `Dismissible` with list-index-based removal. If two rapid dismisses occur, second dismiss may target wrong index. |
| `_strengthInitialized` prevents re-population | Low | If plan data changes while screen is open, stale exercises persist. Edge case but possible with deep links. |

**Destructive Tester Scenarios**:
- Tap Save repeatedly before response returns → `_saving` guard works ✓
- Navigate back mid-save → `mounted` check prevents setState crash ✓
- Rotate device mid-workout → StatefulWidget rebuilds, state preserved ✓
- Kill app mid-workout → ALL data lost ✗

---

### 3.3 Measurements & Weight Tracking

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| Sheet dismisses before save completes | Medium | `measurements_screen.dart` — `Navigator.pop(ctx)` fires BEFORE `MeasurementsService.add()`. If save fails, user doesn't see it. Sheet is gone. |
| Chart null conversion | Low | `kgToDisplay(...) ?? 0` can return 0 for null weight, creating a false zero-point on the chart line. Should filter nulls instead. |
| Stats section silently hides errors | Medium | `_StatsRow.error => SizedBox.shrink()` — if stats API fails, the entire stats section vanishes with no indication. User thinks no data exists when it's actually a load failure. |
| No rate limiting on add | Low | User can rapidly tap "Save" on the add sheet (no `_saving` guard visible in sheet). |

---

### 3.4 AI Coach & Chat

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| SSE stream parsing silent failures | Medium | `coach_service.dart` — SSE JSON parse failures are swallowed. Malformed events are lost without retry or error surface. |
| Chat preview load swallowed error | Medium | `catch (_) {}` in `_loadPreview()` means history load failures are invisible. |
| In-memory rate limiting only | Low | Backend rate limiter resets on server restart. Not persistent. |
| No offline/fallback for daily insight | Medium | If network fails, insight card shows error with "Tap to retry" — good. But no cached last-known insight. |

---

### 3.5 Workout Plans & Routines

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| `int.parse(widget.editId!)` crash | High | `plan_builder_screen.dart:62` — if `editId` is a non-numeric string (e.g., corrupted query param), this throws FormatException → crash. |
| Two providers load independently | Medium | `plans_screen.dart` — plans and routines load from separate providers. UI renders partial data (routines appear empty while loading) causing flicker. |
| TextEditingController in build | High | `plan_builder_screen.dart` — duration weeks controller created in build (see Finding 2.6). |
| Added routine not assigned to day | Medium | `_showAddRoutineSheet()` only adds to `_planRoutineIds` but doesn't assign to any day slot. Routine may be orphaned. |

---

### 3.6 Water Tracking

**Happy Path**: Tap "+" → +250ml logged ✓

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| No optimistic UI | Low | Adding water waits for API before reflecting in UI. With slow network, user taps again thinking it didn't work → double-add. |
| Backend 10,000ml cap not reflected in UI | Low | Backend silently caps at 10,000ml but UI doesn't show this limit. User could be confused why taps stop working. |
| `_busy` guard is good | ✓ | Prevents double-taps during async call. |

---

### 3.7 Settings & Profile

**Bugs & Edge Cases**:

| Issue | Severity | Detail |
|-------|----------|--------|
| AI key stored in plaintext in transit | Medium | Backend accepts API key in request body; encrypts with Fernet for storage. But transmission is over HTTP (not HTTPS by default in development). |
| Fernet key stored in file | Medium | `.fernet_key` file in backend root. If repo is public or file is accessible, all encrypted keys are compromised. |
| Settings are global (not user-scoped) | High | Only one `UserSettings` row exists. Multi-user would share settings. |
| No password strength validation | Medium | Registration accepts any password including empty string. |

---

## 4. Code Quality & Architecture Review

### 4.1 Layer Architecture

```
┌─────────────────────────────────────────────┐
│ Screens (UI)                                │  ← Widgets + layout
├─────────────────────────────────────────────┤
│ Providers (State)                           │  ← Riverpod FutureProviders
├─────────────────────────────────────────────┤
│ Services (API Client)                       │  ← Raw Dio calls
├─────────────────────────────────────────────┤
│ Models (Data)                               │  ← fromJson/toJson
├─────────────────────────────────────────────┤
│ Backend (API + DB)                          │  ← FastAPI + SQLAlchemy
└─────────────────────────────────────────────┘
```

**Verdict**: Clean layer separation exists. However:
- **Services** are anemic — just HTTP wrappers with no error handling, validation, or caching
- **Providers** are thin `FutureProvider.autoDispose` wrappers — correct but provide no local caching
- **Screens** contain too much business logic (calculations, data transformations, formatting)
- **Backend routers** contain business logic that should be in a service layer (TDEE calculation in `profile.py`)

### 4.2 State Management Assessment

| Pattern | Usage | Assessment |
|---------|-------|------------|
| `FutureProvider.autoDispose` | All data fetching | ✅ Correct for server-sourced data |
| `StateProvider` | Date selection, search query | ✅ Appropriate for simple UI state |
| `StateNotifierProvider` | Theme mode | ✅ Correct for persisted state |
| Local `setState` | Workout form, food form | ⚠️ Works but creates god-screen files |
| `ref.invalidate()` | Data refresh after mutations | ✅ Correct pattern |
| No `AsyncNotifierProvider` | Complex flows | ⚠️ Missing — workout save should be an AsyncNotifier |

### 4.3 Navigation Architecture

| Pattern | Assessment |
|---------|------------|
| GoRouter with ShellRoute | ✅ Correct for tab-based nav with full-screen overlays |
| `context.push()` for modals | ✅ Correct |
| `context.go()` for tab switching | ✅ Correct |
| `CupertinoPage` on iOS | ✅ Good platform adaptation |
| GlobalKey for cross-widget communication | ⚠️ Anti-pattern — use a provider or callback |

---

## 5. OOP / SOLID / DRY Analysis

### Single Responsibility Principle (SRP) Violations

| File | Lines | Issue |
|------|-------|-------|
| `new_workout_screen.dart` | ~981 | God-screen: handles strength form, cardio form, exercise search, set management, plan loading, save logic, volume calculation, UI building — all in one StatefulWidget |
| `add_food_screen.dart` | ~800+ | Handles search, selection, serving adjustment, template building, edit mode, meal type switching — too many responsibilities |
| `backend/routers/meals.py` | ~500+ | Contains food search, USDA DB access, caching, template CRUD, nutrition detail aggregation, serving conversion — should be split into sub-services |
| `backend/routers/profile.py` | Contains TDEE/macro calculation | Business logic in router layer; should be in a `nutrition_calculator.py` service |

### Open/Closed Principle (OCP) Violations

| Area | Issue |
|------|-------|
| Meal types | Hardcoded `['breakfast', 'lunch', 'dinner', 'snack']` in both `diary_screen.dart` and backend `constants.py`. Adding a new meal type requires changes in multiple files. |
| Cardio types | Hardcoded list in `new_workout_screen.dart`. Not from backend. |
| AI providers | Hardcoded provider list in backend `ai_providers.py`. Adding new provider requires code change, not config. |

### Dependency Inversion Principle (DIP) Violations

| Area | Issue |
|------|-------|
| Services use concrete `ApiConfig.dio` | No abstraction/interface. Cannot swap implementations for testing. |
| Backend uses `SessionLocal()` directly in seeds | Not injectable; makes testing impossible. |
| `AppColors` uses mutable static state | `_brightness` is global mutable — not injectable, makes testing themes difficult. |

### DRY Violations

See Section 6 below.

---

## 6. Duplicate Code & Reuse Opportunities

### 6.1 Duplicated Patterns

| Pattern | Locations | Recommendation |
|---------|-----------|----------------|
| Date string formatting | `diary_screen.dart:67-68`, `workouts_screen.dart:101-102`, `date_utils.dart` | One function exists in `date_utils.dart` but screens duplicate the logic inline |
| Card decoration | `AppColors.cardDecoration`, `AppCard` widget, inline `BoxDecoration` in coach/diary/workouts | Single `AppCard` widget should be the only path |
| Loading state | Shimmer in diary, shimmer in workouts, inline shimmer in coach, spinner in menu | Single `LoadingState` widget with layout variants |
| Error handling in screens | Try-catch + snackbar pattern repeated in diary, workouts, measurements, plans | Extract `SafeAction.run(context, ref, () async {...})` utility |
| Response parsing pattern | `data is Map ? (data['key'] as List? ?? []) : (data as List? ?? [])` in meals, workouts services | Extract `ApiResponse.parseList(data, key)` helper |
| `ref.invalidate()` after mutation | Every screen calls `ref.invalidate(provider)` after save/delete | Move to service layer or create `MutationNotifier` |
| Previous session loading | Duplicated in `_populatePlanData` and `_addExercise` in new_workout_screen | Extract `_loadPreviousSets(name, unit)` helper |

### 6.2 Screens That Should Be Merged/Abstracted

| Screens | Issue | Recommendation |
|---------|-------|----------------|
| Plan Builder + Routine Builder | Very similar form structures (name + description + list of items + save) | Extract `FormBuilderScaffold` widget |
| Goals Screen sections | Repeated pattern of label → value → picker for each setting | Extract `GoalSettingRow` component |
| Workout history cards (strength + cardio) | Same card shell with different content | Already somewhat abstracted via `WorkoutHistoryCard` ✓ |

### 6.3 Missing Reusable Components

| Should Exist | Currently | Used In |
|-------------|-----------|---------|
| `SafeApiCall` wrapper | Nothing | All services |
| `FormValidator` | Nothing | Setup, workout, plans |
| `CachedProvider` (stale-while-revalidate) | Raw FutureProvider | Dashboard, settings |
| `DismissibleListItem` | Repeated Dismissible setup | Diary, measurements, workouts |
| `NumericInputField` (validated, formatted) | Raw TextFormField | Workout sets, measurements, setup |

---

## 7. Bug & Defect List

### Confirmed Bugs

| # | Severity | Area | Description | Type |
|---|----------|------|-------------|------|
| B1 | 🔴 Critical | auth_service.dart:105 | `_accessToken!` crash if token field missing from response | Null-safety crash |
| B2 | 🔴 Critical | new_workout_screen.dart:262-268 | `int.parse` / `double.parse` throws FormatException on non-numeric input | Unhandled exception |
| B3 | 🔴 Critical | dashboard_data.dart:136 | `json['nutrition'] as Map<String, dynamic>` crashes if key is null | Type cast crash |
| B4 | 🟠 High | new_workout_screen.dart:~844 | TextEditingController created in build() → state loss on rebuild | State management bug |
| B5 | 🟠 High | plan_builder_screen.dart:62 | `int.parse(widget.editId!)` crashes on non-numeric editId | Unhandled exception |
| B6 | 🟠 High | plan_builder_screen.dart:~400 | TextEditingController created in build() → cursor jump/state loss | State management bug |
| B7 | 🟠 High | measurements_screen.dart:~186 | Navigator.pop() before service call → save failure invisible to user | UX logic bug |
| B8 | 🟡 Medium | profile.dart (MealTemplate) | `id: json['id'] as int` crashes if backend returns string ID | Type cast crash |
| B9 | 🟡 Medium | workouts_service.dart:20 | `(data as List).cast<Map<String, dynamic>>()` — unsafe cast if API returns unexpected shape | Type cast crash |
| B10 | 🟡 Medium | coach_screen.dart:44 | `_loadPreview()` catch `(_) {}` — errors swallowed silently | Silent failure |
| B11 | 🟡 Medium | plans_screen.dart:~84 | `routinesAsync.valueOrNull ?? []` — routines shown empty while loading, not actually empty | False empty state |
| B12 | 🟡 Medium | new_workout_screen.dart:~436 | Dismissible index-based removal can race with multiple rapid swipes | Concurrent state mutation |
| B13 | 🟡 Medium | modal_utils.dart | Global `ValueNotifier` never disposed; `showAppSheet` error before `whenComplete` leaves stale state | Memory/state leak |
| B14 | 🟢 Low | measurements chart | `kgToDisplay(...) ?? 0` creates false zero-point instead of filtering nulls | Data visualization bug |
| B15 | 🟢 Low | stats section | `_StatsRow.error => SizedBox.shrink()` hides load failures entirely | Silent error state |

### Suspected Defects (Need Manual Verification)

| # | Area | Suspicion |
|---|------|-----------|
| S1 | SSE chat streaming | Malformed JSON events are dropped — possible message loss |
| S2 | Food search race condition | Rapid typing could flash stale results |
| S3 | Dashboard streak calculation | Timezone/day-boundary edge at midnight — streak may calculate wrong day |
| S4 | Weight unit preference on setup | Setup always shows metric even if user preferred imperial |
| S5 | Water backend cap | 10,000ml cap not communicated to user; taps silently stop working |

---

## 8. QA & Testing Gaps

### 8.1 Current Test Inventory

| Type | Count | Coverage |
|------|-------|----------|
| Widget tests | 1 (smoke) | ~1% |
| Integration tests | 5 files | ~20-30% happy path |
| Unit tests | 0 | 0% |
| Service tests | 0 | 0% |
| Model parsing tests | 0 | 0% |
| API contract tests | 0 | 0% |
| Performance tests | 0 | 0% |

### 8.2 Critical Missing Tests

| Category | What's Needed | Risk if Untested |
|----------|---------------|------------------|
| **Model parsing** | Test all `fromJson()` with malformed data, missing keys, wrong types | App crashes on API changes |
| **Service error handling** | Test DioException paths, timeouts, 4xx/5xx responses | Unhandled crashes in production |
| **Auth flow** | Test token refresh, expired token, refresh failure, concurrent refresh | Silent auth failures, infinite loops |
| **Workout save** | Test concurrent save, empty exercises, partial sets, interrupted save | Data corruption or loss |
| **Form validation** | Test boundary values (age=0, weight=-1, height=9999) | Bad data in system |
| **Offline behavior** | Test all screens with no network | Crashes vs graceful degradation |
| **Provider invalidation** | Test that mutations properly refresh dependent data | Stale data displayed |

### 8.3 Recommended Test Strategy

```
Priority 1 (Prevents crashes):
├── Unit tests for all Model.fromJson() — 8 model classes × 3-5 cases each
├── Unit tests for utility functions (date, weight conversion)
└── Service layer error simulation tests

Priority 2 (Prevents data issues):
├── Integration tests for save/delete/update flows with error simulation
├── Provider state tests (invalidation chains, stale data)
└── Form validation tests for all input screens

Priority 3 (Prevents regressions):
├── Golden tests for key screens (diary, workouts, coach)
├── E2E test for complete food-logging flow
└── E2E test for complete workout-logging flow
```

### 8.4 Feature-Specific QA Scenarios

#### Workout Logging — Destructive Test Cases

| Scenario | Expected | Actual |
|----------|----------|--------|
| Double-tap Save button | Only one save | ✅ `_saving` guard |
| Navigate back mid-save | Confirmation dialog | ❌ No confirmation — data lost |
| Kill app mid-workout | Resume from draft | ❌ All data lost |
| Enter "abc" in distance field, save | Validation error shown | ❌ FormatException crash |
| Network timeout during save | Retry option | ❌ Generic "Failed to save" |
| Server returns 500 on save | Error with retry | ❌ Generic error, no retry |
| Dismiss exercise, rapidly dismiss another | Both removed correctly | ⚠️ Race condition possible |
| Empty workout (no completed sets), save | Save disabled | ✅ `_canSave` guard |

#### Food Logging — Destructive Test Cases

| Scenario | Expected | Actual |
|----------|----------|--------|
| Search with <2 chars | No results, no crash | ✅ Provider returns [] |
| API returns malformed food item | Graceful skip/error | ❌ Potential cast crash in FoodItem.fromJson |
| Delete food, undo | Undo available | ❌ No undo — immediate permanent delete |
| Edit food, change serving to 0 | Validation prevents | ⚠️ Unknown |
| Log same food twice rapidly | Two entries created | ✅ No guard, but probably acceptable |
| Network drops during search | Error shown to user | ⚠️ Depends on provider error state |

---

## 9. Performance / Security / Scalability Risks

### 9.1 Performance Issues

| Issue | Severity | Detail |
|-------|----------|--------|
| `IntrinsicHeight` in diary | Low | Forces two-pass layout for Weight+Exercise card row. Use fixed heights instead. |
| `AppColors.updateBrightness()` in every build | Low | Called in every screen's `build()` method. Mutates static state on every frame. Should be called once at theme change. |
| Sequential API calls in `_populatePlanData` | Medium | Calls `getPreviousSession()` for each exercise IN SEQUENCE. 5 exercises = 5 serial API calls. Should parallelize with `Future.wait`. |
| No HTTP response caching | Medium | Every screen navigation re-fetches data. No `stale-while-revalidate` pattern. Dashboard data (expensive aggregation) is always fresh-fetched. |
| Backend SQLite for all queries | Low (single user) | Fine for single-user. Would not scale to multi-user without migration to PostgreSQL. |

### 9.2 Security Risks

| Risk | Severity | Detail |
|------|----------|--------|
| **Auth disabled by default** | 🔴 Critical | Any client can CRUD all data without authentication |
| **No endpoint authorization** | 🔴 Critical | Even with auth enabled, no user-scoping on data queries |
| **API key in plaintext transit** | 🟠 High | AI API key sent over HTTP in request body. Should use HTTPS. |
| **Fernet key in file system** | 🟠 High | `.fernet_key` in backend root — should be env variable, never committed |
| **No password requirements** | 🟡 Medium | Registration accepts empty/trivial passwords |
| **No rate limiting on auth** | 🟡 Medium | Brute-force login attempts not limited |
| **JWT refresh has no revocation** | 🟡 Medium | No token blacklist; stolen refresh token valid until expiry |
| **SharedPreferences for tokens** | 🟡 Medium | On Android, SharedPreferences is unencrypted. Use `flutter_secure_storage` for tokens. |
| **Health data unencrypted at rest** | 🟡 Medium | SQLite database contains weight, body measurements, calorie data — health data with potential regulatory implications |
| **Delete endpoints have no ownership check** | 🟠 High | `DELETE /api/measurements/{id}` — any id can be deleted by anyone |
| **File upload on knowledge endpoint** | 🟡 Medium | `POST /knowledge/upload` — needs file type/size validation |

### 9.3 Scalability Risks

| Risk | Impact | Detail |
|------|--------|--------|
| Single SQLite file | Multi-user impossible | Concurrent writes will lock/fail |
| Global profile/settings records | Multi-user impossible | `first()` queries return the same record for everyone |
| In-memory rate limiting | Server restart resets | Not persistent across instances |
| No database migrations tool | Schema changes break DB | `ALTER TABLE` in `main.py` startup is fragile |
| No API versioning | Breaking changes crash clients | No `/v1/` prefix; any response shape change breaks Flutter app |
| Monolithic backend | Scaling limits | All routes in one process; coach/AI could be separated |

---

## 10. Priority Action Plan

### 🔴 Fix Immediately (Crash / Security / Data Loss)

| # | Action | Effort | Files |
|---|--------|--------|-------|
| 1 | **Fix `_saveTokens()` null crash** — guard with null checks | 15 min | `auth_service.dart` |
| 2 | **Fix cardio save `int.parse` crash** — use `tryParse` + validation | 30 min | `new_workout_screen.dart` |
| 3 | **Fix DashboardData.fromJson null crash** — add null-safe fallbacks | 20 min | `dashboard_data.dart` |
| 4 | **Fix TextEditingController in build()** — move to state | 30 min | `new_workout_screen.dart`, `plan_builder_screen.dart` |
| 5 | **Fix `int.parse(widget.editId!)` crash** — use tryParse | 10 min | `plan_builder_screen.dart` |
| 6 | **Add input validation to cardio fields** — TextInputFormatters + tryParse | 1 hr | `new_workout_screen.dart` |
| 7 | **Fix measurements sheet dismiss-before-save** — save first, then pop | 20 min | `measurements_screen.dart` |
| 8 | **Enable auth for production** — set `AUTH_ENABLED=true` default, add user scoping | 4 hr | Backend: auth.py + all routers |
| 9 | **Move tokens to secure storage** — replace SharedPreferences with flutter_secure_storage | 1 hr | `auth_service.dart` |
| 10 | **Move `.fernet_key` to env variable** — remove file from repo | 15 min | Backend: settings.py |

### 🟡 Fix Soon (Reliability / Data Integrity / Quality)

| # | Action | Effort | Files |
|---|--------|--------|-------|
| 11 | **Add service-layer error handling** — create BaseService with typed errors | 3 hr | All services |
| 12 | **Add model parsing safety** — null-safe all `fromJson` methods | 2 hr | All models |
| 13 | **Add workout draft persistence** — auto-save to local storage | 4 hr | `new_workout_screen.dart` |
| 14 | **Add unit tests for all models** — test with malformed JSON | 3 hr | New `test/models/` directory |
| 15 | **Parallelize previous-session API calls** — use `Future.wait` | 30 min | `new_workout_screen.dart` |
| 16 | **Fix plans screen loading flicker** — show loading for routines | 30 min | `plans_screen.dart` |
| 17 | **Add exit confirmation for workout** — discard dialog on back press | 1 hr | `new_workout_screen.dart` |
| 18 | **Add password strength validation** — minimum length, complexity | 30 min | Backend: `routers/auth.py` |
| 19 | **Add setup form validation** — ranges, inline errors, disable Next | 2 hr | `setup_screen.dart` |
| 20 | **Fix MealTemplate `id as int` unsafe cast** — use `(as num).toInt()` | 15 min | `profile.dart` |

### 🟢 Improve Later (Architecture / DX / Scalability)

| # | Action | Effort | Files |
|---|--------|--------|-------|
| 21 | **Extract business logic from screens** — create ViewModels/Notifiers for workout + food | 8 hr | New files |
| 22 | **Consolidate card components** — single `AppCard` for all use cases | 2 hr | All screens + widgets |
| 23 | **Add HTTP response caching** — stale-while-revalidate for dashboard/settings | 4 hr | Services + providers |
| 24 | **Split `new_workout_screen.dart`** — separate StrengthForm and CardioForm | 4 hr | New files |
| 25 | **Add database migration tool** — Alembic for backend schema management | 4 hr | Backend |
| 26 | **Add API versioning** — `/v1/` prefix on all routes | 2 hr | Backend + Flutter services |
| 27 | **Add user scoping to all data** — `user_id` FK + query filters | 8 hr | Backend models + routers |
| 28 | **Remove `AppColors.updateBrightness()` from build** — use InheritedWidget or Theme.of | 2 hr | All screens + theme.dart |
| 29 | **Add integration tests for error paths** — network failures, malformed data | 6 hr | `integration_test/` |
| 30 | **Create `SafeAction` utility** — standardized try-catch-snackbar for all mutations | 2 hr | New utility + all screens |
| 31 | **Replace GlobalKey with provider-based communication** — workouts nav interaction | 1 hr | `app_shell.dart`, `workouts_screen.dart` |
| 32 | **Add service abstraction for testability** — interfaces for all services | 4 hr | All services |

---

## Appendix A: Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        Flutter App                            │
├──────────────────────────────────────────────────────────────┤
│  Screens (UI Layer)                                          │
│  ┌─────────┐ ┌──────┐ ┌────────┐ ┌──────┐ ┌─────┐         │
│  │  Diary  │ │Coach │ │Workouts│ │ Menu │ │Setup│ ...       │
│  └────┬────┘ └──┬───┘ └───┬────┘ └──┬───┘ └──┬──┘         │
│       │         │          │          │        │             │
├───────┼─────────┼──────────┼──────────┼────────┼─────────────┤
│  Providers (State Layer — Riverpod)                          │
│  ┌──────────┐ ┌───────────┐ ┌──────────────┐               │
│  │meals_prov│ │workout_prov│ │dashboard_prov│  ...           │
│  └─────┬────┘ └─────┬─────┘ └──────┬───────┘               │
│        │             │              │                        │
├────────┼─────────────┼──────────────┼────────────────────────┤
│  Services (HTTP Client Layer)         ⚠️ NO ERROR HANDLING   │
│  ┌──────────┐ ┌────────────┐ ┌─────────────┐               │
│  │MealsSvc  │ │WorkoutsSvc │ │DashboardSvc │  ...           │
│  └─────┬────┘ └─────┬──────┘ └──────┬──────┘               │
│        │             │               │                       │
├────────┼─────────────┼───────────────┼───────────────────────┤
│  ApiConfig (Dio + Auth Interceptor)                          │
│  └───────────────────┬───────────────────────────────────────┘
│                      │ HTTP/REST
│  ════════════════════╪═══════════════════════════════════════
│                      │
│  ┌───────────────────┴───────────────────────────────────────┐
│  │                    FastAPI Backend                          │
│  ├───────────────────────────────────────────────────────────┤
│  │  Routers (contain business logic ⚠️)                      │
│  │  ┌──────┐┌────────┐┌─────────┐┌──────┐┌─────┐           │
│  │  │meals ││workouts││dashboard││coach ││auth │ ...         │
│  │  └──┬───┘└────┬───┘└────┬────┘└──┬───┘└──┬──┘           │
│  │     │         │          │        │       │               │
│  │  SQLAlchemy ORM + SQLite                                  │
│  │  ┌────────────────────────────────────────┐               │
│  │  │ fitness.db + food_database.db          │               │
│  │  └────────────────────────────────────────┘               │
│  └───────────────────────────────────────────────────────────┘
```

---

## Appendix B: File Risk Map

| File | Lines | Risk Level | Primary Risk |
|------|-------|------------|--------------|
| `new_workout_screen.dart` | ~981 | 🔴 High | Crashes (int.parse), state bugs (controllers in build), no draft save |
| `auth_service.dart` | 110 | 🔴 High | Null crash on token save |
| `dashboard_data.dart` | 145 | 🔴 High | Null crash on partial API response |
| `plan_builder_screen.dart` | ~600 | 🟠 Medium | int.parse crash, controller-in-build |
| `add_food_screen.dart` | ~800 | 🟡 Medium | SRP violation, cast risks |
| `meals_service.dart` | 118 | 🟡 Medium | No error handling, unsafe casts |
| `workouts_service.dart` | 150 | 🟡 Medium | No error handling, unsafe casts |
| `backend/routers/meals.py` | ~500 | 🟡 Medium | SRP violation, no auth |
| `backend/auth.py` | 88 | 🔴 High | Auth bypass, no user scoping |
| `measurements_screen.dart` | ~533 | 🟡 Medium | Pop-before-save, silent errors |
| `coach_screen.dart` | ~400 | 🟢 Low | Swallowed errors, dead tab |
| `diary_screen.dart` | ~800 | 🟢 Low | Working correctly, minor SRP issues |

---

## Appendix C: Questions for the Team

These are decisions I encountered that seem questionable and warrant discussion:

1. **Why is auth disabled by default?** If this is production-bound, this is a P0 security risk. If single-user-only forever, remove the auth system entirely — it adds complexity with no benefit.

2. **Why are services completely devoid of error handling?** Was this a conscious "let errors propagate" decision? The UI screens inconsistently handle errors — some have try-catch, others don't.

3. **Why does `_populatePlanData` make sequential API calls?** For 5 exercises, this is 5 round-trips (~2-5 seconds on moderate latency). `Future.wait` would parallelize this.

4. **Why is `AppColors.updateBrightness()` called in every screen's build()?** This mutates static state 60× per second during animations. It should be called once at theme change.

5. **Why is there no workout draft persistence?** This is the highest-risk data loss scenario in the entire app. A single `SharedPreferences.setString('workout_draft', json)` on each set addition would prevent it.

6. **Why are TextEditingControllers created in build methods?** This is a known Flutter anti-pattern documented in official docs. Was it oversight or expedience?

7. **Why does the measurements sheet pop before saving?** This guarantees the user can't see save failures. The pattern everywhere else is save → success → pop.

8. **Why is there no API versioning?** Any backend change to response shape will crash all existing Flutter clients.

---
In review some problems can be features instead of bug so ask the questions about those after detecting or solving the bugs.

*End of engineering audit.*
