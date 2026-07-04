# Pre-Release UI/UX Audit Checklist

Use this checklist before every release. Each screen must pass all checks.

## Per-Screen Checks

### Accessibility
- [ ] All interactive elements have Semantics labels
- [ ] Touch targets ≥ 44pt
- [ ] Contrast ratio ≥ 4.5:1 for text, ≥ 3:1 for large text
- [ ] No color-only information (icons/labels supplement color)
- [ ] Dynamic Type supported (text scales 0.8x–1.4x without breaking)
- [ ] VoiceOver reads meaningful content in logical order

### States
- [ ] Default state designed
- [ ] Loading state present (shimmer/skeleton)
- [ ] Empty state designed with guidance
- [ ] Error state with retry action
- [ ] Success feedback (snackbar/toast)
- [ ] Disabled state visually distinct

### Consistency
- [ ] Buttons match app-wide style (AppGlassButton for iOS 26)
- [ ] Cards use consistent border radius, padding, color
- [ ] Typography uses established size scale (11/12/13/14/15/16/18/22)
- [ ] Spacing uses AppSpacing tokens
- [ ] Icons from same family (SF Symbols on iOS)

### Edge Cases
- [ ] Long text truncates with ellipsis (no overflow)
- [ ] No data / null values handled gracefully
- [ ] Partial data renders without crash
- [ ] Network error shows user-friendly message
- [ ] Double-tap protection on submit buttons
- [ ] Back navigation doesn't lose unsaved work

### Content & Copy
- [ ] Button labels are action verbs ("Save", "Delete", not "OK")
- [ ] Error messages explain what went wrong and how to fix
- [ ] Placeholder text is helpful, not repetitive
- [ ] Units are consistent (kg/lbs based on settings)
- [ ] Dates use relative format where appropriate ("Today", "Yesterday")

## Per-Flow Checks

### Happy Path
- [ ] Complete flow works end-to-end
- [ ] All transitions are smooth (no frame drops)
- [ ] Final action provides confirmation feedback

### Error Path
- [ ] Network failure mid-flow doesn't lose data
- [ ] Validation errors show on correct fields
- [ ] User can recover and retry without starting over

### Navigation
- [ ] Every screen has a clear way to go back
- [ ] Deep links resolve to correct screen
- [ ] Tab state persists when switching tabs
- [ ] Modal dismissal doesn't lose context

## Pre-Release Gates

1. **Zero** layout overflow errors in debug console
2. **Zero** compile errors or analyzer errors
3. All critical flows tested on:
   - Smallest supported device (iPhone SE)
   - Largest device (iPad / iPhone Pro Max)
   - Dark mode + Light mode
   - Large text (Accessibility > Larger Text)
4. Network error simulation test (airplane mode)
5. Memory pressure test (background/foreground cycle)
6. Fresh install test (no cached data)
