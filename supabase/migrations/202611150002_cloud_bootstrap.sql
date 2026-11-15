-- Atomic one-time cloud bootstrap. The advisory lock and business/profile inserts
-- execute in one database transaction, avoiding a race between concurrent requests.
create or replace function public.bootstrap_initial_business(
  p_auth_user_id uuid,
  p_business_name text,
  p_owner_name text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_business_id uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_auth_user_id is null or length(trim(coalesce(p_business_name,''))) = 0
     or length(trim(coalesce(p_owner_name,''))) = 0 then
    raise exception 'Business and owner details are required';
  end if;
  perform pg_advisory_xact_lock(hashtext('jemba_initial_business_bootstrap'));
  if exists (select 1 from public.businesses) then
    raise exception 'Initial business has already been created';
  end if;
  insert into public.businesses(name, legal_name, currency)
    values (trim(p_business_name), trim(p_business_name), 'NGN')
    returning id into new_business_id;
  insert into public.profiles(id, business_id, full_name, role, is_active)
    values (p_auth_user_id, new_business_id, trim(p_owner_name), 'owner_admin', true);
  return new_business_id;
end;
$$;
revoke all on function public.bootstrap_initial_business(uuid,text,text) from public, anon, authenticated;
grant execute on function public.bootstrap_initial_business(uuid,text,text) to service_role;
