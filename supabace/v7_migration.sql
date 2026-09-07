-- AbdullahAtal V7
-- Admin moderation + payment-ready order state.
alter table public.profiles add column if not exists is_suspended boolean not null default false;
alter table public.orders add column if not exists payment_status text not null default 'unpaid'
  check(payment_status in ('unpaid','pending','paid','failed','refunded'));
alter table public.orders add column if not exists payment_provider text;
alter table public.orders add column if not exists payment_reference text;

create table if not exists public.admin_audit_log(
 id uuid primary key default gen_random_uuid(),
 admin_id uuid not null references public.profiles(id),
 action text not null,
 target_type text,
 target_id uuid,
 details jsonb,
 created_at timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
create policy "admins read audit log" on public.admin_audit_log for select to authenticated
using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and not is_suspended); $$;

create or replace function public.admin_set_store_verified(p_store uuid,p_value boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 update public.stores set is_verified=p_value,updated_at=now() where id=p_store;
 insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
 values(auth.uid(),'set_store_verified','store',p_store,jsonb_build_object('verified',p_value));
end; $$;

create or replace function public.admin_set_product_active(p_product uuid,p_value boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 update public.products set is_active=p_value,updated_at=now() where id=p_product;
 insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
 values(auth.uid(),'set_product_active','product',p_product,jsonb_build_object('active',p_value));
end; $$;

revoke all on function public.admin_set_store_verified(uuid,boolean) from public,anon;
revoke all on function public.admin_set_product_active(uuid,boolean) from public,anon;
grant execute on function public.admin_set_store_verified(uuid,boolean) to authenticated;
grant execute on function public.admin_set_product_active(uuid,boolean) to authenticated;
