-- Combine authenticated read rules; anonymous remains read-only for approved content.
do $$ declare t text; predicate text; begin
 foreach t in array array['profiles','service_categories','services','professionals','professional_services','professional_availability','availability_exceptions','appointments','appointment_status_history','gallery_items','testimonials','bridal_inquiries','site_settings','content_sections','audit_logs'] loop
 execute format('drop policy admin_all on public.%I',t);
 predicate := case t when 'profiles' then 'id=(select auth.uid()) or (select private.is_admin())' when 'service_categories' then 'true' when 'content_sections' then 'true' when 'services' then 'active or (select private.is_admin())' when 'professionals' then 'active or (select private.is_admin())' when 'gallery_items' then 'authorized or (select private.is_admin())' when 'testimonials' then 'authorized or (select private.is_admin())' else '(select private.is_admin())' end;
 execute format('create policy authenticated_read on public.%I for select to authenticated using(%s)',t,predicate);
 if t not in ('audit_logs','appointment_status_history') then
 execute format('create policy admin_insert on public.%I for insert to authenticated with check((select private.is_admin()))',t);
 execute format('create policy admin_update on public.%I for update to authenticated using((select private.is_admin())) with check((select private.is_admin()))',t);
 execute format('create policy admin_delete on public.%I for delete to authenticated using((select private.is_admin()))',t);
 end if;
 end loop;
end $$;
drop policy own_profile on public.profiles;
alter policy public_categories on public.service_categories to anon;
alter policy public_services on public.services to anon;
alter policy public_professionals on public.professionals to anon;
alter policy public_gallery on public.gallery_items to anon;
alter policy public_testimonials on public.testimonials to anon;
alter policy public_content on public.content_sections to anon;
-- All table writes, including direct REST edits, respect appointment eligibility and schedule.
create function private.validate_appointment() returns trigger language plpgsql security invoker set search_path=public as $$
declare duration integer; local_start timestamp; local_end timestamp; must_check boolean;
begin
 must_check := TG_OP='INSERT';
 if TG_OP='UPDATE' then must_check := new.starts_at is distinct from old.starts_at or new.ends_at is distinct from old.ends_at or new.professional_id is distinct from old.professional_id or new.service_id is distinct from old.service_id or (old.status not in ('pending','confirmed') and new.status in ('pending','confirmed')); end if;
 if not must_check or new.status not in ('pending','confirmed') then return new; end if;
 select duration_minutes into duration from public.services where id=new.service_id and active;
 if duration is null or new.ends_at<>new.starts_at+make_interval(mins=>duration) then raise exception 'Confirmed service duration required' using errcode='23514'; end if;
 if new.starts_at<=now() then raise exception 'Appointment must be in future' using errcode='23514'; end if;
 if not exists(select 1 from public.professionals where id=new.professional_id and active) or not exists(select 1 from public.professional_services where professional_id=new.professional_id and service_id=new.service_id) then raise exception 'Professional not eligible' using errcode='23514'; end if;
 local_start=new.starts_at at time zone 'America/Sao_Paulo';local_end=new.ends_at at time zone 'America/Sao_Paulo';
 if local_start::date<>local_end::date or not exists(select 1 from public.professional_availability where professional_id=new.professional_id and weekday=extract(dow from local_start) and starts_at<=local_start::time and ends_at>=local_end::time) then raise exception 'Outside professional schedule' using errcode='23514'; end if;
 if exists(select 1 from public.availability_exceptions where professional_id=new.professional_id and tstzrange(starts_at,ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)')) then raise exception 'Professional unavailable' using errcode='23514'; end if;
 return new;
end $$;
revoke execute on function private.validate_appointment() from public,anon,authenticated;
create trigger enforce_appointment_schedule before insert or update on public.appointments for each row execute function private.validate_appointment();
