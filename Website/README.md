# Spotibai ERP

This folder is the self-contained Spotibai handoff project. It includes the
existing static HTML/CSS/JavaScript application, Vite build setup, Supabase
client, database setup/migrations, and the optional user-invitation Edge
Function.

## Start here

Read [plan.md](./plan.md) for the beginner-oriented project setup guide. It
contains the full SQL scripts in execution order, Supabase Auth/OAuth setup,
email-confirmation redirect allowlisting, first Super Admin bootstrap
instructions, local Windows commands, and troubleshooting.

The `20261104003000_realtime_publication.sql` migration enables the app's
Supabase Realtime subscriptions for profile, business-data, and audit updates.
The latest `20261105000000_protect_superadmin_accounts.sql` migration protects
Super Admin profiles across account-management RPCs and reasserts the profile
column grants and self-only update policy. Apply all migrations in order before
expecting the updated authorization behavior.

Profile pictures use the existing private `avatars` bucket, capped at 5 MB and
restricted by Storage policies to each authenticated user's UUID folder. The
dashboard crops JPG/JPEG, PNG, or WebP uploads to PNG, stores only the object's
path in `profiles.avatar_path`, and displays the default avatar if the picture
is missing or inaccessible. Users can remove their own picture from Edit
Profile; no additional bucket or Storage policy migration is needed.

The database audit and its evidence boundaries are in
[docs/SPOTIBAI_DATABASE_AUDIT.md](./docs/SPOTIBAI_DATABASE_AUDIT.md).

## Quick local commands

1. Copy `.env.example` to `.env.local` and enter your own Supabase Project URL
   and publishable/anon key.
2. Run `npm install`.
3. Run `npm run dev` to start the application.
4. Run `npm run build` to validate a production build.

Never put a Supabase service-role/secret key, database password, OAuth client
secret, or authentication token in frontend configuration. The original
HopeDB SQL dump is intentionally excluded because it starts with destructive
`DROP TABLE ... CASCADE` statements. Use only the guarded setup script and
ordered migrations documented in `plan.md`, and only in a new Supabase project.
