# Sistema de reservas para peluquerías

Sistema de reservas de turnos para peluquerías en Paraguay. El cliente reserva desde el celular, sin crear cuenta, con su nombre y su número de WhatsApp. El dueño administra la agenda, los servicios y los peluqueros desde un panel con login.

Es un producto white-label: cada peluquería tiene su propia copia (proyecto de Supabase y deploy propios) y solo cambia la marca.

## Stack

- HTML, CSS y JavaScript puros, con ES modules nativos. Sin frameworks ni bundler.
- Supabase: Postgres, Auth, RLS, funciones RPC, Edge Functions y pg_cron.
- Hosting estático para el frontend.

## Requisitos de desarrollo

- Node.js (solo para ejecutar `npx`)
- Docker Desktop (para la base de Supabase local)

## Desarrollo local

```bash
# 1. Levantar Supabase local (Docker Desktop debe estar abierto)
npx supabase@3.4.0 start

# 2. Ver URL, claves y el link a Studio local
npx supabase@3.4.0 status

# 3. Servir el frontend (los ES modules no funcionan abriendo el HTML con doble clic)
npx serve .
```

Para detener Supabase: `npx supabase@3.4.0 stop`.

La versión de la CLI va fija en todos los comandos (`@3.4.0`). Sin versión, `npx` podría bajar la última, que podría leer distinto `supabase/config.jsonc`.

### Base de datos

- `npx supabase@3.4.0 db reset`: recrea la base local desde cero, aplica las migraciones de `supabase/migrations/` y carga los datos de prueba de `supabase/seed.sql`. **Borra los datos locales.**
- `npx supabase@3.4.0 test db`: corre los tests de `supabase/tests/database/`, que verifican la seguridad (RLS y permisos) y las restricciones del esquema.
- Studio (http://127.0.0.1:44323) muestra las tablas y los datos.
- Administrador local creado por el seed, **solo para desarrollo**: `admin@onix.test` / `onix-local`.

Con el servidor estático andando, la guía de estilos está en http://localhost:3000/herramientas/guia-estilos.html. Muestra los componentes con la marca actual y calcula el contraste WCAG de sus colores. La carpeta `herramientas/` es de uso interno: no se publica en el deploy.

Puertos locales (cambiados a 443xx porque Windows suele reservar los 543xx por defecto):

| Servicio | URL |
|---|---|
| API | http://127.0.0.1:44321 |
| Studio (panel de la base) | http://127.0.0.1:44323 |
| Mailpit (emails de prueba) | http://127.0.0.1:44324 |
| Postgres | `postgresql://postgres:postgres@127.0.0.1:44322/postgres` |

## Adaptar a una peluquería nueva

Solo se editan:

1. `config.js`: nombre, logo, WhatsApp, dirección, redes, URL y Publishable key de Supabase.
2. El bloque **ZONA DE MARCA** al inicio de `css/styles.css`: colores, tipografías, radios y sombras.
3. Los archivos de `assets/marca/` (logo, favicon).

Después de cambiar la marca, abrir `herramientas/guia-estilos.html` y comprobar que todos los pares de la tabla de contraste digan «Pasa».

En el Sprint 6 se agrega el kit de instalación completo.

## Seguridad

- La Publishable key de `config.js` (la antigua "anon key") es pública por diseño. La seguridad la dan RLS y las funciones RPC.
- La **Secret key / service role key nunca** va en el frontend ni en el repositorio.

## Estructura

Ver [CLAUDE.md](CLAUDE.md): tiene el contexto completo, las reglas, el roadmap y el estado actual del proyecto.
