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
