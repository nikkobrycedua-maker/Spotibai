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
