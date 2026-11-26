# CLAUDE.md — Sistema de reservas de turnos para peluquerías

Leer este archivo completo al inicio de cada sesión. La sección **Estado actual** (al final) se actualiza al cerrar cada sprint.

## Qué es

Sistema de reservas de turnos para peluquerías que se vende como producto **white-label**: cada peluquería recibe su propia copia (su propio proyecto de Supabase y su propio deploy). Entre una copia y otra solo cambia la marca (nombre, logo, colores, contacto).

## Contexto del producto

- Mercado: peluquerías de **Paraguay**. Idioma: **castellano**.
- Moneda: **guaraníes como enteros** (sin decimales), formato `Gs. 50.000` (punto como separador de miles).
- Zona horaria: **America/Asuncion**. Usar siempre el nombre IANA, **nunca un offset fijo** (Paraguay cambió sus reglas de horario de verano; un offset fijo rompe fechas).
- El cliente final reserva **sin crear cuenta**: nombre + número de WhatsApp (formato `+595`).
- El pago es en el local. **No hay pagos online.**
- Hay varios peluqueros, cada uno con su horario semanal (puede tener **horario partido**, p. ej. 8–12 y 14–19). En un mismo horario puede haber tantos turnos simultáneos como peluqueros disponibles.
- Servicios con duración configurable (normalmente 30–45 min) y precio editable por el dueño.
- Un cliente puede reservar **varios servicios en un turno**: se suman las duraciones y los realiza **un mismo peluquero de forma consecutiva**, solo si hay uno libre durante todo el bloque.
- El cliente elige peluquero o **"Cualquiera disponible"**: se asigna automáticamente al peluquero **menos cargado del día**.
- Cancelación: el cliente puede cancelar **hasta 3 horas antes** del turno mediante un **enlace único con token**.
- Notificaciones por WhatsApp: confirmación al reservar y recordatorio el día del turno (Sprint 5).
- Panel del dueño con login: agenda, servicios, peluqueros y horarios, bloqueos/feriados/vacaciones, clientes, estadísticas.

## Stack (no cambiar sin consultar al usuario)

- **Frontend:** HTML, CSS y JavaScript puros. Sin frameworks ni bundler. ES modules nativos. `supabase-js` desde CDN con **versión fijada** (nunca `@latest` ni rango).
- **Backend:** Supabase — Postgres, Auth (solo para el dueño/admin), RLS, funciones SQL (RPC), Edge Functions (Deno), pg_cron.
- **Supabase CLI:** todo cambio de base de datos va como **migración** en `supabase/migrations`. Nada de cambios manuales en el panel de Supabase.
- **Deploy del frontend:** hosting estático (Netlify, Vercel o Cloudflare Pages; a definir en Sprint 6).

## Reglas de arquitectura y seguridad

- El rol `anon` **no lee ni escribe tablas directamente**. El público usa solo funciones RPC `SECURITY DEFINER` con validación completa:
  - consultar disponibilidad,
  - crear reserva,
  - ver/cancelar reserva por token.
  Nunca exponer datos de otros clientes. (Las funciones `SECURITY DEFINER` llevan `set search_path` fijo para evitar secuestro de esquema.)
- Impedir turnos superpuestos **a nivel de base de datos** con un **exclusion constraint** (`btree_gist` + `tstzrange`) por peluquero sobre reservas no canceladas, **además** de validar dentro de la función.
- Todas las fechas en `timestamptz`.
- La **service role key / Secret key (`sb_secret_…`) jamás** va en el frontend ni en el repositorio. Los secretos van en variables de entorno de Supabase.
- Antiabuso en la reserva pública: **campo honeypot** y **límite de reservas activas por número de teléfono**.
- Nombres de dominio en castellano (`reservas`, `peluqueros`, `servicios`…). Comentarios que expliquen **el porqué** de la lógica no obvia.
- **Mobile-first** (la mayoría reservará desde el celular) y **accesible**: contraste WCAG AA, foco visible, `label` en todos los inputs.
- Las páginas de **uso interno** (guías, pruebas, utilidades de desarrollo) van en `herramientas/`. El cliente nunca debe poder verlas, así que esa carpeta no se publica en el deploy.

### Marca (white-label)

Todo lo específico de una peluquería vive **solo** en dos archivos:

| Archivo | Contenido |
|---|---|
| `config.js` | nombre, logo, WhatsApp, dirección, redes, URL y Publishable key de Supabase (`publishableKey`, la antigua "anon key") |
| `css/styles.css` → bloque **ZONA DE MARCA** al inicio | variables CSS: colores, tipografías (incluido el `@import` de Google Fonts), radios, sombras |

- `css/styles.css` es el **único archivo CSS** del proyecto. Debajo de la zona de marca van los estilos genéricos, que solo usan variables (nunca colores ni fuentes literales).
- Los archivos de imagen del logo/favicon van en `assets/marca/` y se referencian **desde `config.js`**; ningún HTML ni JS los nombra directamente.
- **Ningún otro archivo** puede contener datos de una peluquería concreta. Los textos de las páginas se leen de `config.js`.
- Lo que es del producto y no de la marca (zona horaria, moneda, prefijo +595, regla de 3 horas) va en el código, no en `config.js`.

## Dirección de diseño

Base: **`DESIGN.md`** (raíz del repo), una referencia de estilo oscura: lienzo verde azulado profundo, profundidad por capas de superficie **sin sombras**, color muy medido, títulos en un único peso medio con tracking negativo y etiquetas en mayúsculas espaciadas. Se descartó la propuesta inicial de dorado y negro.

Decisiones tomadas en el Sprint 0, que **prevalecen sobre el `.md`** donde difieren:

- **Tipografía: DM Sans** 400/500 (Google Fonts), porque Matter, la fuente del `.md`, no está disponible ahí.
- **Botón primario: degradé aurora con radio de 6 px** y texto `#222`. Va **una sola vez por pantalla**. El `.md` define el botón de tres formas contradictorias. Se descartó la píldora Kelp porque contra el fondo da 1,2:1.
- **Radios:** solo 6 px (botones, campos, opciones) y 16 px (tarjetas).
- **Colores agregados**, porque el `.md` no define estados de formulario:
  - borde de campo `#5E8784`: el borde blanco al 10% del `.md` da 1,34:1 y se necesita 3:1;
  - ocupado `#8FA6A4` (tachado, nunca solo color);
  - error `#FFB3C1` (siempre con texto e ícono);
  - seleccionado: fondo Mist con texto Abyss.
- **Usos restringidos:**
  - Slate `#707777` solo como superficie: como texto da 2,9:1.
  - El degradé bioluminiscente solo como decoración: ningún color de texto pasa en sus dos extremos.
- **Adaptación móvil:**
  - títulos con `clamp()`, como mucho unos 61 px (el `.md` llega a 96 px);
  - etiquetas de 12 px como mínimo (el `.md` usa 10 px);
  - campos con texto de 16 px, para que iOS no haga zoom;
  - zonas táctiles de 48 px, o 44 px en opciones chicas;
  - tarjetas con 16 a 24 px de relleno.
- **Sin la identidad de la marca original** del `.md` (nombre, esfera de partículas): la atmósfera se resuelve con un resplandor radial (`--color-resplandor`).
- **`herramientas/guia-estilos.html` es la referencia viva (uso interno, nunca se publica):** no tiene colores escritos a mano, lee `config.js` y las variables de `styles.css`, y recalcula el contraste WCAG. Al instalar una marca nueva, abrirla y comprobar que todos los pares pasen.

## Entorno de desarrollo

- Una sola PC con Windows 10 Pro.
- **Docker Desktop** se usa para la base local de Supabase (`npx supabase start`).
- **Puertos locales de Supabase: 443xx** (API 44321, DB 44322, Studio 44323, Mailpit 44324), no los 543xx por defecto: en Windows, Hyper-V/WSL2 reserva bloques aleatorios de puertos dentro de 49152-65535 y bloqueaba los 543xx. No volver a los valores por defecto. El motivo está explicado en `supabase/config.jsonc`.
- **Analytics desactivado** en local: en Windows exige exponer el daemon de Docker sin TLS y, si no, el contenedor `vector` queda en bucle.
- En el mismo Docker corre otro proyecto del usuario (`global-exchange`, trabajo de la facultad). **Nunca** usar `docker system/container/volume prune` ni tocar recursos `global-exchange*`.
- Supabase CLI vía `npx supabase …` (no está instalada global). El proyecto se inicializó con la **v3.4.0**, que usa `supabase/config.jsonc` en vez de `config.toml`.
- El frontend se sirve con cualquier servidor estático (los ES modules no funcionan con `file://`), por ejemplo `npx serve .`.

## Estructura de carpetas

```
sistema-reservas/
├── index.html          # Reserva pública (Sprint 3)
├── cancelar.html       # Ver/cancelar reserva por token (Sprint 3)
├── DESIGN.md           # Referencia de estilo base (ver "Dirección de diseño")
├── config.js           # MARCA: datos de la peluquería + Supabase URL/Publishable key
├── admin/              # Login y panel del dueño (Sprint 4)
├── css/styles.css      # Único CSS. ZONA DE MARCA arriba + estilos genéricos
├── js/
│   ├── lib/            # Cliente Supabase, formato de Gs./fechas/teléfono, utilidades
│   └── admin/          # Lógica del panel
├── assets/marca/       # Logo y favicon de la peluquería (referenciados desde config.js)
├── herramientas/       # USO INTERNO, no se publica: guía de estilos (guia-estilos.html + .js)
├── supabase/           # config.jsonc, migrations/, functions/, seed.sql, tests/
├── CLAUDE.md
└── README.md
```

## Forma de trabajo

- Se trabaja por **sprints**. No avanzar a otro sprint hasta que el usuario lo pida.
- Al inicio de cada sprint: presentar un **plan breve** y **esperar aprobación** antes de escribir código.
- Al terminar cada sprint: **resumen** de lo hecho, **pasos para probarlo manualmente** y una **propuesta de mensaje de commit**.
- **Los commits los hace siempre el usuario.** Claude no ejecuta `git commit`, `push`, `merge` ni `rebase`, ni ofrece hacerlo.
- Si algo es ambiguo o hay un riesgo, **preguntar** en lugar de suponer.

## Roadmap

- **Sprint 0** — Setup del proyecto y dirección de diseño
- **Sprint 1** — Esquema de base de datos, RLS y datos de prueba
- **Sprint 2** — Lógica de disponibilidad, reservas y cancelación (funciones SQL + tests)
- **Sprint 3** — Página pública de reserva
- **Sprint 4** — Panel del dueño
- **Sprint 4B** — Estadísticas del negocio (se realiza junto al Sprint 4)
- **Sprint 5** — WhatsApp: confirmación, recordatorio y cancelación
- **Sprint 6** — Pulido, auditoría de seguridad, deploy y kit de instalación para nuevos clientes
  - Ojo en el deploy: publicar **solo los archivos públicos**. No deben quedar accesibles `CLAUDE.md`, `DESIGN.md`, `README.md`, `supabase/` ni `herramientas/`.

## Estado actual

**Sprint 0 — terminado, pendiente de que el usuario lo pruebe y haga el commit.**

- [x] Estructura de carpetas
- [x] CLAUDE.md
- [x] .gitignore y README
- [x] `supabase init` (sin proyecto remoto vinculado) y Supabase local corriendo en Docker
- [x] `config.js` con una peluquería ficticia ("Ónix Peluquería")
- [x] Dirección de diseño: DESIGN.md + DM Sans + botón con degradé aurora (ver "Dirección de diseño")
- [x] `css/styles.css`: zona de marca con la dirección elegida y componentes genéricos (botones, campos, tarjeta de servicio, selector de peluquero, grilla de horarios, avisos)
- [x] `herramientas/guia-estilos.html` + `herramientas/guia-estilos.js` (uso interno)

**Pendiente para el Sprint 3:** definir si los textos al cliente van con *tú*, *vos* o *usted*. Hasta ahora se usaron frases neutras.
