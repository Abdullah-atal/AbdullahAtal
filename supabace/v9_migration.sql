-- AbdullahAtal V9: variants, shipping, returns, seller payouts foundation.
create table if not exists public.product_variants(
 id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,
 sku text not null unique,option_name text,option_value text,price numeric(12,2),stock integer not null default 0 check(stock>=0),
created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.product_variants enable row level security;
create policy "public read variants" on public.product_variants for select using(true);
create policy "seller manage variants" on public.product_variants for all to authenticated
using(exists(select 1 from products p join stores s on s.id=p.store_id where p.id=product_id and s.owner_id=auth.uid()))
with check(exists(select 1 from products p join stores s on s.id=p.store_id where p.id=product_id and s.owner_id=auth.uid()));

create table if not exists public.shipping_methods(
 id uuid primary key default gen_random_uuid(),name text not null unique,description text,price numeric(12,2) not null default 0,estimated_days integer not null default 3,is_active boolean not null default true
);
insert into public.shipping_methods(name,description,price,estimated_days) values
('Standard','Reliable delivery',3.99,5),('Express','Faster delivery',9.99,2)
on conflict(name) do nothing;
alter table public.shipping_methods enable row level security;
create policy "public read shipping methods" on public.shipping_methods for select using(is_active=true);

alter table public.orders add column if not exists shipping_method_id uuid references public.shipping_methods(id);
alter table public.orders add column if not exists shipping_fee numeric(12,2) not null default 0;
alter table public.orders add column if not exists delivered_at timestamptz;

create table if not exists public.returns(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,
user_id uuid not null references public.profiles(id),reason text not null,status text not null default 'requested'
check(status in ('requested','approved','rejected','received','refunded')),details text,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.returns enable row level security;
create policy "customers manage own returns" on public.returns for all to authenticated
using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "sellers read related returns" on public.returns for select to authenticated
using(exists(select 1 from order_items oi join stores s on s.id=oi.store_id where oi.order_id=returns.order_id and s.owner_id=auth.uid()));

create table if not exists public.seller_payouts(
 id uuid primary key default gen_random_uuid(),store_id uuid not null references public.stores(id) on delete cascade,
amount numeric(12,2) not null check(amount>=0),status text not null default 'pending' check(status in ('pending','processing','paid','failed')),
provider text,provider_reference text,created_at timestamptz not null default now()
);
alter table public.seller_payouts enable row level security;
create policy "seller read own payouts" on public.seller_payouts for select to authenticated
using(exists(select 1 from stores s where s.id=store_id and s.owner_id=auth.uid()));

create or replace function public.request_return(p_order uuid,p_reason text,p_details text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare rid uuid;
begin
 if not exists(select 1 from orders where id=p_order and user_id=auth.uid()) then raise exception 'Order not found'; end if;
 if exists(select 1 from returns where order_id=p_order and user_id=auth.uid() and status not in ('rejected')) then raise exception 'Return already requested'; end if;
 insert into returns(order_id,user_id,reason,details) values(p_order,auth.uid(),p_reason,p_details) returning id into rid;
 insert into notifications(user_id,title,body,kind) values(auth.uid(),'Return requested','Your return request has been submitted.','return');
 return rid;
end; $$;
grant execute on function public.request_return(uuid,text,text) to authenticated;
