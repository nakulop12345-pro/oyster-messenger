-- OYSTER schema. Run this whole file in Supabase Dashboard > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check(username ~ '^[a-z0-9_]{3,32}$'),
 display_name text not null default 'OYSTER member' check(char_length(display_name) between 1 and 32),
 created_at timestamptz not null default now()
);
create table if not exists public.conversations (
 id uuid primary key default gen_random_uuid(),
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 joined_at timestamptz not null default now(),
 primary key(conversation_id,user_id)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 content text not null check(char_length(content) between 1 and 4000),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id,created_at);
create index if not exists conversation_members_user_idx on public.conversation_members(user_id);
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create or replace function public.is_conversation_member(target_conversation_id uuid,target_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.conversation_members cm where cm.conversation_id=target_conversation_id and cm.user_id=target_user_id); $$;
revoke all on function public.is_conversation_member(uuid,uuid) from public;
grant execute on function public.is_conversation_member(uuid,uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
declare u text;
begin
 u:=lower(coalesce(new.raw_user_meta_data->>'username',split_part(coalesce(new.email,'member@example.com'),'@',1)));
 u:=regexp_replace(u,'[^a-z0-9_]','_','g');
 if char_length(u)<3 then u:='member_'||substr(new.id::text,1,8); end if;
 u:=substr(u,1,32);
 if exists(select 1 from public.profiles where username=u) then u:=substr(u,1,22)||'_'||substr(new.id::text,1,8); end if;
 insert into public.profiles(id,username,display_name) values(new.id,u,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),u));
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

drop policy if exists "Signed-in users can read profiles" on public.profiles;
create policy "Signed-in users can read profiles" on public.profiles for select to authenticated using(true);
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

drop policy if exists "Members can read conversations" on public.conversations;
create policy "Members can read conversations" on public.conversations for select to authenticated using(public.is_conversation_member(id,auth.uid()));
drop policy if exists "Users create conversations" on public.conversations;
create policy "Users create conversations" on public.conversations for insert to authenticated with check(created_by=auth.uid());

drop policy if exists "Members can read membership" on public.conversation_members;
create policy "Members can read membership" on public.conversation_members for select to authenticated using(public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists "Creator adds members" on public.conversation_members;
create policy "Creator adds members" on public.conversation_members for insert to authenticated with check(exists(select 1 from public.conversations c where c.id=conversation_id and c.created_by=auth.uid()));

drop policy if exists "Members read messages" on public.messages;
create policy "Members read messages" on public.messages for select to authenticated using(public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists "Members send own messages" on public.messages;
create policy "Members send own messages" on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.is_conversation_member(conversation_id,auth.uid()));
drop policy if exists "Members update read status" on public.messages;
create policy "Members update read status" on public.messages for update to authenticated using(public.is_conversation_member(conversation_id,auth.uid())) with check(public.is_conversation_member(conversation_id,auth.uid()));

create or replace function public.find_direct_conversation(other_user_id uuid)
returns uuid language sql stable security invoker set search_path=public
as $$
 select mine.conversation_id from public.conversation_members mine
 join public.conversation_members theirs on theirs.conversation_id=mine.conversation_id
 where mine.user_id=auth.uid() and theirs.user_id=other_user_id
 and (select count(*) from public.conversation_members all_members where all_members.conversation_id=mine.conversation_id)=2
 limit 1;
$$;
revoke all on function public.find_direct_conversation(uuid) from public;
grant execute on function public.find_direct_conversation(uuid) to authenticated;
grant usage on schema public to authenticated;
grant select,update on public.profiles to authenticated;
grant select,insert on public.conversations to authenticated;
grant select,insert on public.conversation_members to authenticated;
grant select,insert,update on public.messages to authenticated;
do $$ begin alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; when others then raise notice 'If needed, enable messages in Database > Replication.'; end $$;
