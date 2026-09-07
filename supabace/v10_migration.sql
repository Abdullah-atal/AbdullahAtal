-- AbdullahAtal V10 — production checkout, inventory reservations, payout calculation, return approvals.
-- Run after V9 migration.

alter table public.order_items add column if not exists variant_id uuid references public.product_variants(id);
alter table public.order_items add column if not exists line_total numeric(12,2);

create table if not exists public.inventory_reservations(
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid not null references public.products(id),
 variant_id uuid references public.product_variants(id),
 quantity integer not null check(quantity>0),
 status text not null default 'reserved' check(status in ('reserved','released','consumed')),
 expires_at timestamptz not null default (now()+interval '15 minutes'),
 created_at timestamptz not null default now()
);
alter table public.inventory_reservations enable row level security;
create policy "customers read own reservations" on public.inventory_reservations
for select to authenticated using(exists(select 1 from orders o where o.id=order_id and o.user_id=auth.uid()));

-- Server calculates shipping + totals and locks inventory before creating an order.
create or replace function public.checkout_cart_v10(
 p_shipping_name text,p_shipping_phone text,p_shipping_address text,p_shipping_method uuid
) returns uuid language plpgsql security definer set search_path=public as $$
declare
 uid uuid:=auth.uid(); cid uuid; oid uuid; subtotal numeric(12,2); fee numeric(12,2); total numeric(12,2); r record;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 select id into cid from carts where user_id=uid for update;
 if cid is null then raise exception 'Cart not found'; end if;
 select coalesce(sum(p.price*ci.quantity),0) into subtotal
 from cart_items ci join products p on p.id=ci.product_id
 where ci.cart_id=cid and p.is_active=true;
 if subtotal<=0 then raise exception 'Cart is empty'; end if;
 select price into fee from shipping_methods where id=p_shipping_method and is_active=true;
 if fee is null then raise exception 'Invalid shipping method'; end if;
 for r in select ci.product_id,ci.quantity,p.stock,p.name,p.price,p.store_id from cart_items ci join products p on p.id=ci.product_id where ci.cart_id=cid for update loop
   if r.stock<r.quantity then raise exception 'Not enough stock for %',r.name; end if;
 end loop;
 total:=subtotal+fee;
 insert into orders(user_id,status,total,shipping_name,shipping_phone,shipping_address,shipping_method_id,shipping_fee)
 values(uid,'pending',total,p_shipping_name,p_shipping_phone,p_shipping_address,p_shipping_method,fee) returning id into oid;
 insert into order_items(order_id,product_id,store_id,product_name,unit_price,quantity,line_total)
 select oid,p.id,p.store_id,p.name,p.price,ci.quantity,p.price*ci.quantity from cart_items ci join products p on p.id=ci.product_id where ci.cart_id=cid;
 insert into inventory_reservations(order_id,product_id,quantity)
 select oid,p.id,ci.quantity from cart_items ci join products p on p.id=ci.product_id where ci.cart_id=cid;
 update products p set stock=p.stock-ci.quantity,updated_at=now() from cart_items ci where ci.cart_id=cid and ci.product_id=p.id;
 delete from cart_items where cart_id=cid;
 return oid;
end; $$;
grant execute on function public.checkout_cart_v10(text,text,text,uuid) to authenticated;

-- Payouts: calculate seller share after paid orders (10% platform fee).
create or replace function public.calculate_store_payout(p_store uuid)
returns numeric language sql stable security definer set search_path=public as $$
 select coalesce(sum(oi.unit_price*oi.quantity)*0.90,0)
 from order_items oi join orders o on o.id=oi.order_id
 where oi.store_id=p_store and o.payment_status='paid'
 and exists(select 1 from stores s where s.id=p_store and s.owner_id=auth.uid());
$$;
grant execute on function public.calculate_store_payout(uuid) to authenticated;

-- Admin return decisions.
create or replace function public.admin_update_return(p_return uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if p_status not in ('approved','rejected','received','refunded') then raise exception 'Invalid status'; end if;
 update returns set status=p_status,updated_at=now() where id=p_return;
end; $$;
grant execute on function public.admin_update_return(uuid,text) to authenticated;

create index if not exists reservations_order_idx on inventory_reservations(order_id);
create index if not exists orders_payment_status_idx on orders(payment_status);
