-- One-time update: adds the table that lets a signed-in person's Journey
-- follow them to a new phone.
-- Paste into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.
-- (The same lines are also in schema.sql, for setting up from scratch.)

create table if not exists public.saved_bottles (
  user_id uuid not null references auth.users on delete cascade,
  code text not null check (char_length(code) between 1 and 40),
  saved_at timestamptz not null default now(),
  primary key (user_id, code)
);

alter table public.saved_bottles enable row level security;
drop policy if exists "saved bottles own" on public.saved_bottles;
create policy "saved bottles own" on public.saved_bottles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

