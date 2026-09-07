-- V14 pre-launch verification queries. Run manually in Supabase SQL editor.
select tablename from pg_tables where schemaname='public' order by tablename;
select policyname,tablename from pg_policies where schemaname='public' order by tablename,policyname;
select key from public.platform_settings order by key;
