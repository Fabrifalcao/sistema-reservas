-- Etapa 1: tablas, regla de no superposición y datos fijos.
--
-- Convenciones:
-- * Los instantes (inicio y fin de turnos y bloqueos) son timestamptz y se guardan en UTC.
--   La conversión a America/Asuncion la hace TypeScript, no la base.
-- * Los horarios semanales son time en hora local de Asunción.
-- * dia_semana va de 1 (lunes) a 7 (domingo), como el estándar ISO.
-- * Los precios son guaraníes enteros.

-- Permite combinar "mismo peluquero" (=) con "rangos que se pisan" (&&) en una exclusion constraint.
create extension if not exists btree_gist with schema extensions;


-- Ajustes ---------------------------------------------------------------------------------------

create table public.ajustes (
  -- Truco para que la tabla tenga una sola fila: la clave solo puede valer true.
  id boolean primary key default true check (id),
  intervalo_min smallint not null default 15 check (intervalo_min between 5 and 60),
  anticipacion_minima_min integer not null default 60 check (anticipacion_minima_min >= 0),
  anticipacion_maxima_dias smallint not null default 30 check (anticipacion_maxima_dias between 1 and 365),
  cancelacion_limite_horas smallint not null default 3 check (cancelacion_limite_horas >= 0),
  max_turnos_futuros smallint not null default 2 check (max_turnos_futuros >= 1)
);

comment on table public.ajustes is 'Reglas de negocio. Tiene una sola fila.';
comment on column public.ajustes.intervalo_min is 'Cada cuántos minutos se ofrece un horario (9:00, 9:15, 9:30…).';
comment on column public.ajustes.anticipacion_minima_min is 'Minutos mínimos entre ahora y el turno para poder reservarlo.';
comment on column public.ajustes.anticipacion_maxima_dias is 'Hasta cuántos días hacia adelante se puede reservar.';
comment on column public.ajustes.cancelacion_limite_horas is 'El cliente puede cancelar hasta esta cantidad de horas antes del turno.';
comment on column public.ajustes.max_turnos_futuros is 'Máximo de turnos futuros confirmados por teléfono.';

insert into public.ajustes default values;


-- Horario general -------------------------------------------------------------------------------

create table public.horario_general (
  id bigint generated always as identity primary key,
  dia_semana smallint not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin time not null,
  check (hora_fin > hora_inicio)
);

comment on table public.horario_general is
  'Plantilla para cargar el horario de un peluquero nuevo. La disponibilidad se calcula con la tabla horarios.';

insert into public.horario_general (dia_semana, hora_inicio, hora_fin) values
  (1, '09:00', '19:00'),
  (2, '09:00', '19:00'),
  (3, '09:00', '19:00'),
  (4, '09:00', '19:00'),
  (5, '09:00', '19:00'),
  (6, '09:00', '13:00');


-- Servicios y peluqueros ------------------------------------------------------------------------

create table public.servicios (
  id bigint generated always as identity primary key,
  nombre text not null check (length(trim(nombre)) > 0),
  duracion_min smallint not null check (duracion_min between 5 and 480),
  precio_gs integer not null check (precio_gs >= 0),
  activo boolean not null default true,
  orden smallint not null default 0,
  creado_en timestamptz not null default now()
);

comment on table public.servicios is 'Lo que se puede reservar. No se borran: se desactivan con activo = false.';

create table public.peluqueros (
  id bigint generated always as identity primary key,
  nombre text not null check (length(trim(nombre)) > 0),
  activo boolean not null default true,
  orden smallint not null default 0,
  creado_en timestamptz not null default now()
);

comment on table public.peluqueros is
  'Quién atiende. "Cualquiera disponible" desempata por orden. No se borran: se desactivan con activo = false.';

create table public.horarios (
  id bigint generated always as identity primary key,
  peluquero_id bigint not null references public.peluqueros (id) on delete cascade,
  dia_semana smallint not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin time not null,
  check (hora_fin > hora_inicio)
);

comment on table public.horarios is
  'Horario semanal de cada peluquero, en hora local. El almuerzo se carga como dos franjas el mismo día.';

create index horarios_peluquero_dia_idx on public.horarios (peluquero_id, dia_semana);


-- Bloqueos --------------------------------------------------------------------------------------

create table public.bloqueos (
  id bigint generated always as identity primary key,
  -- Vacío (null) = bloquea a toda la peluquería, por ejemplo un feriado.
  peluquero_id bigint references public.peluqueros (id) on delete cascade,
  inicio timestamptz not null,
  fin timestamptz not null,
  motivo text,
  creado_en timestamptz not null default now(),
  check (fin > inicio)
);

comment on table public.bloqueos is
  'Excepciones al horario (vacaciones, feriados, trámites). Sin peluquero = toda la peluquería. El público no la lee.';

create index bloqueos_peluquero_idx on public.bloqueos (peluquero_id);
create index bloqueos_inicio_idx on public.bloqueos (inicio);


-- Turnos ----------------------------------------------------------------------------------------

create table public.turnos (
  id bigint generated always as identity primary key,
  -- Secreto del link de cancelación /turno/[token].
  token uuid not null unique default gen_random_uuid(),
  peluquero_id bigint not null references public.peluqueros (id) on delete restrict,
  servicio_id bigint not null references public.servicios (id) on delete restrict,
  inicio timestamptz not null,
  fin timestamptz not null,
  -- Copia del precio al reservar: si después cambia el precio del servicio, el turno no cambia.
  precio_gs integer not null check (precio_gs >= 0),
  cliente_nombre text not null check (length(trim(cliente_nombre)) between 1 and 80),
  -- Normalizado para wa.me: 0981 123 456 → 595981123456.
  cliente_telefono text not null check (cliente_telefono ~ '^595[0-9]{8,9}$'),
  estado text not null default 'confirmado' check (estado in ('confirmado', 'cancelado')),
  origen text not null check (origen in ('cliente', 'admin')),
  creado_en timestamptz not null default now(),
  cancelado_en timestamptz,
  cancelado_por text check (cancelado_por in ('cliente', 'admin')),

  check (fin > inicio),

  -- Un turno confirmado no tiene datos de cancelación; uno cancelado tiene los dos.
  constraint turnos_cancelacion_completa check (
    (estado = 'confirmado' and cancelado_en is null and cancelado_por is null)
    or (estado = 'cancelado' and cancelado_en is not null and cancelado_por is not null)
  ),

  -- Dos turnos confirmados del mismo peluquero nunca se superponen.
  -- '[)' incluye el inicio y excluye el fin: un turno que termina a las 10:00 y otro que
  -- empieza a las 10:00 no chocan. Los cancelados no cuentan.
  -- Si dos personas reservan a la vez, la segunda recibe el error 23P01.
  constraint turnos_sin_superposicion exclude using gist (
    peluquero_id with =,
    tstzrange(inicio, fin, '[)') with &&
  ) where (estado = 'confirmado')
);

comment on table public.turnos is
  'Reservas. El público no la lee: usa la función ocupacion(), que no expone datos de clientes.';

create index turnos_servicio_idx on public.turnos (servicio_id);
create index turnos_inicio_idx on public.turnos (inicio);
-- Para contar los turnos futuros de un teléfono.
create index turnos_telefono_idx on public.turnos (cliente_telefono, inicio) where estado = 'confirmado';


-- Administradores -------------------------------------------------------------------------------

create table public.administradores (
  user_id uuid primary key references auth.users (id) on delete cascade,
  creado_en timestamptz not null default now()
);

comment on table public.administradores is
  'Usuarios de Supabase que pueden usar el panel de administración. Se cargan desde el SQL Editor.';
