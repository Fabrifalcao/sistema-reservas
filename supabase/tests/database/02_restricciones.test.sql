-- =============================================================================
-- Restricciones del esquema: lo que la base rechaza por sí sola, aunque una
-- función o el panel tuvieran un error.
--
-- Corre con `npx supabase test db`, dentro de una transacción que se deshace.
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Datos propios del test. Las horas se escriben en hora local y se convierten
-- con la zona IANA, como en el resto del sistema.
insert into public.peluqueros (nombre) values ('Test A'), ('Test B');
insert into public.clientes (nombre, telefono) values ('Cliente Test', '+595900009101');

create temporary table t as
select
  (select id from public.peluqueros where nombre = 'Test A') as pa,
  (select id from public.peluqueros where nombre = 'Test B') as pb,
  (select id from public.clientes where telefono = '+595900009101') as cli;

-- Atajo: instante a partir de una hora local de un lunes de prueba.
create function pg_temp.lunes(hora text) returns timestamptz
language sql immutable
as $$ select (date '2030-01-07' + hora::time) at time zone 'America/Asuncion' $$;

-- -----------------------------------------------------------------------------
-- Reservas: sin turnos superpuestos para un mismo peluquero
-- -----------------------------------------------------------------------------
select lives_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('10:00'), pg_temp.lunes('10:30') from t$$,
  'Se crea una reserva de 10:00 a 10:30'
);

select throws_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('10:15'), pg_temp.lunes('10:45') from t$$,
  '23P01', null,
  'Rechaza una reserva que se superpone con otra del mismo peluquero'
);

select throws_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('09:00'), pg_temp.lunes('11:00') from t$$,
  '23P01', null,
  'Rechaza una reserva que contiene por completo a otra'
);

select lives_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('10:30'), pg_temp.lunes('11:00') from t$$,
  'Acepta una reserva que empieza justo cuando termina la anterior'
);

select lives_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pb, pg_temp.lunes('10:00'), pg_temp.lunes('10:30') from t$$,
  'Acepta la misma hora con otro peluquero'
);

select lives_ok(
  $$update public.reservas set estado = 'cancelada', cancelada_en = now(), cancelada_por = 'cliente'
    where peluquero_id = (select pa from t) and inicio = pg_temp.lunes('10:00')$$,
  'Se cancela la reserva de las 10:00'
);

select lives_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('10:00'), pg_temp.lunes('10:30') from t$$,
  'Una reserva cancelada libera su horario'
);

select throws_ok(
  $$insert into public.reservas (cliente_id, peluquero_id, inicio, fin)
    select cli, pa, pg_temp.lunes('12:00'), pg_temp.lunes('12:00') from t$$,
  '23514', null,
  'Rechaza una reserva que termina cuando empieza'
);

select throws_ok(
  $$update public.reservas set estado = 'cancelada'
    where peluquero_id = (select pb from t)$$,
  '23514', null,
  'Rechaza cancelar sin registrar cuándo ni quién'
);

select throws_ok(
  $$update public.reservas set cancelada_por = 'local'
    where peluquero_id = (select pb from t)$$,
  '23514', null,
  'Rechaza datos de cancelación en una reserva no cancelada'
);

select is(
  (select length(token_cancelacion) from public.reservas where peluquero_id = (select pb from t)),
  64,
  'El token de cancelación se genera solo y tiene 64 caracteres'
);

select throws_ok(
  $$delete from public.peluqueros where nombre = 'Test A'$$,
  '23503', null,
  'No se puede borrar un peluquero con reservas'
);

-- -----------------------------------------------------------------------------
-- Horarios: franjas sin superposición, horario partido permitido
-- -----------------------------------------------------------------------------
select lives_ok(
  $$insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
    select pa, 1, '08:00', '12:00' from t$$,
  'Se carga la franja de la mañana del lunes'
);

select lives_ok(
  $$insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
    select pa, 1, '14:00', '19:00' from t$$,
  'Se carga la franja de la tarde del mismo lunes (horario partido)'
);

select throws_ok(
  $$insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
    select pa, 1, '11:00', '15:00' from t$$,
  '23P01', null,
  'Rechaza una franja que se superpone con otra del mismo día'
);

select lives_ok(
  $$insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
    select pa, 2, '11:00', '15:00' from t$$,
  'Acepta esa misma franja otro día'
);

select throws_ok(
  $$insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
    select pb, 8, '09:00', '10:00' from t$$,
  '23514', null,
  'Rechaza un día de la semana fuera de 1 a 7'
);

-- -----------------------------------------------------------------------------
-- Clientes, servicios, bloqueos y configuración
-- -----------------------------------------------------------------------------
select throws_ok(
  $$insert into public.clientes (nombre, telefono) values ('Sin prefijo', '0981123456')$$,
  '23514', null,
  'Rechaza un teléfono sin el formato +595'
);

select throws_ok(
  $$insert into public.clientes (nombre, telefono) values ('Fijo', '+595211234567')$$,
  '23514', null,
  'Rechaza un número que no es de celular (no empieza con 9)'
);

select throws_ok(
  $$insert into public.clientes (nombre, telefono) values ('Repetido', '+595900009101')$$,
  '23505', null,
  'Rechaza un teléfono repetido'
);

select throws_ok(
  $$insert into public.servicios (nombre, duracion_min, precio_gs) values ('Raro', 32, 50000)$$,
  '23514', null,
  'Rechaza una duración que no es múltiplo de 5'
);

select throws_ok(
  $$insert into public.servicios (nombre, duracion_min, precio_gs) values ('Negativo', 30, -1)$$,
  '23514', null,
  'Rechaza un precio negativo'
);

select throws_ok(
  $$insert into public.bloqueos (peluquero_id, tipo, inicio, fin)
    select pa, 'feriado', pg_temp.lunes('00:00'), pg_temp.lunes('23:00') from t$$,
  '23514', null,
  'Un feriado es de todo el local: no puede tener peluquero'
);

select throws_ok(
  $$insert into public.configuracion default values$$,
  '23505', null,
  'La configuración es una sola fila'
);

select * from finish();
rollback;
