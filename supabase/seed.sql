-- =============================================================================
-- Datos de prueba de "Ónix Peluquería" (ficticia). SOLO PARA DESARROLLO LOCAL:
-- `npx supabase db reset` los carga después de las migraciones.
--
-- Las fechas se calculan desde HOY en America/Asuncion, así los datos nunca
-- quedan viejos: hay reservas pasadas (completadas, ausentes, canceladas) y
-- futuras (confirmadas y canceladas).
--
-- Teléfonos: +595 900 XXX XXX. En Paraguay los celulares usan los prefijos
-- 96x a 99x, así que ningún mensaje de prueba (Sprint 5) puede llegar a una
-- persona real.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Administrador LOCAL del panel: admin@onix.test / onix-local
-- -----------------------------------------------------------------------------
-- Las columnas de tokens van en '' y no en NULL porque el servicio de Auth no
-- acepta NULL en ellas al iniciar sesión.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
) values (
  '00000000-0000-0000-0000-000000000000',
  'a0000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'admin@onix.test',
  extensions.crypt('onix-local', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}', '{}', now(), now(),
  '', '', '', '', '', '', '', ''
);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
values (
  gen_random_uuid(),
  'a0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001',
  jsonb_build_object('sub', 'a0000000-0000-4000-8000-000000000001', 'email', 'admin@onix.test', 'email_verified', true),
  'email', now(), now(), now()
);

insert into public.administradores (user_id) values ('a0000000-0000-4000-8000-000000000001');

-- -----------------------------------------------------------------------------
-- Peluqueros y horarios
-- -----------------------------------------------------------------------------
insert into public.peluqueros (nombre, orden) values
  ('Ana', 1),
  ('Diego', 2),
  ('Marcos', 3),
  ('Sofía', 4);

-- Días ISO: 1 = lunes … 6 = sábado. Domingo cerrado.
-- Diego tiene horario partido; Marcos no trabaja los lunes.
insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
select p.id, dia, h.inicio, h.fin
from (values
  ('Ana',    1, 5, time '09:00', time '18:00'),
  ('Ana',    6, 6, time '08:00', time '13:00'),
  ('Diego',  1, 6, time '08:00', time '12:00'),
  ('Diego',  1, 6, time '14:00', time '19:00'),
  ('Marcos', 2, 6, time '10:00', time '19:00'),
  ('Sofía',  1, 5, time '13:00', time '20:00'),
  ('Sofía',  6, 6, time '09:00', time '14:00')
) as h (peluquero, desde, hasta, inicio, fin)
join public.peluqueros p on p.nombre = h.peluquero
cross join generate_series(h.desde, h.hasta) as dia;

-- -----------------------------------------------------------------------------
-- Servicios
-- -----------------------------------------------------------------------------
insert into public.servicios (nombre, descripcion, duracion_min, precio_gs, orden) values
  ('Corte clásico',          'Corte a tijera o máquina, con lavado.',          30,  50000, 1),
  ('Corte y barba',          'Corte completo más perfilado de barba.',         45,  75000, 2),
  ('Perfilado de barba',     'Perfilado con navaja y toalla caliente.',        30,  35000, 3),
  ('Corte infantil',         'Para menores de 12 años.',                       30,  40000, 4),
  ('Lavado y peinado',       'Lavado, secado y peinado.',                      30,  45000, 5),
  ('Tratamiento hidratante', 'Hidratación profunda con mascarilla.',           30,  60000, 6),
  ('Color completo',         'Tintura de raíz a puntas. No incluye mechas.',   45, 150000, 7);

-- -----------------------------------------------------------------------------
-- Clientes
-- -----------------------------------------------------------------------------
insert into public.clientes (nombre, telefono) values
  ('Lucía Benítez',     '+595900000001'),
  ('Carlos Giménez',    '+595900000002'),
  ('María José Ortiz',  '+595900000003'),
  ('Jorge Villalba',    '+595900000004'),
  ('Fernanda Acosta',   '+595900000005'),
  ('Rodrigo Báez',      '+595900000006'),
  ('Camila Duarte',     '+595900000007'),
  ('Néstor Ramírez',    '+595900000008');

-- -----------------------------------------------------------------------------
-- Bloqueos y reservas, con fechas relativas a hoy
-- -----------------------------------------------------------------------------
do $$
declare
  zona constant text := 'America/Asuncion';
  hoy constant date := (now() at time zone zona)::date;
  feriado date;
  pasados date[];   -- días hábiles anteriores a hoy, del más cercano al más lejano
  futuros date[];   -- días hábiles posteriores a hoy, del más cercano al más lejano
  r record;
  v_fecha date;
  v_peluquero bigint;
  v_duracion integer;
  v_inicio timestamptz;
  v_fin timestamptz;
  v_reserva bigint;
begin
  -- Próximo 8 de diciembre (Virgen de Caacupé, feriado nacional).
  feriado := make_date(
    extract(year from hoy)::int + (hoy > make_date(extract(year from hoy)::int, 12, 8))::int,
    12, 8
  );

  -- Días hábiles: lunes a sábado, sin el feriado.
  select array_agg(d order by d desc) into pasados
  from (select hoy - i as d from generate_series(1, 40) as i) s
  where extract(isodow from d) < 7 and d <> feriado;

  select array_agg(d order by d) into futuros
  from (select hoy + i as d from generate_series(1, 40) as i) s
  where extract(isodow from d) < 7 and d <> feriado;

  -- Bloqueos. Los timestamp locales se convierten a instantes con la zona IANA.
  insert into public.bloqueos (peluquero_id, tipo, inicio, fin, motivo) values
    (null, 'feriado',
      feriado::timestamp at time zone zona,
      (feriado + 1)::timestamp at time zone zona,
      'Virgen de Caacupé'),
    ((select id from public.peluqueros where nombre = 'Marcos'), 'vacaciones',
      futuros[8]::timestamp at time zone zona,
      (futuros[13] + 1)::timestamp at time zone zona,
      'Vacaciones'),
    ((select id from public.peluqueros where nombre = 'Ana'), 'bloqueo',
      (futuros[2] + time '15:00') at time zone zona,
      (futuros[2] + time '17:00') at time zone zona,
      'Trámite personal');

  -- Plan de reservas. dia: negativo = días hábiles atrás, 0 = hoy, positivo =
  -- días hábiles adelante. Cada cliente queda con 2 reservas activas como
  -- máximo, igual que el límite de la configuración.
  for r in
    select * from (values
      -- Pasadas
      (-1,  'Ana',    time '09:00', array['Corte clásico'],                              'completada', null,      '+595900000001'),
      (-1,  'Diego',  time '10:00', array['Corte y barba'],                              'completada', null,      '+595900000002'),
      (-1,  'Sofía',  time '13:00', array['Color completo'],                             'completada', null,      '+595900000003'),
      (-1,  'Marcos', time '15:00', array['Corte clásico', 'Perfilado de barba'],        'ausente',    null,      '+595900000004'),
      (-2,  'Ana',    time '10:30', array['Lavado y peinado'],                           'completada', null,      '+595900000005'),
      (-2,  'Diego',  time '14:30', array['Corte clásico'],                              'cancelada',  'cliente', '+595900000006'),
      (-2,  'Marcos', time '10:00', array['Corte infantil'],                             'completada', null,      '+595900000007'),
      (-3,  'Sofía',  time '16:00', array['Tratamiento hidratante', 'Lavado y peinado'], 'completada', null,      '+595900000008'),
      (-3,  'Diego',  time '08:30', array['Perfilado de barba'],                         'completada', null,      '+595900000001'),
      (-4,  'Ana',    time '11:30', array['Corte clásico'],                              'ausente',    null,      '+595900000002'),
      (-4,  'Marcos', time '17:30', array['Corte y barba'],                              'completada', null,      '+595900000003'),
      (-5,  'Diego',  time '10:00', array['Corte clásico'],                              'completada', null,      '+595900000004'),
      (-5,  'Sofía',  time '18:30', array['Color completo'],                             'cancelada',  'local',   '+595900000005'),
      (-6,  'Ana',    time '09:00', array['Corte infantil'],                             'completada', null,      '+595900000006'),
      (-6,  'Marcos', time '15:00', array['Corte clásico'],                              'completada', null,      '+595900000007'),
      (-7,  'Diego',  time '14:30', array['Corte y barba'],                              'completada', null,      '+595900000008'),
      (-8,  'Sofía',  time '13:00', array['Lavado y peinado'],                           'completada', null,      '+595900000001'),
      (-9,  'Ana',    time '10:30', array['Corte clásico', 'Perfilado de barba'],        'completada', null,      '+595900000002'),
      (-10, 'Marcos', time '10:00', array['Tratamiento hidratante'],                     'completada', null,      '+595900000003'),
      -- Hoy
      (0,   'Diego',  time '14:30', array['Corte clásico'],                              'confirmada', null,      '+595900000004'),
      (0,   'Sofía',  time '18:30', array['Corte y barba'],                              'confirmada', null,      '+595900000005'),
      -- Futuras
      (1,   'Ana',    time '09:00', array['Corte clásico'],                              'confirmada', null,      '+595900000001'),
      (1,   'Diego',  time '10:00', array['Corte clásico', 'Perfilado de barba'],        'confirmada', null,      '+595900000006'),
      (1,   'Marcos', time '15:00', array['Color completo'],                             'confirmada', null,      '+595900000007'),
      (2,   'Sofía',  time '13:00', array['Lavado y peinado', 'Tratamiento hidratante'], 'confirmada', null,      '+595900000008'),
      (2,   'Ana',    time '10:30', array['Corte infantil'],                             'cancelada',  'cliente', '+595900000002'),
      (2,   'Diego',  time '08:30', array['Corte y barba'],                              'confirmada', null,      '+595900000002'),
      (3,   'Marcos', time '17:30', array['Corte clásico'],                              'confirmada', null,      '+595900000003'),
      (3,   'Ana',    time '11:30', array['Perfilado de barba'],                         'confirmada', null,      '+595900000004'),
      (5,   'Diego',  time '14:30', array['Corte clásico'],                              'confirmada', null,      '+595900000005'),
      (7,   'Sofía',  time '16:00', array['Color completo'],                             'confirmada', null,      '+595900000006')
    ) as plan (dia, peluquero, hora, servicios, estado, cancelada_por, telefono)
  loop
    v_fecha := case
      when r.dia < 0 then pasados[-r.dia]
      when r.dia > 0 then futuros[r.dia]
      else hoy
    end;
    v_peluquero := (select id from public.peluqueros where nombre = r.peluquero);
    v_duracion := (select sum(duracion_min) from public.servicios where nombre = any (r.servicios));
    v_inicio := (v_fecha + r.hora) at time zone zona;
    v_fin := v_inicio + make_interval(mins => v_duracion);

    -- Se descarta la reserva si ese día el peluquero no trabaja a esa hora
    -- (por ejemplo, Marcos un lunes, o hoy si es domingo)…
    continue when not exists (
      select 1 from public.horarios h
      where h.peluquero_id = v_peluquero
        and h.dia_semana = extract(isodow from v_fecha)
        and r.hora >= h.hora_inicio
        and r.hora + make_interval(mins => v_duracion) <= h.hora_fin
    );
    -- …o si cae en un bloqueo suyo o del local.
    continue when exists (
      select 1 from public.bloqueos b
      where (b.peluquero_id is null or b.peluquero_id = v_peluquero)
        and tstzrange(b.inicio, b.fin, '[)') && tstzrange(v_inicio, v_fin, '[)')
    );

    insert into public.reservas (cliente_id, peluquero_id, inicio, fin, estado, cancelada_en, cancelada_por)
    values (
      (select id from public.clientes where telefono = r.telefono),
      v_peluquero, v_inicio, v_fin,
      r.estado::public.estado_reserva,
      case when r.estado = 'cancelada' then least(now(), v_inicio - interval '5 hours') end,
      r.cancelada_por::public.actor_cancelacion
    )
    returning id into v_reserva;

    insert into public.reserva_servicios (reserva_id, orden, servicio_id, duracion_min, precio_gs)
    select v_reserva, s.orden, sv.id, sv.duracion_min, sv.precio_gs
    from unnest(r.servicios) with ordinality as s (nombre, orden)
    join public.servicios sv on sv.nombre = s.nombre;
  end loop;

  -- Aproximadamente un tercio de las reservas se hizo con "Cualquiera disponible".
  update public.reservas set asignacion_automatica = true where id % 3 = 0;
end;
$$;
