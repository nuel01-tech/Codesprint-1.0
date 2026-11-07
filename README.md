# CodeSprint 1.0 — Student Portal

A responsive student portal for the two-week Python and automation class.

## Features
- Open student registration; new accounts are always students
- Email/password authentication with Supabase
- Student learning hub and class schedule\n- 21 structured Python and automation modules across six live class days
- Assignment publishing and private student file submissions
- Multiple-choice quizzes graded server-side
- Leaderboard with administrator-awarded points
- Multiple administrators, promoted securely through Supabase SQL

## Stack
Static HTML/CSS/JavaScript + Supabase Auth, Postgres, Row Level Security and private Storage.

## Deployment
Production: https://codesprint-1-0.vercel.app/\n\nVercel automatically deploys the `main` branch. See [SETUP.md](SETUP.md) for Supabase and Google OAuth configuration. GitHub Pages is a legacy deployment path.

## Security
The browser contains only the Supabase publishable key. Never add a service-role key. Database access is protected by RLS; correct quiz answers are not exposed to students.

## Project
Supabase ref: `hupqkpwrhnoypskathyg`
