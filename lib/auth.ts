import { createClient } from '@/lib/supabase/server';
export async function getCurrentProfile() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { supabase, user: null, profile: null };
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
  return { supabase, user, profile };
}
export async function requireRole(roles: string[]) {
  const ctx = await getCurrentProfile();
  if (!ctx.user || !ctx.profile || !roles.includes(ctx.profile.role)) throw new Error('You are not authorised to perform this action.');
  return ctx;
}
