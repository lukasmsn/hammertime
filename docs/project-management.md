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
   - Add `Configurations/Secrets.xcconfig` with `OPENAI_API_KEY`; bind in `Info.plist`.
   - Acceptance: app builds; SwiftData container initializes; key is readable.

2. Local data model ready (independent)

   - Define `@Model` types: `Workout`, `Exercise`, `SetEntry`, `Message` with relationships.
   - Acceptance: can create/save/load instances in a preview or unit harness.

3. Data access layer (independent)

   - Implement `fetchWorkouts(limit: Int)`, `addWorkout`, `addExercise`, `addSet` using SwiftData context.
   - Acceptance: callable from preview to verify roundtrip.

4. CSV import pipeline (independent)

   - Simple in-app importer: pick `strong.csv` via Files and import to SwiftData.
   - Converts units to SI, parses dates to UTC; dedupe by (date+name/exercise+position/setNumber).
   - Acceptance: seeded workouts appear locally; re-import is idempotent.

5. Workout UI (depends on 3 or 4 for meaningful data)

   - `WorkoutList` with edge-to-edge list, pull-to-refresh, oversized title.
   - `WorkoutDetail` with exercises and sets; add exercise/set actions.
   - Acceptance: can create a workout and see seeded ones; add set updates local store.

6. Chat MVP (with OpenAI)

   - Chat view with Markdown rendering; persist messages locally.
   - On send: save user message, fetch last 5 workouts locally, build prompt, call OpenAI, save assistant.
   - Acceptance: receive assistant reply and see both messages persisted.

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
- Streaming deferred.

### Xcode env handling (OpenAI key)

1. Create `Configurations/Secrets.xcconfig` (git-ignored):
   - `OPENAI_API_KEY=...`
2. Project → Target → Build Settings → Base Configuration → point Debug/Release to the xcconfig.
3. Add `OPENAI_API_KEY` as a user-defined entry in `Info.plist` with value `$(OPENAI_API_KEY)`.
4. Read in code: `Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String`.

### Out-of-scope setup (for later phase)

- Supabase schema, auth/RLS, env secrets, and Edge Functions.
- OpenAI integration and streaming.
