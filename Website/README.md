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

The latest migration enables the app's Supabase Realtime subscriptions for
profile, business-data, and audit updates without changing table definitions or
RLS policies. Apply it in the target project's migration sequence before
expecting live synchronization.

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
