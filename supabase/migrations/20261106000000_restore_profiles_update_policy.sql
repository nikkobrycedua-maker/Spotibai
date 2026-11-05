ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS spotibai_profiles_update_access ON public.profiles;
CREATE POLICY spotibai_profiles_update_access ON public.profiles
  AS PERMISSIVE
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);
