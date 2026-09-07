-- AbdullahAtal V8
-- Search, structured addresses, reviews, seller analytics, notifications.

alter table public.products add column if not exists search_vector tsvector
generated always as (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(description,''))) stored;
create index if not exists products_search_idx on public.products using gin(search_vector);

create table if not exists public.addresses(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 label text not null default 'Home',recipient_name text not null,phone text not null,
 address_line1 text not null,address_line2 text,city text not null,province text,
 country text not null default 'Afghanistan',postal_code text,is_default boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.addresses enable row level security;
create policy "own addresses" on public.addresses for all to authenticated
using(auth.uid()=user_id) with check(auth.uid()=user_id);

create table if not exists public.reviews(
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 order_id uuid references public.orders(id) on delete set null,
 rating integer not null check(rating between 1 and 5),body text,
created_at timestamptz not null default now(),unique(product_id,user_id,order_id)
);
alter table public.reviews enable row level security;
create policy "public read reviews" on public.reviews for select using(true);
create policy "customers create reviews" on public.reviews for insert to authenticated
with check(auth.uid()=user_id and exists(select 1 from public.orders o join public.order_items oi on oi.order_id=o.id where o.id=order_id and o.user_id=auth.uid() and oi.product_id=product_id));
create policy "own reviews update" on public.reviews for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "own reviews delete" on public.reviews for delete to authenticated using(auth.uid()=user_id);

create table if not exists public.notifications(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 title text not null,body text not null,kind text not null default 'general',read_at timestamptz,
created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
create policy "own notifications" on public.notifications for select to authenticated using(auth.uid()=user_id);
create policy "own notifications update" on public.notifications for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function public.search_products(p_query text,p_category text default null)
returns table(id uuid,name text,description text,price numeric,stock integer,image_url text,store_name text,category_name text)
language sql stable security definer set search_path=public as $$
 select p.id,p.name,p.description,p.price,p.stock,p.image_url,s.name,c.name
 from products p join stores s on s.id=p.store_id left join categories c on c.id=p.category_id
 where p.is_active=true and (p_query is null or p_query='' or p.search_vector @@ plainto_tsquery('simple',p_query))
 and (p_category is null or p_category='' or c.slug=p_category)
 order by p.created_at desc limit 50;
$$;
grant execute on function public.search_products(text,text) to anon,authenticated;

create or replace function public.seller_analytics(p_store uuid)
returns table(total_products bigint,total_stock bigint,total_order_items bigint,revenue numeric)
language sql stable security definer set search_path=public as $$
 select
 (select count(*) from products p where p.store_id=p_store),
 (select coalesce(sum(stock),0) from products p where p.store_id=p_store),
 (select coalesce(sum(oi.quantity),0) from order_items oi where oi.store_id=p_store and exists(select 1 from orders o where o.id=oi.order_id and o.payment_status='paid')),
 (select coalesce(sum(oi.unit_price*oi.quantity),0) from order_items oi where oi.store_id=p_store and exists(select 1 from orders o where o.id=oi.order_id and o.payment_status='paid'))
 where exists(select 1 from stores s where s.id=p_store and s.owner_id=auth.uid());
$$;
grant execute on function public.seller_analytics(uuid) to authenticated;
