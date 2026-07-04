# Copy & Content Guidelines

## Principles
1. **Be concise** — Use fewest words that convey meaning
2. **Be actionable** — Buttons say what they do (verbs, not "OK")
3. **Be human** — Conversational but not cute
4. **Be helpful** — Error messages explain what went wrong AND how to fix

## Button Labels
| ✅ Do | ❌ Don't |
|--------|----------|
| Save Workout | OK |
| Delete Set | Yes |
| Start Timer | Submit |
| Log Meal | Confirm |
| Discard Changes | Cancel (when ambiguous) |

## Error Messages
```
Format: [What happened] + [What to do]

✅ "Couldn't save workout. Check your connection and try again."
❌ "Error 500"
❌ "Something went wrong"
```

## Empty States
```
Format: [What would be here] + [How to get started]

✅ "No workouts yet — tap + to start your first session"
❌ "Nothing to show"
❌ (blank screen)
```

## Numbers & Units
- Always show unit: "75 kg" not "75"
- Use user's preferred unit system (kg/lbs from settings)
- Decimals: 1 decimal for weight (72.5 kg), 0 for reps (12)
- Time: "1h 23m" for durations, "2:30" for rest timers
- Dates: "Today", "Yesterday", then "Mon, Jun 9"

## Capitalization
- **Screen titles**: Title Case ("New Workout")
- **Button labels**: Title Case ("Save Changes")
- **Body text**: Sentence case
- **Categories/tags**: lowercase ("chest", "arms")

## Tone by Context
| Context | Tone |
|---------|------|
| Success | Brief, positive ("Workout saved ✓") |
| Error | Clear, helpful, no blame |
| Empty state | Encouraging, instructive |
| Destructive action | Direct, explicit consequence |
| Onboarding | Friendly, brief |

## Placeholder Text
- Search: "Search exercises..." (with ellipsis)
- Number inputs: Show example ("e.g. 75")
- Text inputs: Describe expected content ("Workout notes...")

## Confirmation Dialogs
Only use for:
- Destructive actions (delete workout/routine)
- Losing unsaved work (exit mid-workout)

Never use for:
- Saving (just save)
- Navigation (just navigate)
- Non-destructive toggles
