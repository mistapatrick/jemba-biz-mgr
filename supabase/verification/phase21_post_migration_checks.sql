-- Run in Supabase SQL Editor after applying Release 2.1 to STAGING.
-- These checks are read-only and return diagnostic result sets.

-- 1. Confirm the new tables exist.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('accounting_periods','inventory_cost_balances','inventory_valuation_events')
order by table_name;

-- 2. Confirm all existing products have an unverified valuation snapshot.
select
  (select count(*) from public.products) as products_count,
  (select count(*) from public.inventory_cost_balances) as valuation_balance_count,
  (select count(*) from public.inventory_cost_balances where valuation_status = 'unverified') as unverified_count;

-- 3. Confirm no legacy snapshot was used to create a journal entry.
select count(*) as legacy_snapshot_events
from public.inventory_valuation_events
where event_type = 'legacy_snapshot';

-- 4. Confirm posted journals balance by entry. Expected: zero rows.
select je.id, je.entry_number,
       round(coalesce(sum(jl.debit),0),2) as total_debit,
       round(coalesce(sum(jl.credit),0),2) as total_credit
from public.journal_entries je
left join public.journal_lines jl on jl.journal_entry_id = je.id
where je.status = 'posted'
group by je.id, je.entry_number
having round(coalesce(sum(jl.debit),0),2) <> round(coalesce(sum(jl.credit),0),2);

-- 5. Check current global ledger totals. This is an administrator diagnostic only;
-- compare to the signed-in tenant's v_trial_balance when testing under an authenticated user.
select round(sum(jl.debit),2) as posted_debits,
       round(sum(jl.credit),2) as posted_credits
from public.journal_lines jl
join public.journal_entries je on je.id = jl.journal_entry_id
where je.status = 'posted';

-- 6. Confirm report views exist.
select table_name
from information_schema.views
where table_schema = 'public'
  and table_name in ('v_trial_balance','v_income_statement')
order by table_name;

-- 7. Review new table grants. Authenticated should have SELECT only; no direct writes.
select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('accounting_periods','inventory_cost_balances','inventory_valuation_events')
  and grantee in ('anon','authenticated')
order by table_name, grantee, privilege_type;
