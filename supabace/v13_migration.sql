-- AbdullahAtal V13 — reliability, security and launch operations

create table if not exists public.rate_limits(
 key text primary key,
 window_started_at timestamptz not null default now(),
 request_count integer not null default 0
);
alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from public,anon,authenticated;

create table if not exists public.security_events(
 id uuid primary key default gen_random_uuid(),
 user_id uuid references public.profiles(id) on delete set null,
 event_type text not null,
 severity text not null default 'info' check(severity in ('info','warning','critical')),
 metadata jsonb,
 created_at timestamptz not null default now()
);
alter table public.security_events enable row level security;
create policy "admins read security events" on public.security_events for select to authenticated
using(public.is_admin());

create table if not exists public.platform_settings(
 key text primary key,
 value jsonb not null,
 updated_at timestamptz not null default now()
);
alter table public.platform_settings enable row level security;
create policy "public read safe settings" on public.platform_settings for select using(key in ('store_name','support_email','default_country'));

insert into public.platform_settings(key,value) values
('store_name','"AbdullahAtal"'),('default_country','"Afghanistan"')
on conflict(key) do nothing;

create or replace function public.record_security_event(
 p_event_type text,p_severity text default 'info',p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path=public as $$
declare eid uuid;
begin
 insert into security_events(user_id,event_type,severity,metadata)
 values(auth.uid(),p_event_type,p_severity,p_metadata) returning id into eid;
 return eid;
end; $$;
grant execute on function public.record_security_event(text,text,jsonb) to authenticated;

create or replace function public.cleanup_expired_reservations()
returns integer language plpgsql security definer set search_path=public as $$
declare n integer:=0;r record;
begin
 for r in select * from inventory_reservations where status='reserved' and expires_at<now() for update loop
   update products set stock=stock+r.quantity,updated_at=now() where id=r.product_id;
   update inventory_reservations set status='released' where id=r.id;
   update orders set status='cancelled' where id=r.order_id and payment_status<>'paid' and status='pending';
   n:=n+1;
 end loop;
 return n;
end; $$;
revoke all on function public.cleanup_expired_reservations() from public,anon,authenticated;

create index if not exists security_events_created_idx on security_events(created_at desc);
create index if not exists security_events_user_idx on security_events(user_id,created_at desc);
