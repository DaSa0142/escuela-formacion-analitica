-- EFA • ejecutar en SQL Editor de Supabase una sola vez sobre un proyecto nuevo.
create extension if not exists pgcrypto;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '', email text not null default '', role text not null default 'student' check(role in ('student','admin')), created_at timestamptz default now());
create table public.courses (code text primary key, title text not null, level text not null check(level in ('Básico','Intermedio','Avanzado')), position int not null unique, hours int not null check(hours>0), published boolean not null default true);
create table public.modules (code text primary key, course_code text not null references public.courses(code) on delete cascade, position int not null, title text not null, description text not null default '', video_url text not null default '', resource_url text not null default '', published boolean not null default true, unique(course_code,position));
create table public.enrollments (user_id uuid not null references auth.users(id) on delete cascade, course_code text not null references public.courses(code), created_at timestamptz default now(), primary key(user_id,course_code));
create table public.questions (id uuid primary key default gen_random_uuid(), module_code text not null references public.modules(code) on delete cascade, prompt text not null, options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options)>=2), explanation text not null default '', position int not null default 1);
-- NEVER expose question correct answers via SELECT to student role.
create table public.question_keys (question_id uuid primary key references public.questions(id) on delete cascade, correct_index int not null check(correct_index>=0));
create table public.attempts (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, module_code text not null references public.modules(code), score int not null check(score between 0 and 100), answers jsonb not null default '[]', created_at timestamptz not null default now());
create table public.certificates (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, course_code text references public.courses(code), token text not null unique default upper(encode(gen_random_bytes(12),'hex')), issued_at timestamptz not null default now(), unique nulls not distinct(user_id,course_code));
create table public.audit_log(id bigint generated always as identity primary key, actor uuid not null, action text not null, details jsonb not null default '{}', created_at timestamptz default now());
create index on public.modules(course_code,position);
create index on public.attempts(user_id,module_code,score);
create index on public.certificates(user_id);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists (select 1 from public.profiles where id=auth.uid() and role='admin') $$;
create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id,email,full_name) values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'name','')) on conflict(id) do nothing; return new; end $$;
create trigger auth_user_created after insert on auth.users for each row execute function public.new_profile();
-- RLS
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.modules enable row level security;
alter table public.enrollments enable row level security;
alter table public.questions enable row level security;
alter table public.question_keys enable row level security;
alter table public.attempts enable row level security;
alter table public.certificates enable row level security;
alter table public.audit_log enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy courses_read on public.courses for select to authenticated using(published or public.is_admin());
create policy courses_admin_write on public.courses for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy modules_read on public.modules for select to authenticated using(published or public.is_admin());
create policy modules_admin_write on public.modules for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy enrollments_read on public.enrollments for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy questions_read on public.questions for select to authenticated using(exists(select 1 from public.enrollments e join public.modules m on m.course_code=e.course_code where m.code=module_code and e.user_id=auth.uid()) or public.is_admin());
create policy attempts_read on public.attempts for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy certificates_read on public.certificates for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy audit_read on public.audit_log for select to authenticated using(public.is_admin());
-- Explicit least privilege: no direct inserts to enrollments/attempts/certificates/answers.
revoke all on public.question_keys from anon,authenticated;
revoke insert,update,delete on public.attempts,public.enrollments,public.certificates,public.audit_log from anon,authenticated;
revoke insert,update,delete on public.questions from anon,authenticated;
-- Only authenticated users may invoke transactional enrollment/grading RPCs.
create or replace function public.enroll_next(p_course text) returns text language plpgsql security definer set search_path='' as $$
declare v_position int; v_previous text;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 select position into v_position from public.courses where code=p_course and published;
 if v_position is null then raise exception 'Curso no disponible'; end if;
 select code into v_previous from public.courses where position=v_position-1;
 if v_previous is not null and not public.course_completed(auth.uid(),v_previous) then raise exception 'Debes aprobar el curso anterior'; end if;
 if exists(select 1 from public.enrollments where user_id=auth.uid() and course_code=p_course) then return 'Ya estás matriculado'; end if;
 insert into public.enrollments(user_id,course_code) values(auth.uid(),p_course);
 return 'Matrícula registrada';
end $$;
create or replace function public.module_passed(p_user uuid,p_module text) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.attempts where user_id=p_user and module_code=p_module and score>=70) $$;
create or replace function public.course_completed(p_user uuid,p_course text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.enrollments where user_id=p_user and course_code=p_course) and exists(select 1 from public.modules where course_code=p_course and published) and not exists (select 1 from public.modules m where m.course_code=p_course and m.published and not public.module_passed(p_user,m.code));
$$;
create or replace function public.submit_quiz(p_module text,p_answers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_course text; v_pos int; v_total int; v_correct int; v_score int; v_attempts int; v_max int:=3; v_current int; r record; v_response jsonb:='[]';
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 select course_code,position into v_course,v_pos from public.modules where code=p_module and published;
 if v_course is null then raise exception 'Módulo no disponible'; end if;
 if not exists(select 1 from public.enrollments where user_id=auth.uid() and course_code=v_course) then raise exception 'Debes matricularte primero'; end if;
 if exists(select 1 from public.modules m where m.course_code=v_course and m.position<v_pos and m.published and not public.module_passed(auth.uid(),m.code)) then raise exception 'Aprueba primero el módulo anterior'; end if;
 if public.module_passed(auth.uid(),p_module) then raise exception 'Ya has aprobado este módulo'; end if;
 select count(*) into v_attempts from public.attempts where user_id=auth.uid() and module_code=p_module;
 if v_attempts>=v_max then raise exception 'Has agotado los 3 intentos. Solicita revisión al administrador'; end if;
 if jsonb_typeof(p_answers) <> 'array' then raise exception 'Formato de respuestas no válido'; end if;
 select count(*) into v_total from public.questions where module_code=p_module;
 if v_total<3 then raise exception 'Esta evaluación todavía no tiene 3 preguntas publicadas'; end if;
 if jsonb_array_length(p_answers)<>v_total then raise exception 'Responde todas las preguntas'; end if;
 v_correct:=0; v_current:=0;
 for r in select q.id,q.options,k.correct_index from public.questions q join public.question_keys k on k.question_id=q.id where q.module_code=p_module order by q.position,q.id loop
   if v_current >= jsonb_array_length(p_answers) or jsonb_typeof(p_answers->v_current) <> 'number' then raise exception 'Respuesta inválida'; end if;
   if (p_answers->>v_current)::int<0 or (p_answers->>v_current)::int>=jsonb_array_length(r.options) then raise exception 'Índice de respuesta inválido'; end if;
   if (p_answers->>v_current)::int=r.correct_index then v_correct:=v_correct+1; end if;
   v_current:=v_current+1;
 end loop;
 if v_current<>v_total then raise exception 'Preguntas sin clave de corrección'; end if;
 v_score:=round(100.0*v_correct/v_total);
 insert into public.attempts(user_id,module_code,score,answers) values(auth.uid(),p_module,v_score,p_answers);
 return jsonb_build_object('score',v_score,'passed',v_score>=70,'remaining',v_max-v_attempts-1);
end $$;
create or replace function public.issue_certificate(p_course text default null) returns table(token text,issued_at timestamptz,course_code text) language plpgsql security definer set search_path='' as $$
declare c record;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 if p_course is not null then
  if not public.course_completed(auth.uid(),p_course) then raise exception 'Curso no aprobado'; end if;
 else
  if exists(select 1 from public.courses where published and not public.course_completed(auth.uid(),code)) then raise exception 'Primero debes aprobar todos los cursos'; end if;
 end if;
 insert into public.certificates(user_id,course_code) values(auth.uid(),p_course) on conflict (user_id,course_code) do nothing;
 return query select c2.token,c2.issued_at,c2.course_code from public.certificates c2 where c2.user_id=auth.uid() and c2.course_code is not distinct from p_course;
end $$;
create or replace function public.verify_certificate(p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare c record;
begin
 select cert.token,cert.issued_at,cert.course_code,p.full_name,coalesce(co.title,'Programa Integral de Formación Analítica') as title,coalesce(co.hours,(select sum(hours) from public.courses)) as hours into c from public.certificates cert join public.profiles p on p.id=cert.user_id left join public.courses co on co.code=cert.course_code where cert.token=upper(trim(p_token));
 if c.token is null then return jsonb_build_object('valid',false); end if;
 return jsonb_build_object('valid',true,'holder',c.full_name,'course',c.title,'course_code',c.course_code,'hours',c.hours,'issued_at',c.issued_at,'token',c.token);
end $$;
-- Admin: edit question and answer atomically. Store correct answer exclusively in protected table.
create or replace function public.admin_save_question(p_id uuid,p_module text,p_prompt text,p_options jsonb,p_correct int,p_explanation text default '',p_position int default 1) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not public.is_admin() then raise exception 'Solo administradores'; end if;
 if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<2 or p_correct<0 or p_correct>=jsonb_array_length(p_options) then raise exception 'Opciones incorrectas'; end if;
 if p_id is null then insert into public.questions(module_code,prompt,options,explanation,position) values(p_module,p_prompt,p_options,coalesce(p_explanation,''),p_position) returning id into v_id;
 else update public.questions set prompt=p_prompt,options=p_options,explanation=coalesce(p_explanation,''),position=p_position,module_code=p_module where id=p_id returning id into v_id; end if;
 if v_id is null then raise exception 'Pregunta no encontrada'; end if;
 insert into public.question_keys(question_id,correct_index) values(v_id,p_correct) on conflict(question_id) do update set correct_index=excluded.correct_index;
 insert into public.audit_log(actor,action,details) values(auth.uid(),'save_question',jsonb_build_object('question',v_id,'module',p_module));
 return v_id;
end $$;
create or replace function public.admin_correct_grade(p_user uuid,p_module text,p_score int,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Solo administradores'; end if;
 if p_score<0 or p_score>100 or length(trim(p_reason))<8 then raise exception 'Nota o justificación inválida'; end if;
 if not exists(select 1 from public.enrollments e join public.modules m on m.course_code=e.course_code where e.user_id=p_user and m.code=p_module) then raise exception 'Participante no matriculado'; end if;
 insert into public.attempts(user_id,module_code,score,answers) values(p_user,p_module,p_score,'[]');
 insert into public.audit_log(actor,action,details) values(auth.uid(),'grade_correction',jsonb_build_object('user_id',p_user,'module',p_module,'score',p_score,'reason',p_reason));
end $$;
revoke execute on function public.enroll_next(text),public.submit_quiz(text,jsonb),public.issue_certificate(text),public.admin_save_question(uuid,text,text,jsonb,int,text,int),public.admin_correct_grade(uuid,text,int,text),public.module_passed(uuid,text),public.course_completed(uuid,text),public.is_admin() from public,anon;
grant execute on function public.enroll_next(text),public.submit_quiz(text,jsonb),public.issue_certificate(text),public.admin_save_question(uuid,text,text,jsonb,int,text,int),public.admin_correct_grade(uuid,text,int,text),public.module_passed(uuid,text),public.course_completed(uuid,text),public.is_admin() to authenticated;
revoke execute on function public.verify_certificate(text) from public;
grant execute on function public.verify_certificate(text) to anon,authenticated;
