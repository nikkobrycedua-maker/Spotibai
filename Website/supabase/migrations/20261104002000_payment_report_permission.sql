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
