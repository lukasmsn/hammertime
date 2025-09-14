## Technical Decisions — WorkoutChat (Reference)

### 0) Scope baseline

- iOS: Latest iOS (17+), iPhone only
- Mode: Local storage MVP using SwiftData
- Auth: None for MVP
- Backend: Supabase deferred to later phase

### 1) App architecture

- SwiftUI with MVVM-like structure (`ObservableObject` view models, async/await)
- `NavigationStack` with two tabs: Workouts, Chat (floating tab bar per design)
- Data flow: UI → ViewModel → SwiftData context → UI updates on main
- Local store only (SwiftData `ModelContainer`), no network calls
- Optional `appInstallationId` (UUID) in Keychain for future migration

### 2) Data model and units

- Entities (Swift): `Workout`, `Exercise`, `SetEntry`, `Message`
- IDs: UUID primary keys generated locally
- Time: store as UTC `Date` (Foundation); display in device local time
- Units: SI units (kg, meters, seconds). Convert on import if needed

### 3) Local data model (SwiftData)

- `@Model Workout { id: UUID, startedAt: Date, name: String, durationSeconds: Int?, notes: String?, exercises: [Exercise] }`
- `@Model Exercise { id: UUID, workout: Workout, name: String, position: Int, notes: String?, sets: [SetEntry] }`
- `@Model SetEntry { id: UUID, exercise: Exercise, setNumber: Int, weightKg: Double?, reps: Int?, distanceM: Double?, seconds: Int?, rpe: Double?, notes: String? }`
- `@Model Message { id: UUID, role: String, content: String, createdAt: Date }`

Notes:

- Relationship deletes: deleting a `Workout` should remove its `exercises` and `sets`

### 4) Data access (local)

- `fetchWorkouts(limit: Int = 5)` → query by `startedAt` desc; prefetch relationships
- `addWorkout(...)`, `addExercise(...)`, `addSet(...)` using the SwiftData context
- `saveMessage(role: String, content: String)` and `fetchMessages(limit: Int)`

Error handling:

- Validate inputs and fail early; log in Debug

### 5) CSV import (Strong export) — deferred, decisions preserved

- Expected columns (from sample): `Date, Workout Name, Duration, Exercise Name, Set Order, Weight, Reps, Distance, Seconds, Notes, Workout Notes, RPE`
- Mapping:
  - `Date` → `workouts.started_at` (parse with source timezone → convert to UTC)
  - `Workout Name` → `workouts.name`
  - `Duration` (e.g., `6m`) → `duration_seconds`
  - `Exercise Name` → `exercises.name`
  - `Set Order` → `sets.set_number`
  - `Weight` → `sets.weight_kg` (convert lb→kg if needed)
  - `Reps` → `sets.reps`
  - `Distance` → `sets.distance_m` (if provided)
  - `Seconds` → `sets.seconds`
  - `Notes` → attach to `sets.notes` if per-set, else ignore for MVP
  - `Workout Notes` → `workouts.notes`
  - `RPE` → `sets.rpe`
- Dedupe strategy (local keys):
  - Workouts: `(startedAt, name)`
  - Exercises: `(workout.id, name, position)`
  - Sets: `(exercise.id, setNumber)`
- Import behavior:
  - Defer implementation until after MVP
  - In-app importer preferred; optional Python helper to pre-normalize CSV
  - Idempotent re-runs

### 6) OpenAI integration (included in MVP)

- Call OpenAI from the app (single-shot, no streaming); Markdown response
- Model: `gpt-4o-mini` (or similar); temperature 0.4; max tokens ~600
- Prompt assembly (client):
  - System prompt: concise personal trainer
  - Context blocks (JSON):
    - `METRICS_JSON`: aggregate metrics for the entire dataset
    - `WORKOUTS_JSON`: recent N workouts (N≈15) as rich JSON objects
  - User message appended at the end
- Persist: save user and assistant messages in local `Message`
- Future: move to Supabase + Edge Function when backend added

### 6.1) Supabase

- Backend schema (MVP target):
  - `workouts(id uuid pk, user_id uuid, started_at timestamptz, name text, duration_seconds int, notes text)`
  - `exercises(id uuid pk, user_id uuid, workout_id uuid fk, name text, position int, notes text)`
  - `sets(id uuid pk, user_id uuid, exercise_id uuid fk, set_number int, weight_kg numeric, reps int, distance_m numeric, seconds int, rpe numeric, notes text)`
  - `messages(id uuid pk, user_id uuid, role text, content text, created_at timestamptz, thread_id uuid)`
- Cascades: delete workout → exercises → sets
- Unique constraints for dedupe: `(user_id, started_at, name)`, `(workout_id, name, position)`, `(exercise_id, set_number)`
- No auth in MVP; `client_id` stored from `identifierForVendor` to segregate data. RLS/auth later.

### 6.2) External Services configs

- OpenAI key is provided via `Configurations/Secrets.xcconfig` → Info.plist key `OPENAI_API_KEY`.
- Supabase is configured via `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Configurations/Secrets.xcconfig` → Info.plist keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

### 6.3) Data Sync flow (MVP)

- Local primary store: SwiftData.
- Pull on app launch: `SupabaseService.pullAllAndMergeIntoLocal()` merges remote workouts by id.
- Push on workout completion: `SupabaseService.pushWorkout()` upserts rows via PostgREST.
- No realtime or conflict resolution yet; idempotent by UUID.

### 7) Environment and secrets (Xcode)

- `Configurations/Secrets.xcconfig` (git-ignored) with:
  - `OPENAI_API_KEY=...`
- Reference in `Info.plist` using `$(VAR_NAME)`; read via `Bundle.main.infoDictionary`

### 8) UI/UX technical notes

- Rendering: edge-to-edge lists; oversized titles; floating tab bar with blur
- Primary buttons: orange subtle gradient + light-orange 1pt border
- Cards: hairline border + light shadow; chips flat with tint
- Chat: assistant flat bubble (warm neutral), user elevated bubble; no timestamps/avatars
- Markdown: basic formatting (bold, italics, lists, code blocks) rendered in SwiftUI

### 9) Performance

- Keep view models scoped; avoid unnecessary recomputation
- Prefetch relationships where it improves scrolling

### 10) Security and privacy

- Local-only data store; OpenAI requests send only minimal context

### 11) Future enhancements (non-blocking)

- Add Supabase backend and auth (optional)
- Streaming chat responses
- Migrations: sync SwiftData with backend models
- Tests for data layer and prompt builder

### 12) Operational notes

- Use `.gitignore` for `Configurations/Secrets.xcconfig`
- Keep SQL schema and CSV script in repo for reproducibility
- Keep this doc as the single source of truth for implementation decisions

### Appendix A — Metrics summary format and token budget

Context blocks sent to the model:

- METRICS_JSON

  - Fields:
    - `prs`: { ExerciseName: { bestE1RM: number } }
    - `totalVolumeKg`: { ExerciseName: number }
    - `weeklyCardioMinutes`: { ISOYear-Week: minutes }
    - `avgBodyWeightKg`: number
    - `avgSleepHours`: number

- WORKOUTS_JSON
  - `workouts`: Array of recent N workouts:
    - `startedAt` (ISO8601), `name`, optional `durationSeconds`, `notes`, `bodyWeightKg`, `sleepHours`
    - `exercises[]`: name, position, optional notes, `sets[]` with setNumber, weightKg, reps, distanceM, seconds, rpe, notes, isLogged

Token budget (approx):

- METRICS_JSON: ~100–250 tokens depending on exercise count and weeks
- WORKOUTS_JSON (N=15): ~700–1100 tokens (compact JSON, no whitespace)
- System + user + overhead: ~150–250 tokens
- Total target: ~1.0–1.6k tokens per request (within 4k context comfortably)

Guidelines:

- Prefer concise keys and omit nulls to reduce tokens
- Keep N≈15 for MVP; adjust dynamically if user messages are long
- Include cardio entries and notes; model can ignore if not needed
