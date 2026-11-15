-- Jemba Business Manager: PostgreSQL schema for Supabase.
-- Run with: supabase db push  |  Designed for a single legal entity per business workspace.
create extension if not exists pgcrypto;

create table if not exists public.businesses (
 id uuid primary key default gen_random_uuid(), name text not null, legal_name text, registration_number text,
 tax_id text, email text, phone text, address text, currency char(3) not null default 'NGN',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 business_id uuid not null references public.businesses(id) on delete restrict,
 full_name text, role text not null check(role in ('super_admin','owner_admin','customer_relationship_officer','cashier','storekeeper','supply_chain_manager')),
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists profiles_business_idx on public.profiles(business_id);

create table if not exists public.accounts (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 code text not null, name text not null, account_type text not null check(account_type in ('asset','liability','equity','income','expense','cost_of_sales')),
 is_control boolean not null default false, is_active boolean not null default true, created_at timestamptz not null default now(),
 unique(business_id,code), unique(business_id,name)
);
create table if not exists public.customers (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 name text not null, email text, phone text, address text, tax_id text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 name text not null, email text, phone text, address text, tax_id text, contact_person text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 name text not null, sku text not null, description text, product_type text not null default 'resale' check(product_type in ('resale','manufactured','service','consumable')),
 unit text not null default 'unit', selling_price numeric(18,2) not null default 0 check(selling_price>=0), cost_price numeric(18,2) not null default 0 check(cost_price>=0),
 quantity_on_hand numeric(18,3) not null default 0 check(quantity_on_hand>=0), reorder_level numeric(18,3) not null default 0 check(reorder_level>=0),
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(business_id,sku)
);
create table if not exists public.stock_movements (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete restrict, movement_type text not null check(movement_type in ('opening','purchase','sale','sale_return','adjustment','production_in','production_out','transfer')),
 quantity_change numeric(18,3) not null, unit_cost numeric(18,2) not null default 0, reference_type text, reference_id uuid, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists stock_movements_product_idx on public.stock_movements(product_id,created_at desc);
create table if not exists public.sales (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 customer_id uuid references public.customers(id) on delete set null, invoice_number text not null, total_amount numeric(18,2) not null check(total_amount>=0),
 status text not null default 'posted' check(status in ('draft','posted','void','part_paid','paid')), payment_method text,
 created_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(business_id,invoice_number)
);
create table if not exists public.sale_items (
 id uuid primary key default gen_random_uuid(), sale_id uuid not null references public.sales(id) on delete restrict,
 product_id uuid not null references public.products(id) on delete restrict, description text not null, quantity numeric(18,3) not null check(quantity>0),
 unit_price numeric(18,2) not null check(unit_price>=0), unit_cost numeric(18,2) not null default 0, line_total numeric(18,2) not null check(line_total>=0)
);
create table if not exists public.invoices (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 sale_id uuid references public.sales(id) on delete restrict, customer_id uuid references public.customers(id) on delete set null,
 invoice_number text not null, issue_date date not null default current_date, due_date date, subtotal numeric(18,2) not null default 0,
 tax_amount numeric(18,2) not null default 0, total_amount numeric(18,2) not null, amount_paid numeric(18,2) not null default 0,
 balance_due numeric(18,2) generated always as (total_amount-amount_paid) stored, status text not null default 'issued' check(status in ('draft','issued','part_paid','paid','void')),
 created_at timestamptz not null default now(), unique(business_id,invoice_number), check(amount_paid>=0 and amount_paid<=total_amount)
);
create table if not exists public.receipts (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 invoice_id uuid not null references public.invoices(id) on delete restrict, receipt_number text not null, amount numeric(18,2) not null check(amount>0),
 payment_method text not null, payment_reference text, received_at timestamptz not null default now(), received_by uuid references auth.users(id), unique(business_id,receipt_number)
);
create table if not exists public.expenses (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 description text not null, category text not null default 'General', amount numeric(18,2) not null check(amount>0), expense_date date not null default current_date,
 payment_method text not null default 'cash', created_by uuid references auth.users(id), journal_entry_id uuid, created_at timestamptz not null default now()
);
create table if not exists public.quotations (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 customer_id uuid references public.customers(id) on delete set null, quotation_number text not null, issue_date date not null default current_date,
 valid_until date, subtotal numeric(18,2) not null default 0, tax_amount numeric(18,2) not null default 0, total_amount numeric(18,2) not null default 0,
 status text not null default 'draft' check(status in ('draft','sent','accepted','rejected','expired','converted')), notes text,
 converted_invoice_id uuid references public.invoices(id), created_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(business_id,quotation_number)
);
create table if not exists public.quotation_items (
 id uuid primary key default gen_random_uuid(), quotation_id uuid not null references public.quotations(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null, description text not null, quantity numeric(18,3) not null check(quantity>0),
 unit_price numeric(18,2) not null check(unit_price>=0), line_total numeric(18,2) not null
);
create table if not exists public.journal_entries (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 entry_number text not null, entry_date date not null default current_date, description text not null, source_type text, source_id uuid,
 status text not null default 'posted' check(status in ('draft','posted','reversed')), created_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(business_id,entry_number)
);
create table if not exists public.journal_lines (
 id uuid primary key default gen_random_uuid(), journal_entry_id uuid not null references public.journal_entries(id) on delete restrict,
 account_id uuid not null references public.accounts(id) on delete restrict, debit numeric(18,2) not null default 0 check(debit>=0), credit numeric(18,2) not null default 0 check(credit>=0),
 description text, check(not (debit>0 and credit>0)), check(debit+credit>0)
);
create index if not exists journal_lines_account_idx on public.journal_lines(account_id);
create table if not exists public.audit_logs (
 id uuid primary key default gen_random_uuid(), business_id uuid references public.businesses(id) on delete set null,
 actor_id uuid references auth.users(id) on delete set null, action text not null, entity_type text, entity_id uuid,
 details jsonb not null default '{}'::jsonb, ip_address inet, created_at timestamptz not null default now()
);
create table if not exists public.supplies (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 supplier_id uuid references public.suppliers(id) on delete set null, reference_number text not null, description text not null,
 status text not null default 'ordered' check(status in ('ordered','dispatched','in_transit','delivered','cancelled')),
 ordered_at date not null default current_date, expected_delivery date, delivered_at date, tracking_reference text, notes text, created_at timestamptz not null default now(), unique(business_id,reference_number)
);

-- Default chart of accounts is created for every new business.
create or replace function public.seed_chart_of_accounts() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.accounts(business_id,code,name,account_type,is_control) values
 (new.id,'1000','Cash on Hand','asset',true),(new.id,'1010','Bank Account','asset',true),(new.id,'1100','Trade Receivables','asset',true),
 (new.id,'1200','Inventory','asset',true),(new.id,'2000','Trade Payables','liability',true),(new.id,'2100','VAT Payable','liability',true),
 (new.id,'3000','Owner Capital','equity',true),(new.id,'3100','Retained Earnings','equity',true),(new.id,'4000','Product Sales Revenue','income',false),
 (new.id,'5000','Cost of Goods Sold','cost_of_sales',false),(new.id,'6000','General Operating Expenses','expense',false)
 on conflict(business_id,code) do nothing;
 return new;
end $$;
drop trigger if exists trg_seed_chart on public.businesses;
create trigger trg_seed_chart after insert on public.businesses for each row execute function public.seed_chart_of_accounts();

-- Create a profile automatically for invited users when business_id and role metadata are present.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare bid uuid; r text;
begin
 bid := nullif(new.raw_user_meta_data->>'business_id','')::uuid;
 r := coalesce(new.raw_user_meta_data->>'role','cashier');
 if bid is not null and r in ('super_admin','owner_admin','customer_relationship_officer','cashier','storekeeper','supply_chain_manager') then
  insert into public.profiles(id,business_id,full_name,role) values(new.id,bid,new.raw_user_meta_data->>'full_name',r)
  on conflict(id) do update set business_id=excluded.business_id,full_name=excluded.full_name,role=excluded.role;
 end if;
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.current_business_id() returns uuid language sql stable security definer set search_path=public as $$
 select business_id from public.profiles where id=auth.uid() and is_active=true limit 1
$$;
create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$
 select role from public.profiles where id=auth.uid() and is_active=true limit 1
$$;
create or replace function public.has_any_role(roles text[]) returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.current_role()=any(roles),false)
$$;

-- Immutable posted journal entries: application must reverse and repost rather than edit.
create or replace function public.prevent_posted_journal_mutation() returns trigger language plpgsql as $$
begin
 if old.status='posted' then raise exception 'Posted journal entries are immutable. Reverse the entry instead.'; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
drop trigger if exists trg_journal_immutable on public.journal_entries;
create trigger trg_journal_immutable before update or delete on public.journal_entries for each row execute function public.prevent_posted_journal_mutation();

-- Record a sale, reduce inventory and post balanced accounting entries atomically.
create or replace function public.record_sale(p_business_id uuid,p_product_id uuid,p_quantity numeric,p_payment_method text,p_customer_id uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.products%rowtype; sid uuid; iid uuid; jid uuid; invno text; total numeric(18,2); cogs numeric(18,2); cash_account uuid; ar_account uuid; revenue_account uuid; inventory_account uuid; cogs_account uuid; receipt_no text;
begin
 if auth.uid() is null or public.current_business_id()<>p_business_id then raise exception 'Unauthorised business context'; end if;
 if not public.has_any_role(array['owner_admin','cashier','super_admin']) then raise exception 'Insufficient role'; end if;
 if p_quantity<=0 then raise exception 'Quantity must be positive'; end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id and is_active=true for update;
 if not found then raise exception 'Product not found'; end if;
 if p.quantity_on_hand<p_quantity then raise exception 'Insufficient stock. Available: %',p.quantity_on_hand; end if;
 total:=round(p.selling_price*p_quantity,2); cogs:=round(p.cost_price*p_quantity,2);
 if total<=0 then raise exception 'Selling price must be greater than zero for POS sales'; end if;
 invno:='INV-'||to_char(now(),'YYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
 insert into public.sales(business_id,customer_id,invoice_number,total_amount,status,payment_method,created_by)
 values(p_business_id,p_customer_id,invno,total,case when p_payment_method='credit' then 'posted' else 'paid' end,p_payment_method,auth.uid()) returning id into sid;
 insert into public.sale_items(sale_id,product_id,description,quantity,unit_price,unit_cost,line_total) values(sid,p.id,p.name,p_quantity,p.selling_price,p.cost_price,total);
 update public.products set quantity_on_hand=quantity_on_hand-p_quantity,updated_at=now() where id=p.id;
 insert into public.stock_movements(business_id,product_id,movement_type,quantity_change,unit_cost,reference_type,reference_id,created_by)
 values(p_business_id,p.id,'sale',-p_quantity,p.cost_price,'sale',sid,auth.uid());
 insert into public.invoices(business_id,sale_id,customer_id,invoice_number,total_amount,amount_paid,status)
 values(p_business_id,sid,p_customer_id,invno,total,case when p_payment_method='credit' then 0 else total end,case when p_payment_method='credit' then 'issued' else 'paid' end) returning id into iid;
 select id into cash_account from public.accounts where business_id=p_business_id and code=case when p_payment_method='bank_transfer' then '1010' else '1000' end;
 select id into ar_account from public.accounts where business_id=p_business_id and code='1100';
 select id into revenue_account from public.accounts where business_id=p_business_id and code='4000';
 select id into inventory_account from public.accounts where business_id=p_business_id and code='1200';
 select id into cogs_account from public.accounts where business_id=p_business_id and code='5000';
 insert into public.journal_entries(business_id,entry_number,description,source_type,source_id,created_by)
 values(p_business_id,'JE-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),'Sale '||invno,'sale',sid,auth.uid()) returning id into jid;
 if p_payment_method='credit' then
  insert into public.journal_lines(journal_entry_id,account_id,debit,credit) values(jid,ar_account,total,0),(jid,revenue_account,0,total);
 else
  insert into public.journal_lines(journal_entry_id,account_id,debit,credit) values(jid,cash_account,total,0),(jid,revenue_account,0,total);
  receipt_no:='RCT-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into public.receipts(business_id,invoice_id,receipt_number,amount,payment_method,received_by) values(p_business_id,iid,receipt_no,total,p_payment_method,auth.uid());
 end if;
 if cogs>0 then
  insert into public.journal_lines(journal_entry_id,account_id,debit,credit) values(jid,cogs_account,cogs,0),(jid,inventory_account,0,cogs);
 end if;
 insert into public.audit_logs(business_id,actor_id,action,entity_type,entity_id,details) values(p_business_id,auth.uid(),'sale.created','sale',sid,jsonb_build_object('invoice_number',invno,'total',total,'quantity',p_quantity));
 return sid;
end $$;

create or replace function public.record_expense(p_business_id uuid,p_description text,p_amount numeric,p_category text,p_expense_date date,p_payment_method text)
returns uuid language plpgsql security definer set search_path=public as $$
declare eid uuid; jid uuid; debit_account uuid; credit_account uuid;
begin
 if auth.uid() is null or public.current_business_id()<>p_business_id then raise exception 'Unauthorised business context'; end if;
 if not public.has_any_role(array['owner_admin','cashier','super_admin']) then raise exception 'Insufficient role'; end if;
 if p_amount<=0 or length(trim(p_description))=0 then raise exception 'Invalid expense'; end if;
 select id into debit_account from public.accounts where business_id=p_business_id and code='6000';
 select id into credit_account from public.accounts where business_id=p_business_id and code=case when p_payment_method='bank_transfer' then '1010' else '1000' end;
 insert into public.expenses(business_id,description,category,amount,expense_date,payment_method,created_by)
 values(p_business_id,p_description,p_category,p_amount,p_expense_date,p_payment_method,auth.uid()) returning id into eid;
 insert into public.journal_entries(business_id,entry_number,entry_date,description,source_type,source_id,created_by)
 values(p_business_id,'JE-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),p_expense_date,'Expense: '||p_description,'expense',eid,auth.uid()) returning id into jid;
 insert into public.journal_lines(journal_entry_id,account_id,debit,credit) values(jid,debit_account,p_amount,0),(jid,credit_account,0,p_amount);
 update public.expenses set journal_entry_id=jid where id=eid;
 insert into public.audit_logs(business_id,actor_id,action,entity_type,entity_id,details) values(p_business_id,auth.uid(),'expense.created','expense',eid,jsonb_build_object('amount',p_amount,'category',p_category));
 return eid;
end $$;

-- RLS is enabled on every business table. All tenant data is isolated by profile business_id.
do $$ declare t text; begin foreach t in array array['businesses','profiles','accounts','customers','suppliers','products','stock_movements','sales','sale_items','invoices','receipts','expenses','quotations','quotation_items','journal_entries','journal_lines','audit_logs','supplies'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy "business members read own business" on public.businesses for select using(id=public.current_business_id());
create policy "owner updates business" on public.businesses for update using(id=public.current_business_id() and public.has_any_role(array['owner_admin','super_admin'])) with check(id=public.current_business_id());
create policy "members read own profiles" on public.profiles for select using(business_id=public.current_business_id());
create policy "owner manages profiles" on public.profiles for update using(business_id=public.current_business_id() and public.has_any_role(array['owner_admin','super_admin'])) with check(business_id=public.current_business_id());
create policy "members read accounts" on public.accounts for select using(business_id=public.current_business_id());
create policy "owner manages accounts" on public.accounts for all using(business_id=public.current_business_id() and public.has_any_role(array['owner_admin','super_admin'])) with check(business_id=public.current_business_id());

-- Generic tenant policies; role-sensitive writes are additionally enforced in server actions/RPCs.
do $$ declare t text; begin foreach t in array array['customers','suppliers','products','stock_movements','sales','invoices','receipts','expenses','quotations','journal_entries','audit_logs','supplies'] loop
 execute format('create policy %I on public.%I for select using (business_id=public.current_business_id())',t||'_select_tenant',t);
 execute format('create policy %I on public.%I for insert with check (business_id=public.current_business_id())',t||'_insert_tenant',t);
 execute format('create policy %I on public.%I for update using (business_id=public.current_business_id()) with check (business_id=public.current_business_id())',t||'_update_tenant',t);
end loop; end $$;
create policy "sale items tenant read" on public.sale_items for select using(exists(select 1 from public.sales s where s.id=sale_id and s.business_id=public.current_business_id()));
create policy "sale items tenant insert" on public.sale_items for insert with check(exists(select 1 from public.sales s where s.id=sale_id and s.business_id=public.current_business_id()));
create policy "quotation items tenant read" on public.quotation_items for select using(exists(select 1 from public.quotations q where q.id=quotation_id and q.business_id=public.current_business_id()));
create policy "quotation items tenant insert" on public.quotation_items for insert with check(exists(select 1 from public.quotations q where q.id=quotation_id and q.business_id=public.current_business_id()));
create policy "journal lines tenant read" on public.journal_lines for select using(exists(select 1 from public.journal_entries j where j.id=journal_entry_id and j.business_id=public.current_business_id()));
create policy "journal lines tenant insert" on public.journal_lines for insert with check(exists(select 1 from public.journal_entries j where j.id=journal_entry_id and j.business_id=public.current_business_id()));

-- No client-side deletes for financial records. Reversals/void workflows should be implemented explicitly.
revoke delete on public.sales,public.invoices,public.receipts,public.expenses,public.journal_entries,public.journal_lines from anon,authenticated;
grant execute on function public.record_sale(uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.record_expense(uuid,text,numeric,text,date,text) to authenticated;
grant execute on function public.current_business_id() to authenticated;
grant execute on function public.current_role() to authenticated;

-- Restrict direct writes to money/stock tables. Use validated server-side RPCs instead.
revoke insert,update,delete on public.sales,public.sale_items,public.invoices,public.receipts,public.expenses,
 public.stock_movements,public.journal_entries,public.journal_lines,public.audit_logs from anon,authenticated;
revoke update,delete on public.customers,public.suppliers,public.products,public.quotations,public.quotation_items,public.supplies from anon,authenticated;

-- Receive stock: controlled stock-in transaction and inventory journal.
create or replace function public.receive_stock(p_business_id uuid,p_product_id uuid,p_quantity numeric,p_unit_cost numeric,p_reference text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.products%rowtype; mid uuid; jid uuid; inventory_account uuid; payable_account uuid;
begin
 if auth.uid() is null or public.current_business_id()<>p_business_id then raise exception 'Unauthorised business context'; end if;
 if not public.has_any_role(array['owner_admin','storekeeper','supply_chain_manager','super_admin']) then raise exception 'Insufficient role'; end if;
 if p_quantity<=0 or p_unit_cost<0 then raise exception 'Invalid quantity or cost'; end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id and is_active=true for update;
 if not found then raise exception 'Product not found'; end if;
 update public.products set quantity_on_hand=quantity_on_hand+p_quantity,cost_price=p_unit_cost,updated_at=now() where id=p.id;
 insert into public.stock_movements(business_id,product_id,movement_type,quantity_change,unit_cost,reference_type,notes,created_by)
 values(p_business_id,p.id,'purchase',p_quantity,p_unit_cost,'stock_receipt',p_reference,auth.uid()) returning id into mid;
 select id into inventory_account from public.accounts where business_id=p_business_id and code='1200';
 select id into payable_account from public.accounts where business_id=p_business_id and code='2000';
 if round(p_quantity*p_unit_cost,2)>0 then
  insert into public.journal_entries(business_id,entry_number,description,source_type,source_id,created_by)
  values(p_business_id,'JE-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),'Stock received: '||p.name,'stock_receipt',mid,auth.uid()) returning id into jid;
  insert into public.journal_lines(journal_entry_id,account_id,debit,credit) values(jid,inventory_account,round(p_quantity*p_unit_cost,2),0),(jid,payable_account,0,round(p_quantity*p_unit_cost,2));
 end if;
 insert into public.audit_logs(business_id,actor_id,action,entity_type,entity_id,details) values(p_business_id,auth.uid(),'stock.received','stock_movement',mid,jsonb_build_object('product_id',p.id,'quantity',p_quantity,'unit_cost',p_unit_cost));
 return mid;
end $$;
grant execute on function public.receive_stock(uuid,uuid,numeric,numeric,text) to authenticated;

-- Reporting views are tenant-filtered by the caller's current business.
create or replace view public.v_trial_balance with (security_invoker=true) as
 select a.business_id,a.code,a.name,a.account_type,coalesce(sum(l.debit),0)::numeric(18,2) as total_debit,
 coalesce(sum(l.credit),0)::numeric(18,2) as total_credit,
 (coalesce(sum(l.debit),0)-coalesce(sum(l.credit),0))::numeric(18,2) as net_balance
 from public.accounts a left join public.journal_lines l on l.account_id=a.id
 left join public.journal_entries j on j.id=l.journal_entry_id and j.status='posted'
 where a.business_id=public.current_business_id() group by a.business_id,a.code,a.name,a.account_type;
grant select on public.v_trial_balance to authenticated;

create or replace view public.v_income_statement with (security_invoker=true) as
 select a.business_id,a.code,a.name,a.account_type,
 coalesce(sum(l.credit-l.debit),0)::numeric(18,2) as period_amount
 from public.accounts a left join public.journal_lines l on l.account_id=a.id
 left join public.journal_entries j on j.id=l.journal_entry_id and j.status='posted'
 where a.business_id=public.current_business_id() and a.account_type in ('income','expense','cost_of_sales')
 group by a.business_id,a.code,a.name,a.account_type;
grant select on public.v_income_statement to authenticated;

-- Product creation records opening stock as a movement and opening inventory balance.
create or replace function public.create_product(p_business_id uuid,p_name text,p_sku text,p_selling_price numeric,p_cost_price numeric,p_opening_quantity numeric,p_reorder_level numeric,p_unit text default 'unit',p_product_type text default 'resale')
returns uuid language plpgsql security definer set search_path=public as $$
declare pid uuid; jid uuid; inv_account uuid; capital_account uuid;
begin
 if auth.uid() is null or public.current_business_id()<>p_business_id then raise exception 'Unauthorised business context'; end if;
 if not public.has_any_role(array['owner_admin','storekeeper','super_admin']) then raise exception 'Insufficient role'; end if;
 if length(trim(p_name))=0 or length(trim(p_sku))=0 or p_selling_price<0 or p_cost_price<0 or p_opening_quantity<0 or p_reorder_level<0 then raise exception 'Invalid product details'; end if;
 insert into public.products(business_id,name,sku,selling_price,cost_price,quantity_on_hand,reorder_level,unit,product_type)
 values(p_business_id,trim(p_name),trim(p_sku),p_selling_price,p_cost_price,p_opening_quantity,p_reorder_level,coalesce(nullif(trim(p_unit),''),'unit'),coalesce(p_product_type,'resale')) returning id into pid;
 if p_opening_quantity>0 then
  insert into public.stock_movements(business_id,product_id,movement_type,quantity_change,unit_cost,reference_type,notes,created_by)
  values(p_business_id,pid,'opening',p_opening_quantity,p_cost_price,'opening_balance','Opening stock at product creation',auth.uid());
  select id into inv_account from public.accounts where business_id=p_business_id and code='1200';
  select id into capital_account from public.accounts where business_id=p_business_id and code='3000';
  if round(p_opening_quantity*p_cost_price,2)>0 then
   insert into public.journal_entries(business_id,entry_number,description,source_type,source_id,created_by)
   values(p_business_id,'JE-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),'Opening stock: '||trim(p_name),'opening_stock',pid,auth.uid()) returning id into jid;
   insert into public.journal_lines(journal_entry_id,account_id,debit,credit)
   values(jid,inv_account,round(p_opening_quantity*p_cost_price,2),0),(jid,capital_account,0,round(p_opening_quantity*p_cost_price,2));
  end if;
 end if;
 insert into public.audit_logs(business_id,actor_id,action,entity_type,entity_id,details)
 values(p_business_id,auth.uid(),'product.created','product',pid,jsonb_build_object('sku',p_sku,'opening_quantity',p_opening_quantity));
 return pid;
end $$;
grant execute on function public.create_product(uuid,text,text,numeric,numeric,numeric,numeric,text,text) to authenticated;
