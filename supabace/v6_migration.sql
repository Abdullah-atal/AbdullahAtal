-- AbdullahAtal V6
-- Run after schema.sql and v5_migration.sql.
-- Checkout is performed in one database transaction through this RPC.

create or replace function public.checkout_cart(
  p_shipping_name text,
  p_shipping_phone text,
  p_shipping_address text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_cart uuid;
  v_order uuid;
  v_total numeric(12,2) := 0;
  r record;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select id into v_cart from public.carts where user_id=v_user for update;
  if v_cart is null then raise exception 'Cart not found'; end if;

  select coalesce(sum(p.price * ci.quantity),0)
  into v_total
  from public.cart_items ci
  join public.products p on p.id=ci.product_id
  where ci.cart_id=v_cart and p.is_active=true and p.stock >= ci.quantity;

  if v_total <= 0 then raise exception 'Cart is empty or products are unavailable'; end if;

  for r in
    select ci.product_id,ci.quantity,p.stock,p.name,p.price,p.store_id
    from public.cart_items ci join public.products p on p.id=ci.product_id
    where ci.cart_id=v_cart and p.is_active=true
    for update
  loop
    if r.stock < r.quantity then raise exception 'Not enough stock for %',r.name; end if;
  end loop;

  insert into public.orders(user_id,status,total,shipping_name,shipping_phone,shipping_address)
  values(v_user,'pending',v_total,p_shipping_name,p_shipping_phone,p_shipping_address)
  returning id into v_order;

  insert into public.order_items(order_id,product_id,store_id,product_name,unit_price,quantity)
  select v_order,p.id,p.store_id,p.name,p.price,ci.quantity
  from public.cart_items ci join public.products p on p.id=ci.product_id
  where ci.cart_id=v_cart;

  update public.products p
  set stock=p.stock-ci.quantity,updated_at=now()
  from public.cart_items ci
  where ci.cart_id=v_cart and ci.product_id=p.id;

  delete from public.cart_items where cart_id=v_cart;
  update public.carts set updated_at=now() where id=v_cart;

  return v_order;
end;
$$;

revoke all on function public.checkout_cart(text,text,text) from public,anon;
grant execute on function public.checkout_cart(text,text,text) to authenticated;

-- Customers can read their orders/items.
create policy "customers read own orders"
on public.orders for select to authenticated
using (auth.uid()=user_id);

create policy "customers read own order items"
on public.order_items for select to authenticated
using (exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));

-- Sellers can read only order items belonging to their stores.
create policy "sellers read their order items"
on public.order_items for select to authenticated
using (exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));

-- Sellers can read the parent orders for orders containing their products.
create policy "sellers read relevant orders"
on public.orders for select to authenticated
using (exists(
  select 1 from public.order_items oi
  join public.stores s on s.id=oi.store_id
  where oi.order_id=orders.id and s.owner_id=auth.uid()
));

-- Sellers can update order status only for orders containing their products.
create policy "sellers update relevant orders"
on public.orders for update to authenticated
using (exists(
  select 1 from public.order_items oi
  join public.stores s on s.id=oi.store_id
  where oi.order_id=orders.id and s.owner_id=auth.uid()
))
with check (exists(
  select 1 from public.order_items oi
  join public.stores s on s.id=oi.store_id
  where oi.order_id=orders.id and s.owner_id=auth.uid()
));
