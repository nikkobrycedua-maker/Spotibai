# Global Copilot Instructions

- Tech Stack: Next.js (App Router), Tailwind CSS, Supabase Auth & Database.
- User Roles: superadmin, admin, user. Public signups always default to 'user'; privileged roles must be assigned through a trusted server-side or database path.
- Security: Enable Row Level Security (RLS) on all Supabase tables.
- Git Strategy: Never commit directly to main branch. Always create feature branches.
