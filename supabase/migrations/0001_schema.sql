-- Bigma LMS prototype schema
-- Rules: employees only see their own learning data. HR admins see their own company only.
-- Test answer keys are never readable by employees; grading happens in submit_test().

create extension if not exists pgcrypto;

create table companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mark text not null default 'CO',
  logo_url text,
  pass_mark int not null default 70 check (pass_mark between 0 and 100),
  hr_email text,
  hr_whatsapp text,
  created_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  full_name text not null,
  email text not null,
  dept text,
  title text,
  phone text,
  role text not null default 'learner' check (role in ('learner','admin')),
  consent_at timestamptz,
  hide_on_leaderboard boolean not null default false,
  created_at timestamptz not null default now()
);
create index on profiles(company_id);

-- Invites made by HR before the person has logged in.
create table invites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  email text not null,
  full_name text not null,
  dept text,
  title text,
  role text not null default 'learner' check (role in ('learner','admin')),
  user_id uuid references auth.users(id) on delete set null,
  status text not null default 'sent' check (status in ('sent','active')),
  created_at timestamptz not null default now(),
  unique (company_id, email)
);

create table courses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  title text not null,
  category text not null default 'Umum',
  description text not null default '',
  outcomes text[] not null default '{}',
  duration_label text not null default '',
  art int not null default 0,
  published boolean not null default false,
  pass_mark int check (pass_mark between 0 and 100), -- null = company default
  max_attempts int not null default 3,
  time_limit_min int not null default 30,
  created_at timestamptz not null default now()
);
create index on courses(company_id);

-- Ordered steps of a course. kind: pre, video, pdf, post. section groups lesson steps.
create table steps (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  position int not null,
  kind text not null check (kind in ('pre','video','pdf','post')),
  section text,
  title text not null,
  meta text not null default '',
  media_url text,
  points int not null default 0
);
create index on steps(course_id, position);

create table questions (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  test_kind text not null check (test_kind in ('pre','post')),
  position int not null,
  body text not null,
  options text[] not null
);
create index on questions(course_id, test_kind, position);

-- Answer keys live apart so row level security can hide them from employees.
create table question_keys (
  question_id uuid primary key references questions(id) on delete cascade,
  answer int not null
);

create table assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  due_at timestamptz,
  assigned_at timestamptz not null default now(),
  unique (course_id, user_id)
);
create index on assignments(user_id);

create table step_progress (
  user_id uuid not null references profiles(id) on delete cascade,
  step_id uuid not null references steps(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, step_id)
);

create table attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  test_kind text not null check (test_kind in ('pre','post')),
  score int not null,
  passed boolean,
  answers jsonb not null,
  created_at timestamptz not null default now()
);
create index on attempts(user_id, course_id);

create table points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  amount int not null,
  reason text not null,
  ref text,
  created_at timestamptz not null default now(),
  unique (user_id, ref)
);

create table certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  number text not null,
  score int not null,
  issued_at timestamptz not null default now(),
  unique (user_id, course_id)
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on notifications(user_id, created_at desc);

create table surveys (
  user_id uuid not null references profiles(id) on delete cascade,
  course_id uuid not null references courses(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  primary key (user_id, course_id)
);

-- ---------- helpers ----------
create or replace function my_company() returns uuid
language sql stable security definer set search_path = public as
$$ select company_id from profiles where id = auth.uid() $$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select coalesce((select role = 'admin' from profiles where id = auth.uid()), false) $$;

-- ---------- row level security ----------
alter table companies enable row level security;
alter table profiles enable row level security;
alter table invites enable row level security;
alter table courses enable row level security;
alter table steps enable row level security;
alter table questions enable row level security;
alter table question_keys enable row level security;
alter table assignments enable row level security;
alter table step_progress enable row level security;
alter table attempts enable row level security;
alter table points_ledger enable row level security;
alter table certificates enable row level security;
alter table notifications enable row level security;
alter table surveys enable row level security;

create policy "read own company" on companies for select using (id = my_company());
create policy "admin edits company" on companies for update using (id = my_company() and is_admin());

create policy "read self or admin reads company" on profiles for select
  using (id = auth.uid() or (is_admin() and company_id = my_company()));
create policy "admin edits company profiles" on profiles for update
  using (is_admin() and company_id = my_company());
-- Employees change only phone, consent and leaderboard choice, through update_my_profile().

create policy "admin manages invites" on invites for all
  using (is_admin() and company_id = my_company()) with check (is_admin() and company_id = my_company());

create policy "read published or admin" on courses for select
  using (company_id = my_company() and (published or is_admin()));
create policy "admin manages courses" on courses for all
  using (is_admin() and company_id = my_company()) with check (is_admin() and company_id = my_company());

create policy "read steps of visible course" on steps for select
  using (exists (select 1 from courses c where c.id = course_id));
create policy "admin manages steps" on steps for all
  using (is_admin() and exists (select 1 from courses c where c.id = course_id and c.company_id = my_company()))
  with check (is_admin() and exists (select 1 from courses c where c.id = course_id and c.company_id = my_company()));

create policy "read questions of visible course" on questions for select
  using (exists (select 1 from courses c where c.id = course_id));
create policy "admin manages questions" on questions for all
  using (is_admin() and exists (select 1 from courses c where c.id = course_id and c.company_id = my_company()))
  with check (is_admin() and exists (select 1 from courses c where c.id = course_id and c.company_id = my_company()));

create policy "admin manages keys" on question_keys for all
  using (is_admin() and exists (select 1 from questions q join courses c on c.id = q.course_id where q.id = question_id and c.company_id = my_company()))
  with check (is_admin() and exists (select 1 from questions q join courses c on c.id = q.course_id where q.id = question_id and c.company_id = my_company()));

create policy "own or admin" on assignments for select
  using (user_id = auth.uid() or (is_admin() and company_id = my_company()));
create policy "admin manages assignments" on assignments for all
  using (is_admin() and company_id = my_company()) with check (is_admin() and company_id = my_company());

create policy "own or admin" on step_progress for select
  using (user_id = auth.uid() or (is_admin() and exists (select 1 from profiles p where p.id = user_id and p.company_id = my_company())));
create policy "own or admin" on attempts for select
  using (user_id = auth.uid() or (is_admin() and exists (select 1 from profiles p where p.id = user_id and p.company_id = my_company())));
create policy "own or admin" on points_ledger for select
  using (user_id = auth.uid() or (is_admin() and company_id = my_company()));
create policy "own or admin" on certificates for select
  using (user_id = auth.uid() or (is_admin() and exists (select 1 from profiles p where p.id = user_id and p.company_id = my_company())));
create policy "own" on notifications for select using (user_id = auth.uid());
create policy "own mark read" on notifications for update using (user_id = auth.uid());
create policy "own or admin" on surveys for select
  using (user_id = auth.uid() or (is_admin() and exists (select 1 from profiles p where p.id = user_id and p.company_id = my_company())));
create policy "own insert" on surveys for insert with check (user_id = auth.uid());

-- ---------- actions (run as the signed in person, checked inside) ----------

create or replace function update_my_profile(p_phone text, p_hide boolean, p_consent boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update profiles set
    phone = coalesce(p_phone, phone),
    hide_on_leaderboard = coalesce(p_hide, hide_on_leaderboard),
    consent_at = case when p_consent then coalesce(consent_at, now()) else consent_at end
  where id = auth.uid();
end $$;

create or replace function award_points(p_user uuid, p_amount int, p_reason text, p_ref text)
returns int language plpgsql security definer set search_path = public as $$
declare got int;
begin
  insert into points_ledger(user_id, company_id, amount, reason, ref)
  select p_user, company_id, p_amount, p_reason, p_ref from profiles where id = p_user
  on conflict (user_id, ref) do nothing;
  get diagnostics got = row_count;
  return case when got > 0 then p_amount else 0 end;
end $$;
revoke execute on function award_points from public, anon, authenticated;

-- Marks a video or PDF step done. Returns points earned (0 if already done).
create or replace function complete_step(p_step uuid)
returns int language plpgsql security definer set search_path = public as $$
declare s steps; c courses;
begin
  select * into s from steps where id = p_step;
  select * into c from courses where id = s.course_id;
  if c.company_id is distinct from my_company() then raise exception 'not allowed'; end if;
  if s.kind not in ('video','pdf') then raise exception 'tests are submitted with submit_test'; end if;
  insert into step_progress(user_id, step_id) values (auth.uid(), p_step) on conflict do nothing;
  return award_points(auth.uid(), s.points, 'Menyelesaikan ' || s.title, 'step:' || p_step);
end $$;

-- Grades a test on the server. p_answers is a json array of chosen option indexes (null = skipped).
create or replace function submit_test(p_course uuid, p_kind text, p_answers jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare
  c courses; s steps; total int; correct int := 0; score int; v_mark int; used int;
  is_pass boolean; earned int := 0; q record; i int := 0; cert_no text; review jsonb := '[]'::jsonb;
begin
  select * into c from courses where id = p_course;
  if c.company_id is distinct from my_company() then raise exception 'not allowed'; end if;
  select * into s from steps where course_id = p_course and kind = p_kind order by position limit 1;
  v_mark := coalesce(c.pass_mark, (select pass_mark from companies where id = c.company_id));
  select count(*) into used from attempts where user_id = auth.uid() and course_id = p_course and test_kind = p_kind;
  if p_kind = 'post' and used >= c.max_attempts then raise exception 'no attempts left'; end if;
  if p_kind = 'pre' and used >= 1 then raise exception 'pre test already done'; end if;

  select count(*) into total from questions where course_id = p_course and test_kind = p_kind;
  for q in select qu.id, qu.position, k.answer from questions qu join question_keys k on k.question_id = qu.id
           where qu.course_id = p_course and qu.test_kind = p_kind order by qu.position loop
    if (p_answers->>i) is not null and (p_answers->>i)::int = q.answer then correct := correct + 1; end if;
    review := review || jsonb_build_object('chosen', p_answers->i, 'answer', q.answer);
    i := i + 1;
  end loop;
  score := case when total = 0 then 0 else round(correct * 100.0 / total) end;
  is_pass := case when p_kind = 'post' then score >= v_mark else null end;

  insert into attempts(user_id, course_id, test_kind, score, passed, answers)
  values (auth.uid(), p_course, p_kind, score, is_pass, p_answers);

  if p_kind = 'pre' or is_pass then
    insert into step_progress(user_id, step_id) values (auth.uid(), s.id) on conflict do nothing;
    earned := award_points(auth.uid(), s.points, case when p_kind = 'pre' then 'Mengerjakan pre test ' else 'Lulus post test ' end || c.title, 'test:' || s.id);
  end if;

  if is_pass then
    cert_no := upper((select mark from companies where id = c.company_id)) || '-' || to_char(now(), 'YYYY') || '-' ||
               lpad((select count(*) + 1 from certificates ce join courses co on co.id = ce.course_id where co.company_id = c.company_id)::text, 4, '0');
    insert into certificates(user_id, course_id, number, score) values (auth.uid(), p_course, cert_no, score)
    on conflict (user_id, course_id) do update set score = greatest(certificates.score, excluded.score);
    insert into notifications(user_id, title, body, link)
    values (auth.uid(), 'Sertifikat terbit', c.title, '/certificates');
  end if;

  return json_build_object('score', score, 'correct', correct, 'total', total, 'pass_mark', v_mark,
    'passed', is_pass, 'points', earned, 'attempts_used', used + 1, 'max_attempts', c.max_attempts,
    'review', case when p_kind = 'post' and (is_pass or used + 1 >= c.max_attempts) then review
                   else (select jsonb_agg(jsonb_build_object('chosen', r->'chosen')) from jsonb_array_elements(review) r) end);
end $$;

-- Leaderboard for my company. Names of people who opted out are hidden.
create or replace function leaderboard()
returns table(rank bigint, user_id uuid, name text, dept text, points bigint, is_me boolean)
language sql stable security definer set search_path = public as $$
  select rank() over (order by coalesce(sum(l.amount),0) desc) as rank,
         p.id,
         case when p.hide_on_leaderboard and p.id <> auth.uid() then 'Karyawan ' || upper(left(p.dept, 1)) || '.' else p.full_name end,
         p.dept,
         coalesce(sum(l.amount),0),
         p.id = auth.uid()
  from profiles p left join points_ledger l on l.user_id = p.id
  where p.company_id = my_company() and p.role = 'learner'
  group by p.id order by 5 desc, 3;
$$;

-- Admin: assign a course to many people with one deadline, and notify them.
create or replace function assign_course(p_course uuid, p_users uuid[], p_due timestamptz)
returns int language plpgsql security definer set search_path = public as $$
declare n int; t text;
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  select title into t from courses where id = p_course and company_id = my_company();
  if t is null then raise exception 'course not found'; end if;
  insert into assignments(company_id, course_id, user_id, due_at)
  select my_company(), p_course, u, p_due from unnest(p_users) u
  join profiles p on p.id = u and p.company_id = my_company()
  on conflict (course_id, user_id) do update set due_at = excluded.due_at;
  get diagnostics n = row_count;
  insert into notifications(user_id, title, body, link)
  select u, 'Kelas baru ditugaskan', t || case when p_due is null then '' else ' · tenggat ' || to_char(p_due at time zone 'Asia/Jakarta', 'DD Mon YYYY') end, '/class/' || p_course
  from unnest(p_users) u join profiles p on p.id = u and p.company_id = my_company();
  return n;
end $$;

-- Links a new login to its invite on first sign in.
create or replace function claim_invite()
returns void language plpgsql security definer set search_path = public as $$
declare inv invites; em text;
begin
  if exists (select 1 from profiles where id = auth.uid()) then return; end if;
  select email into em from auth.users where id = auth.uid();
  select * into inv from invites where lower(email) = lower(em) order by created_at limit 1;
  if inv.id is null then raise exception 'no invite for this email'; end if;
  insert into profiles(id, company_id, full_name, email, dept, title, role)
  values (auth.uid(), inv.company_id, inv.full_name, em, inv.dept, inv.title, inv.role);
  update invites set status = 'active', user_id = auth.uid() where id = inv.id;
end $$;

-- Storage bucket for course media. Read by signed in users, write by admins.
insert into storage.buckets (id, name, public) values ('course-media', 'course-media', true) on conflict do nothing;
create policy "admins upload media" on storage.objects for insert to authenticated
  with check (bucket_id = 'course-media' and is_admin());
create policy "admins delete media" on storage.objects for delete to authenticated
  using (bucket_id = 'course-media' and is_admin());
