# Spotibai ERP

Spotibai is a static HTML/CSS application built with Vite and the official
Supabase JavaScript client. The existing page layouts and styling remain in
`Website/Website`.

## Local development

1. Install Node.js 20.11 or later.
2. Copy `.env.example` to `.env.local`.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from the Supabase
   project's public API settings. These are browser-visible values; never put a
   service-role or secret key in this file.
4. Install dependencies with `npm install`.
5. Run `npm run dev`, then open the URL Vite prints.
6. Run `npm run build` to validate and create the static production build in
   `dist`.

The client uses persistent Supabase Auth sessions. Email confirmation returns
to the current site's `/Login/Login.html?mode=signin&auth=confirmed` URL, so
local and deployed confirmations use the same origin that served the signup
page. Configure Supabase Auth **Site URL** to the real production origin and add
the local and deployed app URLs to the **Redirect URLs** allowlist. For example:

- `http://127.0.0.1:5173/**`
- `http://localhost:5173/**`
- `https://<your-actual-vercel-domain>/**`

Email confirmation and password recovery require a working Supabase email
provider. To enable Google sign-in, enable **Authentication → Providers →
Google** in Supabase, enter the OAuth client ID and secret there, and add the
callback URL shown by Supabase to the Google Cloud OAuth client's authorized
redirect URIs. Replace the production placeholder above with the exact
deployed Vercel domain; no production domain is configured in this repository.
Keep the Google client secret in Supabase;
never put it in Vite environment variables or browser code. Google sign-in
will not work until both provider configurations are complete.

The login page stores the selected Sign In/Register mode in its query string
and responds to browser Back/Forward without a full reload. It accepts both
`mode=signup` and `mode=register` for the Register view.

## Database setup and safety

The primary schema reference is
[`Experimental/Hope ERP/HopeDB_audit.sql.txt`](./Experimental/Hope%20ERP/HopeDB_audit.sql.txt).
It defines the existing customer, product/price, HR, sales/detail/payment, and
audit tables used by the app. **Do not rerun this file against an existing
database:** its opening `DROP TABLE ... CASCADE` statements are destructive.
The Spotibai integration migration is additive and is at
[`supabase/migrations/20261103235500_auth_profiles_rls.sql`](./supabase/migrations/20261103235500_auth_profiles_rls.sql).

Before applying the migration, confirm that the ten business tables and
`audit_log` already exist in the Supabase project's `public` schema. The
migration fails early if they do not. It does not import the SQL seed data and
does not recreate the existing business tables. Review the migration and take a
database backup before applying it in the Supabase SQL Editor or CLI. Do not
apply it to production until the schema and permissions have been reviewed.

The migration adds a `profiles` row linked to each `auth.users` account, forces
all newly registered accounts to the `user` role and `pending` status, and
enables RLS on the existing business tables and `audit_log`. It also adds
permission checks that preserve the dashboard's granular permission names,
soft-delete enforcement, private profile-picture storage, and a guarded
`manage_profile` database function. Users cannot directly write profile roles,
status, or permissions. Admins can manage User accounts only; only an active
Super Admin may assign Admin or Super Admin roles.

After applying the initial auth/RLS migration, apply any later numbered files in
[`supabase/migrations`](./supabase/migrations) in order. Later migrations add a
status-only applicant-review RPC, so approval or rejection does not rewrite or
validate profile names, and synchronize available Google name metadata without
changing account roles or status. The
[`20261104002000_payment_report_permission.sql`](./supabase/migrations/20261104002000_payment_report_permission.sql)
migration adds the `reports.payment` permission to the database allowlist. It
does not create or alter business tables or RLS policies; Payment Report reads
existing `payment` rows protected by the existing `sales.view` permission.
The
[`20261104003000_realtime_publication.sql`](./supabase/migrations/20261104003000_realtime_publication.sql)
migration adds the existing `profiles`, ERP, and `audit_log` tables to the
`supabase_realtime` publication when not already present. It does not change
table definitions or RLS policies; row visibility continues to be governed by
the existing policies. Apply it in the target Supabase project for live updates
to work.

### Provision the first Super Admin

There is deliberately no public or browser-based Super Admin bootstrap.

1. In Supabase Dashboard, open **Authentication → Users** and create/invite the
   owner account. Complete the email confirmation/invitation flow.
2. In **SQL Editor**, look up the exact Auth user UUID:

   ```sql
   SELECT id, email FROM auth.users WHERE lower(email) = lower('owner@example.com');
   ```

3. Verify that exactly one row is returned and that a matching
   `public.profiles` row exists. Then provision that UUID in the SQL Editor:

   ```sql
   UPDATE public.profiles
   SET role = 'superadmin',
       account_status = 'active',
       permissions = '{}'::jsonb
   WHERE id = 'REPLACE_WITH_VERIFIED_AUTH_USER_UUID';
   ```

4. Verify the affected row and role:

   ```sql
   SELECT p.id, p.email, p.role, p.account_status
   FROM public.profiles AS p
   JOIN auth.users AS u ON u.id = p.id
   WHERE p.id = 'REPLACE_WITH_VERIFIED_AUTH_USER_UUID';
   ```

Run the update only after verifying the UUID; it should affect exactly one row.
The Auth trigger creates profiles as `user`, so registering the owner through
the public signup page does not grant any privileges.

## User invitations

The User Management “Add User” action uses the
[`invite-user` Edge Function](./supabase/functions/invite-user/index.ts). It
validates the caller's Auth session and database role before using the
service-role key server-side to send an invitation. Deploy it with the
Supabase CLI and configure the function's `ALLOWED_ORIGINS` secret to include
the exact local/deployed app origins. The Supabase-provided
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` must be
available only to the Edge Function runtime. Never expose the service-role key
to Vite or browser code.

## Authorization behavior

- Every public signup receives role `user` and status `pending`; client-supplied
  role metadata is ignored by the database trigger.
- Administrators approve accounts and assign granular business permissions.
- RLS checks profile status, role, and assigned permissions for every
  business-table read/write. Delete actions are soft deletes; hard delete and
  truncate stay unavailable to browser clients. Permission checks also require
  the parent module's view permission for its child actions.
- A report permission controls which report is shown; the relevant source
  module's view permission is also required so report data remains covered by
  the same database RLS rules.
- Profile updates are limited to the signed-in user's name, phone, and avatar
  path. Email changes use Supabase Auth's confirmation flow.
- Super Admin elevation is possible only by the documented trusted bootstrap
  or a role-management call made by an existing active Super Admin.
