# Spotibai ERP: Shareable Setup Plan

This manual is for a **new, empty Supabase project** and a clean copy of this folder. It intentionally does not contain anyone's project URL, API key, database password, OAuth secret, or service-role key. Do not run these setup instructions against an existing or populated database.

## Part 1 — Project overview

Spotibai is a browser-based ERP interface for customer, product/price-history, human-resources, sales, payment, reporting, and user-management workflows.

- **Frontend:** static HTML, CSS, and JavaScript in `Website/`. Vite serves the pages locally and produces a static build. The existing user interface and business modules are retained.
- **Database and backend:** Supabase provides PostgreSQL, Authentication, Row Level Security (RLS), database functions/triggers, and private Storage for avatars.
- **Client integration:** `@supabase/supabase-js` is initialized in `Website/scripts/supabase-client.js` using only the public project URL and publishable/anon key. Authentication sessions persist using local or session storage according to “Remember me”.
- **Trusted server function:** `supabase/functions/invite-user/index.ts` is an Edge Function. It verifies the caller, then uses the server-side service-role key to send invitations. That key must never be placed in frontend code or `.env.local`.

Before starting, have:

1. A Windows computer and VS Code.
2. Node.js 20.11 or later with npm.
3. A Supabase account and permission to create a new project.
4. A new, empty Supabase project for this independent copy.
5. Optional: a Google Cloud account if Google sign-in is desired.
6. Optional: the Supabase CLI if deploying the User Management invitation function.

## Part 2 — Final folder structure

```text
Website/
├── Website/                              # Existing runtime application
│   ├── index.html
│   ├── Dashboard/Dashboard.html
│   ├── Homepage/index.html
│   ├── Homepage/style.css
│   ├── Login/Login.html
│   ├── Login/script.js
│   ├── Login/style.css
│   ├── Login/BG/Background.png
│   ├── Login/BG/Layer1.png
│   └── scripts/
│       ├── supabase-bridge.js
│       └── supabase-client.js
├── supabase/
│   ├── setup/001_initial_schema.sql
│   ├── migrations/
│   │   ├── 20261103235500_auth_profiles_rls.sql
│   │   ├── 20261104000000_review_applicants.sql
│   │   ├── 20261104001000_google_profile_name_sync.sql
│   │   ├── 20261104002000_payment_report_permission.sql
│   │   └── 20261104003000_realtime_publication.sql
│   └── functions/invite-user/index.ts
├── docs/SPOTIBAI_DATABASE_AUDIT.md
├── plan.md
├── package.json
├── package-lock.json
├── vite.config.js
├── .env.example
├── .gitignore
├── README.md
└── Wireframes.html                       # Existing design reference
```

### File purposes

- `Website/` contains the existing HTML pages, CSS, images, JavaScript, and Supabase browser client. Relative page and asset URLs remain unchanged.
- `supabase/setup/001_initial_schema.sql` is the guarded initial business schema **and the only business-data seed script**.
- `supabase/migrations/` contains the required auth/RLS and later feature SQL. Run in the sequence shown in Part 4.
- `supabase/functions/invite-user/index.ts` is the server-side invitation function used by User Management. It is not SQL.
- `docs/SPOTIBAI_DATABASE_AUDIT.md` records audit findings and clearly distinguishes local source evidence from live checks that were not available.
- `package.json` and `package-lock.json` define the frontend dependencies and npm commands.
- `vite.config.js` points Vite at the existing `Website/` application folder and writes build output to `dist/`.
- `.env.example` contains empty frontend variable values. Copy it to `.env.local` and supply your own project's public settings.
- `.gitignore` excludes local environment files, dependencies, and generated output.
- `Wireframes.html` is an optional standalone reference; it is not used by the running application.

The original repository's `.git` folder, `node_modules`, generated `dist`, local `.env.local`, unrelated experimental files, and class/project planning materials are not part of this handoff. The original HopeDB SQL dump is intentionally not copied: it begins with destructive `DROP TABLE ... CASCADE` statements. Its safe, guarded initializer is retained under `supabase/setup/`.

## Part 3 — Create a new Supabase project

1. Visit [https://supabase.com](https://supabase.com) and sign in, or create your own account.
2. Create or select an organization that you control.
3. Choose **New project**.
4. Give the project a new name, such as `spotibai-class-copy`.
5. Create a new strong database password and store it privately. It is not needed in the frontend `.env.local`.
6. Choose a region near the people who will use the project.
7. Create the project and wait until Supabase reports that it is ready.
8. Open the project's **SQL Editor**. You will run the scripts from Part 4 there, in order.
9. Keep this project separate from any existing Spotibai project. All instructions and SQL in this manual are for your own new project.

## Part 4 — Database setup and complete SQL scripts

### Execution order and safety

Run these scripts once, from the Supabase SQL Editor, in this order:

1. `supabase/setup/001_initial_schema.sql` — guarded HopeDB business tables, constraints, seed rows, audit triggers, and active views.
2. `supabase/migrations/20261103235500_auth_profiles_rls.sql` — profiles, auth triggers, role/permission functions, business-table RLS, audit protections, and avatar Storage policies.
3. `supabase/migrations/20261104000000_review_applicants.sql` — secure applicant approval/disapproval RPC.
4. `supabase/migrations/20261104001000_google_profile_name_sync.sql` — synchronize available Google name metadata without changing account roles or status.
5. `supabase/migrations/20261104002000_payment_report_permission.sql` — allowlist the `reports.payment` permission.
6. `supabase/migrations/20261104003000_realtime_publication.sql` — add the existing profiles, ERP, and audit tables to Supabase Realtime's publication.
7. `supabase/migrations/20261105000000_protect_superadmin_accounts.sql` — protect Super Admin profiles in management RPCs and reassert profile update grants and policies.

These are complete source copies embedded below and retained separately as `.sql` files. The safe setup script creates the original business seed records exactly once. **Do not also execute `Experimental/Hope ERP/HopeDB_audit.sql.txt` or run another seed script.**

The first script has a transaction and checks that its target tables, active views, and audit functions do not exist; it stops rather than replacing them. Run it only in the new, empty project's SQL Editor. Do not attempt to make it work against a populated project. Later migration scripts use named `DROP POLICY IF EXISTS` and `DROP TRIGGER IF EXISTS` statements to replace their own policy/trigger definitions. They do not drop business tables, but they are still setup/migration operations and should not be casually replayed against an unrelated project.

The setup source contains no `DROP TABLE`, `DROP SCHEMA`, `DROP FUNCTION`, `DELETE FROM`, or seed-time `TRUNCATE`. Its `UPDATE` assigns the initial audit stamp to the newly seeded rows. It creates triggers that block subsequent hard DELETE/TRUNCATE operations. The auth migration has a foreign key `ON DELETE CASCADE` from `profiles.id` to `auth.users.id`; that is an intentional relationship, not a setup-time delete.

### RLS policy model

PostgreSQL/Supabase requires an applicable **PERMISSIVE** policy to allow a command. The auth/RLS script installs permissive baseline policies for authenticated users, then applies **RESTRICTIVE** policies to narrow the combined result. For those policies, the permissive grants are OR-combined, while restrictive checks must also pass. Do not remove the restrictive policies or replace them with unrestricted permissive policies to solve an access error.

The `has_permission(text)` function requires an active profile and grants the active `superadmin` role system-wide business-table permission; other users need the exact permission and the parent module's view permission for non-view actions. Admins can manage User accounts only. The profile read policy permits a user to read their own profile, a Super Admin to read profiles, and system admins to read User profiles. The final account-protection migration makes `manage_profile` and `review_applicant` lock and validate the authenticated actor and current target in the transaction; existing Super Admin profiles cannot be managed, and direct profile updates remain self-only and limited to non-authority columns.

### Script 1 of 7 — safe business schema and seed

**Filename:** `supabase/setup/001_initial_schema.sql`
**Purpose:** Create the 10 HopeDB business tables, primary/foreign keys and CHECK constraints; insert the original seed data once; add audit/soft-delete columns, functions, triggers, and active views.
**Prerequisites:** A fresh Supabase project whose `public` schema has none of the target business tables, audit table, views, or helper functions.
**Expected result:** Transaction completes with business tables and seed data, and an empty append-only `audit_log` ready to record subsequent changes. If a target object already exists, the guard raises an error and the transaction does not initialize the schema.

```sql
-- Spotibai initial schema for a confirmed-empty Supabase public schema.
-- Generated from Experimental/Hope ERP/HopeDB_audit.sql.txt.
-- Preserves its business schema and seed data, omitting only the original DROP TABLE statements.
-- Run only when the target public tables, active views, and audit functions do not already exist.
-- This script does not create profiles or modify Supabase-managed schemas.

BEGIN;
SET LOCAL search_path = public, pg_temp;

DO $$
DECLARE
  object_name text;
  target_relations text[] := ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log',
    'employee_active', 'department_active', 'job_active', 'jobhistory_active',
    'customer_active', 'sales_active', 'salesdetail_active', 'product_active',
    'payment_active', 'pricehist_active'
  ];
  target_functions text[] := ARRAY[
    'audit_user()', 'audit_stamp(text)', 'trg_set_stamp()', 'trg_audit_log()',
    'trg_block_hard_delete()', 'trg_protect_audit_log()', 'trg_check_children()'
  ];
BEGIN
  FOREACH object_name IN ARRAY target_relations LOOP
    IF to_regclass(format('public.%I', object_name)) IS NOT NULL THEN
      RAISE EXCEPTION 'Target object public.% already exists; initialization stopped without replacing it.', object_name;
    END IF;
  END LOOP;
  FOREACH object_name IN ARRAY target_functions LOOP
    IF to_regprocedure('public.' || object_name) IS NOT NULL THEN
      RAISE EXCEPTION 'Target function public.% already exists; initialization stopped without replacing it.', object_name;
    END IF;
  END LOOP;
END;
$$;

-- Hope, Inc. Database 
-- Fictitious Company
-- Conceptualized by JEREMIAS C. ESPERANZA - NEU CCS
-- Information Management Course
-- Create customer table 
CREATE TABLE public.employee (empno VARCHAR(5) NOT NULL PRIMARY KEY, 
												lastname VARCHAR(15),  
												firstname VARCHAR(15), 
												gender CHAR(1) CONSTRAINT gender_ck CHECK (gender in ('M','F')), 
												birthdate DATE, 
												hiredate DATE, 
												sepDate DATE);

-- Insert employee records
INSERT INTO employee VALUES('00001','Smith', 'John', 'M','1985-02-20','2010-05-11', NULL);
INSERT INTO employee VALUES('00003','Smith', 'Jane', 'F','1990-05-16','2010-05-11', NULL);
INSERT INTO employee VALUES('00005','King', 'Don', 'M','1986-02-14','2010-06-23', NULL);
INSERT INTO employee VALUES('00007','Jenskin', 'Floyd', 'M','1990-02-20','2010-05-30', NULL);
INSERT INTO employee VALUES('00009','Cerudo', 'Bambie', 'F','1983-06-23','2010-05-30', NULL);
INSERT INTO employee VALUES('00011','Davis', 'Tom', 'M','1989-12-16','2010-06-30', NULL);
INSERT INTO employee VALUES('00013','Morris', 'Olive', 'F','1991-07-21','2010-06-30', NULL);
INSERT INTO employee VALUES('00015','Zulueta', 'Maggie', 'F','1990-08-03','2010-07-05', '2011-03-30');
INSERT INTO employee VALUES('00017','Celestino', 'Nelia', 'F','1984-10-24','2010-07-05', NULL);
INSERT INTO employee VALUES('00019','Esperanza', 'Nehemiah', 'M','1982-02-21','2010-07-05', '2014-04-28');
INSERT INTO employee VALUES('00021','Manchester', 'Chelie', 'F','1988-12-07','2010-07-05', NULL);
INSERT INTO employee VALUES('00023','Kline', 'Nicholas', 'M','1992-01-21','2010-07-05', '2010-12-23');
INSERT INTO employee VALUES('00025','Macapagal', 'Ivy', 'F','1992-04-30','2010-07-05', NULL);
INSERT INTO employee VALUES('00027','Blanche', 'Ernest', 'M','1986-12-21','2010-07-05', NULL);
INSERT INTO employee VALUES('00029','Chua', 'Evangeline', 'F','1989-03-10','2010-07-05', NULL);
INSERT INTO employee VALUES('00031','Lancaster', 'Greta', 'F','1987-08-17','2010-07-05', NULL);
INSERT INTO employee VALUES('00033','Parks', 'Nigel', 'M','1993-06-23','2010-07-05', NULL);
INSERT INTO employee VALUES('00035','Carlston', 'Voltaire', 'F','1985-06-12','2010-07-21', NULL);
INSERT INTO employee VALUES('00037','Silva', 'Yves', 'M','1988-09-21','2010-07-21', NULL);
INSERT INTO employee VALUES('00039','Geisert', 'William', 'M','1980-03-03','2010-07-21', NULL);
INSERT INTO employee VALUES('00041','Darwin', 'Helena', 'F','1978-11-08','2010-09-01', NULL);
INSERT INTO employee VALUES('00043','Love', 'Queen', 'F','1983-11-29','2010-09-01', NULL);
INSERT INTO employee VALUES('00045','Raven', 'Danny', 'M','1984-02-15','2010-12-03', NULL);
INSERT INTO employee VALUES('00047','Devito', 'Clint', 'M','1981-06-07','2010-12-03', NULL);
INSERT INTO employee VALUES('00049','Irving', 'Nancy', 'F','1987-09-19','2010-12-03', NULL);
INSERT INTO employee VALUES('00051','Baltimore', 'Fergie', 'F','1986-10-10','2011-01-05', NULL);
INSERT INTO employee VALUES('00053','Jones', 'Veronica', 'F','1983-05-01','2011-01-05', '2011-03-30');
INSERT INTO employee VALUES('00055','Travis', 'Ursula', 'F','1987-06-07','2011-01-05', NULL);
INSERT INTO employee VALUES('00057','Orleans', 'Sylvia', 'F','1987-01-28','2011-01-05', NULL);
INSERT INTO employee VALUES('00059','Sy', 'Alice', 'F','1984-08-13','2011-01-05', '2011-04-20');
INSERT INTO employee VALUES('00061','De Leon', 'Girlie', 'F','1983-07-27','2011-01-05', NULL);
INSERT INTO employee VALUES('00063','Grant', 'Albert', 'M','1979-05-05','2011-01-05', NULL);

-- Create DEPARTMENT
CREATE TABLE public.department (deptCode VARCHAR(3) NOT NULL,
												  deptName VARCHAR (20), 
												  PRIMARY KEY (deptCode)) ;

INSERT INTO department  VALUES  ('ACT', 'Accounting'),
															  ('BR1', 'Sales Branch 1'),
															  ('BR2', 'Sales Branch 2'),
															  ('EXC', 'Executive'),
															  ('HRD', 'Human Resource'),
															  ('IT', 'Information Tech'),
															  ('PAY', 'Payroll'), 
															  ('WHS', 'Warehouse');


-- Create JOB 
CREATE TABLE public.job (jobCode VARCHAR(4) NOT NULL PRIMARY KEY, 
									 jobDesc VARCHAR(20)) ;

-- Insert rows JOB 
INSERT INTO job VALUES('PRES','President');
INSERT INTO job VALUES('VP','Vice president');
INSERT INTO job VALUES('MGR','Manager');
INSERT INTO job VALUES('SA1','Sales Agent 1');
INSERT INTO job VALUES('SA2','Sales Agent 2');
INSERT INTO job VALUES('SPVR','Supervisor');
INSERT INTO job VALUES('CLK1','Clerk 1');
INSERT INTO job VALUES('CLK2','Clerk 2');
INSERT INTO job VALUES('PR1','Programmer 1');
INSERT INTO job VALUES('PR2','Programmer 2');
INSERT INTO job VALUES('ANYS','Analyst');
INSERT INTO job VALUES('ACCT','Accountant');
INSERT INTO job VALUES('WMAN','Warehouse man');
INSERT INTO job VALUES('HRS','HR Specialist');


-- Create jobHistory
CREATE TABLE public.jobHistory (empNo VARCHAR(5) NOT NULL REFERENCES employee,
												  jobCode VARCHAR(4) NOT NULL REFERENCES job, 
												  effDate DATE NOT NULL , 
												  salary DECIMAL(10,2) CONSTRAINT salary_ck 
												  CHECK (salary >= 0.0), deptCode VARCHAR(4),
												  PRIMARY KEY (empNo, jobCode,effDate), 
												  FOREIGN KEY (deptCode) REFERENCES department);

-- Insert rows jobHistory
INSERT INTO jobHistory VALUES('00001','PR1', '2010-05-11', 48000,'IT');
INSERT INTO jobHistory VALUES('00001','PR2', '2010-12-01', 50000,'IT');
INSERT INTO jobHistory VALUES('00003','PR2', '2010-05-11', 50000,'IT');
INSERT INTO jobHistory VALUES('00003','ANYS', '2010-12-01', 55000,'IT');
INSERT INTO jobHistory VALUES('00005','SA1', '2010-06-23', 36000,'BR1');
INSERT INTO jobHistory VALUES('00005','SA2', '2011-01-02', 38000,'BR1');
INSERT INTO jobHistory VALUES('00007','ANYS', '2010-05-30', 55000,'IT');
INSERT INTO jobHistory VALUES('00007','MGR', '2011-01-02', 60000,'IT');
INSERT INTO jobHistory VALUES('00007','VP', '2011-03-31', 80000,'IT');
INSERT INTO jobHistory VALUES('00009','ACCT', '2010-05-30', 50000,'ACT');
INSERT INTO jobHistory VALUES('00009','MGR', '2010-12-01', 60000,'ACT');
INSERT INTO jobHistory VALUES('00011','PRES', '2010-06-30', 100000,'EXC');
INSERT INTO jobHistory VALUES('00013','MGR', '2010-06-30', 60000,'BR1');
INSERT INTO jobHistory VALUES('00013','VP', '2011-01-02', 80000,'BR2');
INSERT INTO jobHistory VALUES('00013','VP', '2011-03-01', 80000,'BR1');
INSERT INTO jobHistory VALUES('00015','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00017','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00017','SPVR', '2011-01-12', 40000,'BR1');
INSERT INTO jobHistory VALUES('00019','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00019','SA2', '2011-01-12', 38000,'BR1');
INSERT INTO jobHistory VALUES('00021','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00021','SA2', '2011-01-12', 38000,'BR1');
INSERT INTO jobHistory VALUES('00023','MGR', '2010-07-05', 60000,'HRD');
INSERT INTO jobHistory VALUES('00025','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00027','SA1', '2010-07-05', 36000,'BR1');
INSERT INTO jobHistory VALUES('00027','SA2', '2011-01-12', 38000,'BR1');
INSERT INTO jobHistory VALUES('00029','SPVR', '2010-07-05', 40000,'BR1');
INSERT INTO jobHistory VALUES('00029','MGR', '2011-01-02', 60000,'BR1');
INSERT INTO jobHistory VALUES('00031','WMAN', '2010-07-05', 35000,'WHS');
INSERT INTO jobHistory VALUES('00031','WMAN', '2011-12-01', 40000,'WHS');
INSERT INTO jobHistory VALUES('00033','WMAN', '2010-07-05', 35000,'WHS');
INSERT INTO jobHistory VALUES('00035','ACCT', '2010-07-21', 50000,'PAY');
INSERT INTO jobHistory VALUES('00037','CLK1', '2010-07-21', 34000,'PAY');
INSERT INTO jobHistory VALUES('00039','CLK1', '2010-07-21', 34000,'PAY');
INSERT INTO jobHistory VALUES('00039','CLK2', '2012-06-30', 35000,'EXC');
INSERT INTO jobHistory VALUES('00041','SPVR', '2010-09-01', 40000,'WHS');
INSERT INTO jobHistory VALUES('00041','MGR', '2011-06-01', 60000,'WHS');
INSERT INTO jobHistory VALUES('00043','CLK2', '2010-09-01', 35000,'EXC');
INSERT INTO jobHistory VALUES('00043','SPVR', '2011-06-01', 35000,'EXC');
INSERT INTO jobHistory VALUES('00043','SPVR', '2011-01-12', 35000,'HRD');
INSERT INTO jobHistory VALUES('00045','SPVR', '2010-12-03', 40000,'ACT');
INSERT INTO jobHistory VALUES('00047','CLK1', '2010-12-03', 34000,'EXC');
INSERT INTO jobHistory VALUES('00047','CLK2', '2011-01-12', 35000,'HRD');
INSERT INTO jobHistory VALUES('00049','MGR', '2010-12-03', 60000,'BR2');
INSERT INTO jobHistory VALUES('00051','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00053','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00055','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00055','SA2', '2011-03-01', 38000,'BR2');
INSERT INTO jobHistory VALUES('00057','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00057','PR1', '2011-06-01', 48000,'BR2');
INSERT INTO jobHistory VALUES('00059','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00061','SA1', '2011-01-05', 36000,'BR2');
INSERT INTO jobHistory VALUES('00063','SA2', '2011-01-05', 38000,'BR2');
INSERT INTO jobHistory VALUES('00063','SPVR', '2011-06-01', 40000,'BR2');

select * from public.jobhistory;

-- Create table Customer
CREATE TABLE public.customer (custno VARCHAR(5) NOT NULL PRIMARY KEY, 
											   custname VARCHAR(20), 
											   address VARCHAR(50), 
											   payterm VARCHAR(3) CONSTRAINT pay_ck 
											   CHECK (payterm IN ('COD', '30D', '45D'))) ;

-- Insert customer records
INSERT INTO customer VALUES('C0001','Globus Medical, Inc', '2560 Gen Armistead Ave Audubon CA 94031', '30D');
INSERT INTO customer VALUES('C0002','RF Industries, Inc', '7610 Miramar Rd San Diego, CA 92602', '45D');
INSERT INTO customer VALUES('C0003','Trisha Macdowell', '7642 Clairemont Mesa Blvd San Diego CA 90321', 'COD');
INSERT INTO customer VALUES('C0004','HMS Holdings, Inc', '1000 So Fremont Ave, Suite 225 Alhambara CA 91303', '45D');
INSERT INTO customer VALUES('C0005','Christian Andersen', '1120 Lincoln St Suite 809 Sacramento CA 95815', 'COD');
INSERT INTO customer VALUES('C0006','Astronics, Inc', '2 Orion Aliso Viejo, CA 92656', '30D');
INSERT INTO customer VALUES('C0007','Morgan Alegore', '2 Goodyear Irvine, CA 92618', 'COD');
INSERT INTO customer VALUES('C0008','Abaxis, Inc', '3240 Whipple Rd, Union City, CA 94587', '30D');
INSERT INTO customer VALUES('C0009','Landec Corp.', '3603 Haven Avenue Menlo Park, CA 94025', '30D');
INSERT INTO customer VALUES('C0010','SMP Corp.', '3718 Northern Long Island NY 12528', '45D');
INSERT INTO customer VALUES('C0011','B&G Foods', '4 Gatehall Dr., Ste. 110 Parsippany, NJ 07054', '45D');
INSERT INTO customer VALUES('C0012','Dexter Santos', '2739 Rebeiro Ave, Santa Clara, CA 95051', 'COD');
INSERT INTO customer VALUES('C0013','Health Stream', '209 10th Ave, South Suite 450 Nashville Tennessee', '45D');
INSERT INTO customer VALUES('C0014','InSync Training LLC', 'P.O. Box 3122 Roanoke, VA 24015', '30D');
INSERT INTO customer VALUES('C0015','Bespoke Education', '8205 Santa Monica Blvd, Suite 365 W HWood CA 90046', '30D');
INSERT INTO customer VALUES('C0016','Peri Solutions', '2880 Zanker Road San Jose CA 95101', '30D');
INSERT INTO customer VALUES('C0017','Janet Lim', '800 N. State College Blvd. Fullerton, CA 92831', 'COD');
INSERT INTO customer VALUES('C0018','Nicole Hutchison', '200 Lincoln Ave, Salinas, CA 93901', 'COD');
INSERT INTO customer VALUES('C0019','Brandon Drucker', '65 West Alisal St., # 101, Salinas, CA 93901', 'COD');
INSERT INTO customer VALUES('C0020','Eugene Whitaker', '45 Fremont Street, Suite 2000 San Frans, CA 9410', 'COD');
INSERT INTO customer VALUES('C0021','Touch Suite', '1081 Holland Dr. Boca Raton, FL 33487', '30D');
INSERT INTO customer VALUES('C0022','CallFire', '1410 2nd St., Suite 200 Santa Monica, CA 90401', '45D');
INSERT INTO customer VALUES('C0023','ISBX Corp', '3415 S. Sepulveda Blvd. 1250 Los Angeles, CA 90034', '30D');
INSERT INTO customer VALUES('C0024','Factual', '1999 Avenue of the Stars Los Angeles, CA 90067 ', '30D');
INSERT INTO customer VALUES('C0025','Predixion', '31910 Del Obispo San Juan Capistrano, CA 92675', '45D');
INSERT INTO customer VALUES('C0026','Datapop', '5762 W Jefferson Blvd, Los Angeles, CA 90016', '45D');
INSERT INTO customer VALUES('C0027','SA Photonics, Inc', '130 Knowles Dr, Los Gatos, CA 95032', '30D');
INSERT INTO customer VALUES('C0028','Acumen Bldg Entp', '7770 Pardee Lane, Ste. 200 Oakland, CA 94621', '30D');
INSERT INTO customer VALUES('C0029','IMCorp', '50 Utopia Road Manchester, CT 06042', '30D');
INSERT INTO customer VALUES('C0030','Brady and Assoc.', '3710 Ruffin Rd, San Diego, CA 90401', '30D');
INSERT INTO customer VALUES('C0031','Yello Hammer LLC', '111 W 28th St, New York, NY 10001', '30D');
INSERT INTO customer VALUES('C0032','Conductor', '2 Park Ave, New York, NY 10016', '30D');
INSERT INTO customer VALUES('C0033','Quantum Networks', '323 West 39th Street 11th Flr NY 10018', '45D');
INSERT INTO customer VALUES('C0034','Refinery29', '225 Broadway NY 10007', '45D');
INSERT INTO customer VALUES('C0035','Gravity Media', '104 W 27th St #11d NY 10001', '30D');
INSERT INTO customer VALUES('C0036','Regal wings', '244 Fifth Avenue, Suite 200 New York, NY 10001', '45D');
INSERT INTO customer VALUES('C0037','33Across', '229 W 28th St, New York, NY 10001', '45D');
INSERT INTO customer VALUES('C0038','RCS Capital', '405 Park Avenue New York, NY 1002', '30D');
INSERT INTO customer VALUES('C0039','OnDeck', '1400 Broadway, 25th Floor, New York, NY 10001', '45D');
INSERT INTO customer VALUES('C0040','Optimatic Media, Inc', '54 West 40th St., 7th Floor, New York, NY 10018', '30D');
INSERT INTO customer VALUES('C0041','James Underwood', '450 West 33rd Street New York, NY 10018', 'COD');
INSERT INTO customer VALUES('C0042','Charles Silverstone', '1335 Ave of the Americas, New York, NY 10019', 'COD');
INSERT INTO customer VALUES('C0043','Nea Sanchez', '371 7th Ave, New York, NY 10001', 'COD');
INSERT INTO customer VALUES('C0044','Tracy Lambert', '234 W 42nd St, New York, NY 10036', 'COD');
INSERT INTO customer VALUES('C0045','Peter Charlestone', '342 W 40th St, New York, NY 10018', 'COD');
INSERT INTO customer VALUES('C0046','Oxford Academy', '5172 Orange Ave, Cypress, CA 90630', '45D');
INSERT INTO customer VALUES('C0047','Whitney High Sch', '16800 Shoemaker Ave, Cerritos, CA 90703', '30D');
INSERT INTO customer VALUES('C0048','Pacfic Collegiate', '255 Swift St, Santa Cruz, CA 95060', '45D');
INSERT INTO customer VALUES('C0049','KIPP San Jose', '1790 Educational Park Dr, San Jose, CA 95133', '30D');
INSERT INTO customer VALUES('C0050','The Preuss School', '9500 Gilman Dr Mc 0536, La Jolla, CA 92093', '45D');
INSERT INTO customer VALUES('C0051','American Indian Sch', '3637 Magee Ave, Oakland, CA 94619', '30D');
INSERT INTO customer VALUES('C0052','Lowell High School', '1101 Eucalyptus Dr, San Francisco, CA 94132', '45D');
INSERT INTO customer VALUES('C0053','University HSchool', '2611 East Matoian M/S Uh134, Fresno, CA 93740', '30D');
INSERT INTO customer VALUES('C0054','Hawthorne Academy', '4467 West Broadway, Hawthorne, CA 90250', '30D');
INSERT INTO customer VALUES('C0055','Lennox Academy', '11036 Hawthorne Blvd, Lennox, CA 90304', '45D');
INSERT INTO customer VALUES('C0056','Manhasset School', '200 Memorial Place Manhasset, NY 11030', '45D');
INSERT INTO customer VALUES('C0057','Pittsford High Sch', '55 Sutherland St Pittsford, NY 14534', '30D');
INSERT INTO customer VALUES('C0058','Jericho High School', '99 Cedar Swamp Rd, Jericho, NY 11753', '45D');
INSERT INTO customer VALUES('C0059','Stuyvesant High', '345 Chambers St, New York, NY 10282', '45D');
INSERT INTO customer VALUES('C0060','Rye High School', 'Parsons St, Rye, NY 10580', '30D');
INSERT INTO customer VALUES('C0061','Brooklyn High', '29 Ft Greene Place, Brooklyn, NY 11217', '45D');
INSERT INTO customer VALUES('C0062','Brooklyn Latin Sch', '325 Bushwick Ave, Brooklyn, NY 11206', '30D');
INSERT INTO customer VALUES('C0063','Bronx Science High', '75 West 205Th St Bronx, NY 10468', '45D');
INSERT INTO customer VALUES('C0064','Staten Island High', '485 Clawson St, Staten Island, NY 10306', '30D');
INSERT INTO customer VALUES('C0065','Yonkers Middle High', '150 Rockland Ave, Yonkers, NY 10705', '45D');
INSERT INTO customer VALUES('C0066','Helen Strong', '800 S Main StTulelake, CA 96134', 'COD');
INSERT INTO customer VALUES('C0067','Gay Rose Silva', '575 3rd St Napa, CA 94559', 'COD');
INSERT INTO customer VALUES('C0068','William Pichler', '1121 L St #407 Sacramento, CA 95814', 'COD');
INSERT INTO customer VALUES('C0069','Terrance Nitz', '23200 Pacific Coast Hwy Malibu, CA 90265', 'COD');
INSERT INTO customer VALUES('C0070','Errol Atanacio', '300 Capitol Mall #555 Sacramento, CA 95814', 'COD');
INSERT INTO customer VALUES('C0071','Chuck Jones', '163 W 125th St New York, NY 10027', 'COD');
INSERT INTO customer VALUES('C0072','Menchu Palmores', '600 College Ave Montour Falls, NY 14865', 'COD');
INSERT INTO customer VALUES('C0073','Princess Ann White', '109 S Union St #411 Rochester, NY 14607', 'COD');
INSERT INTO customer VALUES('C0074','Florence Black', '450 S Salina St Syracuse, NY 13202', 'COD');
INSERT INTO customer VALUES('C0075','Jeremy Irons', '3357 US Highway 9w Highland, NY 12528', 'COD');
INSERT INTO customer VALUES('C0076','Braddy Banks', '1424 Fulton St Brooklyn, NY 11216', 'COD');
INSERT INTO customer VALUES('C0077','Office NY Tech Serv', 'State Capitol Empire State Plaza NY 10027', '45D');
INSERT INTO customer VALUES('C0078','FDA New York', '158-15 Liberty Ave., Jamaica, NY 12528', '45D');
INSERT INTO customer VALUES('C0079','Social Sec Admn NY', '123 William St, New York, NY 10038', '45D');
INSERT INTO customer VALUES('C0080','Social Sec Admn CA', '3836 Wilshire Blvd, Los Angeles, CA 90010', '45D');
INSERT INTO customer VALUES('C0081','Dept Food and Agri', '220 N Street Sacramento, CA 95814', '45D');
INSERT INTO customer VALUES('C0082','California Dept Tech', '1325 J St Suite 1600 Sacramento CA 95814', '45D');


-- Create sales
CREATE TABLE  public.sales (transNo VARCHAR(8) NOT NULL PRIMARY KEY, 
												salesDate DATE, 
												custNo VARCHAR(5), 
												empNo VARCHAR(5), 	
												FOREIGN KEY (custNo) REFERENCES customer, 
												FOREIGN KEY (empno) REFERENCES employee);

-- Insert rows sales
INSERT INTO sales VALUES('TR000001','2010-06-27', 'C0001', '00005');
INSERT INTO sales VALUES('TR000002','2010-07-05', 'C0003', '00005');
INSERT INTO sales VALUES('TR000003','2010-07-05', 'C0002', '00015');
INSERT INTO sales VALUES('TR000004','2010-07-07', 'C0004', '00017');
INSERT INTO sales VALUES('TR000005','2010-07-09', 'C0005', '00019');
INSERT INTO sales VALUES('TR000006','2010-07-07', 'C0001', '00005');
INSERT INTO sales VALUES('TR000007','2010-07-07', 'C0002', '00015');
INSERT INTO sales VALUES('TR000008','2010-07-10', 'C0006', '00021');
INSERT INTO sales VALUES('TR000009','2010-07-10', 'C0007', '00021');
INSERT INTO sales VALUES('TR000010','2010-07-10', 'C0008', '00021');
INSERT INTO sales VALUES('TR000011','2010-07-10', 'C0009', '00005');
INSERT INTO sales VALUES('TR000012','2010-07-12', 'C0004', '00017');
INSERT INTO sales VALUES('TR000013','2010-07-12', 'C0010', '00025');
INSERT INTO sales VALUES('TR000014','2010-07-12', 'C0011', '00021');
INSERT INTO sales VALUES('TR000015','2010-07-12', 'C0012', '00025');
INSERT INTO sales VALUES('TR000016','2010-07-12', 'C0013', '00027');
INSERT INTO sales VALUES('TR000017','2010-07-12', 'C0001', '00005');
INSERT INTO sales VALUES('TR000018','2010-07-13', 'C0006', '00021');
INSERT INTO sales VALUES('TR000019','2010-08-01', 'C0014', '00019');
INSERT INTO sales VALUES('TR000020','2010-08-05', 'C0007', '00021');
INSERT INTO sales VALUES('TR000021','2010-08-05', 'C0015', '00027');
INSERT INTO sales VALUES('TR000022','2010-08-10', 'C0016', '00021');
INSERT INTO sales VALUES('TR000023','2010-08-10', 'C0017', '00027');
INSERT INTO sales VALUES('TR000024','2010-08-10', 'C0018', '00027');
INSERT INTO sales VALUES('TR000025','2010-08-10', 'C0019', '00025');
INSERT INTO sales VALUES('TR000026','2010-08-12', 'C0011', '00021');
INSERT INTO sales VALUES('TR000027','2010-08-30', 'C0009', '00005');
INSERT INTO sales VALUES('TR000028','2010-08-30', 'C0008', '00021');
INSERT INTO sales VALUES('TR000029','2010-09-05', 'C0002', '00015');
INSERT INTO sales VALUES('TR000030','2010-09-05', 'C0010', '00025');
INSERT INTO sales VALUES('TR000031','2010-09-05', 'C0005', '00019');
INSERT INTO sales VALUES('TR000032','2010-09-05', 'C0014', '00019');
INSERT INTO sales VALUES('TR000033','2010-09-06', 'C0012', '00025');
INSERT INTO sales VALUES('TR000034','2010-09-06', 'C0018', '00027');
INSERT INTO sales VALUES('TR000035','2010-09-10', 'C0021', '00027');
INSERT INTO sales VALUES('TR000036','2010-09-10', 'C0022', '00019');
INSERT INTO sales VALUES('TR000037','2010-09-23', 'C0023', '00021');
INSERT INTO sales VALUES('TR000038','2010-09-23', 'C0024', '00005');
INSERT INTO sales VALUES('TR000039','2010-09-23', 'C0025', '00015');
INSERT INTO sales VALUES('TR000040','2010-10-05', 'C0021', '00019');
INSERT INTO sales VALUES('TR000041','2010-10-05', 'C0023', '00025');
INSERT INTO sales VALUES('TR000042','2020-10-25', 'C0026', '00005');
INSERT INTO sales VALUES('TR000043','2010-10-27', 'C0027', '00019');
INSERT INTO sales VALUES('TR000044','2010-11-09', 'C0028', '00027');
INSERT INTO sales VALUES('TR000045','2010-11-10', 'C0029', '00027');
INSERT INTO sales VALUES('TR000046','2010-11-20', 'C0030', '00019');
INSERT INTO sales VALUES('TR000047','2010-11-20', 'C0023', '00025');
INSERT INTO sales VALUES('TR000048','2010-12-05', 'C0026', '00005');
INSERT INTO sales VALUES('TR000049','2010-12-10', 'C0007', '00021');
INSERT INTO sales VALUES('TR000050','2010-12-10', 'C0003', '00005');
INSERT INTO sales VALUES('TR000051','2010-12-10', 'C0011', '00021');
INSERT INTO sales VALUES('TR000052','2011-01-10', 'C0031', '00051');
INSERT INTO sales VALUES('TR000053','2011-01-10', 'C0032', '00051');
INSERT INTO sales VALUES('TR000054','2011-01-10', 'C0033', '00051');
INSERT INTO sales VALUES('TR000055','2011-01-10', 'C0034', '00053');
INSERT INTO sales VALUES('TR000056','2011-01-10', 'C0035', '00055');
INSERT INTO sales VALUES('TR000057','2011-01-10', 'C0036', '00055');
INSERT INTO sales VALUES('TR000058','2011-01-10', 'C0029', '00027');
INSERT INTO sales VALUES('TR000059','2011-01-10', 'C0022', '00019');
INSERT INTO sales VALUES('TR000060','2011-01-10', 'C0026', '00005');
INSERT INTO sales VALUES('TR000061','2011-01-10', 'C0027', '00027');
INSERT INTO sales VALUES('TR000062','2011-01-10', 'C0013', '00027');
INSERT INTO sales VALUES('TR000063','2011-01-10', 'C0016', '00021');
INSERT INTO sales VALUES('TR000064','2011-01-17', 'C0037', '00057');
INSERT INTO sales VALUES('TR000065','2011-01-17', 'C0038', '00059');
INSERT INTO sales VALUES('TR000066','2011-01-17', 'C0039', '00061');
INSERT INTO sales VALUES('TR000067','2011-01-17', 'C0040', '00063');
INSERT INTO sales VALUES('TR000068','2011-01-20', 'C0041', '00059');
INSERT INTO sales VALUES('TR000069','2011-01-20', 'C0042', '00059');
INSERT INTO sales VALUES('TR000070','2011-01-25', 'C0043', '00059');
INSERT INTO sales VALUES('TR000071','2011-01-25', 'C0044', '00059');
INSERT INTO sales VALUES('TR000072','2011-01-25', 'C0045', '00059');
INSERT INTO sales VALUES('TR000073','2011-02-01', 'C0046', '00021');
INSERT INTO sales VALUES('TR000074','2011-02-01', 'C0047', '00005');
INSERT INTO sales VALUES('TR000075','2011-02-01', 'C0048', '00017');
INSERT INTO sales VALUES('TR000076','2011-02-02', 'C0045', '00059');
INSERT INTO sales VALUES('TR000077','2011-02-02', 'C0044', '00059');
INSERT INTO sales VALUES('TR000078','2011-02-07', 'C0035', '00055');
INSERT INTO sales VALUES('TR000079','2011-02-07', 'C0036', '00055');
INSERT INTO sales VALUES('TR000080','2011-02-07', 'C0040', '00063');
INSERT INTO sales VALUES('TR000081','2011-02-10', 'C0049', '00025');
INSERT INTO sales VALUES('TR000082','2011-02-10', 'C0050', '00027');
INSERT INTO sales VALUES('TR000083','2011-02-12', 'C0032', '00051');
INSERT INTO sales VALUES('TR000084','2011-02-12', 'C0033', '00051');
INSERT INTO sales VALUES('TR000085','2011-02-15', 'C0051', '00019');
INSERT INTO sales VALUES('TR000086','2011-02-15', 'C0052', '00019');
INSERT INTO sales VALUES('TR000087','2011-02-20', 'C0053', '00025');
INSERT INTO sales VALUES('TR000088','2011-02-20', 'C0054', '00005');
INSERT INTO sales VALUES('TR000089','2011-02-20', 'C0055', '00021');
INSERT INTO sales VALUES('TR000090','2011-03-02', 'C0056', '00051');
INSERT INTO sales VALUES('TR000091','2011-03-02', 'C0057', '00053');
INSERT INTO sales VALUES('TR000092','2011-03-02', 'C0058', '00053');
INSERT INTO sales VALUES('TR000093','2011-03-02', 'C0059', '00055');
INSERT INTO sales VALUES('TR000094','2011-03-02', 'C0060', '00051');
INSERT INTO sales VALUES('TR000095','2011-03-05', 'C0050', '00027');
INSERT INTO sales VALUES('TR000096','2011-03-05', 'C0051', '00019');
INSERT INTO sales VALUES('TR000097','2011-03-05', 'C0052', '00019');
INSERT INTO sales VALUES('TR000098','2011-03-05', 'C0055', '00021');
INSERT INTO sales VALUES('TR000099','2011-03-13', 'C0061', '00057');
INSERT INTO sales VALUES('TR000100','2011-03-13', 'C0062', '00057');
INSERT INTO sales VALUES('TR000101','2011-03-13', 'C0063', '00059');
INSERT INTO sales VALUES('TR000102','2011-03-21', 'C0064', '00063');
INSERT INTO sales VALUES('TR000103','2011-03-21', 'C0065', '00057');
INSERT INTO sales VALUES('TR000104','2011-03-30', 'C0009', '00005');
INSERT INTO sales VALUES('TR000105','2011-03-30', 'C0010', '00025');
INSERT INTO sales VALUES('TR000106','2011-03-30', 'C0022', '00019');
INSERT INTO sales VALUES('TR000107','2011-03-30', 'C0013', '00027');
INSERT INTO sales VALUES('TR000108','2011-04-07', 'C0066', '00025');
INSERT INTO sales VALUES('TR000109','2011-04-07', 'C0067', '00025');
INSERT INTO sales VALUES('TR000110','2011-04-07', 'C0068', '00025');
INSERT INTO sales VALUES('TR000111','2011-04-07', 'C0069', '00025');
INSERT INTO sales VALUES('TR000112','2011-04-07', 'C0070', '00025');
INSERT INTO sales VALUES('TR000113','2011-04-07', 'C0071', '00059');
INSERT INTO sales VALUES('TR000114','2011-04-07', 'C0072', '00059');
INSERT INTO sales VALUES('TR000115','2011-04-07', 'C0073', '00059');
INSERT INTO sales VALUES('TR000116','2011-04-07', 'C0074', '00059');
INSERT INTO sales VALUES('TR000117','2011-04-07', 'C0075', '00059');
INSERT INTO sales VALUES('TR000118','2011-04-07', 'C0076', '00059');
INSERT INTO sales VALUES('TR000119','2011-04-10', 'C0077', '00063');
INSERT INTO sales VALUES('TR000120','2011-04-10', 'C0078', '00055');
INSERT INTO sales VALUES('TR000121','2011-04-12', 'C0079', '00051');
INSERT INTO sales VALUES('TR000122','2011-04-12', 'C0080', '00025');
INSERT INTO sales VALUES('TR000123','2011-04-12', 'C0081', '00019');
INSERT INTO sales VALUES('TR000124','2011-04-15', 'C0082', '00017');

-- Create PRODUCT
CREATE TABLE public.product (prodCode VARCHAR(6) NOT NULL PRIMARY KEY, 
											description VARCHAR(30), 
											unit VARCHAR(3) CONSTRAINT unit_ck 
											CHECK (unit IN ('pc','ea','mtr','pkg','ltr')));
-- Insert rows PRODUCT
INSERT INTO product VALUES('AD0001','Toshiba Canvio 1 TB', 'ea');
INSERT INTO product VALUES('AD0002','WD Ultra 1TB ', 'ea');
INSERT INTO product VALUES('AD0003','Seagate Bracuda 1TB ', 'ea');
INSERT INTO product VALUES('AD0004','Transcend 1 TB ', 'ea');
INSERT INTO product VALUES('AK0001','HP Pavilion DV6000', 'pc');
INSERT INTO product VALUES('AK0002','Micro Innovations Kb', 'pc');
INSERT INTO product VALUES('AK0003','Steel APEX GAMING KB', 'pc');
INSERT INTO product VALUES('AM0001','MS Wireless Mouse', 'pc');
INSERT INTO product VALUES('AM0002','LOGITECH 910-002696', 'pc');
INSERT INTO product VALUES('AM0003','IMICRO KB-IM8911U', 'pc');
INSERT INTO product VALUES('AM0004','STEEL Rival Mouse', 'pc');
INSERT INTO product VALUES('AM0005','Logitech M500 USB', 'pc');
INSERT INTO product VALUES('AP0001','HDMI Pocket Proj', 'pc');
INSERT INTO product VALUES('AP0002','InFocus IN112 Proj', 'pc');
INSERT INTO product VALUES('AP0003','ViewSonic Projector', 'pc');
INSERT INTO product VALUES('MD0001','ASUS VS228H-P 22-In', 'ea');
INSERT INTO product VALUES('MD0002','ViewSonic VA2446M', 'ea');
INSERT INTO product VALUES('MD0003','Dell UltrShrp U2412M', 'ea');
INSERT INTO product VALUES('MD0004','Acer S231HL BBID 23', 'ea');
INSERT INTO product VALUES('MD0005','Apple Dsplay MC914', 'ea');
INSERT INTO product VALUES('MD0006','Asus VE228H 21.5', 'ea');
INSERT INTO product VALUES('MP0001','Apple iPhone 4 16GB ', 'ea');
INSERT INTO product VALUES('MP0002','Apple iPhone 3G', 'ea');
INSERT INTO product VALUES('MP0003','SAMSUNG GALAXY S4 ', 'ea');
INSERT INTO product VALUES('MP0004','SAMSUNG GALAXY S3', 'ea');
INSERT INTO product VALUES('NB0001','Dell Inspiron Laptop', 'ea');
INSERT INTO product VALUES('NB0002','ASUS Tformer Book', 'ea');
INSERT INTO product VALUES('NB0003','Acer C720 Chrome', 'ea');
INSERT INTO product VALUES('NB0004','HP Chromebook 11', 'ea');
INSERT INTO product VALUES('NB0005','Apple Mac Pro Laptop', 'ea');
INSERT INTO product VALUES('NH0001','NETGEAR ProSAFE 5-Port ', 'pc');
INSERT INTO product VALUES('NH0002','TP-LINK  1000Mbps', 'pc');
INSERT INTO product VALUES('NH0003','Cisco 24-P G Switch ', 'pc');
INSERT INTO product VALUES('NT0001','Apple iPad Retna 16G', 'ea');
INSERT INTO product VALUES('NT0002','Apple iPad 2 MC769LL', 'ea');
INSERT INTO product VALUES('NT0003','Apple iPad Mini ', 'ea');
INSERT INTO product VALUES('NT0004','Samsung Galaxy Tab3 ', 'ea');
INSERT INTO product VALUES('NT0005','Samsung Glaxy Tab32G', 'ea');
INSERT INTO product VALUES('NT0006','DrgonTouch 7B 2Core ', 'ea');
INSERT INTO product VALUES('PA0001','MS Ofc Business 2013', 'ea');
INSERT INTO product VALUES('PA0002','Office Mac Home 2011', 'ea');
INSERT INTO product VALUES('PC0001','CyberpowerPC Gamer', 'ea');
INSERT INTO product VALUES('PC0002','Dell 745 Opti Desk', 'ea');
INSERT INTO product VALUES('PC0003','Dell Inspiron Desk', 'ea');
INSERT INTO product VALUES('PC0004','Dell Inspiron 660', 'ea');
INSERT INTO product VALUES('PF0001','Win7 Pro SP1 64bit ', 'ea');
INSERT INTO product VALUES('PF0002','Win7 Home Pre SP1 64', 'ea');
INSERT INTO product VALUES('PF0003','Mac OS X ver 10.6.3', 'ea');
INSERT INTO product VALUES('PF0004','Windows 8.1 64-Bit ', 'ea');
INSERT INTO product VALUES('PF0005','Windows 8 Pro ', 'ea');
INSERT INTO product VALUES('PF0006','RED HAT Prof Edition', 'ea');
INSERT INTO product VALUES('PR0001','Epson Expression ', 'pc');
INSERT INTO product VALUES('PR0002','Canon PIXMA MX922 ', 'pc');
INSERT INTO product VALUES('PR0003','HP Envy 4500 Wireles', 'pc');
INSERT INTO product VALUES('PS0001','VirServ 12Core 128GB', 'pc');
INSERT INTO product VALUES('PS0002','Ms WinServer 2012', 'pc');
INSERT INTO product VALUES('PS0003','Cisco Virt Hardware', 'pc');
											

-- Create salesDETAIL
CREATE TABLE public.salesDetail (transNo VARCHAR(8) NOT NULL REFERENCES sales, 
													prodCode VARCHAR(6) NOT NULL REFERENCES product, 
													quantity DECIMAL(10,2) CONSTRAINT quantity_ck 
													CHECK (quantity >= 0.0), 
													PRIMARY KEY (transNo, prodCode));
													
-- Insert salesDETAIL rows 
INSERT INTO salesDetail VALUES('TR000001','AK0002', 10);
INSERT INTO salesDetail VALUES('TR000001','AM0003', 10);
INSERT INTO salesDetail VALUES('TR000001','MD0001', 10);
INSERT INTO salesDetail VALUES('TR000001','PC0002', 10);
INSERT INTO salesDetail VALUES('TR000002','NB0001', 5);
INSERT INTO salesDetail VALUES('TR000002','PR0001', 1);
INSERT INTO salesDetail VALUES('TR000003','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000004','AK0003', 6);
INSERT INTO salesDetail VALUES('TR000004','AM0004', 6);
INSERT INTO salesDetail VALUES('TR000004','MD0004', 6);
INSERT INTO salesDetail VALUES('TR000004','NB0002', 4);
INSERT INTO salesDetail VALUES('TR000004','PC0003', 6);
INSERT INTO salesDetail VALUES('TR000004','PR0003', 2);
INSERT INTO salesDetail VALUES('TR000005','AK0003', 1);
INSERT INTO salesDetail VALUES('TR000005','MD0005', 1);
INSERT INTO salesDetail VALUES('TR000006','NB0001', 5);
INSERT INTO salesDetail VALUES('TR000006','PF0005', 5);
INSERT INTO salesDetail VALUES('TR000007','PF0003', 2);
INSERT INTO salesDetail VALUES('TR000008','AP0002', 3);
INSERT INTO salesDetail VALUES('TR000008','MD0002', 2);
INSERT INTO salesDetail VALUES('TR000008','NB0004', 1);
INSERT INTO salesDetail VALUES('TR000009','AM0002', 1);
INSERT INTO salesDetail VALUES('TR000009','MD0003', 1);
INSERT INTO salesDetail VALUES('TR000010','AP0001', 2);
INSERT INTO salesDetail VALUES('TR000010','PA0001', 5);
INSERT INTO salesDetail VALUES('TR000011','AK0003', 3);
INSERT INTO salesDetail VALUES('TR000011','AM0004', 3);
INSERT INTO salesDetail VALUES('TR000011','MD0003', 3);
INSERT INTO salesDetail VALUES('TR000011','PC0004', 3);
INSERT INTO salesDetail VALUES('TR000011','PR0002', 2);
INSERT INTO salesDetail VALUES('TR000012','NB0003', 7);
INSERT INTO salesDetail VALUES('TR000013','AM0005', 2);
INSERT INTO salesDetail VALUES('TR000013','AP0002', 1);
INSERT INTO salesDetail VALUES('TR000014','PF0004', 10);
INSERT INTO salesDetail VALUES('TR000015','AK0003', 1);
INSERT INTO salesDetail VALUES('TR000015','AM0001', 1);
INSERT INTO salesDetail VALUES('TR000015','MD0002', 1);
INSERT INTO salesDetail VALUES('TR000015','PC0001', 1);
INSERT INTO salesDetail VALUES('TR000016','AP0002', 2);
INSERT INTO salesDetail VALUES('TR000016','NB0002', 7);
INSERT INTO salesDetail VALUES('TR000016','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000016','PR0002', 1);
INSERT INTO salesDetail VALUES('TR000017','PA0001', 3);
INSERT INTO salesDetail VALUES('TR000017','PA0002', 4);
INSERT INTO salesDetail VALUES('TR000018','MD0001', 9);
INSERT INTO salesDetail VALUES('TR000018','PC0004', 9);
INSERT INTO salesDetail VALUES('TR000019','AP0002', 2);
INSERT INTO salesDetail VALUES('TR000020','MD0005', 1);
INSERT INTO salesDetail VALUES('TR000021','AM0002', 3);
INSERT INTO salesDetail VALUES('TR000021','NB0002', 3);
INSERT INTO salesDetail VALUES('TR000022','MD0006', 5);
INSERT INTO salesDetail VALUES('TR000022','PA0002', 1);
INSERT INTO salesDetail VALUES('TR000022','PC0002', 5);
INSERT INTO salesDetail VALUES('TR000023','NB0001', 1);
INSERT INTO salesDetail VALUES('TR000024','PA0002', 1);
INSERT INTO salesDetail VALUES('TR000025','AP0002', 1);
INSERT INTO salesDetail VALUES('TR000026','AM0005', 1);
INSERT INTO salesDetail VALUES('TR000026','MD0003', 1);
INSERT INTO salesDetail VALUES('TR000026','PC0001', 1);
INSERT INTO salesDetail VALUES('TR000027','NB0003', 3);
INSERT INTO salesDetail VALUES('TR000027','PF0003', 1);
INSERT INTO salesDetail VALUES('TR000028','AM0001', 2);
INSERT INTO salesDetail VALUES('TR000028','PF0004', 5);
INSERT INTO salesDetail VALUES('TR000029','PF0001', 3);
INSERT INTO salesDetail VALUES('TR000030','AM0001', 5);
INSERT INTO salesDetail VALUES('TR000030','PA0001', 5);
INSERT INTO salesDetail VALUES('TR000030','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000030','PR0003', 2);
INSERT INTO salesDetail VALUES('TR000031','AM0003', 20);
INSERT INTO salesDetail VALUES('TR000032','NB0004', 3);
INSERT INTO salesDetail VALUES('TR000032','PA0002', 2);
INSERT INTO salesDetail VALUES('TR000033','NB0001', 3);
INSERT INTO salesDetail VALUES('TR000034','MD0003', 1);
INSERT INTO salesDetail VALUES('TR000034','PC0001', 1);
INSERT INTO salesDetail VALUES('TR000035','NH0003', 3);
INSERT INTO salesDetail VALUES('TR000035','PC0004', 10);
INSERT INTO salesDetail VALUES('TR000035','PR0002', 2);
INSERT INTO salesDetail VALUES('TR000036','MD0005', 5);
INSERT INTO salesDetail VALUES('TR000037','AM0002', 10);
INSERT INTO salesDetail VALUES('TR000037','PC0004', 5);
INSERT INTO salesDetail VALUES('TR000038','AD0003', 1);
INSERT INTO salesDetail VALUES('TR000038','AK0001', 3);
INSERT INTO salesDetail VALUES('TR000038','PA0001', 3);
INSERT INTO salesDetail VALUES('TR000038','PC0003', 3);
INSERT INTO salesDetail VALUES('TR000039','NB0004', 10);
INSERT INTO salesDetail VALUES('TR000039','NH0002', 2);
INSERT INTO salesDetail VALUES('TR000039','PF0001', 1);
INSERT INTO salesDetail VALUES('TR000039','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000040','NB0002', 15);
INSERT INTO salesDetail VALUES('TR000041','NB0001', 5);
INSERT INTO salesDetail VALUES('TR000041','PR0002', 2);
INSERT INTO salesDetail VALUES('TR000042','AM0005', 3);
INSERT INTO salesDetail VALUES('TR000042','AP0003', 1);
INSERT INTO salesDetail VALUES('TR000043','AD0003', 3);
INSERT INTO salesDetail VALUES('TR000043','NB0004', 5);
INSERT INTO salesDetail VALUES('TR000043','NH0003', 2);
INSERT INTO salesDetail VALUES('TR000043','PA0001', 5);
INSERT INTO salesDetail VALUES('TR000043','PF0001', 2);
INSERT INTO salesDetail VALUES('TR000044','AD0002', 2);
INSERT INTO salesDetail VALUES('TR000044','PC0001', 3);
INSERT INTO salesDetail VALUES('TR000045','AM0004', 5);
INSERT INTO salesDetail VALUES('TR000045','MD0003', 5);
INSERT INTO salesDetail VALUES('TR000045','PC0004', 5);
INSERT INTO salesDetail VALUES('TR000046','AP0001', 1);
INSERT INTO salesDetail VALUES('TR000046','NB0002', 10);
INSERT INTO salesDetail VALUES('TR000047','PA0001', 1);
INSERT INTO salesDetail VALUES('TR000048','AM0005', 3);
INSERT INTO salesDetail VALUES('TR000048','MD0001', 5);
INSERT INTO salesDetail VALUES('TR000048','PC0003', 5);
INSERT INTO salesDetail VALUES('TR000048','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000048','PR0003', 2);
INSERT INTO salesDetail VALUES('TR000049','MP0001', 10);
INSERT INTO salesDetail VALUES('TR000049','MP0003', 10);
INSERT INTO salesDetail VALUES('TR000050','NT0005', 1);
INSERT INTO salesDetail VALUES('TR000051','MP0001', 15);
INSERT INTO salesDetail VALUES('TR000051','MP0004', 15);
INSERT INTO salesDetail VALUES('TR000051','NT0001', 15);
INSERT INTO salesDetail VALUES('TR000052','MP0001', 10);
INSERT INTO salesDetail VALUES('TR000052','MP0003', 10);
INSERT INTO salesDetail VALUES('TR000052','NT0001', 10);
INSERT INTO salesDetail VALUES('TR000053','AK0002', 20);
INSERT INTO salesDetail VALUES('TR000053','AM0002', 20);
INSERT INTO salesDetail VALUES('TR000053','AP0002', 2);
INSERT INTO salesDetail VALUES('TR000053','MD0001', 20);
INSERT INTO salesDetail VALUES('TR000053','PC0004', 20);
INSERT INTO salesDetail VALUES('TR000054','AP0001', 1);
INSERT INTO salesDetail VALUES('TR000054','NB0001', 10);
INSERT INTO salesDetail VALUES('TR000055','AD0003', 3);
INSERT INTO salesDetail VALUES('TR000055','NH0003', 2);
INSERT INTO salesDetail VALUES('TR000055','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000055','PR0003', 2);
INSERT INTO salesDetail VALUES('TR000055','PS0001', 1);
INSERT INTO salesDetail VALUES('TR000056','NB0004', 5);
INSERT INTO salesDetail VALUES('TR000056','PA0002', 2);
INSERT INTO salesDetail VALUES('TR000056','PF0005', 1);
INSERT INTO salesDetail VALUES('TR000057','AD0004', 2);
INSERT INTO salesDetail VALUES('TR000057','NH0002', 2);
INSERT INTO salesDetail VALUES('TR000057','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000057','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000058','MD0005', 2);
INSERT INTO salesDetail VALUES('TR000058','PS0001', 1);
INSERT INTO salesDetail VALUES('TR000059','MP0001', 5);
INSERT INTO salesDetail VALUES('TR000059','NT0002', 5);
INSERT INTO salesDetail VALUES('TR000060','AD0004', 2);
INSERT INTO salesDetail VALUES('TR000060','MP0001', 3);
INSERT INTO salesDetail VALUES('TR000060','PS0002', 1);
INSERT INTO salesDetail VALUES('TR000060','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000061','MP0001', 5);
INSERT INTO salesDetail VALUES('TR000061','MP0003', 5);
INSERT INTO salesDetail VALUES('TR000062','AD0002', 2);
INSERT INTO salesDetail VALUES('TR000062','NH0003', 3);
INSERT INTO salesDetail VALUES('TR000062','NT0006', 2);
INSERT INTO salesDetail VALUES('TR000062','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000063','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000064','MD0002', 2);
INSERT INTO salesDetail VALUES('TR000064','PC0004', 5);
INSERT INTO salesDetail VALUES('TR000064','PF0001', 2);
INSERT INTO salesDetail VALUES('TR000064','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000064','PS0001', 1);
INSERT INTO salesDetail VALUES('TR000065','NB0004', 5);
INSERT INTO salesDetail VALUES('TR000065','PA0002', 2);
INSERT INTO salesDetail VALUES('TR000066','AM0002', 15);
INSERT INTO salesDetail VALUES('TR000066','MP0003', 15);
INSERT INTO salesDetail VALUES('TR000066','NB0002', 15);
INSERT INTO salesDetail VALUES('TR000067','NH0002', 3);
INSERT INTO salesDetail VALUES('TR000067','PS0003', 3);
INSERT INTO salesDetail VALUES('TR000068','MP0001', 2);
INSERT INTO salesDetail VALUES('TR000069','MP0003', 1);
INSERT INTO salesDetail VALUES('TR000070','NT0001', 3);
INSERT INTO salesDetail VALUES('TR000071','NT0003', 1);
INSERT INTO salesDetail VALUES('TR000072','NT0005', 1);
INSERT INTO salesDetail VALUES('TR000073','AP0002', 5);
INSERT INTO salesDetail VALUES('TR000073','PC0004', 40);
INSERT INTO salesDetail VALUES('TR000073','PR0001', 1);
INSERT INTO salesDetail VALUES('TR000074','AM0002', 2);
INSERT INTO salesDetail VALUES('TR000074','PC0002', 20);
INSERT INTO salesDetail VALUES('TR000074','PF0001', 1);
INSERT INTO salesDetail VALUES('TR000075','AM0001', 10);
INSERT INTO salesDetail VALUES('TR000075','AP0003', 2);
INSERT INTO salesDetail VALUES('TR000075','NB0001', 10);
INSERT INTO salesDetail VALUES('TR000075','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000076','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000077','NB0005', 2);
INSERT INTO salesDetail VALUES('TR000078','NB0005', 10);
INSERT INTO salesDetail VALUES('TR000079','AD0004', 2);
INSERT INTO salesDetail VALUES('TR000079','PS0001', 1);
INSERT INTO salesDetail VALUES('TR000080','NB0005', 3);
INSERT INTO salesDetail VALUES('TR000081','NB0005', 4);
INSERT INTO salesDetail VALUES('TR000081','PA0002', 4);
INSERT INTO salesDetail VALUES('TR000082','PC0002', 20);
INSERT INTO salesDetail VALUES('TR000082','PF0005', 1);
INSERT INTO salesDetail VALUES('TR000083','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000083','PA0002', 5);
INSERT INTO salesDetail VALUES('TR000084','AM0001', 2);
INSERT INTO salesDetail VALUES('TR000084','NB0005', 4);
INSERT INTO salesDetail VALUES('TR000084','NH0003', 5);
INSERT INTO salesDetail VALUES('TR000084','PS0002', 1);
INSERT INTO salesDetail VALUES('TR000085','AP0002', 2);
INSERT INTO salesDetail VALUES('TR000085','PC0002', 10);
INSERT INTO salesDetail VALUES('TR000085','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000086','AD0003', 3);
INSERT INTO salesDetail VALUES('TR000086','MD0004', 5);
INSERT INTO salesDetail VALUES('TR000086','PC0003', 10);
INSERT INTO salesDetail VALUES('TR000087','AM0001', 10);
INSERT INTO salesDetail VALUES('TR000087','PC0001', 3);
INSERT INTO salesDetail VALUES('TR000087','PC0004', 7);
INSERT INTO salesDetail VALUES('TR000087','PF0004', 2);
INSERT INTO salesDetail VALUES('TR000088','NH0003', 3);
INSERT INTO salesDetail VALUES('TR000088','PR0001', 5);
INSERT INTO salesDetail VALUES('TR000088','PS0001', 5);
INSERT INTO salesDetail VALUES('TR000089','NB0005', 10);
INSERT INTO salesDetail VALUES('TR000090','NB0005', 3);
INSERT INTO salesDetail VALUES('TR000090','NH0001', 1);
INSERT INTO salesDetail VALUES('TR000090','NH0003', 2);
INSERT INTO salesDetail VALUES('TR000090','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000091','AD0003', 2);
INSERT INTO salesDetail VALUES('TR000091','NT0001', 3);
INSERT INTO salesDetail VALUES('TR000091','NT0005', 2);
INSERT INTO salesDetail VALUES('TR000091','PS0002', 1);
INSERT INTO salesDetail VALUES('TR000092','AD0003', 2);
INSERT INTO salesDetail VALUES('TR000092','AM0001', 5);
INSERT INTO salesDetail VALUES('TR000092','NB0004', 2);
INSERT INTO salesDetail VALUES('TR000092','PC0001', 10);
INSERT INTO salesDetail VALUES('TR000092','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000093','MD0002', 10);
INSERT INTO salesDetail VALUES('TR000093','NH0003', 2);
INSERT INTO salesDetail VALUES('TR000093','PC0002', 20);
INSERT INTO salesDetail VALUES('TR000094','PC0002', 9);
INSERT INTO salesDetail VALUES('TR000094','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000095','MD0003', 3);
INSERT INTO salesDetail VALUES('TR000095','NB0003', 4);
INSERT INTO salesDetail VALUES('TR000096','AP0002', 2);
INSERT INTO salesDetail VALUES('TR000096','PA0001', 1);
INSERT INTO salesDetail VALUES('TR000097','NB0003', 3);
INSERT INTO salesDetail VALUES('TR000097','PC0004', 5);
INSERT INTO salesDetail VALUES('TR000098','NB0001', 2);
INSERT INTO salesDetail VALUES('TR000098','NT0001', 2);
INSERT INTO salesDetail VALUES('TR000098','PC0002', 10);
INSERT INTO salesDetail VALUES('TR000098','PF0004', 1);
INSERT INTO salesDetail VALUES('TR000099','NB0005', 3);
INSERT INTO salesDetail VALUES('TR000099','PS0002', 1);
INSERT INTO salesDetail VALUES('TR000099','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000100','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000100','NT0002', 3);
INSERT INTO salesDetail VALUES('TR000100','NT0004', 3);
INSERT INTO salesDetail VALUES('TR000100','PA0002', 5);
INSERT INTO salesDetail VALUES('TR000100','PC0002', 10);
INSERT INTO salesDetail VALUES('TR000101','AD0001', 2);
INSERT INTO salesDetail VALUES('TR000101','NH0003', 1);
INSERT INTO salesDetail VALUES('TR000101','PC0001', 10);
INSERT INTO salesDetail VALUES('TR000101','PF0006', 1);
INSERT INTO salesDetail VALUES('TR000102','MD0001', 10);
INSERT INTO salesDetail VALUES('TR000102','NH0002', 1);
INSERT INTO salesDetail VALUES('TR000102','PC0004', 10);
INSERT INTO salesDetail VALUES('TR000102','PS0003', 1);
INSERT INTO salesDetail VALUES('TR000103','AK0001', 15);
INSERT INTO salesDetail VALUES('TR000103','AM0004', 15);
INSERT INTO salesDetail VALUES('TR000103','MD0006', 15);
INSERT INTO salesDetail VALUES('TR000103','PC0004', 15);
INSERT INTO salesDetail VALUES('TR000104','MP0002', 2);
INSERT INTO salesDetail VALUES('TR000104','MP0003', 3);
INSERT INTO salesDetail VALUES('TR000104','NB0005', 2);
INSERT INTO salesDetail VALUES('TR000105','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000106','NB0005', 4);
INSERT INTO salesDetail VALUES('TR000107','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000108','MP0001', 1);
INSERT INTO salesDetail VALUES('TR000108','NT0005', 1);
INSERT INTO salesDetail VALUES('TR000109','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000110','MP0003', 2);
INSERT INTO salesDetail VALUES('TR000111','NB0005', 2);
INSERT INTO salesDetail VALUES('TR000112','NB0001', 2);
INSERT INTO salesDetail VALUES('TR000113','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000114','AP0003', 1);
INSERT INTO salesDetail VALUES('TR000115','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000115','NT0001', 1);
INSERT INTO salesDetail VALUES('TR000116','MP0003', 1);
INSERT INTO salesDetail VALUES('TR000116','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000117','NT0005', 1);
INSERT INTO salesDetail VALUES('TR000118','NB0005', 1);
INSERT INTO salesDetail VALUES('TR000119','NB0005', 20);
INSERT INTO salesDetail VALUES('TR000119','PC0004', 100);
INSERT INTO salesDetail VALUES('TR000120','AD0003', 10);
INSERT INTO salesDetail VALUES('TR000120','NH0003', 20);
INSERT INTO salesDetail VALUES('TR000120','PC0004', 150);
INSERT INTO salesDetail VALUES('TR000120','PR0003', 10);
INSERT INTO salesDetail VALUES('TR000120','PS0001', 5);
INSERT INTO salesDetail VALUES('TR000120','PS0003', 3);
INSERT INTO salesDetail VALUES('TR000121','NB0005', 5);
INSERT INTO salesDetail VALUES('TR000121','NH0003', 5);
INSERT INTO salesDetail VALUES('TR000121','NT0001', 5);
INSERT INTO salesDetail VALUES('TR000121','PC0002', 20);
INSERT INTO salesDetail VALUES('TR000122','AP0002', 1);
INSERT INTO salesDetail VALUES('TR000122','NB0005', 10);
INSERT INTO salesDetail VALUES('TR000122','NH0003', 5);
INSERT INTO salesDetail VALUES('TR000122','PC0003', 30);
INSERT INTO salesDetail VALUES('TR000122','PF0001', 5);
INSERT INTO salesDetail VALUES('TR000122','PR0002', 5);
INSERT INTO salesDetail VALUES('TR000122','PS0003', 3);
INSERT INTO salesDetail VALUES('TR000123','AD0001', 5);
INSERT INTO salesDetail VALUES('TR000123','NH0003', 3);
INSERT INTO salesDetail VALUES('TR000123','NT0001', 3);
INSERT INTO salesDetail VALUES('TR000123','PC0004', 60);
INSERT INTO salesDetail VALUES('TR000123','PF0005', 5);
INSERT INTO salesDetail VALUES('TR000123','PF0006', 3);
INSERT INTO salesDetail VALUES('TR000123','PR0003', 5);
INSERT INTO salesDetail VALUES('TR000123','PS0001', 2);
INSERT INTO salesDetail VALUES('TR000124','AM0002', 10);
INSERT INTO salesDetail VALUES('TR000124','MD0006', 5);
INSERT INTO salesDetail VALUES('TR000124','NB0005', 3);
INSERT INTO salesDetail VALUES('TR000124','PC0002', 15);
INSERT INTO salesDetail VALUES('TR000124','PF0005', 3);
INSERT INTO salesDetail VALUES('TR000124','PF0006', 2);
INSERT INTO salesDetail VALUES('TR000124','PS0001', 3);


-- Create table PAYMENT
CREATE TABLE public.payment (orNo VARCHAR(8) NOT NULL PRIMARY KEY, 
											  payDate DATE, 
											  amount DECIMAL(10,2), 
											  transno VARCHAR(8) REFERENCES  sales);

-- Insert PAYMENT rows 
INSERT INTO payment VALUES('OR000001','2010-06-20', '3284.7', 'TR000001');
INSERT INTO payment VALUES('OR000002','2010-07-05', '1581.72', 'TR000002');
INSERT INTO payment VALUES('OR000003','2010-07-05', '7.5', 'TR000003');
INSERT INTO payment VALUES('OR000004','2010-07-07', '57.74', 'TR000007');
INSERT INTO payment VALUES('OR000005','2010-07-09', '924.99', 'TR000005');
INSERT INTO payment VALUES('OR000006','2010-07-10', '3000', 'TR000004');
INSERT INTO payment VALUES('OR000007','2010-07-10', '309.22', 'TR000009');
INSERT INTO payment VALUES('OR000008','2010-07-12', '1393', 'TR000012');
INSERT INTO payment VALUES('OR000009','2010-07-12', '740.97', 'TR000015');
INSERT INTO payment VALUES('OR000010','2010-07-15', '1000', 'TR000006');
INSERT INTO payment VALUES('OR000011','2010-07-20', '1000', 'TR000010');
INSERT INTO payment VALUES('OR000012','2010-07-20', '1500', 'TR000011');
INSERT INTO payment VALUES('OR000013','2010-07-27', '2000', 'TR000016');
INSERT INTO payment VALUES('OR000014','2010-08-01', '403.02', 'TR000013');
INSERT INTO payment VALUES('OR000015','2010-08-01', '500', 'TR000014');
INSERT INTO payment VALUES('OR000016','2010-08-01', '4000', 'TR000018');
INSERT INTO payment VALUES('OR000017','2010-08-05', '907.5', 'TR000020');
INSERT INTO payment VALUES('OR000018','2010-08-07', '1095', 'TR000006');
INSERT INTO payment VALUES('OR000019','2010-08-10', '1000', 'TR000008');
INSERT INTO payment VALUES('OR000020','2010-08-10', '300', 'TR000023');
INSERT INTO payment VALUES('OR000021','2010-08-10', '102.99', 'TR000024');
INSERT INTO payment VALUES('OR000022','2010-08-10', '304.48', 'TR000025');
INSERT INTO payment VALUES('OR000023','2010-08-12', '1000', 'TR000017');
INSERT INTO payment VALUES('OR000024','2010-08-15', '1598.25', 'TR000011');
INSERT INTO payment VALUES('OR000025','2010-08-15', '1919.12', 'TR000018');
INSERT INTO payment VALUES('OR000026','2010-08-20', '767.77', 'TR000026');
INSERT INTO payment VALUES('OR000027','2010-08-20', '700.4', 'TR000004');
INSERT INTO payment VALUES('OR000028','2010-08-23', '608.96', 'TR000019');
INSERT INTO payment VALUES('OR000029','2010-08-30', '1000', 'TR000022');
INSERT INTO payment VALUES('OR000030','2010-08-30', '623.25', 'TR000027');
INSERT INTO payment VALUES('OR000031','2010-09-01', '500', 'TR000021');
INSERT INTO payment VALUES('OR000032','2010-09-05', '498.59', 'TR000028');
INSERT INTO payment VALUES('OR000033','2010-09-05', '429', 'TR000031');
INSERT INTO payment VALUES('OR000034','2010-09-06', '900', 'TR000033');
INSERT INTO payment VALUES('OR000035','2010-09-06', '718.5', 'TR000034');
INSERT INTO payment VALUES('OR000036','2010-09-10', '337.5', 'TR000029');
INSERT INTO payment VALUES('OR000037','2010-09-10', '601.78', 'TR000021');
INSERT INTO payment VALUES('OR000038','2010-09-10', '776.54', 'TR000022');
INSERT INTO payment VALUES('OR000039','2010-09-20', '1000', 'TR000032');
INSERT INTO payment VALUES('OR000040','2010-09-20', '4000', 'TR000035');
INSERT INTO payment VALUES('OR000041','2010-09-30', '1000', 'TR000030');
INSERT INTO payment VALUES('OR000042','2010-09-30', '4000', 'TR000036');
INSERT INTO payment VALUES('OR000043','2010-09-30', '1000', 'TR000038');
INSERT INTO payment VALUES('OR000044','2010-10-01', '1699.98', 'TR000041');
INSERT INTO payment VALUES('OR000045','2010-10-10', '539.17', 'TR000030');
INSERT INTO payment VALUES('OR000046','2010-10-10', '2095.05', 'TR000035');
INSERT INTO payment VALUES('OR000047','2010-10-10', '3417.2', 'TR000037');
INSERT INTO payment VALUES('OR000048','2010-10-23', '917.44', 'TR000038');
INSERT INTO payment VALUES('OR000049','2010-10-23', '2000', 'TR000039');
INSERT INTO payment VALUES('OR000050','2010-10-25', '3000', 'TR000040');
INSERT INTO payment VALUES('OR000051','2010-10-30', '522.68', 'TR000042');
INSERT INTO payment VALUES('OR000052','2010-11-10', '1470', 'TR000040');
INSERT INTO payment VALUES('OR000053','2010-11-20', '959.3', 'TR000039');
INSERT INTO payment VALUES('OR000054','2010-11-20', '2000', 'TR000043');
INSERT INTO payment VALUES('OR000055','2010-11-20', '219', 'TR000047');
INSERT INTO payment VALUES('OR000056','2010-12-01', '1503.6', 'TR000044');
INSERT INTO payment VALUES('OR000057','2010-12-05', '3000', 'TR000045');
INSERT INTO payment VALUES('OR000058','2010-12-10', '3294.99', 'TR000046');
INSERT INTO payment VALUES('OR000059','2010-12-10', '6249.5', 'TR000049');
INSERT INTO payment VALUES('OR000060','2010-12-10', '499.99', 'TR000050');
INSERT INTO payment VALUES('OR000061','2010-12-20', '1472.55', 'TR000045');
INSERT INTO payment VALUES('OR000062','2011-01-02', '1500', 'TR000048');
INSERT INTO payment VALUES('OR000063','2011-01-05', '5000', 'TR000051');
INSERT INTO payment VALUES('OR000064','2011-01-15', '1516.26', 'TR000048');
INSERT INTO payment VALUES('OR000065','2011-01-15', '5000', 'TR000051');
INSERT INTO payment VALUES('OR000066','2011-01-15', '599.99', 'TR000063');
INSERT INTO payment VALUES('OR000067','2011-01-20', '399.9', 'TR000068');
INSERT INTO payment VALUES('OR000068','2011-01-20', '425', 'TR000069');
INSERT INTO payment VALUES('OR000069','2011-01-25', '1237.47', 'TR000070');
INSERT INTO payment VALUES('OR000070','2011-01-25', '287', 'TR000071');
INSERT INTO payment VALUES('OR000071','2011-01-25', '499.99', 'TR000072');
INSERT INTO payment VALUES('OR000072','2011-01-30', '10000', 'TR000053');
INSERT INTO payment VALUES('OR000073','2011-01-30', '1371.02', 'TR000062');
INSERT INTO payment VALUES('OR000074','2011-01-30', '5000', 'TR000066');
INSERT INTO payment VALUES('OR000075','2011-02-01', '1000', 'TR000054');
INSERT INTO payment VALUES('OR000076','2011-02-01', '3000', 'TR000058');
INSERT INTO payment VALUES('OR000077','2011-02-02', '2369.44', 'TR000077');
INSERT INTO payment VALUES('OR000078','2011-02-05', '5000', 'TR000052');
INSERT INTO payment VALUES('OR000079','2011-02-05', '3000', 'TR000055');
INSERT INTO payment VALUES('OR000080','2011-02-05', '1709.16', 'TR000056');
INSERT INTO payment VALUES('OR000081','2011-02-05', '800.77', 'TR000057');
INSERT INTO payment VALUES('OR000082','2011-02-07', '1500', 'TR000080');
INSERT INTO payment VALUES('OR000083','2011-02-10', '5374.4', 'TR000052');
INSERT INTO payment VALUES('OR000084','2011-02-10', '5654.2', 'TR000053');
INSERT INTO payment VALUES('OR000085','2011-02-10', '2314.99', 'TR000054');
INSERT INTO payment VALUES('OR000086','2011-02-10', '2015', 'TR000058');
INSERT INTO payment VALUES('OR000087','2011-02-10', '2624.7', 'TR000059');
INSERT INTO payment VALUES('OR000088','2011-02-10', '2043.81', 'TR000060');
INSERT INTO payment VALUES('OR000089','2011-02-10', '1500', 'TR000061');
INSERT INTO payment VALUES('OR000090','2011-02-10', '3343.98', 'TR000079');
INSERT INTO payment VALUES('OR000091','2011-02-15', '1624.75', 'TR000061');
INSERT INTO payment VALUES('OR000092','2011-02-15', '6451.8', 'TR000064');
INSERT INTO payment VALUES('OR000093','2011-02-15', '1600.98', 'TR000065');
INSERT INTO payment VALUES('OR000094','2011-02-15', '1874.94', 'TR000067');
INSERT INTO payment VALUES('OR000095','2011-02-15', '4067.98', 'TR000082');
INSERT INTO payment VALUES('OR000096','2011-02-15', '3000', 'TR000083');
INSERT INTO payment VALUES('OR000097','2011-02-17', '6935.8', 'TR000066');
INSERT INTO payment VALUES('OR000098','2011-02-25', '4217.74', 'TR000074');
INSERT INTO payment VALUES('OR000099','2011-02-25', '10041.28', 'TR000075');
INSERT INTO payment VALUES('OR000100','2011-02-25', '1184.72', 'TR000076');
INSERT INTO payment VALUES('OR000101','2011-02-25', '7000', 'TR000078');
INSERT INTO payment VALUES('OR000102','2011-02-25', '2054.16', 'TR000080');
INSERT INTO payment VALUES('OR000103','2011-02-25', '7000', 'TR000088');
INSERT INTO payment VALUES('OR000104','2011-02-25', '5000', 'TR000089');
INSERT INTO payment VALUES('OR000105','2011-02-26', '3000', 'TR000081');
INSERT INTO payment VALUES('OR000106','2011-03-01', '10000', 'TR000073');
INSERT INTO payment VALUES('OR000107','2011-03-01', '4000', 'TR000087');
INSERT INTO payment VALUES('OR000108','2011-03-02', '3046.32', 'TR000091');
INSERT INTO payment VALUES('OR000109','2011-03-02', '1788.73', 'TR000094');
INSERT INTO payment VALUES('OR000110','2011-03-05', '2150.84', 'TR000081');
INSERT INTO payment VALUES('OR000111','2011-03-05', '3438.55', 'TR000083');
INSERT INTO payment VALUES('OR000112','2011-03-05', '3000', 'TR000084');
INSERT INTO payment VALUES('OR000113','2011-03-05', '2626.12', 'TR000085');
INSERT INTO payment VALUES('OR000114','2011-03-05', '1587.88', 'TR000095');
INSERT INTO payment VALUES('OR000115','2011-03-05', '858.4', 'TR000096');
INSERT INTO payment VALUES('OR000116','2011-03-10', '7000', 'TR000088');
INSERT INTO payment VALUES('OR000117','2011-03-10', '6847.2', 'TR000089');
INSERT INTO payment VALUES('OR000118','2011-03-11', '13200.22', 'TR000073');
INSERT INTO payment VALUES('OR000119','2011-03-15', '3000', 'TR000086');
INSERT INTO payment VALUES('OR000120','2011-03-15', '3489.29', 'TR000098');
INSERT INTO payment VALUES('OR000121','2011-03-15', '3000', 'TR000100');
INSERT INTO payment VALUES('OR000122','2011-03-20', '2923.67', 'TR000088');
INSERT INTO payment VALUES('OR000123','2011-03-20', '2000', 'TR000092');
INSERT INTO payment VALUES('OR000124','2011-03-20', '4000', 'TR000093');
INSERT INTO payment VALUES('OR000125','2011-03-20', '1500', 'TR000097');
INSERT INTO payment VALUES('OR000126','2011-03-20', '4854.14', 'TR000099');
INSERT INTO payment VALUES('OR000127','2011-03-30', '4519.52', 'TR000090');
INSERT INTO payment VALUES('OR000128','2011-03-30', '3000', 'TR000100');
INSERT INTO payment VALUES('OR000129','2011-04-02', '3410.45', 'TR000092');
INSERT INTO payment VALUES('OR000130','2011-04-02', '2953.08', 'TR000093');
INSERT INTO payment VALUES('OR000131','2011-04-05', '1787', 'TR000097');
INSERT INTO payment VALUES('OR000132','2011-04-05', '5000', 'TR000102');
INSERT INTO payment VALUES('OR000133','2011-04-05', '3000', 'TR000103');
INSERT INTO payment VALUES('OR000134','2011-04-05', '2000', 'TR000106');
INSERT INTO payment VALUES('OR000135','2011-04-07', '699.94', 'TR000108');
INSERT INTO payment VALUES('OR000136','2011-04-07', '1184.72', 'TR000109');
INSERT INTO payment VALUES('OR000137','2011-04-07', '850', 'TR000110');
INSERT INTO payment VALUES('OR000138','2011-04-07', '2369.44', 'TR000111');
INSERT INTO payment VALUES('OR000139','2011-04-07', '600', 'TR000112');
INSERT INTO payment VALUES('OR000140','2011-04-07', '1184.72', 'TR000113');
INSERT INTO payment VALUES('OR000141','2011-04-07', '367.49', 'TR000114');
INSERT INTO payment VALUES('OR000142','2011-04-07', '1597.21', 'TR000115');
INSERT INTO payment VALUES('OR000143','2011-04-07', '1609.72', 'TR000116');
INSERT INTO payment VALUES('OR000144','2011-04-07', '499.99', 'TR000117');
INSERT INTO payment VALUES('OR000145','2011-04-07', '1184.72', 'TR000118');
INSERT INTO payment VALUES('OR000146','2011-04-10', '3000', 'TR000100');
INSERT INTO payment VALUES('OR000147','2011-04-10', '4000', 'TR000103');
INSERT INTO payment VALUES('OR000148','2011-04-13', '4839.91', 'TR000101');
INSERT INTO payment VALUES('OR000149','2011-04-20', '2321.48', 'TR000102');
INSERT INTO payment VALUES('OR000150','2011-04-20', '4689.05', 'TR000103');
INSERT INTO payment VALUES('OR000151','2011-04-20', '5923.6', 'TR000105');
INSERT INTO payment VALUES('OR000152','2011-04-20', '20000', 'TR000119');
INSERT INTO payment VALUES('OR000153','2011-04-20', '30000', 'TR000120');
INSERT INTO payment VALUES('OR000154','2011-04-30', '3000', 'TR000104');
INSERT INTO payment VALUES('OR000155','2011-04-30', '2738.88', 'TR000106');
INSERT INTO payment VALUES('OR000156','2011-04-30', '5923.6', 'TR000107');
INSERT INTO payment VALUES('OR000157','2011-04-30', '20000', 'TR000123');
INSERT INTO payment VALUES('OR000158','2011-05-01', '20000', 'TR000119');
INSERT INTO payment VALUES('OR000159','2011-05-05', '30000', 'TR000120');
INSERT INTO payment VALUES('OR000160','2011-05-10', '37494.4', 'TR000119');
INSERT INTO payment VALUES('OR000161','2011-05-15', '17872.99', 'TR000124');
INSERT INTO payment VALUES('OR000162','2011-05-20', '21898.9', 'TR000123');
INSERT INTO payment VALUES('OR000163','2011-05-30', '43708.17', 'TR000120');
INSERT INTO payment VALUES('OR000164','2011-05-30', '12804.3', 'TR000121');
INSERT INTO payment VALUES('OR000165','2011-05-30', '27587.77', 'TR000122');


-- Create table PRICEHIST
CREATE TABLE public.priceHist (effDate DATE NOT NULL, 
											   prodCode VARCHAR(6) NOT NULL REFERENCES product, 
											   unitPrice DECIMAL(10,2) CONSTRAINT unitP_ck 
											   CHECK (unitPrice > 0),  
											   PRIMARY KEY (effDate, prodCode));

--  Insert PRICEHIST rows 
INSERT INTO priceHist VALUES('2010-05-15','AK0001', 12);
INSERT INTO priceHist VALUES('2010-05-15','AK0002', 8.37);
INSERT INTO priceHist VALUES('2010-05-15','AK0003', 99.99);
INSERT INTO priceHist VALUES('2010-05-15','AM0001', 36.45);
INSERT INTO priceHist VALUES('2010-05-15','AM0002', 69.26);
INSERT INTO priceHist VALUES('2010-05-15','AM0003', 20.43);
INSERT INTO priceHist VALUES('2010-05-15','AM0004', 88.14);
INSERT INTO priceHist VALUES('2010-05-15','AM0005', 49.27);
INSERT INTO priceHist VALUES('2010-05-15','AP0001', 299.99);
INSERT INTO priceHist VALUES('2010-05-15','AP0002', 304.48);
INSERT INTO priceHist VALUES('2010-05-15','AP0003', 349.99);
INSERT INTO priceHist VALUES('2010-05-15','MD0001', 119.68);
INSERT INTO priceHist VALUES('2010-05-15','MD0002', 149.99);
INSERT INTO priceHist VALUES('2010-05-15','MD0003', 239.96);
INSERT INTO priceHist VALUES('2010-05-15','MD0004', 132.21);
INSERT INTO priceHist VALUES('2010-05-15','MD0005', 825);
INSERT INTO priceHist VALUES('2010-05-15','MD0006', 124.29);
INSERT INTO priceHist VALUES('2010-05-15','NB0001', 300);
INSERT INTO priceHist VALUES('2010-05-15','NB0002', 298);
INSERT INTO priceHist VALUES('2010-05-15','NB0003', 199);
INSERT INTO priceHist VALUES('2010-05-15','NB0004', 279);
INSERT INTO priceHist VALUES('2010-05-15','PA0001', 219);
INSERT INTO priceHist VALUES('2010-05-15','PA0002', 102.99);
INSERT INTO priceHist VALUES('2010-07-12','PC0001', 454.54);
INSERT INTO priceHist VALUES('2010-05-15','PC0001', 499.99);
INSERT INTO priceHist VALUES('2010-07-12','PC0002', 197.99);
INSERT INTO priceHist VALUES('2010-05-15','PC0002', 179.99);
INSERT INTO priceHist VALUES('2010-05-15','PC0003', 390);
INSERT INTO priceHist VALUES('2010-05-15','PC0004', 538);
INSERT INTO priceHist VALUES('2010-05-15','PF0001', 123.75);
INSERT INTO priceHist VALUES('2010-05-15','PF0002', 64.25);
INSERT INTO priceHist VALUES('2010-05-15','PF0003', 28.87);
INSERT INTO priceHist VALUES('2010-05-15','PF0004', 92.85);
INSERT INTO priceHist VALUES('2010-05-15','PF0005', 119);
INSERT INTO priceHist VALUES('2010-05-15','PF0006', 7.5);
INSERT INTO priceHist VALUES('2010-05-15','PR0001', 81.72);
INSERT INTO priceHist VALUES('2010-05-15','PR0002', 99.99);
INSERT INTO priceHist VALUES('2010-05-15','PR0003', 123);
INSERT INTO priceHist VALUES('2010-08-01','MD0001', 131.65);
INSERT INTO priceHist VALUES('2010-08-01','MD0002', 164.99);
INSERT INTO priceHist VALUES('2010-08-01','MD0003', 263.96);
INSERT INTO priceHist VALUES('2010-08-01','MD0004', 145.43);
INSERT INTO priceHist VALUES('2010-08-01','MD0005', 907.5);
INSERT INTO priceHist VALUES('2010-08-01','MD0006', 136.72);
INSERT INTO priceHist VALUES('2010-08-16','PF0001', 112.5);
INSERT INTO priceHist VALUES('2010-08-16','PF0002', 58.41);
INSERT INTO priceHist VALUES('2010-08-16','PF0003', 26.25);
INSERT INTO priceHist VALUES('2010-08-16','PF0004', 84.41);
INSERT INTO priceHist VALUES('2010-08-16','PF0005', 108.18);
INSERT INTO priceHist VALUES('2010-08-16','PF0006', 6.82);
INSERT INTO priceHist VALUES('2010-08-16','AM0001', 38.27);
INSERT INTO priceHist VALUES('2010-08-16','AM0002', 72.72);
INSERT INTO priceHist VALUES('2010-08-16','AM0003', 21.45);
INSERT INTO priceHist VALUES('2010-08-16','AM0004', 92.55);
INSERT INTO priceHist VALUES('2010-08-16','AM0005', 51.73);
INSERT INTO priceHist VALUES('2010-08-16','AP0001', 314.99);
INSERT INTO priceHist VALUES('2010-08-16','AP0002', 319.7);
INSERT INTO priceHist VALUES('2010-08-16','AP0003', 367.49);
INSERT INTO priceHist VALUES('2010-08-16','AD0001', 58);
INSERT INTO priceHist VALUES('2010-08-16','AD0002', 69.99);
INSERT INTO priceHist VALUES('2010-08-16','AD0003', 54.44);
INSERT INTO priceHist VALUES('2010-08-16','AD0004', 71.99);
INSERT INTO priceHist VALUES('2010-08-16','NH0001', 21.99);
INSERT INTO priceHist VALUES('2010-08-16','NH0002', 24.99);
INSERT INTO priceHist VALUES('2010-08-16','NH0003', 171.69);
INSERT INTO priceHist VALUES('2010-12-01','NT0001', 412.49);
INSERT INTO priceHist VALUES('2010-12-01','NT0002', 324.99);
INSERT INTO priceHist VALUES('2010-12-01','NT0003', 287);
INSERT INTO priceHist VALUES('2010-12-01','NT0004', 219.89);
INSERT INTO priceHist VALUES('2010-12-01','NT0005', 499.99);
INSERT INTO priceHist VALUES('2010-12-01','NT0006', 57.99);
INSERT INTO priceHist VALUES('2010-12-01','PS0001', 3200);
INSERT INTO priceHist VALUES('2010-12-01','PS0002', 699.99);
INSERT INTO priceHist VALUES('2010-12-01','PS0003', 599.99);
INSERT INTO priceHist VALUES('2010-12-01','MP0001', 199.95);
INSERT INTO priceHist VALUES('2010-12-01','MP0002', 126.72);
INSERT INTO priceHist VALUES('2010-12-01','MP0003', 425);
INSERT INTO priceHist VALUES('2010-12-01','MP0004', 302);
INSERT INTO priceHist VALUES('2011-02-01','NB0005', 1184.72);


-- =====================================================================
-- AUDIT TRAIL + SOFT DELETE  (standard PostgreSQL)
-- Everything below runs AFTER all the data above has been loaded.
--   * every table gets:  is_deleted (soft delete flag)  and  stamp
--   * stamp looks like:  EDIT user1 2026-10-12 11:18 AM
--       (ADD / EDIT / DELETE / RESTORE  +  user  +  date  +  time)
--   * audit_log keeps the full history (old and new values)
--   * hard DELETE and TRUNCATE are blocked on every table
--   * <table>_active views show only rows where is_deleted = false
-- =====================================================================

-- 1. Central audit table ------------------------------------------------
CREATE TABLE public.audit_log (
    audit_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR(30) NOT NULL,
    action      VARCHAR(7)  NOT NULL CHECK (action IN ('ADD','EDIT','DELETE','RESTORE')),
    record_key  VARCHAR(60),             -- primary key value(s), joined with '|'
    old_values  JSONB,                   -- NULL for ADD
    new_values  JSONB,
    action_by   VARCHAR(50) NOT NULL,
    action_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Helper functions ---------------------------------------------------
-- Who is acting? If the application sets  SET app.username = 'user1'
-- (e.g. because everyone shares one DB login) that name is used; otherwise
-- the database login name is used.
CREATE OR REPLACE FUNCTION public.audit_user() RETURNS TEXT
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(NULLIF(current_setting('app.username', true), ''),
                    session_user::text);
$$;

-- Builds the stamp text, e.g.  EDIT user1 2026-10-12 11:18 AM
-- (time shown in Asia/Manila; change the zone here if needed)
CREATE OR REPLACE FUNCTION public.audit_stamp(p_action TEXT) RETURNS TEXT
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
    SELECT p_action || ' ' || public.audit_user() || ' ' ||
           to_char(now() AT TIME ZONE 'Asia/Manila', 'YYYY-MM-DD HH12:MI AM');
$$;

-- 3. Trigger functions --------------------------------------------------

-- 3a. Sets the stamp column on every INSERT / UPDATE
CREATE OR REPLACE FUNCTION public.trg_set_stamp() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.stamp := public.audit_stamp('ADD');
    ELSIF (to_jsonb(OLD) - 'stamp') = (to_jsonb(NEW) - 'stamp') THEN
        NEW.stamp := OLD.stamp;                      -- nothing changed
    ELSIF NOT OLD.is_deleted AND NEW.is_deleted THEN
        NEW.stamp := public.audit_stamp('DELETE');
    ELSIF OLD.is_deleted AND NOT NEW.is_deleted THEN
        NEW.stamp := public.audit_stamp('RESTORE');
    ELSE
        NEW.stamp := public.audit_stamp('EDIT');
    END IF;
    RETURN NEW;
END;
$$;

-- 3b. Writes the history row to audit_log (key columns passed as arguments)
CREATE OR REPLACE FUNCTION public.trg_audit_log() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_action TEXT;
    v_key    TEXT;
BEGIN
    SELECT string_agg(to_jsonb(NEW) ->> k, '|' ORDER BY ord)
      INTO v_key
      FROM unnest(TG_ARGV) WITH ORDINALITY AS t(k, ord);

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_log (table_name, action, record_key, old_values, new_values, action_by)
        VALUES (TG_TABLE_NAME, 'ADD', v_key, NULL, to_jsonb(NEW), public.audit_user());
    ELSE
        IF (to_jsonb(OLD) - 'stamp') = (to_jsonb(NEW) - 'stamp') THEN
            RETURN NULL;                             -- nothing changed, no log
        END IF;
        v_action := CASE
                      WHEN NOT OLD.is_deleted AND NEW.is_deleted THEN 'DELETE'
                      WHEN OLD.is_deleted AND NOT NEW.is_deleted THEN 'RESTORE'
                      ELSE 'EDIT'
                    END;
        INSERT INTO public.audit_log (table_name, action, record_key, old_values, new_values, action_by)
        VALUES (TG_TABLE_NAME, v_action, v_key, to_jsonb(OLD), to_jsonb(NEW), public.audit_user());
    END IF;
    RETURN NULL;
END;
$$;

-- 3c. Blocks hard DELETE / TRUNCATE (soft delete only)
CREATE OR REPLACE FUNCTION public.trg_block_hard_delete() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete/truncate not allowed on %. Use UPDATE ... SET is_deleted = true.', TG_TABLE_NAME;
END;
$$;

-- 3d. Blocks any change to audit_log itself (history is append-only)
CREATE OR REPLACE FUNCTION public.trg_protect_audit_log() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only.';
END;
$$;

-- 3e. A parent row cannot be soft-deleted while it still has active children
CREATE OR REPLACE FUNCTION public.trg_check_children() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_n INT := 0;
BEGIN
    IF NOT (NEW.is_deleted AND NOT OLD.is_deleted) THEN
        RETURN NEW;                                  -- not a soft delete
    END IF;

    CASE TG_TABLE_NAME
        WHEN 'employee' THEN
            SELECT count(*) INTO v_n FROM (
                SELECT 1 FROM public.jobhistory WHERE empno = OLD.empno AND NOT is_deleted
                UNION ALL
                SELECT 1 FROM public.sales      WHERE empno = OLD.empno AND NOT is_deleted) c;
        WHEN 'department' THEN
            SELECT count(*) INTO v_n FROM public.jobhistory
             WHERE deptcode = OLD.deptcode AND NOT is_deleted;
        WHEN 'job' THEN
            SELECT count(*) INTO v_n FROM public.jobhistory
             WHERE jobcode = OLD.jobcode AND NOT is_deleted;
        WHEN 'customer' THEN
            SELECT count(*) INTO v_n FROM public.sales
             WHERE custno = OLD.custno AND NOT is_deleted;
        WHEN 'sales' THEN
            SELECT count(*) INTO v_n FROM (
                SELECT 1 FROM public.salesdetail WHERE transno = OLD.transno AND NOT is_deleted
                UNION ALL
                SELECT 1 FROM public.payment     WHERE transno = OLD.transno AND NOT is_deleted) c;
        WHEN 'product' THEN
            SELECT count(*) INTO v_n FROM (
                SELECT 1 FROM public.salesdetail WHERE prodcode = OLD.prodcode AND NOT is_deleted
                UNION ALL
                SELECT 1 FROM public.pricehist   WHERE prodcode = OLD.prodcode AND NOT is_deleted) c;
        ELSE
            NULL;                                    -- child tables: nothing to check
    END CASE;

    IF v_n > 0 THEN
        RAISE EXCEPTION 'Cannot delete % row: % active related record(s) still exist.', TG_TABLE_NAME, v_n;
    END IF;
    RETURN NEW;
END;
$$;

-- 4. Attach everything to the 10 tables ---------------------------------
DO $$
DECLARE
    r      RECORD;
    v_args TEXT;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            ('employee',    'empno'),
            ('department',  'deptcode'),
            ('job',         'jobcode'),
            ('jobhistory',  'empno,jobcode,effdate'),
            ('customer',    'custno'),
            ('sales',       'transno'),
            ('salesdetail', 'transno,prodcode'),
            ('product',     'prodcode'),
            ('payment',     'orno'),
            ('pricehist',   'effdate,prodcode')
        ) AS t(tbl, keycols)
    LOOP
        -- new columns
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
                                      ADD COLUMN stamp VARCHAR(60)', r.tbl);

        -- label the rows loaded by this script
        EXECUTE format('UPDATE public.%I SET stamp = %L', r.tbl,
                       'ADD system ' || to_char(now() AT TIME ZONE 'Asia/Manila', 'YYYY-MM-DD HH12:MI AM'));

        -- trigger arguments = quoted key column names
        SELECT string_agg(quote_literal(k), ',') INTO v_args
          FROM unnest(string_to_array(r.keycols, ',')) AS k;

        EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I
                        FOR EACH ROW EXECUTE FUNCTION public.trg_check_children()',
                       r.tbl || '_bu_check', r.tbl);
        EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I
                        FOR EACH ROW EXECUTE FUNCTION public.trg_set_stamp()',
                       r.tbl || '_biu_stamp', r.tbl);
        EXECUTE format('CREATE TRIGGER %I BEFORE DELETE ON public.%I
                        FOR EACH ROW EXECUTE FUNCTION public.trg_block_hard_delete()',
                       r.tbl || '_bd_block', r.tbl);
        EXECUTE format('CREATE TRIGGER %I BEFORE TRUNCATE ON public.%I
                        FOR EACH STATEMENT EXECUTE FUNCTION public.trg_block_hard_delete()',
                       r.tbl || '_bt_block', r.tbl);
        EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE ON public.%I
                        FOR EACH ROW EXECUTE FUNCTION public.trg_audit_log(%s)',
                       r.tbl || '_aiu_audit', r.tbl, v_args);

        -- view of active (not deleted) rows
        EXECUTE format('CREATE VIEW public.%I AS SELECT * FROM public.%I WHERE NOT is_deleted',
                       r.tbl || '_active', r.tbl);
    END LOOP;
END;
$$;

-- audit_log is append-only
CREATE TRIGGER audit_log_protect_row
    BEFORE UPDATE OR DELETE ON public.audit_log
    FOR EACH ROW EXECUTE FUNCTION public.trg_protect_audit_log();
CREATE TRIGGER audit_log_protect_truncate
    BEFORE TRUNCATE ON public.audit_log
    FOR EACH STATEMENT EXECUTE FUNCTION public.trg_protect_audit_log();

-- =====================================================================
-- Usage examples
--   Soft delete : UPDATE employee SET is_deleted = true  WHERE empno = '00015';
--   Restore     : UPDATE employee SET is_deleted = false WHERE empno = '00015';
--   History     : SELECT * FROM audit_log WHERE table_name = 'employee' ORDER BY audit_id;
--   Active rows : SELECT * FROM employee_active;
-- =====================================================================

-- Keep the schema, seed data, and audit objects atomic.
COMMIT;
```

### Script 2 of 7 — profiles, permissions, RLS, and avatars

**Filename:** `supabase/migrations/20261103235500_auth_profiles_rls.sql`
**Purpose:** Create linked profiles and Auth triggers; add server-side permission functions; enable and configure RLS on the business tables, profiles, and audit log; configure private avatar Storage. It installs permissive access policies paired with restrictive permission guards.
**Prerequisites:** Script 1; Supabase Auth and Storage services enabled (the standard Supabase project services).
**Expected result:** New signups get `role='user'` and `account_status='pending'`. Browser clients cannot directly set administrative profile fields or hard-delete business records. Avatar objects are private and scoped by user folder.

```sql
-- Additive Supabase security migration for the existing Hope/Spotibai schema.
-- Apply only after the ten business tables and audit_log from HopeDB_audit.sql.txt exist.
-- The source script begins with destructive DROP TABLE statements and must not be rerun.

DO $$
DECLARE
  table_name text;
  required_tables text[] := ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log'
  ];
BEGIN
  FOREACH table_name IN ARRAY required_tables LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required table public.% is missing. Apply the existing schema safely before this migration.', table_name;
    END IF;
  END LOOP;
END;
$$;

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email text NOT NULL,
  first_name text NOT NULL DEFAULT '',
  last_name text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  avatar_path text,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('superadmin', 'admin', 'user')),
  account_status text NOT NULL DEFAULT 'pending'
    CHECK (account_status IN ('active', 'pending', 'blocked', 'disapproved')),
  permissions jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(permissions) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS profiles_role_status_idx
  ON public.profiles (role, account_status);

INSERT INTO public.profiles (id, email, first_name, last_name, role, account_status)
SELECT
  id,
  email,
  COALESCE(raw_user_meta_data ->> 'first_name', ''),
  COALESCE(raw_user_meta_data ->> 'last_name', ''),
  'user',
  'pending'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.handle_auth_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.profiles (id, email, first_name, last_name, role, account_status)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data ->> 'first_name', ''),
      COALESCE(NEW.raw_user_meta_data ->> 'last_name', ''),
      'user',
      'pending'
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    UPDATE public.profiles
    SET email = NEW.email, updated_at = now()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS spotibai_auth_profile_created ON auth.users;
CREATE TRIGGER spotibai_auth_profile_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_profile();

DROP TRIGGER IF EXISTS spotibai_auth_profile_email_updated ON auth.users;
CREATE TRIGGER spotibai_auth_profile_email_updated
AFTER UPDATE OF email ON auth.users
FOR EACH ROW WHEN (OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION public.handle_auth_user_profile();

CREATE OR REPLACE FUNCTION public.touch_profile_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_touch_updated_at ON public.profiles;
CREATE TRIGGER profiles_touch_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.touch_profile_updated_at();

CREATE OR REPLACE FUNCTION public.has_permission(permission_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = auth.uid()
      AND profile.account_status = 'active'
      AND (
        profile.role = 'superadmin'
        OR (
          COALESCE((profile.permissions ->> permission_name)::boolean, false)
          AND (
            permission_name LIKE '%.view'
            OR COALESCE(
              (profile.permissions ->> (split_part(permission_name, '.', 1) || '.view'))::boolean,
              false
            )
          )
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_system_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = auth.uid()
      AND profile.account_status = 'active'
      AND profile.role IN ('superadmin', 'admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = auth.uid()
      AND profile.account_status = 'active'
      AND profile.role = 'superadmin'
  );
$$;

CREATE OR REPLACE FUNCTION public.valid_spotibai_permissions(permission_set jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT jsonb_typeof(permission_set) = 'object'
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_each(permission_set) AS entry
      WHERE jsonb_typeof(entry.value) <> 'boolean'
         OR entry.key NOT IN (
           'customers.view', 'customers.add', 'customers.edit', 'customers.delete',
           'products.view', 'products.add', 'products.edit', 'products.delete',
           'products.priceAdd', 'products.priceEdit', 'products.priceDelete',
           'hr.view', 'hr.jobAdd', 'hr.jobEdit', 'hr.jobDelete',
           'hr.deptAdd', 'hr.deptEdit', 'hr.deptDelete',
           'hr.empAdd', 'hr.empEdit', 'hr.empDelete',
           'hr.jhView', 'hr.jhAdd', 'hr.jhEdit', 'hr.jhDelete',
           'sales.view', 'sales.add', 'sales.edit', 'sales.delete',
           'sales.detailView', 'sales.detailAdd', 'sales.detailEdit', 'sales.detailDelete',
           'reports.view', 'reports.topCustomers', 'reports.productMaster',
           'reports.topProducts', 'reports.activeEmployees', 'reports.allEmployees',
           'reports.empJobHistory', 'reports.topSales'
         )
    );
$$;

REVOKE ALL ON FUNCTION public.has_permission(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_system_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_superadmin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.valid_spotibai_permissions(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_system_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;

CREATE OR REPLACE FUNCTION public.manage_profile(
  target_user_id uuid,
  new_role text,
  new_status text,
  new_permissions jsonb,
  new_first_name text,
  new_last_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role text;
  target_role text;
  active_superadmin_count bigint;
BEGIN
  IF auth.uid() IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot manage your own administrative profile.';
  END IF;

  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid() AND account_status = 'active';

  SELECT role INTO target_role
  FROM public.profiles
  WHERE id = target_user_id
  FOR UPDATE;

  IF target_role IS NULL THEN
    RAISE EXCEPTION 'The target profile does not exist.';
  END IF;
  IF caller_role IS NULL OR caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only administrators may manage user accounts.';
  END IF;
  IF new_role IS NULL OR new_role NOT IN ('superadmin', 'admin', 'user') THEN
    RAISE EXCEPTION 'Invalid account role.';
  END IF;
  IF new_status IS NULL OR new_status NOT IN ('active', 'pending', 'blocked', 'disapproved') THEN
    RAISE EXCEPTION 'Invalid account status.';
  END IF;
  IF jsonb_typeof(new_permissions) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Permissions must be a JSON object.';
  END IF;
  IF length(trim(COALESCE(new_first_name, ''))) = 0
     OR length(trim(COALESCE(new_first_name, ''))) > 80
     OR length(trim(COALESCE(new_last_name, ''))) > 80 THEN
    RAISE EXCEPTION 'First name must be non-empty and names must be no longer than 80 characters.';
  END IF;
  IF NOT public.valid_spotibai_permissions(new_permissions) THEN
    RAISE EXCEPTION 'Permissions contain an unsupported key or a non-boolean value.';
  END IF;

  IF caller_role = 'admin'
     AND (target_role <> 'user' OR new_role <> 'user') THEN
    RAISE EXCEPTION 'Admins may manage User accounts only.';
  END IF;

  IF target_role = 'superadmin'
     AND (new_role <> 'superadmin' OR new_status <> 'active') THEN
    PERFORM pg_advisory_xact_lock(73640192);
    SELECT count(*) INTO active_superadmin_count
    FROM public.profiles
    WHERE role = 'superadmin' AND account_status = 'active';
    IF active_superadmin_count <= 1 THEN
      RAISE EXCEPTION 'The last active Super Admin cannot be demoted.';
    END IF;
  END IF;

  UPDATE public.profiles
  SET role = new_role,
      account_status = new_status,
      permissions = new_permissions,
      first_name = trim(new_first_name),
      last_name = trim(COALESCE(new_last_name, ''))
  WHERE id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.manage_profile(uuid, text, text, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manage_profile(uuid, text, text, jsonb, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.enforce_business_permissions()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  module_key text := TG_ARGV[0];
  action_key text;
  record_changed boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    action_key := CASE module_key
      WHEN 'products.price' THEN 'products.priceAdd'
      WHEN 'hr.job' THEN 'hr.jobAdd'
      WHEN 'hr.dept' THEN 'hr.deptAdd'
      WHEN 'hr.emp' THEN 'hr.empAdd'
      WHEN 'hr.jh' THEN 'hr.jhAdd'
      WHEN 'sales.detail' THEN 'sales.detailAdd'
      WHEN 'sales.payment' THEN 'sales.add'
      ELSE module_key || '.add'
    END;
    IF NOT public.has_permission(action_key) THEN
      RAISE EXCEPTION 'Permission denied: %.', action_key USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  record_changed := (to_jsonb(OLD) - 'is_deleted' - 'stamp')
                    IS DISTINCT FROM
                    (to_jsonb(NEW) - 'is_deleted' - 'stamp');

  IF NEW.is_deleted IS DISTINCT FROM OLD.is_deleted THEN
    action_key := CASE module_key
      WHEN 'products.price' THEN 'products.priceDelete'
      WHEN 'hr.job' THEN 'hr.jobDelete'
      WHEN 'hr.dept' THEN 'hr.deptDelete'
      WHEN 'hr.emp' THEN 'hr.empDelete'
      WHEN 'hr.jh' THEN 'hr.jhDelete'
      WHEN 'sales.detail' THEN 'sales.detailDelete'
      WHEN 'sales.payment' THEN 'sales.delete'
      ELSE module_key || '.delete'
    END;
    IF NOT public.has_permission(action_key) THEN
      RAISE EXCEPTION 'Permission denied: %.', action_key USING ERRCODE = '42501';
    END IF;
  END IF;

  IF record_changed THEN
    action_key := CASE module_key
      WHEN 'products.price' THEN 'products.priceEdit'
      WHEN 'hr.job' THEN 'hr.jobEdit'
      WHEN 'hr.dept' THEN 'hr.deptEdit'
      WHEN 'hr.emp' THEN 'hr.empEdit'
      WHEN 'hr.jh' THEN 'hr.jhEdit'
      WHEN 'sales.detail' THEN 'sales.detailEdit'
      WHEN 'sales.payment' THEN 'sales.edit'
      ELSE module_key || '.edit'
    END;
    IF NOT public.has_permission(action_key) THEN
      RAISE EXCEPTION 'Permission denied: %.', action_key USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DO $$
DECLARE
  item record;
  table_name text;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('customer',    'customers',     'customers.view'),
      ('product',     'products',      'products.view'),
      ('pricehist',   'products.price','products.view'),
      ('employee',    'hr.emp',        'hr.view'),
      ('department',  'hr.dept',       'hr.view'),
      ('job',         'hr.job',        'hr.view'),
      ('jobhistory',  'hr.jh',         'hr.jhView'),
      ('sales',       'sales',         'sales.view'),
      ('salesdetail', 'sales.detail',  'sales.detailView'),
      ('payment',     'sales.payment', 'sales.view')
    ) AS permissions(table_name, module_key, select_permission)
  LOOP
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false', item.table_name);
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS stamp varchar(60)', item.table_name);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', item.table_name);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon', item.table_name);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO authenticated', item.table_name);

    EXECUTE format('DROP POLICY IF EXISTS spotibai_select ON public.%I', item.table_name);
    EXECUTE format('DROP POLICY IF EXISTS spotibai_select_access ON public.%I', item.table_name);
    EXECUTE format('DROP POLICY IF EXISTS spotibai_insert ON public.%I', item.table_name);
    EXECUTE format('DROP POLICY IF EXISTS spotibai_insert_access ON public.%I', item.table_name);
    EXECUTE format('DROP POLICY IF EXISTS spotibai_update ON public.%I', item.table_name);
    EXECUTE format('DROP POLICY IF EXISTS spotibai_update_access ON public.%I', item.table_name);
    EXECUTE format(
      'CREATE POLICY spotibai_select_access ON public.%I FOR SELECT TO authenticated USING (true)',
      item.table_name
    );
    EXECUTE format(
      'CREATE POLICY spotibai_insert_access ON public.%I FOR INSERT TO authenticated WITH CHECK (true)',
      item.table_name
    );
    EXECUTE format(
      'CREATE POLICY spotibai_update_access ON public.%I FOR UPDATE TO authenticated USING (true) WITH CHECK (true)',
      item.table_name
    );
    EXECUTE format(
      'CREATE POLICY spotibai_select ON public.%I AS RESTRICTIVE FOR SELECT TO authenticated USING (public.has_permission(%L))',
      item.table_name, item.select_permission
    );
    EXECUTE format(
      'CREATE POLICY spotibai_insert ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.has_permission(%L))',
      item.table_name,
      CASE item.module_key
        WHEN 'products.price' THEN 'products.priceAdd'
        WHEN 'hr.job' THEN 'hr.jobAdd'
        WHEN 'hr.dept' THEN 'hr.deptAdd'
        WHEN 'hr.emp' THEN 'hr.empAdd'
        WHEN 'hr.jh' THEN 'hr.jhAdd'
        WHEN 'sales.detail' THEN 'sales.detailAdd'
        WHEN 'sales.payment' THEN 'sales.add'
        ELSE item.module_key || '.add'
      END
    );
    EXECUTE format(
      'CREATE POLICY spotibai_update ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.has_permission(%L) OR public.has_permission(%L)) WITH CHECK (public.has_permission(%L) OR public.has_permission(%L))',
      item.table_name,
      CASE item.module_key
        WHEN 'products.price' THEN 'products.priceEdit'
        WHEN 'hr.job' THEN 'hr.jobEdit'
        WHEN 'hr.dept' THEN 'hr.deptEdit'
        WHEN 'hr.emp' THEN 'hr.empEdit'
        WHEN 'hr.jh' THEN 'hr.jhEdit'
        WHEN 'sales.detail' THEN 'sales.detailEdit'
        WHEN 'sales.payment' THEN 'sales.edit'
        ELSE item.module_key || '.edit'
      END,
      CASE item.module_key
        WHEN 'products.price' THEN 'products.priceDelete'
        WHEN 'hr.job' THEN 'hr.jobDelete'
        WHEN 'hr.dept' THEN 'hr.deptDelete'
        WHEN 'hr.emp' THEN 'hr.empDelete'
        WHEN 'hr.jh' THEN 'hr.jhDelete'
        WHEN 'sales.detail' THEN 'sales.detailDelete'
        WHEN 'sales.payment' THEN 'sales.delete'
        ELSE item.module_key || '.delete'
      END,
      CASE item.module_key
        WHEN 'products.price' THEN 'products.priceEdit'
        WHEN 'hr.job' THEN 'hr.jobEdit'
        WHEN 'hr.dept' THEN 'hr.deptEdit'
        WHEN 'hr.emp' THEN 'hr.empEdit'
        WHEN 'hr.jh' THEN 'hr.jhEdit'
        WHEN 'sales.detail' THEN 'sales.detailEdit'
        WHEN 'sales.payment' THEN 'sales.edit'
        ELSE item.module_key || '.edit'
      END,
      CASE item.module_key
        WHEN 'products.price' THEN 'products.priceDelete'
        WHEN 'hr.job' THEN 'hr.jobDelete'
        WHEN 'hr.dept' THEN 'hr.deptDelete'
        WHEN 'hr.emp' THEN 'hr.empDelete'
        WHEN 'hr.jh' THEN 'hr.jhDelete'
        WHEN 'sales.detail' THEN 'sales.detailDelete'
        WHEN 'sales.payment' THEN 'sales.delete'
        ELSE item.module_key || '.delete'
      END
    );

    EXECUTE format('DROP TRIGGER IF EXISTS spotibai_permission_guard ON public.%I', item.table_name);
    EXECUTE format(
      'CREATE TRIGGER spotibai_permission_guard BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.enforce_business_permissions(%L)',
      item.table_name, item.module_key
    );
    EXECUTE format('REVOKE DELETE, TRUNCATE ON public.%I FROM anon, authenticated', item.table_name);
  END LOOP;

  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.profiles FROM PUBLIC, anon, authenticated;
  GRANT SELECT ON public.profiles TO authenticated;
  GRANT UPDATE (first_name, last_name, phone, avatar_path) ON public.profiles TO authenticated;
  DROP POLICY IF EXISTS spotibai_profiles_read_access ON public.profiles;
  CREATE POLICY spotibai_profiles_read_access ON public.profiles
    FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS profiles_read_authorized ON public.profiles;
  CREATE POLICY profiles_read_authorized ON public.profiles AS RESTRICTIVE
    FOR SELECT TO authenticated
    USING (
      id = auth.uid()
      OR public.is_superadmin()
      OR (public.is_system_admin() AND role = 'user')
    );
  DROP POLICY IF EXISTS spotibai_profiles_update_access ON public.profiles;
  CREATE POLICY spotibai_profiles_update_access ON public.profiles
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
  DROP POLICY IF EXISTS profiles_update_self ON public.profiles;
  CREATE POLICY profiles_update_self ON public.profiles AS RESTRICTIVE
    FOR UPDATE TO authenticated
    USING (id = auth.uid() AND account_status = 'active')
    WITH CHECK (id = auth.uid() AND account_status = 'active');

  ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.audit_log FROM PUBLIC, anon, authenticated;
  GRANT SELECT ON public.audit_log TO authenticated;
  DROP POLICY IF EXISTS spotibai_audit_log_read_access ON public.audit_log;
  CREATE POLICY spotibai_audit_log_read_access ON public.audit_log
    FOR SELECT TO authenticated USING (true);
  DROP POLICY IF EXISTS audit_log_read_admin ON public.audit_log;
  CREATE POLICY audit_log_read_admin ON public.audit_log AS RESTRICTIVE
    FOR SELECT TO authenticated
    USING (action_by = auth.uid()::text OR public.is_system_admin());
END;
$$;

CREATE OR REPLACE FUNCTION public.audit_user()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(auth.uid()::text, current_user::text);
$$;

ALTER FUNCTION public.trg_audit_log() SECURITY DEFINER;
ALTER FUNCTION public.trg_audit_log() SET search_path = public, auth, pg_temp;
ALTER FUNCTION public.trg_check_children() SECURITY DEFINER;
ALTER FUNCTION public.trg_check_children() SET search_path = public, pg_temp;

DO $$
DECLARE
  view_name text;
BEGIN
  FOREACH view_name IN ARRAY ARRAY[
    'employee_active', 'department_active', 'job_active', 'jobhistory_active',
    'customer_active', 'sales_active', 'salesdetail_active', 'product_active',
    'payment_active', 'pricehist_active'
  ] LOOP
    IF to_regclass(format('public.%I', view_name)) IS NOT NULL THEN
      EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', view_name);
      EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon', view_name);
      EXECUTE format('GRANT SELECT ON public.%I TO authenticated', view_name);
    END IF;
  END LOOP;
END;
$$;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', false, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp'];

DROP POLICY IF EXISTS spotibai_avatar_read_own ON storage.objects;
CREATE POLICY spotibai_avatar_read_own ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS spotibai_avatar_insert_own ON storage.objects;
CREATE POLICY spotibai_avatar_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS spotibai_avatar_update_own ON storage.objects;
CREATE POLICY spotibai_avatar_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS spotibai_avatar_delete_own ON storage.objects;
CREATE POLICY spotibai_avatar_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS spotibai_avatar_read_guard ON storage.objects;
CREATE POLICY spotibai_avatar_read_guard ON storage.objects AS RESTRICTIVE
  FOR SELECT
  USING (bucket_id <> 'avatars' OR (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text));

DROP POLICY IF EXISTS spotibai_avatar_insert_guard ON storage.objects;
CREATE POLICY spotibai_avatar_insert_guard ON storage.objects AS RESTRICTIVE
  FOR INSERT
  WITH CHECK (bucket_id <> 'avatars' OR (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text));

DROP POLICY IF EXISTS spotibai_avatar_update_guard ON storage.objects;
CREATE POLICY spotibai_avatar_update_guard ON storage.objects AS RESTRICTIVE
  FOR UPDATE
  USING (bucket_id <> 'avatars' OR (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text))
  WITH CHECK (bucket_id <> 'avatars' OR (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text));

DROP POLICY IF EXISTS spotibai_avatar_delete_guard ON storage.objects;
CREATE POLICY spotibai_avatar_delete_guard ON storage.objects AS RESTRICTIVE
  FOR DELETE
  USING (bucket_id <> 'avatars' OR (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text));
```

### Script 3 of 7 — applicant review RPC

**Filename:** `supabase/migrations/20261104000000_review_applicants.sql`
**Purpose:** Add the guarded `review_applicant(uuid,text)` function for active admins to approve or disapprove another pending User account.
**Prerequisites:** Script 2.
**Expected result:** Only an active Super Admin or Admin can set another pending User's status to `active` or `disapproved`; self-review and other roles/statuses are rejected.

```sql
CREATE OR REPLACE FUNCTION public.review_applicant(
  target_user_id uuid,
  new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role text;
  target_role text;
  target_status text;
BEGIN
  IF auth.uid() IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot review your own account.';
  END IF;

  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid() AND account_status = 'active';

  SELECT role, account_status INTO target_role, target_status
  FROM public.profiles
  WHERE id = target_user_id
  FOR UPDATE;

  IF target_role IS NULL THEN
    RAISE EXCEPTION 'The selected applicant does not exist.';
  END IF;
  IF caller_role IS NULL OR caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only active administrators may review applicants.';
  END IF;
  IF target_role <> 'user' THEN
    RAISE EXCEPTION 'Only User accounts may be reviewed as applicants.';
  END IF;
  IF target_status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending applicants may be reviewed.';
  END IF;
  IF new_status IS NULL OR new_status NOT IN ('active', 'disapproved') THEN
    RAISE EXCEPTION 'Applicant status must be active or disapproved.';
  END IF;

  UPDATE public.profiles
  SET account_status = new_status
  WHERE id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.review_applicant(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_applicant(uuid, text) TO authenticated;
```

### Script 4 of 7 — Google profile-name synchronization

**Filename:** `supabase/migrations/20261104001000_google_profile_name_sync.sql`
**Purpose:** Replace the profile trigger function so it can map available Google name metadata, and fill blank names for existing Google-linked User profiles.
**Prerequisites:** Script 2.
**Expected result:** Google metadata can populate names without changing roles or account status. The backfill updates only matching Google-linked `user` profiles with blank names.

```sql
CREATE OR REPLACE FUNCTION public.handle_auth_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  full_name text;
  first_name text;
  last_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    full_name := COALESCE(
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'name'), ''),
      ''
    );
    first_name := COALESCE(
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'first_name'), ''),
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'given_name'), ''),
      (pg_catalog.regexp_match(full_name, '^\s*(\S+)'))[1],
      ''
    );
    last_name := COALESCE(
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'last_name'), ''),
      NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'family_name'), ''),
      NULLIF(pg_catalog.btrim(pg_catalog.regexp_replace(full_name, '^\s*\S+\s*', '')), ''),
      ''
    );

    INSERT INTO public.profiles (id, email, first_name, last_name, role, account_status)
    VALUES (NEW.id, NEW.email, first_name, last_name, 'user', 'pending')
    ON CONFLICT (id) DO NOTHING;
  ELSE
    UPDATE public.profiles
    SET email = NEW.email, updated_at = pg_catalog.now()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

UPDATE public.profiles AS profile
SET first_name = CASE
      WHEN NULLIF(pg_catalog.btrim(profile.first_name), '') IS NULL THEN COALESCE(
        NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'first_name'), ''),
        NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'given_name'), ''),
        (pg_catalog.regexp_match(COALESCE(
          NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'full_name'), ''),
          NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'name'), ''),
          ''
        ), '^\s*(\S+)'))[1],
        ''
      )
      ELSE profile.first_name
    END,
    last_name = CASE
      WHEN NULLIF(pg_catalog.btrim(profile.last_name), '') IS NULL THEN COALESCE(
        NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'last_name'), ''),
        NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'family_name'), ''),
        NULLIF(pg_catalog.btrim(pg_catalog.regexp_replace(COALESCE(
          NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'full_name'), ''),
          NULLIF(pg_catalog.btrim(auth_user.raw_user_meta_data ->> 'name'), ''),
          ''
        ), '^\s*\S+\s*', '')), ''),
        ''
      )
      ELSE profile.last_name
    END
FROM auth.users AS auth_user
WHERE auth_user.id = profile.id
  AND profile.role = 'user'
  AND EXISTS (
    SELECT 1
    FROM auth.identities AS identity
    WHERE identity.user_id = auth_user.id
      AND identity.provider = 'google'
  )
  AND (
    NULLIF(pg_catalog.btrim(profile.first_name), '') IS NULL
    OR NULLIF(pg_catalog.btrim(profile.last_name), '') IS NULL
  );
```

### Script 5 of 7 — payment-report permission

**Filename:** `supabase/migrations/20261104002000_payment_report_permission.sql`
**Purpose:** Add `reports.payment` to the database permission validator's allowlist. It does not create tables or alter RLS.
**Prerequisites:** Script 2 (function `public.valid_spotibai_permissions(jsonb)` must exist).
**Expected result:** The permission key is accepted for assignment. Payment Report additionally requires `sales.view` in the frontend and remains protected by the payment table's `sales.view` RLS policy.

```sql
DO $$
BEGIN
  IF to_regprocedure('public.valid_spotibai_permissions(jsonb)') IS NULL THEN
    RAISE EXCEPTION 'Required function public.valid_spotibai_permissions(jsonb) is missing. Apply the Spotibai auth/RLS migration first.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.valid_spotibai_permissions(permission_set jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT jsonb_typeof(permission_set) = 'object'
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_each(permission_set) AS entry
      WHERE jsonb_typeof(entry.value) <> 'boolean'
         OR entry.key NOT IN (
           'customers.view', 'customers.add', 'customers.edit', 'customers.delete',
           'products.view', 'products.add', 'products.edit', 'products.delete',
           'products.priceAdd', 'products.priceEdit', 'products.priceDelete',
           'hr.view', 'hr.jobAdd', 'hr.jobEdit', 'hr.jobDelete',
           'hr.deptAdd', 'hr.deptEdit', 'hr.deptDelete',
           'hr.empAdd', 'hr.empEdit', 'hr.empDelete',
           'hr.jhView', 'hr.jhAdd', 'hr.jhEdit', 'hr.jhDelete',
           'sales.view', 'sales.add', 'sales.edit', 'sales.delete',
           'sales.detailView', 'sales.detailAdd', 'sales.detailEdit', 'sales.detailDelete',
           'reports.view', 'reports.topCustomers', 'reports.productMaster',
           'reports.topProducts', 'reports.activeEmployees', 'reports.allEmployees',
           'reports.empJobHistory', 'reports.topSales', 'reports.payment'
         )
    );
$$;
```

### Script 6 of 7 — Supabase Realtime publication

**Filename:** `supabase/migrations/20261104003000_realtime_publication.sql`
**Purpose:** Add the existing profiles, ERP business, and audit tables to the default `supabase_realtime` publication if they are not already members. This does not alter table definitions or RLS policies.
**Prerequisites:** Scripts 1 and 2, including all listed tables and their existing RLS policies.
**Expected result:** Changes to rows visible to the signed-in user can be delivered to the dashboard. RLS continues to govern row visibility.

```sql
DO $$
DECLARE
  table_name text;
  realtime_tables text[] := ARRAY[
    'profiles',
    'customer',
    'product',
    'pricehist',
    'employee',
    'department',
    'job',
    'jobhistory',
    'sales',
    'salesdetail',
    'payment',
    'audit_log'
  ];
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    RAISE EXCEPTION 'Supabase Realtime publication supabase_realtime does not exist.';
  END IF;

  FOREACH table_name IN ARRAY realtime_tables LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required Realtime table public.% is missing.', table_name;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = table_name
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', table_name);
    END IF;
  END LOOP;
END;
$$;
```

### Script 7 of 7 — Super Admin account protection

**Filename:** `supabase/migrations/20261105000000_protect_superadmin_accounts.sql`
**Purpose:** Replace the profile-management and applicant-review RPCs with transaction-serialized actor/target checks. No account-management caller can modify an existing Super Admin profile; Admins remain limited to User profiles. Reassert profile column grants and the active-user self-update policy.
**Prerequisites:** Scripts 1–6, including `public.profiles`, the permission validator, and existing profile RLS.
**Expected result:** Super Admin, Admin, and User management calls are authorized against the authenticated profile and locked target row. Direct authenticated updates cannot change roles, status, or permissions, and can update only the caller's permitted profile fields.

```sql
CREATE OR REPLACE FUNCTION public.manage_profile(
  target_user_id uuid,
  new_role text,
  new_status text,
  new_permissions jsonb,
  new_first_name text,
  new_last_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role text;
  target_role text;
BEGIN
  IF auth.uid() IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot manage your own administrative profile.';
  END IF;

  PERFORM pg_advisory_xact_lock(73640192);

  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid() AND account_status = 'active'
  FOR SHARE;

  SELECT role INTO target_role
  FROM public.profiles
  WHERE id = target_user_id
  FOR UPDATE;

  IF target_role IS NULL THEN
    RAISE EXCEPTION 'The target profile does not exist.';
  END IF;
  IF caller_role IS NULL OR caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only administrators may manage user accounts.';
  END IF;
  IF target_role = 'superadmin' THEN
    RAISE EXCEPTION 'Super Admin accounts cannot be managed by another account.';
  END IF;
  IF new_role IS NULL OR new_role NOT IN ('superadmin', 'admin', 'user') THEN
    RAISE EXCEPTION 'Invalid account role.';
  END IF;
  IF new_status IS NULL OR new_status NOT IN ('active', 'pending', 'blocked', 'disapproved') THEN
    RAISE EXCEPTION 'Invalid account status.';
  END IF;
  IF jsonb_typeof(new_permissions) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Permissions must be a JSON object.';
  END IF;
  IF length(trim(COALESCE(new_first_name, ''))) = 0
     OR length(trim(COALESCE(new_first_name, ''))) > 80
     OR length(trim(COALESCE(new_last_name, ''))) > 80 THEN
    RAISE EXCEPTION 'First name must be non-empty and names must be no longer than 80 characters.';
  END IF;
  IF NOT public.valid_spotibai_permissions(new_permissions) THEN
    RAISE EXCEPTION 'Permissions contain an unsupported key or a non-boolean value.';
  END IF;

  IF caller_role = 'admin'
     AND (target_role <> 'user' OR new_role <> 'user') THEN
    RAISE EXCEPTION 'Admins may manage User accounts only.';
  END IF;

  UPDATE public.profiles
  SET role = new_role,
      account_status = new_status,
      permissions = new_permissions,
      first_name = trim(new_first_name),
      last_name = trim(COALESCE(new_last_name, ''))
  WHERE id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.review_applicant(
  target_user_id uuid,
  new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role text;
  target_role text;
  target_status text;
BEGIN
  IF auth.uid() IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot review your own account.';
  END IF;

  PERFORM pg_advisory_xact_lock(73640192);

  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid() AND account_status = 'active'
  FOR SHARE;

  SELECT role, account_status INTO target_role, target_status
  FROM public.profiles
  WHERE id = target_user_id
  FOR UPDATE;

  IF target_role IS NULL THEN
    RAISE EXCEPTION 'The selected applicant does not exist.';
  END IF;
  IF caller_role IS NULL OR caller_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only active administrators may review applicants.';
  END IF;
  IF target_role <> 'user' THEN
    RAISE EXCEPTION 'Only User accounts may be reviewed as applicants.';
  END IF;
  IF target_status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending applicants may be reviewed.';
  END IF;
  IF new_status IS NULL OR new_status NOT IN ('active', 'disapproved') THEN
    RAISE EXCEPTION 'Applicant status must be active or disapproved.';
  END IF;

  UPDATE public.profiles
  SET account_status = new_status
  WHERE id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.manage_profile(uuid, text, text, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manage_profile(uuid, text, text, jsonb, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.review_applicant(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_applicant(uuid, text) TO authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE (first_name, last_name, phone, avatar_path) ON public.profiles TO authenticated;

DROP POLICY IF EXISTS spotibai_profiles_update_access ON public.profiles;
CREATE POLICY spotibai_profiles_update_access ON public.profiles
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS profiles_update_self ON public.profiles;
CREATE POLICY profiles_update_self ON public.profiles AS RESTRICTIVE
  FOR UPDATE TO authenticated
  USING (id = auth.uid() AND account_status = 'active')
  WITH CHECK (id = auth.uid() AND account_status = 'active');
```

### Optional Supabase Edge Function — invitations

The User Management invitation workflow also uses `supabase/functions/invite-user/index.ts`. This TypeScript Edge Function is included separately; it is not SQL and is therefore not embedded in the SQL blocks above. It validates the caller through Supabase Auth and `profiles`, then uses the Edge Function runtime's service-role client to send an invitation and call `manage_profile`.

Deploy only if you want the dashboard's invite-user feature:

1. Install the Supabase CLI using the current official Windows installation instructions.
2. In a terminal opened at this folder, run `supabase init` to create local CLI configuration for this copied project. This is a local development configuration step; it does not connect to or change a database.
3. Run `supabase login`.
4. Find the project reference in your own Supabase project settings and run `supabase link --project-ref YOUR_PROJECT_REF`.
5. Set the exact browser origins allowed to call the function. For local Vite, use `http://127.0.0.1:5173,http://localhost:5173`; for production add only your actual deployed origin:

   ```powershell
   supabase secrets set ALLOWED_ORIGINS=http://127.0.0.1:5173,http://localhost:5173
   ```

6. Deploy the function:

   ```powershell
   supabase functions deploy invite-user
   ```

The function requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` inside the Edge Function server environment. Supabase normally injects project values; if your deployment requires configuring them, set them only as Supabase function secrets using your own project credentials. **Never paste a service-role key into this plan, `.env.local`, frontend code, or a ZIP.** For production, update `ALLOWED_ORIGINS` to the real origin. Function deployment was not tested as part of this handoff preparation.

## Part 5 — Create the first Super Admin

Public registration intentionally creates an ordinary `user` with `pending` status. It cannot grant Super Admin privileges. The first Super Admin must be provisioned by a trusted project owner in Supabase's SQL Editor after all seven SQL scripts have completed.

1. Open the new site's registration form and create the classmate/owner account with an email they control. Complete email confirmation if it is enabled.
2. In Supabase **Authentication → Users**, confirm the account exists. In SQL Editor, confirm the matching profile exists:

   ```sql
   SELECT id, email, role, account_status
   FROM public.profiles
   WHERE lower(email) = lower('owner@example.com');
   ```

3. Replace `owner@example.com` with that person's own email. Confirm exactly one row is returned and it is the intended account.
4. In the SQL Editor for this new project only, run the following trusted bootstrap. Replace the email. `SELECT ... INTO STRICT` intentionally fails if zero or multiple profiles match.

   ```sql
   DO $bootstrap$
   DECLARE
     target_profile_id uuid;
   BEGIN
     SELECT id
     INTO STRICT target_profile_id
     FROM public.profiles
     WHERE lower(email) = lower('owner@example.com');

     UPDATE public.profiles
     SET role = 'superadmin',
         account_status = 'active',
         permissions = '{}'::jsonb
     WHERE id = target_profile_id;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Profile was not updated; verify the account and try again.';
     END IF;
   END;
   $bootstrap$;
   ```

5. Verify the update affected the expected account:

   ```sql
   SELECT id, email, role, account_status
   FROM public.profiles
   WHERE lower(email) = lower('owner@example.com');
   ```

6. Sign in with that account. The profile must show `role='superadmin'` and `account_status='active'`.

This SQL is a trusted one-time bootstrap for the new project's owner, not a website feature. Never give SQL Editor access to an ordinary user for self-promotion. There is no Super Admin email or UUID embedded in this manual. After the first owner is active, use the protected User Management flow to administer Admin and User accounts. Existing Super Admin profiles cannot be modified through account-management RPCs.

## Part 6 — Authentication configuration

### Email and password

The application supports email/password registration and login, persisted sessions, logout, and password recovery. New public signups start pending and must be approved by an Admin or Super Admin before they can use protected business modules. In Supabase **Authentication → Providers**, keep Email enabled and configure confirmation/email delivery as appropriate. For reliable production email, configure your own email provider and sender domain.

### Site URL and redirect allowlist

In Supabase **Authentication → URL Configuration**:

- Email confirmation returns to the current app origin at
  `/Login/Login.html?mode=signin&auth=confirmed`; password recovery returns to
  `/Login/Login.html?mode=recovery`.
- Sign In and Register state is carried in the `mode` query parameter and
  remains selected after refresh. Register accepts both `mode=signup` and
  `mode=register`; switching modes also supports browser Back and Forward.
- Add `http://127.0.0.1:5173/**` and `http://localhost:5173/**` to the redirect
  allowlist for local development.
- In production, set the Site URL to the actual HTTPS Vercel domain and add
  `https://<your-actual-vercel-domain>/**` to the allowlist. This repository
  does not identify a production domain, so replace the placeholder with the
  deployed site's real domain; do not guess one.

Do not use the project owner's private production domain as a placeholder. Supabase only accepts redirect targets allowed by this configuration.

### Google OAuth (optional)

The existing login UI supports Google sign-in. Each person must create and own their own OAuth credentials:

1. In Supabase **Authentication → Providers → Google**, enable Google and copy the callback/redirect URI shown there.
2. In the person's Google Cloud Console, configure an OAuth consent screen and create an OAuth Client ID for a Web application.
3. Add the exact Supabase callback URI from the Supabase provider page to the Google OAuth client's **Authorized redirect URIs**. This callback is the Supabase URL, not the local Vite URL.
4. Copy that person's Client ID and Client Secret into the Supabase Google provider settings and save.
5. Add the local and production app login redirect URLs in Supabase's URL Configuration as described above.

Never put the Google Client Secret in frontend files or Vite environment variables. Google OAuth credentials and provider setup are not included in the ZIP.

## Part 7 — Environment configuration

The frontend reads these exact variables from `Website/scripts/supabase-client.js`:

```dotenv
VITE_SUPABASE_URL=
VITE_SUPABASE_PUBLISHABLE_KEY=
```

The included `.env.example` contains those names with empty values. On Windows:

1. In the `Website` folder, copy `.env.example`.
2. Rename the copy to `.env.local` (ensure Windows did not leave a `.txt` extension).
3. In Supabase **Project Settings → API** (or the current project API-key settings), copy your own Project URL into `VITE_SUPABASE_URL`.
4. Copy your own **publishable** key, or the legacy anon/public key for that project if it is still what your project provides, into `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Save `.env.local` and restart the Vite server after changing it.

Only the browser-safe publishable/anon key belongs in this frontend configuration. Supabase service-role/secret keys, database passwords, OAuth client secrets, and access/refresh tokens must never be exposed in a `VITE_` variable. `.gitignore` excludes `.env.local` and other environment files while allowing `.env.example`.

## Part 8 — Install and run the website (Windows)

1. Install Node.js 20.11 or later from [https://nodejs.org](https://nodejs.org), if needed. Reopen VS Code after installation.
2. Extract the ZIP to a normal folder. In VS Code, choose **File → Open Folder** and open the extracted `Website` folder (the one containing `package.json`).
3. Choose **Terminal → New Terminal**.
4. Create `.env.local` as described in Part 7.
5. Install the locked dependencies:

   ```powershell
   npm install
   ```

6. Run the production build check:

   ```powershell
   npm run build
   ```

7. Start the development server:

   ```powershell
   npm run dev
   ```

8. Open the exact local URL printed by Vite (by default `http://127.0.0.1:5173`) in a browser.
9. Stop the development server with `Ctrl+C` in the terminal.

The available package scripts are `npm run dev`, `npm run build`, and `npm run preview`. `npm run build` writes generated output into `dist/`; do not include that output in the distributable ZIP.

## Part 9 — First-run verification checklist

Check each item in your own Supabase project and browser. This checklist is not a claim that the tests have been performed.

- [ ] Homepage loads.
- [ ] Login page loads and no Supabase configuration error appears.
- [ ] Supabase email/password login works for the active first Super Admin.
- [ ] New registration creates a `user` profile in pending status.
- [ ] Pending account is blocked from protected dashboard use until reviewed.
- [ ] Profile lookup succeeds for the authenticated user.
- [ ] Super Admin can access allowed administration and business modules.
- [ ] An Admin can access only its assigned operations and User-account management.
- [ ] A normal User can access only explicitly assigned modules/permissions.
- [ ] Dashboard and Customers display database records.
- [ ] Products and price history display database records.
- [ ] Employees, Departments, Jobs, and Job History display database records.
- [ ] Sales, Sales Details, and Payments display database records.
- [ ] Reports show data only when both report and source-module permissions allow access.
- [ ] Applicant approval and disapproval work for an active admin.
- [ ] Google sign-in works, if you configured your own OAuth credentials.
- [ ] Avatar upload/read works, if tested.
- [ ] A permitted update persists after refreshing and signing in again.
- [ ] Browser Console and Network show no unexpected errors or unauthorized requests.

To inspect browser errors, press `F12` and use **Console** for JavaScript errors. Use **Network**, filter by `Fetch/XHR`, and inspect the failed request's status and response body. Never share request headers containing bearer tokens, API keys, cookies, or password data. Do not test delete actions against valuable records; if validating soft-delete, use a throwaway record in your own test project and follow the UI's soft-delete flow.

## Part 10 — Troubleshooting

| Symptom | What to check |
|---|---|
| Invalid API key | Confirm `VITE_SUPABASE_PUBLISHABLE_KEY` belongs to the same project as the URL, has no surrounding quotes/spaces, and is the public publishable/anon key—not a service-role or secret key. Restart Vite after editing `.env.local`. |
| Invalid Supabase URL | Use the Project URL shown in your own Supabase settings, including `https://` and without extra path text or a trailing typo. |
| Failed database connection | Check internet access, the project's health/paused status, URL/key pairing, and the browser Network request status. Do not put database credentials in frontend settings. |
| Missing table or column | Verify all setup scripts were run in order in the intended new project and `public` schema. Do not rerun original destructive SQL. Check the exact error and schema before considering a migration. |
| RLS permission denied / empty table result | Confirm the account's profile is `active`, correct role/permissions are assigned, and all SQL scripts completed. Inspect deployed policies/functions in the SQL Editor. Do not disable RLS or add unrestricted policies. |
| Profile not loading | Verify that `auth.users` account has a corresponding `public.profiles` row and the profile SELECT policy is installed. Inspect Console/Network status and SQL error details without exposing tokens. |
| User stuck in pending | An active Admin or Super Admin must review that applicant. Verify the `review_applicant` migration and caller role/status. Do not directly alter an ordinary account's role from the browser. |
| OAuth redirect mismatch | Compare the exact URL (scheme, host, port, path, query) with Supabase URL Configuration. Google Cloud must allow the callback URL shown by Supabase's Google provider settings. |
| Storage upload failure | Confirm script 2 completed, the private `avatars` bucket exists, file type/size is accepted, and the object path starts with the authenticated user's UUID folder. Check Storage RLS policies rather than making the bucket public. |
| Missing environment variables | Confirm `.env.local` is in the folder containing `package.json`, contains both required `VITE_` names, and Vite was restarted. Do not send the file to anyone. |
| Vite build failure | Check Node version with `node --version`, run `npm install`, review the first build error, and ensure the project was opened at the folder containing `package.json`. |
| Invitation feature unavailable | Deploy `invite-user`, set `ALLOWED_ORIGINS` to the exact app origins, ensure the function runtime has required Supabase environment variables, and check Edge Function logs. Keep its service-role key server-side. |

## Part 11 — Fresh project versus existing project

The SQL sequence is intended only for a **new, empty Supabase project**. The first script is not a migration for a populated database. It creates tables and inserts seed data. Running seed/setup SQL against existing records can cause conflicts or duplicate business data. The original HopeDB dump is even more dangerous because it begins with `DROP TABLE ... CASCADE`; it is intentionally not part of this setup sequence.

For future changes, inspect the new migration and its prerequisites, make a backup, and apply it once to the correct project in the intended order. Do not rerun the initial setup script. Keep the matching migration file in `supabase/migrations/` and record whether it was applied. Do not assume that a local migration file is deployed just because it is present in this folder.

## Part 12 — Database reference

| Table | Purpose and key relationships |
|---|---|
| `customer` | Customer master; primary key `custno`; referenced by `sales.custno`. |
| `product` | Product master; primary key `prodcode`; referenced by `salesdetail.prodcode` and `pricehist.prodcode`. |
| `pricehist` | Effective-dated product unit prices; composite primary key `(effdate, prodcode)`; product FK. |
| `employee` | Employee master; primary key `empno`; referenced by `sales.empno` and `jobhistory.empno`. |
| `department` | Department master; primary key `deptcode`; referenced by `jobhistory.deptcode`. |
| `job` | Job master; primary key `jobcode`; referenced by `jobhistory.jobcode`. |
| `jobhistory` | Effective-dated employee job, department, and salary history; composite primary key `(empno, jobcode, effdate)`; FKs to employee, job, and department. |
| `sales` | Sales transaction header; primary key `transno`; FKs to customer and employee. |
| `salesdetail` | Product/quantity lines on a sale; composite primary key `(transno, prodcode)`; FKs to sales and product. |
| `payment` | Receipt/date/amount linked optionally to a sale; primary key `orno`; FK `transno → sales.transno`. |
| `audit_log` | Append-only audit history of business-table additions, edits, soft deletions, and restores. |
| `profiles` | Spotibai account profile linked by `profiles.id → auth.users.id`; stores profile metadata, role, status, and permissions. |

The first ten business tables receive `is_deleted` and `stamp` in initial setup. The UI uses soft delete and restore; active views expose non-deleted rows. Database triggers prevent hard deleting/truncating business records and reject soft deletion of parents that still have active children. Audit triggers write history for changes; audit rows are protected from update/delete/truncate.

The role model is `superadmin`, `admin`, and `user`. Public signup provisions `user` + `pending`. Database functions and restrictive RLS policies enforce active status and granular permissions; frontend visibility is supplementary, not the security boundary. A Super Admin is bootstrapped by the trusted project owner only. Admins manage User accounts only; system-wide role changes require the protected management function and an authorized Super Admin.

## Part 13 — Final handoff checklist

- [ ] Existing application source and assets are included under `Website/`.
- [ ] Vite, package manifest, and lockfile are included at the ZIP root.
- [ ] All required setup SQL is embedded in this plan and retained under `supabase/`.
- [ ] SQL execution order and prerequisites are documented.
- [ ] `.env.example` is included with empty values.
- [ ] `.env.local` and all private credentials are excluded.
- [ ] No `node_modules`, generated `dist`, temporary files, or logs are included.
- [ ] No unnecessary Git internals or unrelated experimental files are included.
- [ ] `README.md`, `plan.md`, and the database audit report are included.
- [ ] Edge Function source is included; deployment remains an optional manual step.
- [ ] Production build passes from the consolidated `Website` folder.
- [ ] Fresh Supabase installation is tested separately before claiming it works.

### Verification status for this handoff

The source files were copied into the existing top-level `Website` folder without deleting originals. The project build and SQL installation were not yet tested from a clean extracted ZIP or a new Supabase project. Follow the validation and report any unverified results honestly.
