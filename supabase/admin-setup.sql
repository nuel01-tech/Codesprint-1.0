-- Run after the administrator has registered and confirmed their email.
-- Repeat for each trusted administrator. Never expose role selection on public signup.
update public.profiles
set role = 'admin'
where lower(email) = lower('YOUR_ADMIN_EMAIL')
  and exists (
    select 1 from auth.users u
    where u.id = profiles.id and u.email_confirmed_at is not null
  );
