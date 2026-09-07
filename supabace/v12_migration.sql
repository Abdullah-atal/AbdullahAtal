-- AbdullahAtal V12 — launch hardening
-- Final application-layer foundations: idempotency, order lifecycle, seller ratings, favorites, support tickets.

create table if not exists public.checkout_requests(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 idempotency_key text not null,
 order_id uuid references public.orders(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(user_id,idempotency_key)
);
alter table public.checkout_requests enable row level security;
create policy "own checkout requests" on public.checkout_requests for select to authenticated
using(auth.uid()=user_id);

create table if not exists public.favorites(
 user_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,product_id)
);
alter table public.favorites enable row level security;
create policy "own favorites" on public.favorites for all to authenticated
using(auth.uid()=user_id) with check(auth.uid()=user_id);

create table if not exists public.support_tickets(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 subject text not null,body text not null,
 status text not null default 'open' check(status in ('open','pending','resolved','closed')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.support_tickets enable row level security;
create policy "customers own tickets" on public.support_tickets for all to authenticated
using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "admins read tickets" on public.support_tickets for select to authenticated
using(public.is_admin());
create policy "admins update tickets" on public.support_tickets for update to authenticated
using(public.is_admin()) with check(public.is_admin());

create or replace function public.checkout_cart_v12(
 p_shipping_name text,p_shipping_phone text,p_shipping_address text,p_shipping_method uuid,p_idempotency_key text
) returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); existing uuid; oid uuid;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 select order_id into existing from checkout_requests where user_id=uid and idempotency_key=p_idempotency_key;
 if existing is not null then return existing; end if;
 -- Reuse the locked V10 transaction and record the idempotency key.
 oid:=public.checkout_cart_v10(p_shipping_name,p_shipping_phone,p_shipping_address,p_shipping_method);
 insert into checkout_requests(user_id,idempotency_key,order_id) values(uid,p_idempotency_key,oid);
 return oid;
end; $$;
grant execute on function public.checkout_cart_v12(text,text,text,uuid,text) to authenticated;

create or replace function public.create_support_ticket(p_subject text,p_body text,p_priority text default 'normal')
returns uuid language plpgsql security definer set search_path=public as $$
declare tid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_priority not in ('low','normal','high','urgent') then raise exception 'Invalid priority'; end if;
 insert into support_tickets(user_id,subject,body,priority) values(auth.uid(),p_subject,p_body,p_priority) returning id into tid;
 return tid;
end; $$;
grant execute on function public.create_support_ticket(text,text,text) to authenticated;

create index if not exists favorites_product_idx on favorites(product_id);
create index if not exists support_tickets_status_idx on support_tickets(status,priority,created_at desc);
create index if not exists checkout_requests_user_idx on checkout_requests(user_id,created_at desc);
