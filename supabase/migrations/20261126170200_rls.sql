-- =============================================================================
-- RLS y permisos
--
-- - anon: ningún permiso sobre tablas. El público solo va a entrar por las
--   funciones RPC del Sprint 2, habilitadas una por una.
-- - authenticated: permisos de tabla para el panel del dueño, pero RLS deja
--   pasar solo a quienes figuran en public.administradores.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- ¿El usuario autenticado es administrador?
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER para leer administradores sin depender de sus propias
-- políticas (evita recursión). search_path vacío para que nadie pueda
-- interponer un objeto con el mismo nombre.
create function privado.es_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.administradores
    where user_id = (select auth.uid())
  );
$$;

revoke all on function privado.es_admin() from public, anon;
grant usage on schema privado to authenticated;
grant execute on function privado.es_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Revocación explícita
-- ---------------------------------------------------------------------------
-- La migración seguridad_base ya cierra los permisos por defecto. Esto lo
-- repite sobre lo que ya existe, por si un entorno trajera otros valores.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS en todas las tablas
-- ---------------------------------------------------------------------------
alter table public.peluqueros enable row level security;
alter table public.servicios enable row level security;
alter table public.horarios enable row level security;
alter table public.bloqueos enable row level security;
alter table public.clientes enable row level security;
alter table public.reservas enable row level security;
alter table public.reserva_servicios enable row level security;
alter table public.configuracion enable row level security;
alter table public.administradores enable row level security;

-- ---------------------------------------------------------------------------
-- Permisos del panel (authenticated). RLS los limita a administradores.
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on
  public.peluqueros,
  public.servicios,
  public.horarios,
  public.bloqueos,
  public.clientes,
  public.reservas,
  public.reserva_servicios
to authenticated;

-- La configuración es una sola fila: se lee y se modifica, no se crea ni se borra.
grant select, update on public.configuracion to authenticated;

-- Cada usuario solo puede consultar si él mismo es administrador. Las altas y
-- bajas de administradores se hacen por SQL, no desde el panel.
grant select on public.administradores to authenticated;

-- Las columnas identity necesitan su secuencia para generar ids al insertar.
grant usage on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Políticas
-- ---------------------------------------------------------------------------
-- (select privado.es_admin()) entre paréntesis: Postgres lo evalúa una vez por
-- consulta y no una vez por fila.
create policy "administradores gestionan peluqueros" on public.peluqueros
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan servicios" on public.servicios
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan horarios" on public.horarios
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan bloqueos" on public.bloqueos
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan clientes" on public.clientes
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan reservas" on public.reservas
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan servicios de reservas" on public.reserva_servicios
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "administradores gestionan la configuración" on public.configuracion
  for all to authenticated
  using ((select privado.es_admin())) with check ((select privado.es_admin()));

create policy "cada usuario ve solo su propia fila" on public.administradores
  for select to authenticated
  using (user_id = (select auth.uid()));
