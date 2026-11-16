-- Jemba Business Manager Phase 2.1: accounting foundation.
-- Additive migration. Does not rewrite historical transactions or change live posting RPCs.
-- Apply only after reviewing on a staging Supabase project and taking a production backup.

begin;

-- 1. Accounting periods. Fiscal year dates are configured explicitly by the owner/accountant.
create table if not exists public.accounting_periods (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'open' check (status in ('open','closed')),
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint accounting_period_dates_valid check (end_date >= start_date),
  constraint accounting_period_close_consistent check (
    (status = 'open' and closed_at is null) or
    (status = 'closed' and closed_at is not null)
  ),
  unique (business_id, name),
  unique (business_id, start_date, end_date)
);
create index if not exists accounting_periods_business_dates_idx
  on public.accounting_periods (business_id, start_date, end_date);

-- 2. Extend journal metadata without changing existing posted entries.
alter table public.journal_entries
  add column if not exists accounting_period_id uuid references public.accounting_periods(id) on delete restrict,
  add column if not exists posted_at timestamptz,
  add column if not exists reversed_by_entry_id uuid references public.journal_entries(id) on delete restrict,
  add column if not exists reversal_of_entry_id uuid references public.journal_entries(id) on delete restrict,
  add column if not exists idempotency_key text;

create unique index if not exists journal_entries_business_idempotency_uidx
  on public.journal_entries (business_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists journal_entries_business_date_status_idx
  on public.journal_entries (business_id, entry_date, status);

-- Preserve historical journal entries without modifying posted records.
-- Historical posted_at remains NULL. Future posting workflows must populate it.

-- 3. Inventory valuation foundation for perpetual moving weighted-average costing.
-- Legacy snapshots are explicitly marked unverified and MUST be reconciled before Stage 2
-- activates this state as the authoritative cost source.
create table if not exists public.inventory_cost_balances (
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity_on_hand numeric(18,3) not null default 0 check (quantity_on_hand >= 0),
  inventory_value numeric(20,4) not null default 0 check (inventory_value >= 0),
  average_unit_cost numeric(20,6) not null default 0 check (average_unit_cost >= 0),
  valuation_status text not null default 'unverified'
    check (valuation_status in ('unverified','reconciled','active')),
  last_movement_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (business_id, product_id)
);

create table if not exists public.inventory_valuation_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  stock_movement_id uuid references public.stock_movements(id) on delete restrict,
  event_type text not null check (event_type in
    ('legacy_snapshot','receipt','issue','customer_return','supplier_return','adjustment_in','adjustment_out','landed_cost')),
  quantity_delta numeric(18,3) not null,
  unit_cost numeric(20,6) not null check (unit_cost >= 0),
  value_delta numeric(20,4) not null,
  quantity_after numeric(18,3) not null check (quantity_after >= 0),
  value_after numeric(20,4) not null check (value_after >= 0),
  average_cost_after numeric(20,6) not null check (average_cost_after >= 0),
  source_type text,
  source_id uuid,
  idempotency_key text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (business_id, idempotency_key)
);
create index if not exists inventory_valuation_events_product_date_idx
  on public.inventory_valuation_events (business_id, product_id, created_at, id);

-- Snapshot existing stock for reconciliation only. No journal is posted and no historical
-- stock movement is rewritten. The status prevents this snapshot being mistaken for verified WAC.
insert into public.inventory_cost_balances
  (business_id, product_id, quantity_on_hand, inventory_value, average_unit_cost,
   valuation_status, last_movement_at)
select p.business_id, p.id, p.quantity_on_hand,
       round(p.quantity_on_hand * p.cost_price, 4),
       case when p.quantity_on_hand > 0 then p.cost_price else 0 end,
       'unverified', now()
from public.products p
on conflict (business_id, product_id) do nothing;

insert into public.inventory_valuation_events
  (business_id, product_id, event_type, quantity_delta, unit_cost, value_delta,
   quantity_after, value_after, average_cost_after, source_type, notes, created_at)
select p.business_id, p.id, 'legacy_snapshot', p.quantity_on_hand, p.cost_price,
       round(p.quantity_on_hand * p.cost_price, 4), p.quantity_on_hand,
       round(p.quantity_on_hand * p.cost_price, 4),
       case when p.quantity_on_hand > 0 then p.cost_price else 0 end,
       'migration_snapshot',
       'Unverified opening snapshot from products.quantity_on_hand and products.cost_price. Reconcile before activating WAC.',
       now()
from public.products p
where not exists (
  select 1 from public.inventory_valuation_events e
  where e.business_id = p.business_id and e.product_id = p.id
    and e.event_type = 'legacy_snapshot'
);

-- 4. Correct reports: filter posted journals before aggregation. This fixes the original
-- LEFT JOIN issue where unposted journal lines could still enter SUM aggregates.
create or replace view public.v_trial_balance
with (security_invoker = true) as
select
  a.business_id,
  a.code,
  a.name,
  a.account_type,
  coalesce(sum(l.debit), 0)::numeric(18,2) as total_debit,
  coalesce(sum(l.credit), 0)::numeric(18,2) as total_credit,
  (coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0))::numeric(18,2) as net_balance
from public.accounts a
left join (
  select jl.account_id, jl.debit, jl.credit
  from public.journal_lines jl
  inner join public.journal_entries je on je.id = jl.journal_entry_id
  where je.status = 'posted'
) l on l.account_id = a.id
where a.business_id = public.current_business_id()
group by a.business_id, a.code, a.name, a.account_type;
grant select on public.v_trial_balance to authenticated;

create or replace view public.v_income_statement
with (security_invoker = true) as
select
  a.business_id,
  a.code,
  a.name,
  a.account_type,
  coalesce(sum(l.credit - l.debit), 0)::numeric(18,2) as period_amount
from public.accounts a
left join (
  select jl.account_id, jl.debit, jl.credit
  from public.journal_lines jl
  inner join public.journal_entries je on je.id = jl.journal_entry_id
  where je.status = 'posted'
) l on l.account_id = a.id
where a.business_id = public.current_business_id()
  and a.account_type in ('income','expense','cost_of_sales')
group by a.business_id, a.code, a.name, a.account_type;
grant select on public.v_income_statement to authenticated;

-- 5. Tenant-scoped read policies. Writes to these new foundation tables are reserved for
-- controlled service/RPC paths in subsequent releases.
alter table public.accounting_periods enable row level security;
alter table public.inventory_cost_balances enable row level security;
alter table public.inventory_valuation_events enable row level security;

drop policy if exists accounting_periods_select_tenant on public.accounting_periods;
create policy accounting_periods_select_tenant
  on public.accounting_periods for select to authenticated
  using (business_id = public.current_business_id());

drop policy if exists inventory_cost_balances_select_tenant on public.inventory_cost_balances;
create policy inventory_cost_balances_select_tenant
  on public.inventory_cost_balances for select to authenticated
  using (business_id = public.current_business_id());

drop policy if exists inventory_valuation_events_select_tenant on public.inventory_valuation_events;
create policy inventory_valuation_events_select_tenant
  on public.inventory_valuation_events for select to authenticated
  using (business_id = public.current_business_id());

revoke all on public.accounting_periods from anon;
revoke all on public.inventory_cost_balances from anon;
revoke all on public.inventory_valuation_events from anon;
grant select on public.accounting_periods to authenticated;
grant select on public.inventory_cost_balances to authenticated;
grant select on public.inventory_valuation_events to authenticated;

commit;
