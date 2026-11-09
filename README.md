# PELUQUERIA: reservas de turnos

Aplicación web para que los clientes reserven turnos en la peluquería desde el celular,
sin crear una cuenta, y para que el administrador gestione la agenda.

> El proyecto se desarrolla por etapas. Esta guía se completa a medida que avanzan;
> el deploy en Vercel llega en la etapa 8.

## Qué necesitás

- **Node.js 22.18 o superior.** En Windows se instala con:
  ```
  winget install OpenJS.NodeJS.LTS
  ```
  Después cerrá y volvé a abrir VS Code para que lo reconozca.
- **Una cuenta gratuita en [supabase.com](https://supabase.com).** Ahí vive la base de datos.
  No hace falta instalar Postgres ni Docker.

## Correr el proyecto en tu computadora

1. Abrí una terminal en la carpeta del proyecto.
2. Instalá las dependencias (solo la primera vez, o cuando cambie `package.json`):
   ```
   npm install
   ```
3. Levantá el servidor de desarrollo:
   ```
   npm run dev
   ```
4. Abrí http://localhost:3000 en el navegador.

### Verlo en el celular

1. Conectá el celular a la misma red wifi que la computadora.
2. Al ejecutar `npm run dev`, la terminal muestra una línea `Network: http://192.168.x.x:3000`.
   Abrí esa dirección en el navegador del celular.
3. Si Windows pregunta si permitís que Node.js use la red, elegí **Redes privadas** y aceptá.

También podés simular un celular en Chrome: `F12` → ícono de celular (o `Ctrl+Shift+M`).

## Base de datos (Supabase)

La base de datos es un proyecto de Supabase en la nube. Para manejarla desde la terminal se usa
la CLI de Supabase, que se instala sola con `npm install` y se ejecuta con `npx supabase`.

### Primera vez: crear el proyecto y conectarlo

1. Entrá a https://supabase.com/dashboard e iniciá sesión.
2. Tocá **New project** y completá:
   - **Name:** `peluqueria-dev`.
   - **Database password:** tocá **Generate a password**, copiala y guardala en un lugar seguro
     (por ejemplo, un gestor de contraseñas). La vas a necesitar en el paso 5.
   - **Region:** South America (São Paulo), la más cercana a Asunción.
   - Si aparecen otras opciones, dejá las que vienen marcadas.
3. Tocá **Create new project** y esperá a que termine de prepararse (un par de minutos).
4. Iniciá sesión en la CLI. Es como iniciar sesión en el sitio de Supabase, pero para la terminal:
   le permite a la CLI tocar tus proyectos. Se hace una sola vez por computadora.
   1. En VS Code abrí la terminal: menú **Terminal → Nueva terminal** (o **New Terminal**).
      Aparece abajo un panel con un texto que termina en `sistema-reservas>`.
   2. Escribí este comando y apretá Enter:
      ```
      npx supabase login
      ```
   3. Si te pide apretar Enter para abrir el navegador, apretalo.

      Si el navegador no se abre, o muestra **Missing sign-in parameters**, el link llegó cortado.
      Cancelá con `Ctrl+C` y corré `npx supabase login --no-browser`. El link ocupa varias
      líneas: seleccionalo con el mouse desde `https://` hasta el final de la última línea,
      copialo y pegalo en la barra de direcciones del navegador.
   4. En el navegador, iniciá sesión en Supabase si no lo estabas y autorizá el acceso.
   5. El navegador muestra un código de verificación. Copialo, volvé a la terminal, pegalo
      (clic derecho o `Ctrl+V`) y apretá Enter.
   6. Está listo cuando la terminal dice `You are now logged in`.
5. Conectá esta carpeta con tu proyecto. Esto solo anota en tu computadora a qué proyecto apuntar;
   no cambia nada en la base. El identificador son las 20 letras que aparecen en la dirección del
   navegador (`supabase.com/dashboard/project/`**`abcdefghijklmnopqrst`**), o en la columna
   `REFERENCE ID` de `npx supabase projects list`:
   ```
   npx supabase link --project-ref abcdefghijklmnopqrst
   ```
   Si te pide la contraseña de la base, es la del paso 2.
6. Creá las tablas y cargá los datos de ejemplo. Si pregunta si querés continuar, respondé `y`:
   ```
   npm run db:push
   npm run db:seed
   ```
7. Comprobá que quedó todo bien. Cada línea tiene que decir **OK**:
   ```
   npm run db:verificar
   ```

### Comandos de la base de datos

| Comando | Qué hace |
|---|---|
| `npm run db:push` | Aplica en Supabase las migraciones nuevas (los cambios en las tablas) |
| `npm run db:seed` | Carga los datos de ejemplo. Si la base ya tiene datos, no hace nada |
| `npm run db:verificar` | Corre los chequeos de la base; cada línea tiene que decir OK |
| `npm run db:revisar` | Le pide a Supabase que revise la seguridad de la base |
| `npm run db:tipos` | Actualiza los tipos de TypeScript a partir de las tablas |

Nunca corras `npx supabase db reset --remote`: borra toda la base.

### Cambiar las tablas

1. Cada cambio va en un archivo nuevo dentro de `supabase/migrations/`. Se crea con:
   ```
   npx supabase migration new nombre-del-cambio
   ```
2. Una migración que ya se aplicó no se edita: para corregirla se crea otra.
3. Después de aplicarla con `npm run db:push`, corré `npm run db:tipos`.

### Si la base no responde

Los proyectos gratuitos se pausan después de una semana sin uso. Entrá al panel de Supabase,
abrí el proyecto y tocá **Restore project**. Vuelve a funcionar en unos minutos.

## Tests

```
npm test
```

Corre todos los tests una vez y muestra cuáles pasaron. Los tests usan
[Vitest](https://vitest.dev) y se instalan junto con el resto en `npm install`.

Mientras programás, `npm run test:watch` los vuelve a correr cada vez que guardás un archivo.
Para salir, apretá `q`.

## Otros comandos

| Comando | Qué hace |
|---|---|
| `npm run lint` | Revisa el código en busca de errores comunes |
| `npm run build` | Genera la versión de producción (lo mismo que hará Vercel) |
