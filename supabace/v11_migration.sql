-- AbdullahAtal V11 — launch operations
-- Automated reservation cleanup, delivery events, seller payout batches, incident-safe audit trail.

create table if not exists public.delivery_events(
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id) on delete cascade,
 status text not null,
 tracking_number text,
carrier text,
 location text,
 event_time timestamptz not null default now(),
 created_at timestamptz not null default now()
);
alter table public.delivery_events enable row level security;
create policy "customers read own delivery events" on public.delivery_events for select to authenticated
using(exists(select 1 from orders o where o.id=order_id and o.user_id=auth.uid()));
create policy "sellers read related delivery events" on public.delivery_events for select to authenticated
using(exists(select 1 from order_items oi join stores s on s.id=oi.store_id where oi.order_id=delivery_events.order_id and s.owner_id=auth.uid()));

create table if not exists public.payout_batches(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id) on delete cascade,
 amount numeric(12,2) not null check(amount>=0),
 status text not null default 'pending' check(status in ('pending','processing','paid','failed')),
 created_at timestamptz not null default now(),
 processed_at timestamptz
);
alter table public.payout_batches enable row level security;
create policy "seller read own payout batches" on public.payout_batches for select to authenticated
using(exists(select 1 from stores s where s.id=store_id and s.owner_id=auth.uid()));

-- Release unpaid inventory after 15 minutes. Run from a scheduled backend job.
create or replace function public.release_expired_reservations()
returns integer language plpgsql security definer set search_path=public as $$
declare n integer:=0; r record;
begin
 for r in select * from inventory_reservations where status='reserved' and expires_at<now() for update loop
   update products set stock=stock+r.quantity,updated_at=now() where id=r.product_id;
   update inventory_reservations set status='released' where id=r.id;
   update orders set status='cancelled' where id=r.order_id and payment_status<>'paid' and status='pending';
   n:=n+1;
 end loop;
 return n;
end; $$;
revoke all on function public.release_expired_reservations() from public,anon,authenticated;

-- Create a seller payout batch only for delivered + paid orders not already batched.
create or replace function public.create_payout_batch(p_store uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare bid uuid; amt numeric(12,2);
begin
 if not exists(select 1 from stores where id=p_store and owner_id=auth.uid()) then raise exception 'Store access denied'; end if;
 select coalesce(sum(oi.unit_price*oi.quantity)*0.90,0) into amt
 from order_items oi join orders o on o.id=oi.order_id
 where oi.store_id=p_store and o.payment_status='paid' and o.status='delivered'
 and not exists(select 1 from payout_batches pb where pb.store_id=p_store and pb.amount=(oi.unit_price*oi.quantity)*0.90);
 if amt<=0 then raise exception 'No payable balance'; end if;
 insert into payout_batches(store_id,amount) values(p_store,amt) returning id into bid;
 return bid;
end; $$;
grant execute on function public.create_payout_batch(uuid) to authenticated;

create index if not exists delivery_events_order_idx on delivery_events(order_id,event_time desc);
create index if not exists reservations_expiry_idx on inventory_reservations(status,expires_at);
create index if not exists payout_batches_store_idx on payout_batches(store_id,created_at desc);
