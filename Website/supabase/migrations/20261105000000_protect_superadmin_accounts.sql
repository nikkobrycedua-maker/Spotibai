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
