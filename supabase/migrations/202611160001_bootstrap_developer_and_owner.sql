-- Provision the developer Super Admin and business Owner Admin in one transaction.
-- Called only by the server-side bootstrap endpoint using the Supabase service-role key.
create or replace function public.bootstrap_initial_business(
  p_developer_user_id uuid,
  p_developer_name text,
  p_owner_user_id uuid,
  p_owner_name text,
  p_business_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  new_business_id uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_developer_user_id is null or p_owner_user_id is null or p_developer_user_id = p_owner_user_id
     or length(trim(coalesce(p_developer_name,''))) = 0
     or length(trim(coalesce(p_owner_name,''))) = 0
     or length(trim(coalesce(p_business_name,''))) = 0 then
    raise exception 'Distinct developer and owner identities and business details are required';
  end if;

  perform pg_advisory_xact_lock(hashtext('jemba_initial_business_bootstrap'));
  if exists (select 1 from public.businesses) then
    raise exception 'Initial business has already been created';
  end if;

  insert into public.businesses(name, legal_name, currency)
    values (trim(p_business_name), trim(p_business_name), 'NGN')
    returning id into new_business_id;

  insert into public.profiles(id, business_id, full_name, role, is_active)
    values
      (p_developer_user_id, new_business_id, trim(p_developer_name), 'super_admin', true),
      (p_owner_user_id, new_business_id, trim(p_owner_name), 'owner_admin', true);

  return jsonb_build_object('business_id', new_business_id);
end;
$$;

revoke all on function public.bootstrap_initial_business(uuid,text,uuid,text,text) from public, anon, authenticated;
grant execute on function public.bootstrap_initial_business(uuid,text,uuid,text,text) to service_role;
