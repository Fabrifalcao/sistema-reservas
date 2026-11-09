-- Chequeos de la etapa 1: regla de no superposición, permisos (RLS) y la función ocupacion().
-- Se corre con: npm run db:verificar  (o pegándolo en el SQL Editor de Supabase).
--
-- Crea un peluquero, servicios y turnos de prueba, y los deshace al final:
-- no queda nada guardado en la base. Cada chequeo muestra OK o FALLA.

drop table if exists pg_temp.resultados;
create temp table resultados (orden integer, chequeo text, resultado text);

do $$
declare
  -- Un instante lejos en el futuro, para no cruzarse con turnos reales.
  t0 constant timestamptz := date_trunc('hour', now()) + interval '400 days';
  rol_original constant text := current_user;
  peluquero_a bigint;
  peluquero_b bigint;
  servicio_activo bigint;
  servicio_inactivo bigint;
  turno_base bigint;
  turno_borde bigint;
  n integer;
  n_turnos integer;
  n_bloqueos integer;
  resultado text;
  lista jsonb := '[]';
begin
  -- Todo lo que pasa dentro de este bloque se deshace al final (ver "deshacer" abajo).
  begin
    insert into public.peluqueros (nombre) values ('Prueba A') returning id into peluquero_a;
    insert into public.peluqueros (nombre) values ('Prueba B') returning id into peluquero_b;
    insert into public.servicios (nombre, duracion_min, precio_gs)
      values ('Prueba activo', 30, 0) returning id into servicio_activo;
    insert into public.servicios (nombre, duracion_min, precio_gs, activo)
      values ('Prueba inactivo', 30, 0, false) returning id into servicio_inactivo;

    -- Turno base del peluquero A: de t0 a t0 + 30 min.
    insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
      values (peluquero_a, servicio_activo, t0, t0 + interval '30 min', 0, 'Prueba', '595981000000', 'cliente')
      returning id into turno_base;


    -- Regla de no superposición ------------------------------------------------------------------

    begin
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_a, servicio_activo, t0 + interval '15 min', t0 + interval '45 min', 0, 'Prueba', '595981000000', 'cliente');
      resultado := 'FALLA: se aceptó';
    exception
      when exclusion_violation then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un turno que se superpone con otro del mismo peluquero se rechaza (23P01)', 'resultado', resultado);

    begin
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_a, servicio_activo, t0 + interval '30 min', t0 + interval '60 min', 0, 'Prueba', '595981000000', 'cliente')
        returning id into turno_borde;
      resultado := 'OK';
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un turno que empieza justo cuando termina otro se acepta', 'resultado', resultado);

    begin
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_b, servicio_activo, t0, t0 + interval '30 min', 0, 'Prueba', '595981000000', 'cliente');
      resultado := 'OK';
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Otro peluquero puede tener un turno a la misma hora', 'resultado', resultado);

    begin
      update public.turnos
        set estado = 'cancelado', cancelado_en = now(), cancelado_por = 'cliente'
        where id = turno_base;
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_a, servicio_activo, t0, t0 + interval '30 min', 0, 'Prueba', '595981000000', 'cliente');
      resultado := 'OK';
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un turno cancelado deja libre el horario', 'resultado', resultado);


    -- Controles de datos -------------------------------------------------------------------------

    begin
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_a, servicio_activo, t0 + interval '3 hours', t0 + interval '4 hours', 0, 'Prueba', '0981 000 000', 'cliente');
      resultado := 'FALLA: se aceptó';
    exception
      when check_violation then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un teléfono sin normalizar (0981 000 000) se rechaza', 'resultado', resultado);

    begin
      update public.turnos set estado = 'cancelado' where id = turno_borde;
      resultado := 'FALLA: se aceptó';
    exception
      when check_violation then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un turno cancelado sin fecha ni autor de cancelación se rechaza', 'resultado', resultado);

    begin
      insert into public.ajustes default values;
      resultado := 'FALLA: se aceptó';
    exception
      when unique_violation then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'La tabla ajustes no acepta una segunda fila', 'resultado', resultado);


    -- Función ocupacion() ------------------------------------------------------------------------

    insert into public.bloqueos (peluquero_id, inicio, fin, motivo)
      values (peluquero_b, t0 + interval '1 hour', t0 + interval '2 hours', 'Prueba');

    resultado := pg_get_function_result('public.ocupacion(timestamptz, timestamptz)'::regprocedure);
    resultado := case
      when resultado = 'TABLE(peluquero_id bigint, inicio timestamp with time zone, fin timestamp with time zone, tipo text)'
        then 'OK'
      else 'FALLA: devuelve ' || resultado
    end;
    lista := lista || jsonb_build_object('chequeo', 'ocupacion() devuelve solo peluquero, inicio, fin y tipo', 'resultado', resultado);

    -- Hasta acá hay 3 turnos confirmados (2 de A, 1 de B), 1 cancelado y 1 bloqueo de B.
    select count(*) filter (where o.tipo = 'turno'), count(*) filter (where o.tipo = 'bloqueo')
      into n_turnos, n_bloqueos
      from public.ocupacion(t0 - interval '1 hour', t0 + interval '1 day') as o
      where o.peluquero_id in (peluquero_a, peluquero_b);
    resultado := case
      when n_turnos = 3 and n_bloqueos = 1 then 'OK'
      else format('FALLA: %s turnos y %s bloqueos (se esperaban 3 y 1)', n_turnos, n_bloqueos)
    end;
    lista := lista || jsonb_build_object('chequeo', 'ocupacion() trae turnos confirmados y bloqueos, sin los cancelados', 'resultado', resultado);

    begin
      perform * from public.ocupacion(t0, t0 + interval '63 days');
      resultado := 'FALLA: se aceptó';
    exception
      when invalid_parameter_value then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'ocupacion() rechaza rangos de más de 62 días', 'resultado', resultado);


    -- Permisos del público (anon) ----------------------------------------------------------------
    -- Si una consulta falla, el bloque se deshace y el rol vuelve solo al original.

    begin
      set local role anon;
      select count(*) into n from public.turnos;
      execute format('set local role %I', rol_original);
      resultado := format('FALLA: pudo leer %s turnos', n);
    exception
      when insufficient_privilege then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'El público no puede leer la tabla turnos', 'resultado', resultado);

    begin
      set local role anon;
      select count(*) into n from public.bloqueos;
      execute format('set local role %I', rol_original);
      resultado := format('FALLA: pudo leer %s bloqueos', n);
    exception
      when insufficient_privilege then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'El público no puede leer la tabla bloqueos', 'resultado', resultado);

    begin
      set local role anon;
      insert into public.turnos (peluquero_id, servicio_id, inicio, fin, precio_gs, cliente_nombre, cliente_telefono, origen)
        values (peluquero_a, servicio_activo, t0 + interval '5 hours', t0 + interval '6 hours', 0, 'Prueba', '595981000000', 'cliente');
      execute format('set local role %I', rol_original);
      resultado := 'FALLA: pudo crear un turno';
    exception
      when insufficient_privilege then resultado := 'OK';
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'El público no puede crear turnos directamente', 'resultado', resultado);

    begin
      set local role anon;
      select count(*) into n from public.servicios where id in (servicio_activo, servicio_inactivo);
      execute format('set local role %I', rol_original);
      resultado := case when n = 1 then 'OK' else format('FALLA: ve %s de 2 (se esperaba 1)', n) end;
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'El público ve los servicios activos y no los inactivos', 'resultado', resultado);

    begin
      set local role anon;
      select count(*) into n
        from public.ocupacion(t0 - interval '1 hour', t0 + interval '1 day') as o
        where o.peluquero_id in (peluquero_a, peluquero_b);
      execute format('set local role %I', rol_original);
      resultado := case when n = 4 then 'OK' else format('FALLA: devolvió %s filas (se esperaban 4)', n) end;
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'El público puede consultar ocupacion()', 'resultado', resultado);


    -- Usuario con sesión que no es admin --------------------------------------------------------

    begin
      -- Simula la sesión de un usuario cualquiera que no figura en administradores.
      perform set_config(
        'request.jwt.claims',
        json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text,
        true
      );
      set local role authenticated;
      select count(*) into n from public.turnos;
      execute format('set local role %I', rol_original);
      perform set_config('request.jwt.claims', '', true);
      resultado := case when n = 0 then 'OK' else format('FALLA: vio %s turnos', n) end;
    exception
      when others then resultado := 'FALLA: ' || sqlerrm;
    end;
    lista := lista || jsonb_build_object('chequeo', 'Un usuario con sesión que no es admin no ve turnos', 'resultado', resultado);


    -- Deshacer: este error a propósito borra todo lo creado arriba.
    raise exception using errcode = 'ZZ001', message = 'deshacer datos de prueba';
  exception
    when sqlstate 'ZZ001' then null;
  end;

  insert into resultados (orden, chequeo, resultado)
    select e.orden, e.item ->> 'chequeo', e.item ->> 'resultado'
    from jsonb_array_elements(lista) with ordinality as e (item, orden);
end;
$$;

select chequeo, resultado from resultados order by orden;
