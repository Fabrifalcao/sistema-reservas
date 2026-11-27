-- =============================================================================
-- Seguridad: RLS, permisos de anon y acceso solo para administradores.
--
-- Corre con `npx supabase test db`. Todo pasa dentro de una transacción que se
-- deshace al final: no deja datos en la base.
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- -----------------------------------------------------------------------------
-- Estructura de permisos
-- -----------------------------------------------------------------------------
select is(
  array(
    select c.relname::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
    order by 1
  ),
  '{}'::text[],
  'Todas las tablas de public tienen RLS activado'
);

select is(
  array(
    select c.relname::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
    order by 1
  ),
  '{}'::text[],
  'anon no tiene ningún permiso sobre tablas ni vistas de public'
);

select is(
  array(
    select c.relname::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    -- El CASE garantiza que has_sequence_privilege solo se evalúe sobre
    -- secuencias: Postgres no respeta el orden de las condiciones de un WHERE.
    where n.nspname = 'public'
      and case when c.relkind = 'S' then has_sequence_privilege('anon', c.oid, 'USAGE, SELECT, UPDATE') else false end
    order by 1
  ),
  '{}'::text[],
  'anon no tiene permisos sobre secuencias de public'
);

-- Lista blanca de funciones RPC públicas. Vacía por ahora: el Sprint 2 agrega
-- acá, una por una, las que anon puede ejecutar.
select is(
  array(
    select p.oid::regprocedure::text
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'EXECUTE')
    order by 1
  ),
  '{}'::text[],
  'anon solo puede ejecutar las funciones RPC públicas aprobadas'
);

select ok(
  not has_function_privilege('anon', 'privado.es_admin()', 'EXECUTE'),
  'anon no puede ejecutar privado.es_admin()'
);

select ok(
  not has_schema_privilege('anon', 'privado', 'USAGE'),
  'anon no tiene acceso al esquema privado'
);

-- -----------------------------------------------------------------------------
-- Datos propios del test
-- -----------------------------------------------------------------------------
insert into auth.users (id, aud, role, email) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'admin@test.local'),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'intruso@test.local');
insert into public.administradores (user_id) values ('11111111-1111-4111-8111-111111111111');
insert into public.peluqueros (nombre) values ('Peluquero de prueba');
insert into public.clientes (nombre, telefono) values ('Cliente de prueba', '+595900009001');

-- -----------------------------------------------------------------------------
-- anon: rechazado de entrada
-- -----------------------------------------------------------------------------
set local role anon;

select throws_ok(
  'select * from public.reservas',
  '42501', null,
  'anon no puede leer reservas'
);

select throws_ok(
  $$insert into public.clientes (nombre, telefono) values ('Anónimo', '+595900009002')$$,
  '42501', null,
  'anon no puede crear clientes'
);

reset role;

-- -----------------------------------------------------------------------------
-- Usuario autenticado que NO es administrador
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "22222222-2222-4222-8222-222222222222", "role": "authenticated"}', true);

select is_empty('select * from public.peluqueros', 'Un usuario que no es admin no ve peluqueros');
select is_empty('select * from public.configuracion', 'Un usuario que no es admin no ve la configuración');
select is_empty('select * from public.administradores', 'Un usuario que no es admin no ve la lista de administradores');

select throws_ok(
  $$insert into public.peluqueros (nombre) values ('Intruso')$$,
  '42501', null,
  'Un usuario que no es admin no puede crear peluqueros'
);

reset role;

-- -----------------------------------------------------------------------------
-- Administrador
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "11111111-1111-4111-8111-111111111111", "role": "authenticated"}', true);

select isnt_empty('select * from public.peluqueros', 'Un admin ve los peluqueros');

select is(
  (select count(*) from public.configuracion)::int, 1,
  'Un admin ve la fila de configuración'
);

select lives_ok(
  $$insert into public.servicios (nombre, duracion_min, precio_gs) values ('Servicio de prueba', 30, 50000)$$,
  'Un admin puede crear servicios'
);

-- También comprueba que el token de cancelación por defecto se genere con
-- los permisos de authenticated.
select lives_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select c.id, p.id, timestamptz '2030-01-07 13:00Z', timestamptz '2030-01-07 13:30Z'
    from public.clientes c, public.peluqueros p
    where c.telefono = '+595900009001' and p.nombre = 'Peluquero de prueba'$$,
  'Un admin puede crear reservas'
);

select throws_ok(
  $$delete from public.configuracion$$,
  '42501', null,
  'Nadie puede borrar la fila de configuración desde el panel'
);

reset role;

select * from finish();
rollback;
