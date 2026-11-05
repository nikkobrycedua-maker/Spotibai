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
