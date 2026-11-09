-- Etapa 1: quién puede leer y escribir cada tabla.
--
-- Roles de Supabase:
-- * anon: el público, cualquiera que abra el sitio sin iniciar sesión.
-- * authenticated: alguien con sesión iniciada. Solo es admin si figura en administradores.
-- * service_role: el servidor de Next.js con la clave secreta. Ignora RLS; nunca llega al navegador.
--
-- Hay dos capas:
-- 1. Permisos (grant/revoke): qué tablas puede tocar cada rol. Supabase da todo por defecto,
--    así que primero se quita todo y después se da solo lo necesario.
-- 2. RLS (políticas): qué filas ve cada uno dentro de las tablas permitidas.


-- Funciones privadas ----------------------------------------------------------------------------

-- El esquema privado no se publica en la API: sus funciones no se pueden llamar desde el navegador,
-- pero las políticas de RLS sí las usan.
create schema privado;
revoke all on schema privado from public;
grant usage on schema privado to anon, authenticated, service_role;

-- true si quien hace la consulta es un administrador.
-- security definer: lee administradores con permisos del dueño, sin pasar por RLS
-- (si pasara por RLS, la política de administradores se llamaría a sí misma).
create function privado.es_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.administradores as a
    where a.user_id = (select auth.uid())
  );
$$;

revoke all on function privado.es_admin() from public;
grant execute on function privado.es_admin() to anon, authenticated, service_role;


-- Permisos por tabla ----------------------------------------------------------------------------

revoke all on table
  public.ajustes,
  public.horario_general,
  public.servicios,
  public.peluqueros,
  public.horarios,
  public.bloqueos,
  public.turnos,
  public.administradores
from anon, authenticated;

-- El público solo lee lo necesario para mostrar servicios, peluqueros y horarios.
grant select on table
  public.ajustes,
  public.servicios,
  public.peluqueros,
  public.horarios
to anon;

-- Con sesión iniciada se puede intentar todo; las políticas de abajo lo limitan a los admins.
grant select, update on table public.ajustes to authenticated;
grant select, insert, update, delete on table
  public.horario_general,
  public.servicios,
  public.peluqueros,
  public.horarios,
  public.bloqueos,
  public.turnos
to authenticated;
-- Los administradores se cargan desde el SQL Editor, no desde la app.
grant select on table public.administradores to authenticated;

grant all on table
  public.ajustes,
  public.horario_general,
  public.servicios,
  public.peluqueros,
  public.horarios,
  public.bloqueos,
  public.turnos,
  public.administradores
to service_role;


-- RLS -------------------------------------------------------------------------------------------

alter table public.ajustes enable row level security;
alter table public.horario_general enable row level security;
alter table public.servicios enable row level security;
alter table public.peluqueros enable row level security;
alter table public.horarios enable row level security;
alter table public.bloqueos enable row level security;
alter table public.turnos enable row level security;
alter table public.administradores enable row level security;

-- (select privado.es_admin()) va entre paréntesis con select para que Postgres lo calcule
-- una vez por consulta y no una vez por fila.

-- ajustes: todos leen; solo el admin modifica. Nadie agrega ni borra filas.
create policy "todos leen los ajustes"
  on public.ajustes for select
  to anon, authenticated
  using (true);

create policy "el admin modifica los ajustes"
  on public.ajustes for update
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

-- horario_general: solo el admin.
create policy "el admin gestiona el horario general"
  on public.horario_general for all
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

-- servicios: el público ve los activos; el admin ve y gestiona todos.
create policy "se leen los servicios activos"
  on public.servicios for select
  to anon, authenticated
  using (activo or (select privado.es_admin()));

create policy "el admin crea servicios"
  on public.servicios for insert
  to authenticated
  with check ((select privado.es_admin()));

create policy "el admin modifica servicios"
  on public.servicios for update
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

create policy "el admin borra servicios"
  on public.servicios for delete
  to authenticated
  using ((select privado.es_admin()));

-- peluqueros: igual que servicios.
create policy "se leen los peluqueros activos"
  on public.peluqueros for select
  to anon, authenticated
  using (activo or (select privado.es_admin()));

create policy "el admin crea peluqueros"
  on public.peluqueros for insert
  to authenticated
  with check ((select privado.es_admin()));

create policy "el admin modifica peluqueros"
  on public.peluqueros for update
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

create policy "el admin borra peluqueros"
  on public.peluqueros for delete
  to authenticated
  using ((select privado.es_admin()));

-- horarios: todos leen (son solo días y horas); solo el admin modifica.
create policy "todos leen los horarios"
  on public.horarios for select
  to anon, authenticated
  using (true);

create policy "el admin crea horarios"
  on public.horarios for insert
  to authenticated
  with check ((select privado.es_admin()));

create policy "el admin modifica horarios"
  on public.horarios for update
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

create policy "el admin borra horarios"
  on public.horarios for delete
  to authenticated
  using ((select privado.es_admin()));

-- bloqueos y turnos: solo el admin. El público usa la función ocupacion().
create policy "el admin gestiona los bloqueos"
  on public.bloqueos for all
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

create policy "el admin gestiona los turnos"
  on public.turnos for all
  to authenticated
  using ((select privado.es_admin()))
  with check ((select privado.es_admin()));

-- administradores: el admin ve la lista; nadie la modifica desde la app.
create policy "el admin ve los administradores"
  on public.administradores for select
  to authenticated
  using ((select privado.es_admin()));


-- Funciones públicas ----------------------------------------------------------------------------

-- Períodos ocupados entre dos instantes: turnos confirmados y bloqueos.
-- Devuelve solo peluquero, inicio, fin y tipo ('turno' o 'bloqueo'):
-- nunca nombres, teléfonos ni motivos. peluquero_id vacío = bloqueo de toda la peluquería.
-- La usa el cálculo de horarios disponibles (etapa 2).
create function public.ocupacion(p_desde timestamptz, p_hasta timestamptz)
returns table (peluquero_id bigint, inicio timestamptz, fin timestamptz, tipo text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_desde is null or p_hasta is null or p_hasta <= p_desde then
    raise exception 'El rango no es válido: "hasta" tiene que ser posterior a "desde".'
      using errcode = '22023';
  end if;

  if p_hasta - p_desde > interval '62 days' then
    raise exception 'El rango no puede superar los 62 días.'
      using errcode = '22023';
  end if;

  return query
    select t.peluquero_id, t.inicio, t.fin, 'turno'::text
    from public.turnos as t
    where t.estado = 'confirmado'
      and t.inicio < p_hasta
      and t.fin > p_desde
    union all
    select b.peluquero_id, b.inicio, b.fin, 'bloqueo'::text
    from public.bloqueos as b
    where b.inicio < p_hasta
      and b.fin > p_desde
    order by 2, 1;
end;
$$;

revoke all on function public.ocupacion(timestamptz, timestamptz) from public;
grant execute on function public.ocupacion(timestamptz, timestamptz) to anon, authenticated, service_role;
