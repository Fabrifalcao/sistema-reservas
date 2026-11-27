-- =============================================================================
-- Esquema del sistema de reservas
--
-- Convenciones:
-- - Montos en guaraníes como enteros (integer): no existen los centavos.
-- - Reservas y bloqueos en timestamptz: son instantes reales.
-- - Los horarios semanales en time: son horas de reloj de America/Asuncion que
--   se repiten cada semana. Las funciones del Sprint 2 los convierten en
--   instantes usando el nombre IANA de la zona, nunca un offset fijo.
-- - Días de la semana según ISO 8601: 1 = lunes … 7 = domingo, igual que
--   extract(isodow from fecha).
-- - Peluqueros y servicios con historial no se borran: se desactivan.
-- - El cliente elige peluquero o "Cualquiera disponible". Todos los
--   peluqueros hacen todos los servicios.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
create type public.estado_reserva as enum ('confirmada', 'cancelada', 'completada', 'ausente');
comment on type public.estado_reserva is
  'ausente = el cliente no se presentó. Completada y ausente las marca el dueño desde el panel.';

create type public.actor_cancelacion as enum ('cliente', 'local');

create type public.tipo_bloqueo as enum ('bloqueo', 'feriado', 'vacaciones');

-- ---------------------------------------------------------------------------
-- Función auxiliar para mantener actualizado_en
-- ---------------------------------------------------------------------------
create function privado.marcar_actualizado()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Peluqueros
-- ---------------------------------------------------------------------------
create table public.peluqueros (
  id bigint generated always as identity primary key,
  nombre text not null check (char_length(btrim(nombre)) between 2 and 60),
  activo boolean not null default true,
  orden smallint not null default 0,
  creado_en timestamptz not null default now()
);
comment on table public.peluqueros is
  'Peluqueros del local. Si tienen reservas no se pueden borrar: se desactivan (activo = false).';

-- ---------------------------------------------------------------------------
-- Servicios
-- ---------------------------------------------------------------------------
create table public.servicios (
  id bigint generated always as identity primary key,
  nombre text not null check (char_length(btrim(nombre)) between 2 and 80),
  descripcion text check (char_length(descripcion) <= 300),
  -- Múltiplo de 5 para que los bloques encajen en cualquier grilla permitida.
  duracion_min smallint not null check (duracion_min between 5 and 480 and duracion_min % 5 = 0),
  precio_gs integer not null check (precio_gs >= 0),
  activo boolean not null default true,
  orden smallint not null default 0,
  creado_en timestamptz not null default now()
);
comment on table public.servicios is
  'Servicios que ofrece el local. Todos los peluqueros hacen todos. Si tienen reservas no se borran: se desactivan.';

-- ---------------------------------------------------------------------------
-- Horario semanal de cada peluquero
-- ---------------------------------------------------------------------------
create table public.horarios (
  id bigint generated always as identity primary key,
  peluquero_id bigint not null references public.peluqueros (id) on delete cascade,
  dia_semana smallint not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin time not null,
  constraint horarios_fin_despues_de_inicio check (hora_fin > hora_inicio),
  -- Un peluquero puede tener varias franjas el mismo día (horario partido),
  -- pero no superpuestas. Las horas se montan sobre una fecha fija cualquiera
  -- solo para poder armar un rango (tsrange); esa fecha no significa nada.
  constraint horarios_sin_solapamiento exclude using gist (
    peluquero_id with =,
    dia_semana with =,
    tsrange(date '2000-01-01' + hora_inicio, date '2000-01-01' + hora_fin) with &&
  )
);
comment on table public.horarios is
  'Franjas de trabajo semanales en hora local de America/Asuncion. Varias filas el mismo día = horario partido.';

-- ---------------------------------------------------------------------------
-- Bloqueos, feriados y vacaciones
-- ---------------------------------------------------------------------------
create table public.bloqueos (
  id bigint generated always as identity primary key,
  -- Sin peluquero = afecta a todo el local (feriado, cierre); con peluquero = solo a él.
  peluquero_id bigint references public.peluqueros (id) on delete cascade,
  tipo public.tipo_bloqueo not null default 'bloqueo',
  inicio timestamptz not null,
  fin timestamptz not null,
  motivo text check (char_length(motivo) <= 200),
  creado_en timestamptz not null default now(),
  constraint bloqueos_fin_despues_de_inicio check (fin > inicio),
  constraint bloqueos_feriado_es_de_todo_el_local check (tipo <> 'feriado' or peluquero_id is null)
);
-- La disponibilidad (Sprint 2) busca bloqueos que se solapen con un rango.
create index bloqueos_rango_idx on public.bloqueos using gist (tstzrange(inicio, fin, '[)'));

-- ---------------------------------------------------------------------------
-- Clientes (sin cuenta: se identifican por su WhatsApp)
-- ---------------------------------------------------------------------------
create table public.clientes (
  id bigint generated always as identity primary key,
  -- Último nombre que usó con este teléfono.
  nombre text not null check (char_length(btrim(nombre)) between 2 and 80),
  -- Celular paraguayo en formato E.164: +595 9XX XXX XXX. Identifica al
  -- cliente y es el destino de los mensajes de WhatsApp.
  telefono text not null unique check (telefono ~ '^\+5959[0-9]{8}$'),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create trigger clientes_actualizado_en
  before update on public.clientes
  for each row execute function privado.marcar_actualizado();

-- ---------------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------------
create table public.reservas (
  id bigint generated always as identity primary key,
  cliente_id bigint not null references public.clientes (id) on delete restrict,
  -- El que eligió el cliente o, con "Cualquiera disponible", el que asigna la
  -- función de reserva (Sprint 2): el menos cargado del día entre los que
  -- estén libres durante todo el bloque.
  peluquero_id bigint not null references public.peluqueros (id) on delete restrict,
  -- true = lo eligió el sistema ("Cualquiera disponible"). false = lo eligió una
  -- persona (el cliente o el dueño). Al reasignar un turno, el panel avisa si
  -- el cliente había pedido a ese peluquero.
  asignacion_automatica boolean not null default false,
  inicio timestamptz not null,
  fin timestamptz not null,
  estado public.estado_reserva not null default 'confirmada',
  -- 32 bytes aleatorios en hexadecimal (64 caracteres): imposible de adivinar.
  -- Se guarda en claro y no hasheado porque el recordatorio del Sprint 5 vuelve
  -- a enviar el enlace de cancelación. Está protegido porque anon no puede
  -- leer esta tabla: solo una función RPC lo compara.
  token_cancelacion text not null unique default encode(extensions.gen_random_bytes(32), 'hex'),
  cancelada_en timestamptz,
  cancelada_por public.actor_cancelacion,
  creado_en timestamptz not null default now(),
  constraint reservas_fin_despues_de_inicio check (fin > inicio),
  -- Los datos de cancelación existen si y solo si la reserva está cancelada.
  constraint reservas_datos_de_cancelacion check (
    (estado = 'cancelada' and cancelada_en is not null and cancelada_por is not null)
    or (estado <> 'cancelada' and cancelada_en is null and cancelada_por is null)
  ),
  -- Última línea de defensa contra turnos superpuestos: aunque dos reservas
  -- lleguen al mismo tiempo, la base rechaza la segunda. El rango es
  -- semiabierto [inicio, fin): un turno que termina a las 10:00 y otro que
  -- empieza a las 10:00 no chocan. Las canceladas no ocupan lugar.
  constraint reservas_sin_solapamiento exclude using gist (
    peluquero_id with =,
    tstzrange(inicio, fin, '[)') with &&
  ) where (estado <> 'cancelada')
);
create index reservas_inicio_idx on public.reservas (inicio);
create index reservas_cliente_idx on public.reservas (cliente_id);

-- ---------------------------------------------------------------------------
-- Servicios de cada reserva
-- ---------------------------------------------------------------------------
create table public.reserva_servicios (
  reserva_id bigint not null references public.reservas (id) on delete cascade,
  -- Posición dentro del bloque: el mismo peluquero los hace uno detrás de otro.
  orden smallint not null check (orden >= 1),
  servicio_id bigint not null references public.servicios (id) on delete restrict,
  -- Copias tomadas al reservar: si después cambia el precio o la duración del
  -- servicio, la reserva y las estadísticas conservan lo que se acordó.
  duracion_min smallint not null check (duracion_min between 5 and 480),
  precio_gs integer not null check (precio_gs >= 0),
  primary key (reserva_id, orden),
  unique (reserva_id, servicio_id)
);
create index reserva_servicios_servicio_idx on public.reserva_servicios (servicio_id);

-- ---------------------------------------------------------------------------
-- Configuración del local (una sola fila, editable por el dueño)
-- ---------------------------------------------------------------------------
-- Ajustes operativos de cada peluquería. La regla de cancelar hasta 3 horas
-- antes NO está acá: es del producto y vive en el código (Sprint 2).
create table public.configuracion (
  -- Tabla de una sola fila: la clave solo puede valer true.
  id boolean primary key default true check (id),
  intervalo_grilla_min smallint not null default 15
    check (intervalo_grilla_min in (5, 10, 15, 20, 30, 60)),
  anticipacion_minima_min smallint not null default 60
    check (anticipacion_minima_min between 0 and 10080),
  dias_a_futuro smallint not null default 30
    check (dias_a_futuro between 1 and 365),
  max_reservas_activas_por_telefono smallint not null default 2
    check (max_reservas_activas_por_telefono between 1 and 20),
  actualizado_en timestamptz not null default now()
);
comment on column public.configuracion.intervalo_grilla_min is 'Cada cuántos minutos se ofrece un horario de inicio.';
comment on column public.configuracion.anticipacion_minima_min is 'Minutos mínimos entre el momento de reservar y el inicio del turno.';
comment on column public.configuracion.dias_a_futuro is 'Hasta cuántos días hacia adelante se puede reservar.';
comment on column public.configuracion.max_reservas_activas_por_telefono is 'Antiabuso: reservas confirmadas y futuras que puede tener un mismo teléfono.';

insert into public.configuracion default values;

create trigger configuracion_actualizado_en
  before update on public.configuracion
  for each row execute function privado.marcar_actualizado();

-- ---------------------------------------------------------------------------
-- Administradores del panel
-- ---------------------------------------------------------------------------
-- Tener una cuenta de Auth no alcanza: solo los usuarios listados acá ven y
-- modifican datos. Así, aunque alguien lograra crearse una cuenta, no vería nada.
create table public.administradores (
  user_id uuid primary key references auth.users (id) on delete cascade,
  creado_en timestamptz not null default now()
);
