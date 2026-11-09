-- Datos de ejemplo para el proyecto de desarrollo. No se cargan en producción.
-- Se corre con: npm run db:seed
--
-- Si la base ya tiene servicios o peluqueros no hace nada, así se puede correr de nuevo sin duplicar.

do $$
begin
  if exists (select 1 from public.servicios) or exists (select 1 from public.peluqueros) then
    raise notice 'La base ya tiene datos: no se cargó nada.';
    return;
  end if;

  insert into public.servicios (nombre, duracion_min, precio_gs, orden) values
    ('Corte caballero', 30, 50000, 1),
    ('Corte dama', 45, 80000, 2),
    ('Color', 90, 200000, 3),
    ('Barba', 20, 30000, 4);

  insert into public.peluqueros (nombre, orden) values
    ('Carlos', 1),
    ('Laura', 2),
    ('Diego', 3);

  -- Los tres: lunes a viernes de 9 a 13 y de 14 a 19 (almuerzo de 13 a 14).
  insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
  select p.id, dia.numero, franja.inicio, franja.fin
  from public.peluqueros as p
  cross join generate_series(1, 5) as dia (numero)
  cross join (values (time '09:00', time '13:00'), (time '14:00', time '19:00')) as franja (inicio, fin);

  -- Sábados de 9 a 13: Carlos y Laura. Diego no trabaja los sábados.
  insert into public.horarios (peluquero_id, dia_semana, hora_inicio, hora_fin)
  select p.id, 6, time '09:00', time '13:00'
  from public.peluqueros as p
  where p.nombre in ('Carlos', 'Laura');
end;
$$;
