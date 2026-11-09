@AGENTS.md

# PELUQUERIA: reservas de turnos

App web mobile-first para reservar turnos en una peluquería de Asunción (Paraguay).
Los clientes reservan sin crear cuenta; el administrador (con login) gestiona la agenda,
los servicios, los peluqueros y los bloqueos.

## Stack

- Next.js 16 (App Router, `cacheComponents` activado) + TypeScript
- Tailwind CSS 4 + shadcn/ui (estilo `base-nova`, sobre Base UI)
- Supabase (Postgres + Auth) **en la nube, sin Docker**: Docker se usa para otro proyecto
  de la facultad en esta máquina y no queremos interferir con él.
- Deploy en Vercel

## Comandos

- `npm run dev`: servidor local en http://localhost:3000 (también accesible desde el celular en la misma red)
- `npm test`: tests
- `npm run lint`
- `npm run build`

## Forma de trabajo

- Para algo nuevo: proponer un plan y esperar aprobación antes de escribir código.
- Trabajar por etapas. Al terminar cada una, explicar cómo probarla paso a paso.
- La lógica de cálculo de horarios disponibles siempre tiene tests.
- El README está escrito para alguien que no es experto: pasos concretos, sin dar nada por sabido.

## Etapas

0. Base del proyecto, tema y layout ✅
1. Base de datos: migraciones, exclusion constraint, RLS, funciones y seed
2. Cálculo de horarios disponibles + tests
3. Flujo de reserva del cliente + confirmación con WhatsApp
4. Link de cancelación `/turno/[token]`
5. Admin: login y agenda diaria/semanal
6. Admin: turnos manuales (crear, editar, cancelar)
7. Admin: servicios, peluqueros con horarios, bloqueos
8. Proyecto de producción en Supabase, deploy en Vercel, README completo

Fuera de alcance por ahora: pagos online, recordatorios automáticos, estadísticas.

## Idioma y nombres

- Toda la interfaz en español con voseo ("Elegí", "Reservá"), en minúsculas normales.
  La única palabra en mayúsculas sostenidas es el nombre PELUQUERIA.
- Dominio en español en la base y en el código (`turno`, `peluquero`, `servicio`, `bloqueo`);
  términos técnicos en inglés (`route`, `proxy`, `utils`).
- Tablas y columnas en `snake_case`.

## Reglas de negocio

Los valores viven en la tabla `ajustes` para poder cambiarlos sin tocar código:

- Intervalo entre horarios ofrecidos: 15 min.
- Anticipación: mínimo 1 hora, máximo 30 días.
- El cliente puede cancelar hasta 3 horas antes del turno.
- Máximo 2 turnos futuros por teléfono.
- Horario general: lunes a viernes 9:00–19:00, sábados 9:00–13:00. Es la plantilla para el
  horario de cada peluquero; la disponibilidad se calcula con el horario del peluquero.
- El almuerzo fijo se carga como dos franjas el mismo día; los bloqueos son para excepciones.
- Todos los peluqueros hacen todos los servicios.
- "Cualquiera disponible" asigna al peluquero con menos turnos ese día (empate: por `orden`).
- **Dos turnos confirmados del mismo peluquero nunca se superponen.** Lo garantiza la exclusion
  constraint `turnos_sin_superposicion` en Postgres; no quitarla ni reemplazarla por validaciones
  en el código. El error `23P01` se muestra como "Ese horario se acaba de ocupar. Elegí otro."
- RLS: el público nunca lee `turnos` ni `bloqueos` directamente; usa funciones `security definer`
  que no exponen datos de clientes.

## Fechas, horas y dinero

- La base guarda `timestamptz` (UTC). Todo se muestra en `America/Asuncion`.
- Nunca escribir offsets a mano (`-03:00`); usar siempre la zona IANA.
- Los horarios semanales de los peluqueros son `time` en hora local.
- Precios en guaraníes enteros (`precio_gs integer`). Mostrar con `formatearGuaranies`
  de `src/lib/formato.ts` ("Gs. 50.000").
- Teléfonos: se guardan normalizados para wa.me (`0981 123 456` → `595981123456`).

## Tests

- Se usa el test runner nativo de Node (`node:test` + `node:assert/strict`), con archivos
  `*.test.ts` al lado del código.
- **No usar Vitest ni Vite**: Smart App Control de Windows bloquea en esta máquina los binarios
  nativos de rolldown y rollup.
- Node ejecuta los `.ts` directamente, así que los módulos con tests y todo lo que importan deben:
  - importarse entre sí con rutas relativas y extensión `.ts` (no el alias `@/`);
  - usar `import type` para los tipos;
  - evitar `enum` y `namespace` (lo controlan `erasableSyntaxOnly` y `verbatimModuleSyntax`).

## Diseño

- Sitio público en tema oscuro (clase `dark` en `src/app/(publico)/layout.tsx`).
  Admin en tema claro, con barra lateral negra.
- Paleta en `src/app/globals.css`: negro `#000000`, carbón `#1C1B19`, dorado `#C9A24D`,
  dorado oscuro `#6B5A33`, hueso `#F2F0EB`, gris `#8F8B84`.
- El dorado significa "esto elegiste": solo la selección y la acción principal
  (y en el admin, la línea de "ahora"). Nunca texto dorado sobre fondo blanco.
- Una sola familia tipográfica: Archivo. `font-stretch-expanded` + `font-semibold` para la marca,
  los títulos y los horarios grandes; ancho normal para el resto; `tabular-nums` en horarios y precios.
  Escala: 14 / 16 / 20 / 24 / 36 / 48 px.
- Mobile-first: una columna `max-w-md`, alineada a la izquierda, botones de 48 px como mínimo.
- Sin gradientes, sin sombras decorativas, sin animaciones de entrada. La única animación es la
  tarjeta del turno al confirmar.
- El logo es un cuadro vacío (`src/components/marca.tsx`) hasta tener el definitivo.
- Textos: voz activa; cada botón dice lo que hace ("Confirmar turno") y el mensaje posterior usa el
  mismo verbo ("Turno confirmado"). Los errores dicen qué pasó y cómo seguir, sin disculparse.

## Next.js 16

- Esta versión cambia APIs respecto de versiones anteriores: leer la guía correspondiente en
  `node_modules/next/dist/docs/` antes de usar algo nuevo.
- `middleware.ts` ahora se llama `proxy.ts`.
- Con `cacheComponents`, los datos dinámicos van dentro de `<Suspense>` o se cachean con `"use cache"`.
