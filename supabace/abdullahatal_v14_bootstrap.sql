-- AbdullahAtal V14 — CLEAN BOOTSTRAP
-- Paste this ONE file into Supabase SQL Editor on a NEW/EMPTY AbdullahAtal project.
-- It intentionally replaces the earlier multi-migration sequence for a clean first install.

create extension if not exists pgcrypto;

-- ---------- Types ----------
do $$ begin
  create type public.app_role as enum ('customer','seller','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum ('pending','confirmed','processing','shipped','delivered','cancelled');
exception when duplicate_object then null; end $$;

-- ---------- Core ----------
create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, avatar_url text,
 role public.app_role not null default 'customer',
 is_suspended boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.categories(
 id uuid primary key default gen_random_uuid(), name text not null unique,
 slug text not null unique, created_at timestamptz not null default now()
);

create table if not exists public.stores(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 name text not null, slug text not null unique, description text, logo_url text,
 is_verified boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.products(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id) on delete cascade,
 category_id uuid references public.categories(id) on delete set null,
 name text not null, slug text not null unique, description text,
 price numeric(12,2) not null check(price>=0), stock integer not null default 0 check(stock>=0),
 image_url text, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

alter table public.products add column if not exists search_vector tsvector generated always as
(to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,''))) stored;

create table if not exists public.product_variants(
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
 sku text not null unique, option_name text, option_value text,
 price numeric(12,2) check(price is null or price>=0), stock integer not null default 0 check(stock>=0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.carts(
 id uuid primary key default gen_random_uuid(), user_id uuid not null unique references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.cart_items(
 id uuid primary key default gen_random_uuid(), cart_id uuid not null references public.carts(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 variant_id uuid references public.product_variants(id) on delete set null,
 quantity integer not null default 1 check(quantity>0), created_at timestamptz not null default now(),
 unique(cart_id,product_id,variant_id)
);

-- ---------- Orders / payments ----------
create table if not exists public.shipping_methods(
 id uuid primary key default gen_random_uuid(), name text not null unique, description text,
 price numeric(12,2) not null default 0 check(price>=0), estimated_days integer not null default 3 check(estimated_days>0),
 is_active boolean not null default true
);

create table if not exists public.orders(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete restrict,
 status public.order_status not null default 'pending',
 total numeric(12,2) not null default 0 check(total>=0),
 shipping_name text, shipping_phone text, shipping_address text,
 shipping_method_id uuid references public.shipping_methods(id), shipping_fee numeric(12,2) not null default 0 check(shipping_fee>=0),
 payment_status text not null default 'unpaid' check(payment_status in ('unpaid','pending','paid','failed','refunded')),
 payment_provider text, payment_reference text,
 delivered_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.order_items(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null, variant_id uuid references public.product_variants(id) on delete set null,
 store_id uuid references public.stores(id) on delete set null, product_name text not null,
 unit_price numeric(12,2) not null check(unit_price>=0), quantity integer not null check(quantity>0),
 line_total numeric(12,2) generated always as (unit_price*quantity) stored
);

create table if not exists public.inventory_reservations(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid not null references public.products(id), variant_id uuid references public.product_variants(id),
 quantity integer not null check(quantity>0), status text not null default 'reserved' check(status in ('reserved','released','consumed')),
 expires_at timestamptz not null default (now()+interval '15 minutes'), created_at timestamptz not null default now()
);

-- ---------- Customer / trust ----------
create table if not exists public.addresses(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 label text not null default 'Home', recipient_name text not null, phone text not null,
 address_line1 text not null, address_line2 text, city text not null, province text,
 country text not null default 'Afghanistan', postal_code text, is_default boolean not null default false,
 created_at timestamptz not null default now()
);

create table if not exists public.reviews(
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, order_id uuid references public.orders(id) on delete set null,
 rating integer not null check(rating between 1 and 5), body text, created_at timestamptz not null default now(),
 unique(product_id,user_id,order_id)
);

create table if not exists public.favorites(
 user_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,product_id)
);

create table if not exists public.notifications(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, body text not null, kind text not null default 'general', read_at timestamptz,
 created_at timestamptz not null default now()
);

create table if not exists public.returns(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 user_id uuid not null references public.profiles(id), reason text not null,
 status text not null default 'requested' check(status in ('requested','approved','rejected','received','refunded')),
 details text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.support_tickets(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 subject text not null, body text not null,
 status text not null default 'open' check(status in ('open','pending','resolved','closed')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- ---------- Operations ----------
create table if not exists public.delivery_events(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 status text not null, tracking_number text, carrier text, location text,
 event_time timestamptz not null default now(), created_at timestamptz not null default now()
);

create table if not exists public.payout_batches(
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
 amount numeric(12,2) not null check(amount>=0), status text not null default 'pending'
 check(status in ('pending','processing','paid','failed')), created_at timestamptz not null default now(), processed_at timestamptz
);

create table if not exists public.admin_audit_log(
 id uuid primary key default gen_random_uuid(), admin_id uuid not null references public.profiles(id),
 action text not null, target_type text, target_id uuid, details jsonb, created_at timestamptz not null default now()
);

create table if not exists public.security_events(
 id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id) on delete set null,
 event_type text not null, severity text not null default 'info' check(severity in ('info','warning','critical')),
 metadata jsonb, created_at timestamptz not null default now()
);

create table if not exists public.rate_limits(
 key text primary key, window_started_at timestamptz not null default now(), request_count integer not null default 0
);

create table if not exists public.platform_settings(
 key text primary key, value jsonb not null, updated_at timestamptz not null default now()
);

create table if not exists public.checkout_requests(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 idempotency_key text not null, order_id uuid references public.orders(id) on delete set null,
 created_at timestamptz not null default now(), unique(user_id,idempotency_key)
);

-- ---------- Seed data ----------
insert into public.categories(name,slug) values
('Electronics','electronics'),('Fashion','fashion'),('Home & Living','home-living'),('Beauty & Personal Care','beauty'),
('Grocery','grocery'),('Kids & Toys','kids-toys'),('Automotive','automotive'),('Tools & Hardware','tools-hardware'),
('Sports & Outdoors','sports-outdoors'),('Books & Education','books-education'),('Digital Products','digital-products'),('Local & Handmade','local-handmade')
on conflict(slug) do nothing;
insert into public.shipping_methods(name,description,price,estimated_days) values
('Standard','Reliable delivery',3.99,5),('Express','Faster delivery',9.99,2)
on conflict(name) do nothing;
insert into public.platform_settings(key,value) values
('store_name','"AbdullahAtal"'::jsonb),('default_country','"Afghanistan"'::jsonb)
on conflict(key) do nothing;

-- ---------- Auth ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name) values(new.id,new.raw_user_meta_data->>'full_name') on conflict(id) do nothing;
 insert into public.carts(user_id) values(new.id) on conflict(user_id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and not is_suspended);
$$;

-- ---------- Secure checkout ----------
create or replace function public.checkout_cart_v14(
 p_shipping_name text,p_shipping_phone text,p_shipping_address text,p_shipping_method uuid,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); existing uuid; cid uuid; oid uuid; subtotal numeric(12,2); fee numeric(12,2); total numeric(12,2); r record;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if length(trim(coalesce(p_idempotency_key,'')))<8 then raise exception 'Invalid checkout key'; end if;
 select order_id into existing from public.checkout_requests where user_id=uid and idempotency_key=p_idempotency_key;
 if existing is not null then return existing; end if;
 select id into cid from public.carts where user_id=uid for update;
 if cid is null then raise exception 'Cart not found'; end if;
 select coalesce(sum(p.price*ci.quantity),0) into subtotal
 from public.cart_items ci join public.products p on p.id=ci.product_id
 where ci.cart_id=cid and p.is_active=true;
 if subtotal<=0 then raise exception 'Cart is empty'; end if;
 select price into fee from public.shipping_methods where id=p_shipping_method and is_active=true;
 if fee is null then raise exception 'Invalid shipping method'; end if;
 for r in select ci.product_id,ci.quantity,p.stock,p.name,p.price,p.store_id from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=cid and p.is_active=true for update loop
   if r.stock<r.quantity then raise exception 'Not enough stock for %',r.name; end if;
 end loop;
 total:=subtotal+fee;
 insert into public.orders(user_id,status,total,shipping_name,shipping_phone,shipping_address,shipping_method_id,shipping_fee,payment_status)
 values(uid,'pending',total,p_shipping_name,p_shipping_phone,p_shipping_address,p_shipping_method,fee,'unpaid') returning id into oid;
 insert into public.order_items(order_id,product_id,store_id,product_name,unit_price,quantity)
 select oid,p.id,p.store_id,p.name,p.price,ci.quantity from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=cid;
 insert into public.inventory_reservations(order_id,product_id,quantity)
 select oid,p.id,ci.quantity from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=cid;
 update public.products p set stock=p.stock-ci.quantity,updated_at=now() from public.cart_items ci where ci.cart_id=cid and ci.product_id=p.id;
 delete from public.cart_items where cart_id=cid;
 update public.carts set updated_at=now() where id=cid;
 insert into public.checkout_requests(user_id,idempotency_key,order_id) values(uid,p_idempotency_key,oid);
 return oid;
end; $$;
revoke all on function public.checkout_cart_v14(text,text,text,uuid,text) from public,anon;
grant execute on function public.checkout_cart_v14(text,text,text,uuid,text) to authenticated;

-- ---------- Search / analytics ----------
create index if not exists products_search_idx on public.products using gin(search_vector);
create or replace function public.search_products(p_query text,p_category text default null)
returns table(id uuid,name text,description text,price numeric,stock integer,image_url text,store_name text,category_name text)
language sql stable security definer set search_path=public as $$
 select p.id,p.name,p.description,p.price,p.stock,p.image_url,s.name,c.name
 from public.products p join public.stores s on s.id=p.store_id left join public.categories c on c.id=p.category_id
 where p.is_active=true and (p_query is null or p_query='' or p.search_vector @@ plainto_tsquery('simple',p_query))
 and (p_category is null or p_category='' or c.slug=p_category) order by p.created_at desc limit 50;
$$;
grant execute on function public.search_products(text,text) to anon,authenticated;

create or replace function public.seller_analytics(p_store uuid)
returns table(total_products bigint,total_stock bigint,total_order_items bigint,revenue numeric)
language sql stable security definer set search_path=public as $$
 select (select count(*) from public.products p where p.store_id=p_store),
 (select coalesce(sum(stock),0) from public.products p where p.store_id=p_store),
 (select coalesce(sum(oi.quantity),0) from public.order_items oi join public.orders o on o.id=oi.order_id where oi.store_id=p_store and o.payment_status='paid'),
 (select coalesce(sum(oi.unit_price*oi.quantity),0) from public.order_items oi join public.orders o on o.id=oi.order_id where oi.store_id=p_store and o.payment_status='paid')
 where exists(select 1 from public.stores s where s.id=p_store and s.owner_id=auth.uid());
$$;
grant execute on function public.seller_analytics(uuid) to authenticated;

-- ---------- Returns / support ----------
create or replace function public.request_return(p_order uuid,p_reason text,p_details text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare rid uuid;
begin
 if not exists(select 1 from public.orders where id=p_order and user_id=auth.uid()) then raise exception 'Order not found'; end if;
 if exists(select 1 from public.returns where order_id=p_order and user_id=auth.uid() and status not in ('rejected')) then raise exception 'Return already requested'; end if;
 insert into public.returns(order_id,user_id,reason,details) values(p_order,p_reason,p_details) returning id into rid;
 insert into public.notifications(user_id,title,body,kind) values(auth.uid(),'Return requested','Your return request has been submitted.','return');
 return rid;
end; $$;
grant execute on function public.request_return(uuid,text,text) to authenticated;

create or replace function public.create_support_ticket(p_subject text,p_body text,p_priority text default 'normal')
returns uuid language plpgsql security definer set search_path=public as $$
declare tid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_priority not in ('low','normal','high','urgent') then raise exception 'Invalid priority'; end if;
 insert into public.support_tickets(user_id,subject,body,priority) values(auth.uid(),p_subject,p_body,p_priority) returning id into tid;
 return tid;
end; $$;
grant execute on function public.create_support_ticket(text,text,text) to authenticated;

-- ---------- Admin / security ----------
create or replace function public.admin_set_store_verified(p_store uuid,p_value boolean) returns void
language plpgsql security definer set search_path=public as $$
begin if not public.is_admin() then raise exception 'Admin access required'; end if;
update public.stores set is_verified=p_value,updated_at=now() where id=p_store;
insert into public.admin_audit_log(admin_id,action,target_type,target_id,details) values(auth.uid(),'set_store_verified','store',p_store,jsonb_build_object('verified',p_value)); end; $$;
grant execute on function public.admin_set_store_verified(uuid,boolean) to authenticated;

create or replace function public.admin_set_product_active(p_product uuid,p_value boolean) returns void
language plpgsql security definer set search_path=public as $$
begin if not public.is_admin() then raise exception 'Admin access required'; end if;
update public.products set is_active=p_value,updated_at=now() where id=p_product;
insert into public.admin_audit_log(admin_id,action,target_type,target_id,details) values(auth.uid(),'set_product_active','product',p_product,jsonb_build_object('active',p_value)); end; $$;
grant execute on function public.admin_set_product_active(uuid,boolean) to authenticated;

create or replace function public.admin_update_return(p_return uuid,p_status text) returns void
language plpgsql security definer set search_path=public as $$
begin if not public.is_admin() then raise exception 'Admin access required'; end if;
if p_status not in ('approved','rejected','received','refunded') then raise exception 'Invalid status'; end if;
update public.returns set status=p_status,updated_at=now() where id=p_return; end; $$;
grant execute on function public.admin_update_return(uuid,text) to authenticated;

create or replace function public.record_security_event(p_event_type text,p_severity text default 'info',p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare eid uuid; begin insert into public.security_events(user_id,event_type,severity,metadata) values(auth.uid(),p_event_type,p_severity,p_metadata) returning id into eid; return eid; end; $$;
grant execute on function public.record_security_event(text,text,jsonb) to authenticated;

-- ---------- Reservation cleanup (trusted scheduler only) ----------
create or replace function public.cleanup_expired_reservations() returns integer
language plpgsql security definer set search_path=public as $$
declare n integer:=0;r record;
begin
 for r in select * from public.inventory_reservations where status='reserved' and expires_at<now() for update loop
  update public.products set stock=stock+r.quantity,updated_at=now() where id=r.product_id;
  update public.inventory_reservations set status='released' where id=r.id;
  update public.orders set status='cancelled',updated_at=now() where id=r.order_id and payment_status<>'paid' and status='pending';
  n:=n+1;
 end loop; return n;
end; $$;
revoke all on function public.cleanup_expired_reservations() from public,anon,authenticated;

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.shipping_methods enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.inventory_reservations enable row level security;
alter table public.addresses enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.notifications enable row level security;
alter table public.returns enable row level security;
alter table public.support_tickets enable row level security;
alter table public.delivery_events enable row level security;
alter table public.payout_batches enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.security_events enable row level security;
alter table public.rate_limits enable row level security;
alter table public.platform_settings enable row level security;
alter table public.checkout_requests enable row level security;

-- Policies use unique names so this bootstrap can be run once on a clean project.
create policy profiles_read_own on public.profiles for select to authenticated using(auth.uid()=id);
create policy profiles_update_own on public.profiles for update to authenticated using(auth.uid()=id) with check(auth.uid()=id);
create policy categories_public_read on public.categories for select using(true);
create policy stores_public_read on public.stores for select using(true);
create policy stores_owner_manage on public.stores for all to authenticated using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy products_public_read on public.products for select using(is_active=true);
create policy products_owner_manage on public.products for all to authenticated using(exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid())) with check(exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));
create policy variants_public_read on public.product_variants for select using(true);
create policy variants_owner_manage on public.product_variants for all to authenticated using(exists(select 1 from public.products p join public.stores s on s.id=p.store_id where p.id=product_id and s.owner_id=auth.uid())) with check(exists(select 1 from public.products p join public.stores s on s.id=p.store_id where p.id=product_id and s.owner_id=auth.uid()));
create policy carts_own on public.carts for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy cart_items_own on public.cart_items for all to authenticated using(exists(select 1 from public.carts c where c.id=cart_id and c.user_id=auth.uid())) with check(exists(select 1 from public.carts c where c.id=cart_id and c.user_id=auth.uid()));
create policy shipping_public_read on public.shipping_methods for select using(is_active=true);
create policy orders_own_read on public.orders for select to authenticated using(auth.uid()=user_id);
create policy orders_seller_read on public.orders for select to authenticated using(exists(select 1 from public.order_items oi join public.stores s on s.id=oi.store_id where oi.order_id=orders.id and s.owner_id=auth.uid()));
create policy order_items_own_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));
create policy order_items_seller_read on public.order_items for select to authenticated using(exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));
create policy reservations_own_read on public.inventory_reservations for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));
create policy addresses_own on public.addresses for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy reviews_public_read on public.reviews for select using(true);
create policy reviews_own_write on public.reviews for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy favorites_own on public.favorites for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy notifications_own_read on public.notifications for select to authenticated using(auth.uid()=user_id);
create policy notifications_own_update on public.notifications for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy returns_own on public.returns for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy returns_seller_read on public.returns for select to authenticated using(exists(select 1 from public.order_items oi join public.stores s on s.id=oi.store_id where oi.order_id=returns.order_id and s.owner_id=auth.uid()));
create policy support_own on public.support_tickets for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy support_admin_read on public.support_tickets for select to authenticated using(public.is_admin());
create policy support_admin_update on public.support_tickets for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy delivery_customer_read on public.delivery_events for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));
create policy delivery_seller_read on public.delivery_events for select to authenticated using(exists(select 1 from public.order_items oi join public.stores s on s.id=oi.store_id where oi.order_id=delivery_events.order_id and s.owner_id=auth.uid()));
create policy payouts_seller_read on public.payout_batches for select to authenticated using(exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));
create policy audit_admin_read on public.admin_audit_log for select to authenticated using(public.is_admin());
create policy security_admin_read on public.security_events for select to authenticated using(public.is_admin());
create policy platform_safe_read on public.platform_settings for select using(key in ('store_name','support_email','default_country'));
create policy checkout_requests_own_read on public.checkout_requests for select to authenticated using(auth.uid()=user_id);

-- ---------- Grants ----------
grant select on public.categories,public.products,public.stores,public.product_variants,public.shipping_methods,public.reviews to anon;
grant select,insert,update,delete on public.profiles,public.stores,public.products,public.product_variants,public.carts,public.cart_items,public.addresses,public.reviews,public.favorites,public.notifications,public.returns,public.support_tickets to authenticated;
grant select on public.orders,public.order_items,public.inventory_reservations,public.delivery_events,public.payout_batches,public.platform_settings,public.checkout_requests to authenticated;

-- ---------- Indexes ----------
create index if not exists products_store_idx on public.products(store_id);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists variants_product_idx on public.product_variants(product_id);
create index if not exists cart_items_cart_idx on public.cart_items(cart_id);
create index if not exists orders_user_idx on public.orders(user_id,created_at desc);
create index if not exists orders_payment_idx on public.orders(payment_status);
create index if not exists order_items_order_idx on public.order_items(order_id);
create index if not exists reservations_expiry_idx on public.inventory_reservations(status,expires_at);
create index if not exists delivery_events_order_idx on public.delivery_events(order_id,event_time desc);
create index if not exists notifications_user_idx on public.notifications(user_id,created_at desc);
create index if not exists returns_user_idx on public.returns(user_id,created_at desc);
create index if not exists support_status_idx on public.support_tickets(status,priority,created_at desc);
create index if not exists security_events_created_idx on public.security_events(created_at desc);

-- ---------- Storage ----------
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do nothing;
create policy product_images_public_read on storage.objects for select using(bucket_id='product-images');
create policy product_images_authenticated_upload on storage.objects for insert to authenticated
with check(bucket_id='product-images' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy product_images_owner_update on storage.objects for update to authenticated
using(bucket_id='product-images' and owner_id=(select auth.uid()::text))
with check(bucket_id='product-images' and owner_id=(select auth.uid()::text));
create policy product_images_owner_delete on storage.objects for delete to authenticated
using(bucket_id='product-images' and owner_id=(select auth.uid()::text));

-- ---------- Verification ----------
select 'AbdullahAtal V14 bootstrap complete' as status,
 (select count(*) from public.categories) as categories,
 (select count(*) from public.shipping_methods) as shipping_methods;
