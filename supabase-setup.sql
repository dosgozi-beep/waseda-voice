-- =========================================================
-- 早稲田ボイス：Supabase 初期設定
-- Supabase の「SQL Editor」にこのファイルの中身を全部貼り付けて「Run」を押してください。
-- 何度実行しても壊れないように書いてあります。
-- =========================================================

-- 1) 悩み（後輩の投稿）
create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  category    text not null check (category in ('履修・授業','サークル','就活・キャリア','一人暮らし','人間関係・恋愛','バイト・お金','留学','進路・受験','その他')),
  title       text not null check (char_length(title) between 1 and 60),
  body        text not null check (char_length(body) between 1 and 1200),
  nickname    text not null default '匿名' check (char_length(nickname) <= 16),
  grade       text check (char_length(grade) <= 10)
);

-- 2) 先輩の回答（post_id はデモ投稿の "demo-01" なども入るので文字列）
create table if not exists public.comments (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  post_id     text not null check (char_length(post_id) <= 64),
  body        text not null check (char_length(body) between 1 and 1500),
  profile     jsonb not null default '{}'::jsonb check (char_length(profile::text) < 2000)
);
create index if not exists comments_post_id_idx on public.comments (post_id);

-- 3) わかる（1人1回。匿名ログインのIDで管理）
create table if not exists public.likes (
  post_id     text not null check (char_length(post_id) <= 64),
  user_id     uuid not null default auth.uid(),
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- 4) アクセスのルール（誰でも読める・誰でも投稿/回答できる・削除は管理画面からだけ）
alter table public.posts    enable row level security;
alter table public.comments enable row level security;
alter table public.likes    enable row level security;

drop policy if exists "posts are public"        on public.posts;
drop policy if exists "anyone can post"         on public.posts;
drop policy if exists "comments are public"     on public.comments;
drop policy if exists "anyone can comment"      on public.comments;
drop policy if exists "likes are public"        on public.likes;
drop policy if exists "like as yourself"        on public.likes;
drop policy if exists "unlike your own"         on public.likes;

create policy "posts are public"    on public.posts    for select to anon, authenticated using (true);
create policy "anyone can post"     on public.posts    for insert to anon, authenticated with check (true);
create policy "comments are public" on public.comments for select to anon, authenticated using (true);
create policy "anyone can comment"  on public.comments for insert to anon, authenticated with check (true);
create policy "likes are public"    on public.likes    for select to anon, authenticated using (true);
create policy "like as yourself"    on public.likes    for insert to authenticated with check (user_id = auth.uid());
create policy "unlike your own"     on public.likes    for delete to authenticated using (user_id = auth.uid());

-- 5) ほかの人の投稿がリアルタイムで画面に出るようにする
do $$
begin
  begin alter publication supabase_realtime add table public.posts;    exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.comments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.likes;    exception when duplicate_object then null; end;
end $$;
