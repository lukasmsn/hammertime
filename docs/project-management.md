## Project Management — WorkoutChat (MVP)

### Scope

- SwiftUI iOS app (latest iOS), iPhone only.
- Local-only MVP using SwiftData for storage (no backend).
- Single-user; no auth.
- Persist workouts/exercises/sets and chat messages locally.
- Defer Supabase; include OpenAI (single-shot) in MVP.

### Key decisions

- Time stored as UTC `Date` in local store; display device local.
- Last 5 workouts for context in chat.
- CSV import: initial pass can be an in-app importer; optional helper script to convert CSV→JSON.
- OpenAI key via `xcconfig` + `Info.plist` substitution.

### Phased checkpoints

1. Foundation setup (independent)

   - Create Xcode project `WorkoutChat` (SwiftUI, iPhone only).
   - Add SwiftData; define model container.
   - Acceptance: app builds; SwiftData container initializes.

2. Local data model ready (independent)

   - Define `@Model` types: `Workout`, `Exercise`, `SetEntry`, `Message` with relationships.
   - Acceptance: can create/save/load instances in a preview or unit harness.

3. Data access layer (independent)

   - Implement `fetchWorkouts(limit: Int)`, `addWorkout`, `addExercise`, `addSet` using SwiftData context.
   - Acceptance: callable from preview to verify roundtrip.

4. Mock data generation (independent)

   - Implement deterministic mock data factory using the SwiftData models.
   - Generate recent workouts with exercises/sets for development and previews.
   - Acceptance: app shows non-empty lists and details without manual input.

5. Workout UI (depends on 3 or 4 for meaningful data)

   - `WorkoutList` with edge-to-edge list, pull-to-refresh, oversized title.
   - `WorkoutDetail` with exercises and sets; add exercise/set actions.
   - Acceptance: can create a workout and see seeded ones; add set updates local store.

6. Chat MVP (introduce OpenAI here)

   - Chat view with Markdown rendering; persist messages locally.
   - On send: save user message, fetch last 5 workouts locally, build prompt, call OpenAI, save assistant.
   - Acceptance: receive assistant reply and see both messages persisted.

   - OpenAI setup steps (do here, not earlier):
     - Create `Configurations/Secrets.xcconfig` (git-ignored) with `OPENAI_API_KEY=...`.
     - Add `OPENAI_API_KEY` to `Info.plist` as `$(OPENAI_API_KEY)`.
     - Read via `Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String`.

7. Navigation and chrome (independent of chat; light dependency on Workout UI)

   - Floating white tab bar with blur; tabs for Workouts and Chat.
   - Primary button style (orange gradient with light-orange border); cards and chips per design.
   - Acceptance: tab switch works; visuals match design tokens.

8. Polishing pass (final)

   - Loading and error toasts; empty states copy.
   - Shadow tuning (bottom-heavy), spacing checks, small haptics/motion.
   - Acceptance: simulator walkthrough without obvious UX gaps.

### Deliverables

- Running iOS app: list/detail/chat (local SwiftData store) with OpenAI chat working.
- `docs/design-guidelines.md` (visual language) and this plan.
- Optional: CSV import helper (script or in-app importer).

### Risks / Notes

- No backend means data is device-only until Supabase is added.
- OpenAI key in app (acceptable for personal prototype). Keep `Secrets.xcconfig` git-ignored.
- Add Supabase keys to `Secrets.xcconfig` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) and expose via Info.plist substitution. If missing, app runs local-only.
- Streaming deferred.

### Xcode env handling (OpenAI key) — performed in Chat phase

1. Create `Configurations/Secrets.xcconfig` (git-ignored):
   - `OPENAI_API_KEY=...`
2. Project → Target → Build Settings → Base Configuration → point Debug/Release to the xcconfig.
3. Add `OPENAI_API_KEY` as a user-defined entry in `Info.plist` with value `$(OPENAI_API_KEY)`.
4. Read in code: `Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String`.

### TODO — OpenAI key handling (Release readiness)

- Ensure Debug and Release both resolve `OPENAI_API_KEY` at runtime:
  - Base Configuration for target set to `Configurations/Secrets.xcconfig`.
  - Build Settings → add `INFOPLIST_KEY_OPENAI_API_KEY = $(OPENAI_API_KEY)`.
  - Or create a real `Info.plist` and add key `OPENAI_API_KEY` with value `$(OPENAI_API_KEY)`.
- For local dev, Scheme → Run → Environment Variables can set `OPENAI_API_KEY`.
- Verify by checking console in Debug:
  - Expect `[OpenAI] Found key in Info.plist (len=...)` or `... ENV ...`.
- Security note: shipping the key in-app is acceptable for this MVP only. Plan to proxy via backend in a later phase.

### Out-of-scope setup (for later phase)

- Supabase schema, auth/RLS, env secrets, and Edge Functions.
- OpenAI streaming.

#### CSV import (deferred)

- Preserve decisions for future import:
  - Columns: `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, Notes, Workout Notes, RPE`.
  - Mapping: Date→`startedAt` (UTC), Workout Name→`name`, Duration→`durationSeconds`, Exercise Name→`name`, Set Order→`setNumber`, Weight→`weightKg` (lb→kg if needed), Reps→`reps`, Distance→`distanceM`, Seconds→`seconds`, Notes→per-set notes, Workout Notes→workout notes, RPE→`rpe`.
  - Dedupe keys (local): Workouts `(startedAt, name)`, Exercises `(workout.id, name, position)`, Sets `(exercise.id, setNumber)`.
  - Behavior: idempotent re-runs; SI units; parse device-local time → UTC.
