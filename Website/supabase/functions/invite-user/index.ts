import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const headersFor = (origin: string | null) => {
  const allowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') || 'http://127.0.0.1:5173,http://localhost:5173')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);

  if (!origin || !allowedOrigins.includes(origin)) return null;
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin'
  };
};

const jsonResponse = (status: number, body: Record<string, unknown>, headers: Record<string, string>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' }
  });

Deno.serve(async request => {
  const corsHeaders = headersFor(request.headers.get('Origin'));
  if (!corsHeaders) return new Response('Origin is not allowed.', { status: 403 });
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse(405, { error: 'Method not allowed.' }, corsHeaders);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('Authorization');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Invite function server configuration is incomplete.');
    return jsonResponse(500, { error: 'User invitations are unavailable.' }, corsHeaders);
  }
  if (!authorization?.startsWith('Bearer ')) {
    return jsonResponse(401, { error: 'Authentication is required.' }, corsHeaders);
  }

  const authenticatedClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authorization } }
  });
  const { data: authData, error: authError } = await authenticatedClient.auth.getUser();
  if (authError || !authData.user) {
    return jsonResponse(401, { error: 'Your session is invalid or expired.' }, corsHeaders);
  }

  const { data: caller, error: callerError } = await authenticatedClient.from('profiles')
    .select('role,account_status')
    .eq('id', authData.user.id)
    .maybeSingle();
  if (callerError) {
    console.error('Unable to verify invitation caller.', callerError);
    return jsonResponse(500, { error: 'Unable to verify your account.' }, corsHeaders);
  }
  if (!caller || caller.account_status !== 'active' || !['superadmin', 'admin'].includes(caller.role)) {
    return jsonResponse(403, { error: 'Only active administrators may invite users.' }, corsHeaders);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
  let payload: {
    email?: unknown;
    first_name?: unknown;
    last_name?: unknown;
    role?: unknown;
    status?: unknown;
  };
  try {
    const body: unknown = await request.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return jsonResponse(400, { error: 'The request body must be a JSON object.' }, corsHeaders);
    }
    payload = body as typeof payload;
  } catch {
    return jsonResponse(400, { error: 'The request body must be valid JSON.' }, corsHeaders);
  }

  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
  const firstName = typeof payload.first_name === 'string' ? payload.first_name.trim() : '';
  const lastName = typeof payload.last_name === 'string' ? payload.last_name.trim() : '';
  const role = payload.role;
  const status = payload.status;
  if (email.length > 254
      || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
      || !firstName
      || firstName.length > 80
      || lastName.length > 80) {
    return jsonResponse(400, { error: 'Provide a valid email address and names no longer than 80 characters.' }, corsHeaders);
  }
  if (role !== 'user' && role !== 'admin' && role !== 'superadmin') {
    return jsonResponse(400, { error: 'Invalid account role.' }, corsHeaders);
  }
  if (caller.role === 'admin' && role !== 'user') {
    return jsonResponse(403, { error: 'Admins may invite User accounts only.' }, corsHeaders);
  }
  if (!['active', 'pending', 'blocked', 'disapproved'].includes(String(status))) {
    return jsonResponse(400, { error: 'Invalid account status.' }, corsHeaders);
  }

  const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
    data: { first_name: firstName, last_name: lastName }
  });
  if (inviteError || !inviteData.user) {
    console.error('Unable to create user invitation.', inviteError);
    return jsonResponse(400, { error: inviteError?.message || 'Unable to create the invitation.' }, corsHeaders);
  }

  const permissions = role === 'admin' || role === 'superadmin' ? {
    'customers.view': true, 'customers.add': true, 'customers.edit': true, 'customers.delete': true,
    'products.view': true, 'products.add': true, 'products.edit': true, 'products.delete': true,
    'products.priceAdd': true, 'products.priceEdit': true, 'products.priceDelete': true,
    'hr.view': true, 'hr.jobAdd': true, 'hr.jobEdit': true, 'hr.jobDelete': true,
    'hr.deptAdd': true, 'hr.deptEdit': true, 'hr.deptDelete': true,
    'hr.empAdd': true, 'hr.empEdit': true, 'hr.empDelete': true,
    'hr.jhView': true, 'hr.jhAdd': true, 'hr.jhEdit': true, 'hr.jhDelete': true,
    'sales.view': true, 'sales.add': true, 'sales.edit': true, 'sales.delete': true,
    'sales.detailView': true, 'sales.detailAdd': true, 'sales.detailEdit': true, 'sales.detailDelete': true,
    'reports.view': true, 'reports.topCustomers': true, 'reports.productMaster': true,
    'reports.topProducts': true, 'reports.activeEmployees': true, 'reports.allEmployees': true,
    'reports.empJobHistory': true, 'reports.topSales': true
  } : {};

  const { error: profileError } = await authenticatedClient.rpc('manage_profile', {
    target_user_id: inviteData.user.id,
    new_role: role,
    new_status: status,
    new_permissions: permissions,
    new_first_name: firstName,
    new_last_name: lastName
  });
  if (profileError) {
    console.error('Invitation exists but its profile role update failed.', profileError);
    return jsonResponse(500, { error: 'The invitation was sent, but the account profile needs administrator review.' }, corsHeaders);
  }

  return jsonResponse(200, { invited: true }, corsHeaders);
});
