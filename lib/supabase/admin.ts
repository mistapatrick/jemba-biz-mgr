import { createClient as createSupabaseClient } from '@supabase/supabase-js';
/** Server-only. Never import this module into a Client Component. */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Missing Supabase URL or service role key');
  return createSupabaseClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
}
