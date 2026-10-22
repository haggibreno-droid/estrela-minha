-- Estrela Minha: schema de conta, diário privado, amizades e mensagens.
-- Execute este arquivo no Supabase SQL Editor do seu projeto.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text not null unique check (handle ~ '^[A-Za-z0-9_.]{3,24}$'),
  display_name text not null default 'Nova estrelinha' check (char_length(display_name) between 1 and 50),
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_handle_lower_idx on public.profiles (lower(handle));

create table if not exists public.user_vault (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  unique(requester_id, recipient_id),
  check (requester_id <> recipient_id)
);
create index if not exists friendships_recipient_status_idx on public.friendships(recipient_id, status);
create index if not exists friendships_requester_status_idx on public.friendships(requester_id, status);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 3000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);
create index if not exists messages_conversation_idx on public.messages(sender_id, recipient_id, created_at);

create or replace function public.is_accepted_friend(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.recipient_id = b)
        or (f.requester_id = b and f.recipient_id = a))
  );
$$;

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  base_handle text;
begin
  base_handle := regexp_replace(coalesce(new.raw_user_meta_data->>'handle', split_part(new.email, '@', 1), 'estrelinha'), '[^A-Za-z0-9_.]', '', 'g');
  base_handle := substring(base_handle from 1 for 18);
  if length(base_handle) < 3 then base_handle := 'user' || substring(replace(new.id::text,'-','') from 1 for 8); end if;
  if exists (select 1 from public.profiles p where lower(p.handle) = lower(base_handle)) then
    base_handle := substring(base_handle from 1 for 18) || '_' || substring(replace(new.id::text,'-','') from 1 for 4);
  end if;
  insert into public.profiles(id, handle, display_name)
  values(new.id, base_handle, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), 'Nova estrelinha'))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.user_vault enable row level security;
alter table public.friendships enable row level security;
alter table public.messages enable row level security;

drop policy if exists "profiles searchable by signed in users" on public.profiles;
create policy "profiles searchable by signed in users" on public.profiles for select to authenticated using (true);
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile" on public.profiles for insert to authenticated with check (id = auth.uid());

drop policy if exists "read own vault" on public.user_vault;
create policy "read own vault" on public.user_vault for select to authenticated using (user_id = auth.uid());
drop policy if exists "insert own vault" on public.user_vault;
create policy "insert own vault" on public.user_vault for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "update own vault" on public.user_vault;
create policy "update own vault" on public.user_vault for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "read own friendship requests" on public.friendships;
create policy "read own friendship requests" on public.friendships for select to authenticated using (requester_id = auth.uid() or recipient_id = auth.uid());
drop policy if exists "send friend requests as self" on public.friendships;
create policy "send friend requests as self" on public.friendships for insert to authenticated with check (requester_id = auth.uid() and recipient_id <> auth.uid() and status = 'pending');
drop policy if exists "recipient accepts request" on public.friendships;
create policy "recipient accepts request" on public.friendships for update to authenticated using (recipient_id = auth.uid() and status = 'pending') with check (recipient_id = auth.uid() and status = 'accepted');
drop policy if exists "participants delete friendship" on public.friendships;
create policy "participants delete friendship" on public.friendships for delete to authenticated using (requester_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "read messages in accepted friendships" on public.messages;
create policy "read messages in accepted friendships" on public.messages for select to authenticated using (
  (sender_id = auth.uid() or recipient_id = auth.uid())
  and public.is_accepted_friend(sender_id, recipient_id)
);
drop policy if exists "send messages to accepted friends" on public.messages;
create policy "send messages to accepted friends" on public.messages for insert to authenticated with check (
  sender_id = auth.uid()
  and recipient_id <> auth.uid()
  and public.is_accepted_friend(sender_id, recipient_id)
);

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.user_vault to authenticated;
grant select, insert, update, delete on public.friendships to authenticated;
grant select, insert on public.messages to authenticated;
