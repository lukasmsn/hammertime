-- Supabase schema for hammertime MVP (no auth; segregate by client_id)

create table if not exists public.workouts (
  id uuid primary key,
  client_id text not null,
  started_at timestamptz not null,
  finished_at timestamptz null,
  name text not null,
  duration_seconds int null,
  notes text null,
  body_weight_kg double precision null,
  sleep_hours double precision null,
  is_seed boolean not null default false,
  inserted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_exercises (
  id uuid primary key,
  client_id text not null,
  workout_id uuid not null references public.workouts(id) on delete cascade,
  name text not null,
  position int not null,
  notes text null,
  inserted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_sets (
  id uuid primary key,
  client_id text not null,
  exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  set_number int not null,
  weight_kg double precision null,
  reps int null,
  distance_m double precision null,
  seconds int null,
  rpe double precision null,
  notes text null,
  is_logged boolean not null default false,
  inserted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Useful indexes
create index if not exists idx_workouts_client_started on public.workouts(client_id, started_at);
create index if not exists idx_exercises_workout_pos on public.workout_exercises(workout_id, position);
create index if not exists idx_sets_exercise_num on public.workout_sets(exercise_id, set_number);


