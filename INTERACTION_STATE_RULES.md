# Interaction & State Rules

## Component States

Every interactive component must support these states:

| State | Visual Treatment |
|-------|-----------------|
| Default | Base appearance |
| Pressed | Scale 0.95 + reduced opacity (GlassButton handles this) |
| Disabled | 40% opacity, non-interactive |
| Loading | Spinner replaces label, non-interactive |
| Selected | Orange accent or filled background |
| Error | Red border / red helper text below |

## Tap Behavior Rules

1. **Single action per tap** — Never trigger multiple side effects
2. **Debounce destructive actions** — Disable button after first tap until complete
3. **Haptic feedback** — `selectionClick()` on selection, `lightImpact()` on actions
4. **Minimum touch target** — 44×44pt (iOS HIG requirement)
5. **No invisible tap areas** — If it's tappable, it must look tappable

## Loading Patterns

| Scenario | Pattern |
|----------|---------|
| Full screen load | Skeleton/shimmer placeholders |
| Button action | Inline spinner, button disabled |
| Pull to refresh | Native refresh indicator |
| Background save | No UI blocking, toast on complete |
| Slow network | Show content after 300ms, skeleton if >1s |

## Navigation Rules

1. Every screen has a back affordance (arrow or swipe)
2. Modals close with X, swipe-down, or background tap
3. Tab state persists across tab switches
4. Deep navigation preserves stack (push, don't replace)
5. Destructive exits require confirmation if data is unsaved

## Form Interaction Rules

1. Validate on blur (when field loses focus), not on every keystroke
2. Show errors below the field, not in alerts
3. Scroll to first error on submit
4. Preserve form data on orientation change / tab switch
5. Number inputs use numeric keyboard
6. Auto-advance focus after selection (e.g., after picker closes)

## Gesture Rules

| Gesture | Usage |
|---------|-------|
| Tap | Primary action |
| Long press | Secondary menu / favorite toggle |
| Swipe right | Go back (iOS default) |
| Swipe left on row | Delete/archive action |
| Pull down | Refresh |
| Pinch | Zoom (charts only) |

## Animation Rules

1. Duration: 200–300ms for transitions, 150ms for micro-interactions
2. Curve: `easeOutCubic` for entries, `easeInCubic` for exits
3. No animation >400ms (feels sluggish)
4. Reduce motion: respect `MediaQuery.disableAnimations`
5. Loading spinners start after 300ms delay (avoid flash)

## State Persistence

| What | Where | When Restored |
|------|-------|---------------|
| Auth token | Secure storage | App launch |
| User preferences | SharedPreferences | App launch |
| Draft workout | In-memory | Tab switch |
| Search favorites | SharedPreferences | Sheet open |
| Scroll position | Automatic (ListView) | Tab switch |
| Selected date | Provider state | Session lifetime |

## Error Recovery

1. Network errors: Show inline message + retry button
2. Validation errors: Highlight field + helper text
3. Server 500: Generic message + auto-retry once after 3s
4. Auth expired: Navigate to login, preserve deep link
5. Data conflict: Last-write-wins with toast notification
