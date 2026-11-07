# CodeSprint 1.0 — Student Portal

A responsive student portal for the two-week Python and automation class.

## Features
- Open student registration; new accounts are always students
- Email/password authentication with Supabase
- Student learning hub and class schedule
- Assignment publishing and private student file submissions
- Multiple-choice quizzes graded server-side
- Leaderboard with administrator-awarded points
- Multiple administrators, promoted securely through Supabase SQL

## Stack
Static HTML/CSS/JavaScript + Supabase Auth, Postgres, Row Level Security and private Storage.

## Deployment
See [SETUP.md](SETUP.md). Enable GitHub Pages with **GitHub Actions** as the source. The workflow deploys each push to main.

## Security
The browser contains only the Supabase publishable key. Never add a service-role key. Database access is protected by RLS; correct quiz answers are not exposed to students.

## Project
Supabase ref: `hupqkpwrhnoypskathyg`
