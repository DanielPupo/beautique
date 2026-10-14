-- Apply in a dedicated Supabase project. No demo customers, staff, prices or slots.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
create extension if not exists btree_gist with schema extensions;
set search_path = public, extensions;
create table public.profiles (id uuid primary key references auth.users on delete cascade, role text not null default 'viewer' check(role in ('admin','viewer')), created_at timestamptz not null default now());
create function private.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;
create table public.service_categories (slug text primary key, name text not null, created_at timestamptz not null default now());
insert into public.service_categories values ('estetica-facial','Estética facial',now()),('estetica-corporal','Estética corporal',now()),('hair-beauty','Hair & Beauty',now()),('spa-bem-estar','Spa & bem-estar',now()),('dia-da-noiva','Dia da Noiva',now());
create table public.services (id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null check(length(name) between 1 and 120), description text, category_slug text references public.service_categories, duration_minutes integer check(duration_minutes between 1 and 1440), price_cents integer check(price_cents>=0), photo_url text, active boolean not null default true, created_at timestamptz not null default now());
create table public.professionals (id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120), description text, photo_url text, active boolean not null default true, created_at timestamptz not null default now());
create table public.professional_services (professional_id uuid references public.professionals on delete cascade, service_id uuid references public.services on delete cascade, primary key(professional_id,service_id));
create table public.professional_availability (id uuid primary key default gen_random_uuid(), professional_id uuid not null references public.professionals on delete cascade, weekday smallint check(weekday between 0 and 6), starts_at time not null, ends_at time not null, check(ends_at>starts_at));
create table public.availability_exceptions (id uuid primary key default gen_random_uuid(), professional_id uuid not null references public.professionals on delete cascade, starts_at timestamptz not null, ends_at timestamptz not null, reason text, check(ends_at>starts_at));
create table public.appointments (id uuid primary key default gen_random_uuid(), protocol uuid not null default gen_random_uuid() unique, service_id uuid not null references public.services, professional_id uuid not null references public.professionals, starts_at timestamptz not null, ends_at timestamptz not null, customer_name text not null check(length(customer_name) between 1 and 120), phone text not null check(phone ~ '^[+()0-9 -]{10,20}$'), email text, notes text check(length(notes)<=1000), status text not null default 'pending' check(status in ('pending','confirmed','cancelled','completed')), consent_at timestamptz not null default now(), created_at timestamptz not null default now(), check(ends_at>starts_at), exclude using gist (professional_id with =, tstzrange(starts_at,ends_at,'[)') with &&) where (status in ('pending','confirmed')));
create index appointments_start_idx on public.appointments(starts_at);
create table public.appointment_status_history (id uuid primary key default gen_random_uuid(), appointment_id uuid references public.appointments on delete cascade, old_status text, new_status text not null, actor_id uuid references auth.users, created_at timestamptz not null default now());
create table public.gallery_items (id uuid primary key default gen_random_uuid(), photo_url text not null, alt text not null, authorized boolean not null default false, created_at timestamptz not null default now());
create table public.testimonials (id uuid primary key default gen_random_uuid(), public_name text not null, quote text not null, source_url text not null, stars smallint check(stars between 1 and 5), authorized boolean not null default false, created_at timestamptz not null default now());
create table public.bridal_inquiries (id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120), phone text not null check(phone ~ '^[+()0-9 -]{10,20}$'), event_date date not null, participants integer check(participants between 1 and 1000), notes text check(length(notes)<=1000), consent_at timestamptz not null default now(), created_at timestamptz not null default now());
create table public.site_settings (id uuid primary key default gen_random_uuid(), key text unique not null, value jsonb not null, created_at timestamptz not null default now());
create table public.content_sections (id uuid primary key default gen_random_uuid(), slug text unique not null, content jsonb not null, created_at timestamptz not null default now());
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users, operation text not null, table_name text not null, record_id text, created_at timestamptz not null default now());
-- Audit metadata only: do not copy client PII into logs.
create function private.log_admin_change() returns trigger language plpgsql security definer set search_path=public as $$ begin
 insert into public.audit_logs(actor_id,operation,table_name,record_id) values(auth.uid(),TG_OP,TG_TABLE_NAME,case when TG_OP='DELETE' then old.id::text else new.id::text end);
 if TG_TABLE_NAME='appointments' then if TG_OP='UPDATE' then if old.status is distinct from new.status then insert into public.appointment_status_history(appointment_id,old_status,new_status,actor_id) values(new.id,old.status,new.status,auth.uid()); end if; end if; end if;
 if TG_OP='DELETE' then return old; else return new; end if; end; $$;
do $$ declare t text; begin foreach t in array array['profiles','service_categories','services','professionals','professional_services','professional_availability','availability_exceptions','appointments','appointment_status_history','gallery_items','testimonials','bridal_inquiries','site_settings','content_sections','audit_logs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy admin_all on public.%I for all to authenticated using((select private.is_admin())) with check((select private.is_admin()))',t);
 end loop;
 foreach t in array array['services','professionals','appointments','gallery_items','testimonials','bridal_inquiries','site_settings','content_sections'] loop execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function private.log_admin_change()',t); end loop; end $$;
create policy own_profile on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy public_categories on public.service_categories for select to anon,authenticated using(true);
create policy public_services on public.services for select to anon,authenticated using(active);
create policy public_professionals on public.professionals for select to anon,authenticated using(active);
create policy public_gallery on public.gallery_items for select to anon,authenticated using(authorized);
create policy public_testimonials on public.testimonials for select to anon,authenticated using(authorized);
create policy public_content on public.content_sections for select to anon,authenticated using(true);
-- No public appointment, inquiry, exception, audit, settings or customer reads/writes.
-- Reservation RPC is authenticated admin only until production abuse protection is installed.
create function public.reserve_appointment(p_service uuid,p_professional uuid,p_start timestamptz,p_name text,p_phone text,p_email text default null,p_notes text default null) returns uuid language plpgsql security invoker set search_path=public as $$
declare dur integer; finish timestamptz; local_start timestamp; local_finish timestamp; result uuid;
begin
 if not private.is_admin() then raise exception 'Administrator required'; end if;
 select duration_minutes into dur from public.services where id=p_service and active;
 if dur is null then raise exception 'Service duration must be confirmed'; end if;
 if not exists(select 1 from public.professionals where id=p_professional and active) or not exists(select 1 from public.professional_services where professional_id=p_professional and service_id=p_service) then raise exception 'Professional not eligible'; end if;
 if p_start<=now() then raise exception 'Appointment must be in future'; end if;
 finish=p_start+make_interval(mins=>dur);local_start=p_start at time zone 'America/Sao_Paulo';local_finish=finish at time zone 'America/Sao_Paulo';
 if local_start::date<>local_finish::date or not exists(select 1 from public.professional_availability where professional_id=p_professional and weekday=extract(dow from local_start) and starts_at<=local_start::time and ends_at>=local_finish::time) then raise exception 'Outside professional schedule'; end if;
 if exists(select 1 from public.availability_exceptions where professional_id=p_professional and tstzrange(starts_at,ends_at,'[)') && tstzrange(p_start,finish,'[)')) then raise exception 'Professional unavailable'; end if;
 insert into public.appointments(service_id,professional_id,starts_at,ends_at,customer_name,phone,email,notes) values(p_service,p_professional,p_start,finish,p_name,p_phone,p_email,p_notes) returning protocol into result;
 return result;
end $$;
revoke all on function public.reserve_appointment(uuid,uuid,timestamptz,text,text,text,text) from public,anon;
grant execute on function public.reserve_appointment(uuid,uuid,timestamptz,text,text,text,text) to authenticated;
-- First administrator: create Auth account in dashboard, then run a separate one-time
-- INSERT INTO public.profiles(id,role) VALUES ('REAL_AUTH_USER_UUID','admin');
-- Disable public sign-up; enable Auth rate limits and strong password policy.
create function public.reschedule_appointment(p_id uuid,p_start timestamptz) returns void language plpgsql security invoker set search_path=public as $$
declare item public.appointments; dur integer; finish timestamptz; local_start timestamp; local_finish timestamp;
begin
 if not private.is_admin() then raise exception 'Administrator required'; end if;
 select * into item from public.appointments where id=p_id for update;
 if item.id is null or item.status not in ('pending','confirmed') then raise exception 'Appointment cannot be rescheduled'; end if;
 select duration_minutes into dur from public.services where id=item.service_id and active;
 if dur is null or p_start<=now() then raise exception 'Invalid duration or date'; end if;
 finish=p_start+make_interval(mins=>dur);local_start=p_start at time zone 'America/Sao_Paulo';local_finish=finish at time zone 'America/Sao_Paulo';
 if local_start::date<>local_finish::date or not exists(select 1 from public.professional_availability where professional_id=item.professional_id and weekday=extract(dow from local_start) and starts_at<=local_start::time and ends_at>=local_finish::time) then raise exception 'Outside professional schedule'; end if;
 if exists(select 1 from public.availability_exceptions where professional_id=item.professional_id and tstzrange(starts_at,ends_at,'[)') && tstzrange(p_start,finish,'[)')) then raise exception 'Professional unavailable'; end if;
 update public.appointments set starts_at=p_start,ends_at=finish where id=p_id;
end $$;
revoke all on function public.reschedule_appointment(uuid,timestamptz) from public,anon;
grant execute on function public.reschedule_appointment(uuid,timestamptz) to authenticated;

-- Least privilege, independent of project default grants.
revoke execute on function private.is_admin() from public,anon;
grant execute on function private.is_admin() to authenticated;
revoke execute on function private.log_admin_change() from public,anon,authenticated;
do $$ declare t text; begin foreach t in array array['profiles','service_categories','services','professionals','professional_services','professional_availability','availability_exceptions','appointments','appointment_status_history','gallery_items','testimonials','bridal_inquiries','site_settings','content_sections','audit_logs'] loop
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop; end $$;
grant select on public.service_categories,public.services,public.professionals,public.gallery_items,public.testimonials,public.content_sections to anon;
revoke insert,update,delete on public.audit_logs,public.appointment_status_history from authenticated;
create index professional_services_service_idx on public.professional_services(service_id);
create index services_category_idx on public.services(category_slug);
create index professional_availability_professional_idx on public.professional_availability(professional_id,weekday);
create index availability_exceptions_professional_idx on public.availability_exceptions(professional_id,starts_at);
create index appointments_service_idx on public.appointments(service_id);
create index appointment_history_appointment_idx on public.appointment_status_history(appointment_id);
create index appointment_history_actor_idx on public.appointment_status_history(actor_id);
create index audit_actor_idx on public.audit_logs(actor_id);
create index audit_created_idx on public.audit_logs(created_at);
