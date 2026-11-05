# Spotibai Database Audit

## Live Supabase Verification

**Audit timestamp:** 2026-11-04 19:41:05 +08:00
**Mode:** Read-only
**Overall live verification status:** NOT TESTED

### Access and evidence boundary

| Evidence source | Result |
|---|---|
| Shared browser pages | Both were on `http://127.0.0.1:5173/Login/Login.html`. Neither displayed an authenticated dashboard session. |
| Browser auth storage | Checked both shared pages for the Supabase auth-storage key without reading or printing its value. No auth session key was present. |
| Supabase CLI | Unavailable in this environment. |
| Supabase CLI project link | No `supabase/config.toml` was present. |
| Project environment | `.env.local` exists. Its contents were not read or displayed. Presence of frontend configuration does not establish a database-authenticated session or provide SQL access. |
| Live database SQL executed | None. No Supabase SQL Editor/Database MCP connection or authenticated database session was available. |

No live schema, row, policy, permission-function, or migration-history query was executed. Therefore, no live database result is claimed below. Query templates later in this section are read-only follow-up queries and **were not executed**.

### Results

| Check | Status | Result |
|---|---|---|
| Existence and full schema of the 10 business tables and `audit_log` | NOT TESTED | Live table/column metadata could not be queried. |
| Types, lengths, precision, nullability, defaults, PKs, FKs, checks, unique constraints, indexes | NOT TESTED | No deployed catalog output was available for comparison. |
| Spotibai `profiles`, `is_deleted`, `stamp`, views, and audit additions | NOT TESTED | Local migration/source definitions are not evidence of deployment. |
| Total, active, and soft-deleted live row counts | NOT TESTED | No count query was run. Counts reported in earlier conversation are user-provided, not independently verified in this pass. |
| Seed primary-key coverage and per-field values | NOT TESTED | No live row exports were available. |
| Duplicate keys and orphaned FK references | NOT TESTED | No live data queries were run. |
| Deployed RLS policies and function definitions | NOT TESTED | Local migration SQL was inspected, but deployment state is unknown. |
| Super Admin, Admin, and User authorization behavior | NOT TESTED | No authenticated role-specific sessions were available. |
| Destructive or mutating database operations | PASS | None were performed. |

### Local source evidence (not live evidence)

- `Experimental/Hope ERP/HopeDB_audit.sql.txt` defines ten business tables: `employee`, `department`, `job`, `jobhistory`, `customer`, `sales`, `salesdetail`, `product`, `payment`, and `pricehist`, plus `audit_log`.
- Parsing the source SQL's INSERT statements produced these seed counts: employee 32, department 8, job 14, jobhistory 54, customer 82, sales 124, salesdetail 313, product 57, payment 165, and pricehist 79. These are source-file counts, not current live counts.
- Earlier in the conversation, the user reported counts equal to those seed counts for those ten tables and zero `audit_log` rows. This audit did not independently verify them or compare record values.
- The source SQL adds `is_deleted` and `stamp` to its ten business tables, creates active-row views and audit/soft-delete triggers, blocks hard deletes/truncates, and protects `audit_log` from mutation.
- `supabase/migrations/20261103235500_auth_profiles_rls.sql` locally defines `profiles`, business-table RLS, `has_permission`, admin helpers, a `manage_profile` RPC, and an audit-log read policy. Its SQL is only local source evidence.
- `supabase/migrations/20261104002000_payment_report_permission.sql` locally adds `reports.payment` to `valid_spotibai_permissions(jsonb)`. Whether this migration is deployed is unknown.
- The frontend mapping in `Website/Website/Dashboard/Dashboard.html` uses the HopeDB table/column names, the Supabase client, range paging, shared in-memory stores, and `is_deleted` updates for soft delete/restore. Frontend behavior does not prove live RLS, schema, persistence, or role behavior.
- Potential frontend limitation: `salesdetail.quantity` is `DECIMAL(10,2)` in the source, while the UI parses it as an integer and requires a value of at least 1. This was observed in source only and was not changed.
- Sales totals and reports derive unit price from the latest `pricehist` record effective on or before `salesDate`; the source schema does not record a sale-time unit price. Whether this matches the business rule remains unverified.

### SQL queries

**Queries actually used against Supabase:** none. No SQL was executed because authenticated SQL access was unavailable.

The following read-only query templates are provided for a later Supabase SQL Editor run. They are **not executed results**. Run under a role authorized to read the relevant catalogs and rows. They do not modify database state.

#### 1. Tables and column definitions

```sql
SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  character_maximum_length,
  numeric_precision,
  numeric_scale,
  datetime_precision,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = ANY (ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log', 'profiles'
  ])
ORDER BY table_name, ordinal_position;
```

#### 2. Constraints and indexes

```sql
SELECT
  ns.nspname AS schema_name,
  cls.relname AS table_name,
  con.conname AS constraint_name,
  CASE con.contype
    WHEN 'p' THEN 'PRIMARY KEY'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'c' THEN 'CHECK'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 'x' THEN 'EXCLUSION'
    ELSE con.contype::text
  END AS constraint_type,
  pg_get_constraintdef(con.oid, true) AS definition,
  con.convalidated AS is_validated
FROM pg_constraint AS con
JOIN pg_class AS cls ON cls.oid = con.conrelid
JOIN pg_namespace AS ns ON ns.oid = cls.relnamespace
WHERE ns.nspname = 'public'
  AND cls.relname = ANY (ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log', 'profiles'
  ])
ORDER BY cls.relname, con.contype, con.conname;
```

```sql
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = ANY (ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log', 'profiles'
  ])
ORDER BY tablename, indexname;
```

#### 3. Row counts including soft-delete state

```sql
SELECT 'customer' AS table_name, count(*) AS total_rows,
       count(*) FILTER (WHERE is_deleted = false) AS active_rows,
       count(*) FILTER (WHERE is_deleted = true) AS soft_deleted_rows
FROM public.customer
UNION ALL SELECT 'department', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.department
UNION ALL SELECT 'employee', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.employee
UNION ALL SELECT 'job', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.job
UNION ALL SELECT 'jobhistory', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.jobhistory
UNION ALL SELECT 'product', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.product
UNION ALL SELECT 'pricehist', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.pricehist
UNION ALL SELECT 'sales', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.sales
UNION ALL SELECT 'salesdetail', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.salesdetail
UNION ALL SELECT 'payment', count(*), count(*) FILTER (WHERE is_deleted = false), count(*) FILTER (WHERE is_deleted = true) FROM public.payment
UNION ALL SELECT 'audit_log', count(*), NULL::bigint, NULL::bigint FROM public.audit_log
ORDER BY table_name;
```

#### 4. Deployed RLS status and policy definitions

```sql
SELECT
  cls.relname AS table_name,
  cls.relrowsecurity AS rls_enabled,
  cls.relforcerowsecurity AS rls_forced,
  pol.policyname,
  pol.permissive,
  pol.roles,
  pol.cmd,
  pol.qual AS using_expression,
  pol.with_check AS with_check_expression
FROM pg_class AS cls
JOIN pg_namespace AS ns ON ns.oid = cls.relnamespace
LEFT JOIN pg_policies AS pol
  ON pol.schemaname = ns.nspname AND pol.tablename = cls.relname
WHERE ns.nspname = 'public'
  AND cls.relname = ANY (ARRAY[
    'employee', 'department', 'job', 'jobhistory', 'customer', 'sales',
    'salesdetail', 'product', 'payment', 'pricehist', 'audit_log', 'profiles'
  ])
ORDER BY cls.relname, pol.policyname;
```

#### 5. Deployed permission function definitions

```sql
SELECT
  ns.nspname AS schema_name,
  proc.proname AS function_name,
  pg_get_function_identity_arguments(proc.oid) AS arguments,
  pg_get_function_result(proc.oid) AS return_type,
  pg_get_functiondef(proc.oid) AS definition
FROM pg_proc AS proc
JOIN pg_namespace AS ns ON ns.oid = proc.pronamespace
WHERE ns.nspname = 'public'
  AND proc.proname = ANY (ARRAY[
    'has_permission', 'is_system_admin', 'is_superadmin',
    'valid_spotibai_permissions', 'manage_profile',
    'enforce_business_permissions', 'audit_user', 'trg_audit_log',
    'trg_check_children'
  ])
ORDER BY proc.proname, arguments;
```

#### 6. FK orphan checks

```sql
SELECT 'jobhistory.empno -> employee.empno' AS relationship, count(*) AS orphan_rows
FROM public.jobhistory child LEFT JOIN public.employee parent ON parent.empno = child.empno
WHERE child.empno IS NOT NULL AND parent.empno IS NULL
UNION ALL
SELECT 'jobhistory.jobcode -> job.jobcode', count(*)
FROM public.jobhistory child LEFT JOIN public.job parent ON parent.jobcode = child.jobcode
WHERE child.jobcode IS NOT NULL AND parent.jobcode IS NULL
UNION ALL
SELECT 'jobhistory.deptcode -> department.deptcode', count(*)
FROM public.jobhistory child LEFT JOIN public.department parent ON parent.deptcode = child.deptcode
WHERE child.deptcode IS NOT NULL AND parent.deptcode IS NULL
UNION ALL
SELECT 'sales.custno -> customer.custno', count(*)
FROM public.sales child LEFT JOIN public.customer parent ON parent.custno = child.custno
WHERE child.custno IS NOT NULL AND parent.custno IS NULL
UNION ALL
SELECT 'sales.empno -> employee.empno', count(*)
FROM public.sales child LEFT JOIN public.employee parent ON parent.empno = child.empno
WHERE child.empno IS NOT NULL AND parent.empno IS NULL
UNION ALL
SELECT 'salesdetail.transno -> sales.transno', count(*)
FROM public.salesdetail child LEFT JOIN public.sales parent ON parent.transno = child.transno
WHERE child.transno IS NOT NULL AND parent.transno IS NULL
UNION ALL
SELECT 'salesdetail.prodcode -> product.prodcode', count(*)
FROM public.salesdetail child LEFT JOIN public.product parent ON parent.prodcode = child.prodcode
WHERE child.prodcode IS NOT NULL AND parent.prodcode IS NULL
UNION ALL
SELECT 'payment.transno -> sales.transno', count(*)
FROM public.payment child LEFT JOIN public.sales parent ON parent.transno = child.transno
WHERE child.transno IS NOT NULL AND parent.transno IS NULL
UNION ALL
SELECT 'pricehist.prodcode -> product.prodcode', count(*)
FROM public.pricehist child LEFT JOIN public.product parent ON parent.prodcode = child.prodcode
WHERE child.prodcode IS NOT NULL AND parent.prodcode IS NULL;
```

#### 7. Data export for primary-key comparison

Export rows from each business table using the source primary keys. Do not compare only counts; join each result with the original seed records by primary key and inspect each source column. These SELECTs are read-only and were not run here.

```sql
SELECT * FROM public.employee ORDER BY empno;
SELECT * FROM public.department ORDER BY deptcode;
SELECT * FROM public.job ORDER BY jobcode;
SELECT * FROM public.jobhistory ORDER BY empno, jobcode, effdate;
SELECT * FROM public.customer ORDER BY custno;
SELECT * FROM public.sales ORDER BY transno;
SELECT * FROM public.salesdetail ORDER BY transno, prodcode;
SELECT * FROM public.product ORDER BY prodcode;
SELECT * FROM public.payment ORDER BY orno;
SELECT * FROM public.pricehist ORDER BY effdate, prodcode;
```

### Follow-up needed to complete live verification

Run the SELECT query templates in the Supabase SQL Editor using an authorized account, then provide the results with secrets and personal authentication data removed. For role checks, use existing authenticated sessions only; if a role has no existing session, leave its behavior NOT TESTED. Do not run the original HopeDB SQL file or any migration as part of this audit.
