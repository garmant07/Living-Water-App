-- Living Water Co. database setup.
-- Paste this whole file into Supabase: SQL Editor -> New query -> Run.
-- It is safe to run more than once.

-- ---------------------------------------------------------------------------
-- PROFILES: one row per account. "role" is 'user' or 'operator'.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  role text not null default 'user' check (role in ('user', 'operator')),
  created_at timestamptz not null default now()
);

-- True when the signed-in person is an operator. Every rule below uses this.
create or replace function public.is_operator()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'operator');
$$;

-- Give every new account a profile row with the role 'user'.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'display_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Nobody can change a role from the app, not even an operator.
-- Roles are changed only in the Supabase dashboard (where auth.uid() is empty).
create or replace function public.protect_profile_role()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null then
    raise exception 'Roles can only be changed in the Supabase dashboard.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- ---------------------------------------------------------------------------
-- CONTENT
-- ---------------------------------------------------------------------------
-- Single pieces of editable text, looked up by key (e.g. 'shop_intro').
create table if not exists public.content_blocks (
  key text primary key,
  text text not null default '',
  image_url text,
  updated_by uuid references auth.users on delete set null,
  updated_at timestamptz not null default now()
);

-- The verses, slogans and mission statements that take turns on the home page.
create table if not exists public.home_messages (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'scripture' check (kind in ('scripture', 'slogan', 'mission')),
  text text not null,
  reference text,
  sort_order int not null default 0,
  is_published boolean not null default true,
  updated_by uuid references auth.users on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.partners (
  id text primary key,
  name text not null,
  tagline text not null default '',
  about text not null default '',
  key_facts text[] not null default '{}',
  faith_note text not null default '',
  logo_url text,
  website_url text not null default '',
  donate_url text not null default '',
  sort_order int not null default 0,
  is_published boolean not null default true,
  updated_by uuid references auth.users on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.community_stories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  image_url text,
  location text,
  partner_id text references public.partners on delete set null,
  published_at timestamptz not null default now(),
  is_published boolean not null default false,
  updated_by uuid references auth.users on delete set null,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- SHOP
-- ---------------------------------------------------------------------------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  price_cents int not null check (price_cents >= 0),
  currency text not null default 'usd',
  image_urls text[] not null default '{}',
  badge text not null default '',
  stock_quantity int check (stock_quantity is null or stock_quantity >= 0),
  is_active boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users on delete set null
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity (start with 1001),
  -- Set to empty if the customer deletes their account.
  user_id uuid references auth.users on delete set null,
  status text not null default 'pending_payment'
    check (status in ('pending_payment', 'paid', 'shipped', 'delivered', 'cancelled', 'refunded')),
  subtotal_cents int not null,
  shipping_cents int not null default 0,
  tax_cents int not null default 0,
  total_cents int not null,
  currency text not null default 'usd',
  shipping_name text,
  shipping_line1 text,
  shipping_line2 text,
  shipping_city text,
  shipping_state text,
  shipping_postal_code text,
  shipping_country text,
  contact_email text,
  contact_phone text,
  stripe_payment_intent_id text,
  shipping_carrier text,
  tracking_url text,
  shipped_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders on delete cascade,
  product_id uuid references public.products on delete set null,
  -- Copies taken at the time of purchase, so later edits don't change old orders.
  product_name text not null,
  unit_price_cents int not null,
  quantity int not null check (quantity > 0)
);

create index if not exists orders_user_id_idx on public.orders (user_id);
create index if not exists order_items_order_id_idx on public.order_items (order_id);

-- Takes sold items out of stock once an order is paid. Called by the server only.
create or replace function public.decrement_stock(p_order uuid)
returns void language sql security definer set search_path = public as $$
  update public.products p
  set stock_quantity = greatest(p.stock_quantity - i.quantity, 0)
  from public.order_items i
  where i.order_id = p_order and i.product_id = p.id and p.stock_quantity is not null;
$$;
revoke execute on function public.decrement_stock(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- SECURITY RULES (Row Level Security)
-- These are enforced by the database itself, so they hold even if someone
-- tampers with the app.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.content_blocks enable row level security;
alter table public.home_messages enable row level security;
alter table public.partners enable row level security;
alter table public.community_stories enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Profiles: you can see and rename your own. Operators can see everyone's.
drop policy if exists "profiles read own or operator" on public.profiles;
create policy "profiles read own or operator" on public.profiles
  for select using (id = auth.uid() or public.is_operator());
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Content: everyone reads what is published; only operators change anything.
drop policy if exists "content read" on public.content_blocks;
create policy "content read" on public.content_blocks for select using (true);
drop policy if exists "content write operators" on public.content_blocks;
create policy "content write operators" on public.content_blocks
  for all using (public.is_operator()) with check (public.is_operator());

drop policy if exists "messages read" on public.home_messages;
create policy "messages read" on public.home_messages
  for select using (is_published or public.is_operator());
drop policy if exists "messages write operators" on public.home_messages;
create policy "messages write operators" on public.home_messages
  for all using (public.is_operator()) with check (public.is_operator());

drop policy if exists "partners read" on public.partners;
create policy "partners read" on public.partners
  for select using (is_published or public.is_operator());
drop policy if exists "partners write operators" on public.partners;
create policy "partners write operators" on public.partners
  for all using (public.is_operator()) with check (public.is_operator());

drop policy if exists "stories read" on public.community_stories;
create policy "stories read" on public.community_stories
  for select using (is_published or public.is_operator());
drop policy if exists "stories write operators" on public.community_stories;
create policy "stories write operators" on public.community_stories
  for all using (public.is_operator()) with check (public.is_operator());

drop policy if exists "products read" on public.products;
create policy "products read" on public.products
  for select using (is_active or public.is_operator());
drop policy if exists "products write operators" on public.products;
create policy "products write operators" on public.products
  for all using (public.is_operator()) with check (public.is_operator());

-- Orders: customers see only their own and can change nothing.
-- Operators see all and can update them (status, carrier, tracking link).
-- Orders are CREATED only by the server, so there is no insert rule at all.
drop policy if exists "orders read own or operator" on public.orders;
create policy "orders read own or operator" on public.orders
  for select using (user_id = auth.uid() or public.is_operator());
drop policy if exists "orders update operators" on public.orders;
create policy "orders update operators" on public.orders
  for update using (public.is_operator()) with check (public.is_operator());

drop policy if exists "order items read own or operator" on public.order_items;
create policy "order items read own or operator" on public.order_items
  for select using (
    public.is_operator()
    or exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- PHOTOS: anyone can view; only operators can upload, replace or delete.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('public-images', 'public-images', true)
on conflict (id) do nothing;

drop policy if exists "public images read" on storage.objects;
create policy "public images read" on storage.objects
  for select using (bucket_id = 'public-images');
drop policy if exists "public images insert operators" on storage.objects;
create policy "public images insert operators" on storage.objects
  for insert with check (bucket_id = 'public-images' and public.is_operator());
drop policy if exists "public images update operators" on storage.objects;
create policy "public images update operators" on storage.objects
  for update using (bucket_id = 'public-images' and public.is_operator());
drop policy if exists "public images delete operators" on storage.objects;
create policy "public images delete operators" on storage.objects
  for delete using (bucket_id = 'public-images' and public.is_operator());

-- ---------------------------------------------------------------------------
-- To make an account an operator, run this in the SQL Editor with the
-- person's email address:
--
--   update public.profiles set role = 'operator'
--   where id = (select id from auth.users where email = 'you@example.com');
-- ---------------------------------------------------------------------------
