-- CodeSprint 1.0 schema reference (initial migration 20261107052459).
-- Production project: hupqkpwrhnoypskathyg.
create extension if not exists pgcrypto;
create schema if not exists private;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default 'CodeSprint Learner',
 email text not null,
 role text not null default 'student' check(role in ('student','admin')),
 created_at timestamptz not null default now()
);
create table public.leaderboard_entries (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 display_name text not null, points integer not null default 0 check(points>=0),
 updated_at timestamptz not null default now()
);
create table public.assignments (
 id uuid primary key default gen_random_uuid(), title text not null, description text not null,
 week smallint not null check(week in (1,2)), due_at timestamptz,
 published boolean not null default false, created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now()
);
create table public.submissions (
 id uuid primary key default gen_random_uuid(),
 assignment_id uuid not null references public.assignments(id) on delete cascade,
 student_id uuid not null references public.profiles(id) on delete cascade,
 storage_path text not null unique, original_filename text not null,
 status text not null default 'submitted' check(status in ('submitted','reviewed','needs_revision')),
 feedback text, score numeric(6,2) check(score is null or score between 0 and 100),
 created_at timestamptz not null default now(), reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id)
);
create table public.quizzes (
 id uuid primary key default gen_random_uuid(), title text not null,
 week smallint not null check(week in (1,2)), published boolean not null default false,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table public.quiz_questions (
 id uuid primary key default gen_random_uuid(),
 quiz_id uuid not null references public.quizzes(id) on delete cascade,
 question_text text not null, option_a text not null, option_b text not null, option_c text not null,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table public.quiz_answer_keys (
 question_id uuid primary key references public.quiz_questions(id) on delete cascade,
 correct_option smallint not null check(correct_option between 0 and 2)
);
create table public.quiz_attempts (
 id uuid primary key default gen_random_uuid(),
 quiz_id uuid not null references public.quizzes(id) on delete cascade,
 student_id uuid not null references public.profiles(id) on delete cascade,
 score smallint not null check(score between 0 and 100),
 answers jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'); $$;
revoke all on function private.is_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into public.profiles(id,full_name,email,role)
 values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'CodeSprint Learner'),lower(new.email),'student')
 on conflict(id) do nothing;
 insert into public.leaderboard_entries(user_id,display_name,points)
 values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'CodeSprint Learner'),0)
 on conflict(user_id) do nothing;
 return new;
end; $$;
revoke all on function public.handle_new_user() from public,anon,authenticated;
create trigger on_auth_user_created_codesprint after insert on auth.users
for each row execute function public.handle_new_user();

-- Keep the student-facing profile email aligned with Supabase Auth after a
-- confirmed email change. This keeps admin lookup and account records in sync.
create or replace function public.sync_profile_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path=''
as $
begin
  update public.profiles
  set email=lower(trim(new.email))
  where id=new.id;
  return new;
end;
$;
revoke all on function public.sync_profile_email_from_auth() from public,anon,authenticated;
drop trigger if exists on_auth_user_email_updated_codesprint on auth.users;
create trigger on_auth_user_email_updated_codesprint
after update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function public.sync_profile_email_from_auth();

alter table public.profiles enable row level security;
alter table public.leaderboard_entries enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_answer_keys enable row level security;
alter table public.quiz_attempts enable row level security;

create policy "profile read self or admin" on public.profiles for select to authenticated using(id=(select auth.uid()) or (select private.is_admin()));
create policy "admin update profiles" on public.profiles for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "read published assignments" on public.assignments for select to authenticated using(published or (select private.is_admin()));
create policy "admins insert assignments" on public.assignments for insert to authenticated with check((select private.is_admin()) and created_by=(select auth.uid()));
create policy "admins update assignments" on public.assignments for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admins delete assignments" on public.assignments for delete to authenticated using((select private.is_admin()));
create policy "students read own submissions" on public.submissions for select to authenticated using(student_id=(select auth.uid()) or (select private.is_admin()));
create policy "students submit own work" on public.submissions for insert to authenticated with check(student_id=(select auth.uid()) and exists(select 1 from public.assignments a where a.id=assignment_id and a.published));
create policy "admins review submissions" on public.submissions for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "read published quizzes" on public.quizzes for select to authenticated using(published or (select private.is_admin()));
create policy "admins insert quizzes" on public.quizzes for insert to authenticated with check((select private.is_admin()) and created_by=(select auth.uid()));
create policy "admins update quizzes" on public.quizzes for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admins delete quizzes" on public.quizzes for delete to authenticated using((select private.is_admin()));
create policy "read questions for published quizzes" on public.quiz_questions for select to authenticated using((select private.is_admin()) or exists(select 1 from public.quizzes q where q.id=quiz_id and q.published));
create policy "admins insert questions" on public.quiz_questions for insert to authenticated with check((select private.is_admin()) and created_by=(select auth.uid()));
create policy "admins update questions" on public.quiz_questions for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "admins delete questions" on public.quiz_questions for delete to authenticated using((select private.is_admin()));
create policy "admins manage answer keys" on public.quiz_answer_keys for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "students read own attempts" on public.quiz_attempts for select to authenticated using(student_id=(select auth.uid()) or (select private.is_admin()));
create policy "authenticated read leaderboard" on public.leaderboard_entries for select to authenticated using(true);
create policy "admins update leaderboard" on public.leaderboard_entries for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));

create or replace function public.submit_quiz_attempt(p_quiz_id uuid,p_answers jsonb)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid:=(select auth.uid()); v_total integer; v_correct integer; v_score integer;
begin
 if v_user_id is null then raise exception 'Sign in required'; end if;
 if jsonb_typeof(p_answers)<>'array' then raise exception 'Answers must be an array'; end if;
 if not exists(select 1 from public.quizzes q where q.id=p_quiz_id and q.published) then raise exception 'Quiz is not available'; end if;
 select count(*) into v_total from public.quiz_questions where quiz_id=p_quiz_id;
 if v_total=0 or jsonb_array_length(p_answers)<>v_total then raise exception 'Submit one answer for every question'; end if;
 if exists(select 1 from jsonb_to_recordset(p_answers) as a(question_id uuid,selected_option integer)
  where a.selected_option not between 0 and 2 or not exists(select 1 from public.quiz_questions qq where qq.id=a.question_id and qq.quiz_id=p_quiz_id))
 then raise exception 'Invalid answer submitted'; end if;
 if (select count(distinct a.question_id) from jsonb_to_recordset(p_answers) as a(question_id uuid,selected_option integer))<>v_total
 then raise exception 'Duplicate or missing question answers'; end if;
 select count(*) into v_correct from jsonb_to_recordset(p_answers) as a(question_id uuid,selected_option integer)
 join public.quiz_questions qq on qq.id=a.question_id and qq.quiz_id=p_quiz_id
 join public.quiz_answer_keys ak on ak.question_id=qq.id where ak.correct_option=a.selected_option;
 v_score:=round((v_correct::numeric/v_total)*100)::integer;
 insert into public.quiz_attempts(quiz_id,student_id,score,answers) values(p_quiz_id,v_user_id,v_score,p_answers);
 return v_score;
end; $$;
revoke all on function public.submit_quiz_attempt(uuid,jsonb) from public,anon;
grant execute on function public.submit_quiz_attempt(uuid,jsonb) to authenticated;

create or replace function public.award_leaderboard_points(target_user_id uuid,points_to_add integer)
returns void language plpgsql security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null or not private.is_admin() then raise exception 'Admin access required'; end if;
 if points_to_add is null or points_to_add<0 or points_to_add>10000 then raise exception 'Points must be between 0 and 10000'; end if;
 update public.leaderboard_entries set points=points+points_to_add,updated_at=now() where user_id=target_user_id;
 if not found then raise exception 'Student leaderboard entry not found'; end if;
end; $$;
revoke all on function public.award_leaderboard_points(uuid,integer) from public,anon;
grant execute on function public.award_leaderboard_points(uuid,integer) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('assignment-files','assignment-files',false,10485760,array['text/x-python','text/plain','application/pdf','text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/zip','application/x-zip-compressed','application/octet-stream']);
create policy "students upload to own folder" on storage.objects for insert to authenticated
with check(bucket_id='assignment-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "students read own files and admins read all" on storage.objects for select to authenticated
using(bucket_id='assignment-files' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select private.is_admin())));
create policy "admins delete assignment files" on storage.objects for delete to authenticated using(bucket_id='assignment-files' and (select private.is_admin()));

grant select on public.profiles to authenticated;
grant update(full_name) on public.profiles to authenticated;
grant select,insert,update,delete on public.assignments to authenticated;
grant select,insert,update on public.submissions to authenticated;
grant select,insert,update,delete on public.quizzes to authenticated;
grant select,insert,update,delete on public.quiz_questions to authenticated;
grant select,insert,update,delete on public.quiz_answer_keys to authenticated;
grant select on public.quiz_attempts to authenticated;
grant select,update on public.leaderboard_entries to authenticated;
grant select,insert,delete on storage.objects to authenticated;
