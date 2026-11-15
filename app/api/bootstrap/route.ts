import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** One-time cloud bootstrap endpoint. Remove JEMBA_BOOTSTRAP_SECRET from Vercel
 * immediately after owner provisioning. The service-role key remains server-only. */
export async function POST(request: NextRequest) {
  const configuredSecret = process.env.JEMBA_BOOTSTRAP_SECRET;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!configuredSecret || !serviceKey || !supabaseUrl) {
    return NextResponse.json({ error: 'Bootstrap is not configured.' }, { status: 503 });
  }
  const suppliedSecret = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') || '';
  if (suppliedSecret.length !== configuredSecret.length || suppliedSecret !== configuredSecret) {
    return NextResponse.json({ error: 'Unauthorised.' }, { status: 401 });
  }
  const body = await request.json().catch(() => null) as null | {
    businessName?: string; ownerName?: string; email?: string; password?: string;
  };
  const businessName = body?.businessName?.trim();
  const ownerName = body?.ownerName?.trim();
  const email = body?.email?.trim().toLowerCase();
  const password = body?.password;
  if (!businessName || !ownerName || !email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !password || password.length < 14) {
    return NextResponse.json({ error: 'Provide valid businessName, ownerName, email and a password of at least 14 characters.' }, { status: 400 });
  }
  const admin = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: authData, error: authError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { role: 'owner_admin', full_name: ownerName }
  });
  if (authError) {
    return NextResponse.json({ error: 'Owner account creation failed.', detail: authError.message }, { status: 409 });
  }
  const { data: businessId, error: bootstrapError } = await admin.rpc('bootstrap_initial_business', {
    p_auth_user_id: authData.user.id,
    p_business_name: businessName,
    p_owner_name: ownerName
  });
  if (bootstrapError || !businessId) {
    await admin.auth.admin.deleteUser(authData.user.id);
    return NextResponse.json({ error: 'Initial business provisioning failed.', detail: bootstrapError?.message || 'No business ID returned.' }, { status: 409 });
  }
  return NextResponse.json({
    success: true,
    businessId,
    ownerUserId: authData.user.id,
    message: 'Owner account created. Remove JEMBA_BOOTSTRAP_SECRET from Vercel now.'
  }, { status: 201 });
}
