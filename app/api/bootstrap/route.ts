import { timingSafeEqual } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function secretMatches(supplied: string, configured: string): boolean {
  const a = Buffer.from(supplied, 'utf8');
  const b = Buffer.from(configured, 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

/** One-time provisioning of the platform developer and the business owner.
 * Keep the service-role key server-side. Remove JEMBA_BOOTSTRAP_SECRET after success. */
export async function POST(request: NextRequest) {
  const configuredSecret = process.env.JEMBA_BOOTSTRAP_SECRET;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;

  if (!configuredSecret || !serviceKey || !supabaseUrl) {
    return NextResponse.json({ error: 'Bootstrap is not configured. Check the Vercel server environment variables.' }, { status: 503 });
  }

  const suppliedSecret = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  if (!secretMatches(suppliedSecret, configuredSecret)) {
    return NextResponse.json({ error: 'Unauthorised.' }, { status: 401 });
  }

  const body = await request.json().catch(() => null) as null | {
    businessName?: string;
    developerName?: string;
    developerEmail?: string;
    developerPassword?: string;
    ownerName?: string;
    ownerEmail?: string;
    ownerPassword?: string;
  };

  const businessName = body?.businessName?.trim();
  const developerName = body?.developerName?.trim();
  const developerEmail = body?.developerEmail?.trim().toLowerCase();
  const developerPassword = body?.developerPassword;
  const ownerName = body?.ownerName?.trim();
  const ownerEmail = body?.ownerEmail?.trim().toLowerCase();
  const ownerPassword = body?.ownerPassword;
  const validEmail = (value?: string) => !!value && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

  if (!businessName || !developerName || !validEmail(developerEmail) || !developerPassword || developerPassword.length < 14 ||
      !ownerName || !validEmail(ownerEmail) || !ownerPassword || ownerPassword.length < 14 ||
      developerEmail === ownerEmail) {
    return NextResponse.json({
      error: 'Provide a business name, separate developer and owner names/emails, and passwords of at least 14 characters. Developer and owner emails must be different.'
    }, { status: 400 });
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const createdUserIds: string[] = [];

  try {
    const { data: developerData, error: developerError } = await admin.auth.admin.createUser({
      email: developerEmail!, password: developerPassword!, email_confirm: true,
      user_metadata: { role: 'super_admin', full_name: developerName }
    });
    if (developerError || !developerData.user) {
      return NextResponse.json({ error: 'Developer account creation failed.', detail: developerError?.message ?? 'No developer user returned.' }, { status: 409 });
    }
    createdUserIds.push(developerData.user.id);

    const { data: ownerData, error: ownerError } = await admin.auth.admin.createUser({
      email: ownerEmail!, password: ownerPassword!, email_confirm: true,
      user_metadata: { role: 'owner_admin', full_name: ownerName }
    });
    if (ownerError || !ownerData.user) {
      await admin.auth.admin.deleteUser(developerData.user.id);
      return NextResponse.json({ error: 'Business owner account creation failed.', detail: ownerError?.message ?? 'No owner user returned.' }, { status: 409 });
    }
    createdUserIds.push(ownerData.user.id);

    const { data: result, error: bootstrapError } = await admin.rpc('bootstrap_initial_business', {
      p_developer_user_id: developerData.user.id,
      p_developer_name: developerName,
      p_owner_user_id: ownerData.user.id,
      p_owner_name: ownerName,
      p_business_name: businessName
    });

    if (bootstrapError || !result?.business_id) {
      for (const id of createdUserIds) await admin.auth.admin.deleteUser(id);
      return NextResponse.json({ error: 'Initial business provisioning failed. Both temporary Auth users were removed.', detail: bootstrapError?.message ?? 'No business ID returned.' }, { status: 409 });
    }

    return NextResponse.json({
      success: true,
      businessId: result.business_id,
      developerUserId: developerData.user.id,
      ownerUserId: ownerData.user.id,
      developerRole: 'super_admin',
      ownerRole: 'owner_admin',
      message: 'Developer Super Admin and business Owner Admin accounts created. Remove JEMBA_BOOTSTRAP_SECRET from Vercel immediately.'
    }, { status: 201 });
  } catch (error) {
    for (const id of createdUserIds) await admin.auth.admin.deleteUser(id);
    return NextResponse.json({ error: 'Unexpected bootstrap failure. Temporary Auth users were cleaned up where possible.', detail: error instanceof Error ? error.message : 'Unknown error.' }, { status: 500 });
  }
}
