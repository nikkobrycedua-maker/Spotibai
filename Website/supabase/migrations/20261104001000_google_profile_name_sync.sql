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
