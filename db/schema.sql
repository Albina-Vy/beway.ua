-- ============================================================
-- BEWAY — схема бази даних
-- Postgres. Розгортається в Supabase (SQL Editor → New query → Run).
--
-- Принцип: сайт статичний, ключ клієнта публічний і видимий у коді сторінки.
-- Тому безпека тримається не на секретності ключа, а на політиках рядкового
-- доступу (RLS): анонімний відвідувач може ТІЛЬКИ вставити рядок і НЕ МОЖЕ
-- прочитати жодного. Заявки видно лише через панель Supabase або через
-- бекенд із service-ключем.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. Заявки учасників на професійні проби
-- ------------------------------------------------------------
create table if not exists public.applications (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz  not null default now(),

  full_name          text         not null check (char_length(trim(full_name)) between 2 and 120),
  email              text         not null check (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  phone              text                  check (phone is null or char_length(phone) <= 32),
  city               text                  check (city  is null or char_length(city)  <= 80),

  -- який напрям цікавить; slug із каталогу або null, якщо заявка загальна
  opportunity_slug   text                  check (opportunity_slug is null or char_length(opportunity_slug) <= 80),
  preferred_format   text         not null default 'Будь-який'
                                  check (preferred_format in ('Онлайн','На місці','Будь-який')),

  -- Посилання на резюме, а не сам файл. Навмисно:
  -- зберігання файлів CV — це значний обсяг персональних даних,
  -- який вимагає окремого механізму видалення, контролю доступу
  -- та перевірки вмісту. Додається окремим етапом, не в першій версії.
  cv_url             text                  check (cv_url is null or char_length(cv_url) <= 500),
  motivation         text                  check (motivation is null or char_length(motivation) <= 1500),

  -- Згоди зберігаються окремо: згода на обробку обовʼязкова,
  -- згода на новини — ні. Їх не можна зливати в одну галочку.
  consent_processing boolean      not null check (consent_processing = true),
  consent_marketing  boolean      not null default false,
  consent_version    text         not null default 'privacy-2026-11',

  source_page        text                  check (source_page is null or char_length(source_page) <= 200),
  status             text         not null default 'new'
                                  check (status in ('new','reviewed','forwarded','rejected','withdrawn'))
);

comment on table  public.applications is 'Заявки молоді на професійні проби. Персональні дані — див. docs/PRIVACY_NOTES.md';
comment on column public.applications.cv_url is 'Посилання на резюме. Файли не зберігаються.';
comment on column public.applications.status is 'new → reviewed → forwarded (передано компанії) → rejected | withdrawn';

create index if not exists applications_created_idx     on public.applications (created_at desc);
create index if not exists applications_opportunity_idx on public.applications (opportunity_slug);
create index if not exists applications_status_idx      on public.applications (status);

-- ------------------------------------------------------------
-- 2. Звернення компаній та освітніх партнерів
-- ------------------------------------------------------------
create table if not exists public.partner_requests (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz  not null default now(),

  organization       text         not null check (char_length(trim(organization)) between 2 and 200),
  contact_name       text         not null check (char_length(trim(contact_name)) between 2 and 120),
  email              text         not null check (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  phone              text                  check (phone is null or char_length(phone) <= 32),
  website            text                  check (website is null or char_length(website) <= 300),

  partner_type       text         not null default 'Компанія'
                                  check (partner_type in ('Компанія','Освітня організація','Інше')),
  industry           text                  check (industry is null or char_length(industry) <= 120),
  message            text                  check (message  is null or char_length(message)  <= 2000),

  consent_processing boolean      not null check (consent_processing = true),
  consent_version    text         not null default 'privacy-2026-11',
  status             text         not null default 'new'
                                  check (status in ('new','contacted','verified','declined'))
);

create index if not exists partner_requests_created_idx on public.partner_requests (created_at desc);

-- ------------------------------------------------------------
-- 3. Політики доступу
-- ------------------------------------------------------------
-- Роль anon існує в Supabase із коробки. Створюємо її, якщо скрипт
-- запускають у звичайному Postgres, інакше політики нижче не створяться,
-- а RLS уже буде увімкнено — і вставка перестане працювати взагалі.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
end
$$;

grant usage on schema public to anon;
grant insert on public.applications, public.partner_requests to anon;

alter table public.applications     enable row level security;
alter table public.partner_requests enable row level security;

-- Прибираємо попередні версії політик, щоб скрипт можна було запускати повторно
drop policy if exists "anon can insert application"     on public.applications;
drop policy if exists "anon can insert partner request" on public.partner_requests;

-- Анонім може ЛИШЕ вставляти. Жодної політики на select, update чи delete
-- немає — отже, з публічним ключем прочитати або змінити заявки неможливо.
create policy "anon can insert application"
  on public.applications for insert to anon
  with check (consent_processing = true);

create policy "anon can insert partner request"
  on public.partner_requests for insert to anon
  with check (consent_processing = true);

-- ------------------------------------------------------------
-- 4. Перевірка після розгортання
-- ------------------------------------------------------------
-- Має повернути rowsecurity = true для обох таблиць:
--   select tablename, rowsecurity from pg_tables where schemaname='public';
-- Має повернути рівно дві політики, обидві з cmd = INSERT:
--   select tablename, policyname, cmd, roles from pg_policies where schemaname='public';
