# CodeSprint 1.0 setup

## Supabase
This portal uses the dedicated project `hupqkpwrhnoypskathyg` at https://hupqkpwrhnoypskathyg.supabase.co. The schema, RLS policies, private assignment bucket and server-side quiz grading function have already been applied to that project.

In Supabase Dashboard → Authentication → URL Configuration, set Site URL to:
`https://codesprint-1-0.vercel.app/`
Add `https://codesprint-1-0.vercel.app/**` to the Redirect URLs allow-list. The Google OAuth provider's redirect URI in Google Cloud must be the Supabase callback URL shown in the Google provider settings (not the Vercel URL).

## First administrator
1. Register your own account in the portal.
2. Confirm the email if email confirmation is enabled.
3. Open Supabase SQL Editor and run the SQL in `supabase/admin-setup.sql`, replacing `YOUR_ADMIN_EMAIL` with your confirmed email.
4. Repeat that statement for each additional administrator. Never let public signup select the admin role.

## Production deployment
The production portal is hosted at `https://codesprint-1-0.vercel.app/`. Vercel is connected to this GitHub repository and automatically deploys pushes to `main`. Use the Vercel production URL for student access and Supabase Auth redirects. The GitHub Pages workflow is a legacy deployment path and should not be used as the primary OAuth redirect.

## Test before inviting students
- Register a student and confirm profile creation.
- Promote one trusted account to admin with the SQL above.
- Publish a test assignment and quiz.
- Upload a small .py file, submit a quiz, and award test points.
- Verify students can only access their own submission records and private files.

## Security
The frontend uses only a Supabase publishable key. Never put a service-role key in this public repository. RLS protects database rows; quiz correct answers remain server-side. Student registration always creates the student role.
