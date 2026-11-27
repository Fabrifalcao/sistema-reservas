# Guías de los sprints

Guía de cada sprint tal como la definió el usuario, con sus agregados posteriores ya incorporados. **Al empezar un sprint, Claude lee su guía completa** junto con `CLAUDE.md` y presenta un plan antes de escribir código.

Archivo de uso interno: no se publica en el deploy.

## Adaptaciones respecto de los textos originales

Los textos originales se escribieron antes de algunas decisiones de los Sprints 0 y 1. Acá ya están ajustados así:

| Texto original | Cómo quedó | Por qué |
|---|---|---|
| `theme.css` | Bloque **ZONA DE MARCA** de `css/styles.css` | Sprint 0: un único archivo CSS |
| `guia-estilos.html` | `herramientas/guia-estilos.html` | Sprint 0: uso interno, no se publica |
| Colores "dorados sobre negro" | Colores de la marca actual (variables de `css/styles.css`) | Sprint 0: se descartó el dorado; la base es `DESIGN.md` |
| `recordatorio_enviado_at` | `recordatorio_enviado_en` | La base usa el sufijo en castellano (`creado_en`, `cancelada_en`) |
| Peluqueros: "servicios que realiza" | No aplica | Sprint 1: todos los peluqueros hacen todos los servicios |
| "Crear usuario admin" | Cuenta de Auth **más** su fila en `administradores` | Sprint 1: sin esa fila, RLS no le muestra nada |

Además, los textos al cliente van con **tú**.

Los Sprints 0 y 1 están cerrados: ver "Estado actual" en `CLAUDE.md`.

---

## Sprint 2 — Lógica de disponibilidad, reservas y cancelación

Lógica en la base de datos. Crear funciones RPC `SECURITY DEFINER`:

1. **`obtener_disponibilidad(fecha, servicio_ids[], peluquero_id opcional)`** → horarios disponibles y qué peluqueros pueden atender cada uno. Considera:
   - horarios partidos;
   - bloqueos;
   - reservas existentes;
   - que el bloque completo termine antes del cierre;
   - la anticipación mínima;
   - las horas ya pasadas del día actual.

   Un peluquero con bloqueo (día libre, ausencia, vacaciones) no ofrece horarios durante ese período: ni cuando el cliente lo elige directamente ni dentro del cálculo de "Cualquiera disponible". Los bloqueos pueden ser de día completo o de una franja (por ejemplo, solo por la tarde).
2. **`obtener_dias_disponibles(desde, hasta, servicio_ids[], peluquero_id opcional)`** → para deshabilitar en el calendario los días sin turnos.
3. **`crear_reserva(nombre, telefono, servicio_ids[], inicio, peluquero_id opcional)`** →
   - revalida todo dentro de la transacción;
   - asigna peluquero si es "cualquiera";
   - aplica el límite por teléfono;
   - crea o actualiza el cliente;
   - devuelve un resumen y el token.
4. **`obtener_reserva_por_token(token)`** y **`cancelar_reserva(token)`** → respetan el límite de 3 horas y devuelven mensajes de error claros en castellano.

Escribir tests con pgTAP (`supabase test db`) que cubran:
- doble reserva simultánea;
- horario partido;
- bloqueo;
- servicio que no entra antes del cierre;
- cancelación a 2h59 vs 3h01;
- que anon no pueda leer tablas;
- con 3 peluqueros y uno bloqueado ese día, "Cualquiera disponible" permite como máximo 2 turnos simultáneos.

Primero el plan.

**Notas acordadas para el plan:**
- **"Menos cargado del día"** = el que tiene menos minutos reservados ese día, contando las reservas no canceladas. Desempate: menos reservas; si sigue el empate, menor `orden`. Se cuentan minutos y no reservas porque los servicios duran distinto y se combinan: 2 turnos de 90 minutos ocupan más que 3 de 30.
- **Test de zona horaria:** `'2026-07-15 12:00 America/Asuncion'::timestamptz` debe ser igual a `'2026-07-15 15:00+00'`.
  - Desde octubre de 2024, Paraguay es UTC-3 todo el año.
  - Si el test falla, la base tiene datos de zona horaria desactualizados y en invierno todos los turnos se correrían una hora.
  - En la base local pasa (verificado el 2026-11-26, Postgres 17.12).
- **"Que anon no pueda leer tablas"** ya lo cubre `01_seguridad.test.sql` del Sprint 1. Se reutiliza ese test y se amplía su lista blanca con las RPC nuevas, en lugar de escribir uno duplicado.
- Cada RPC pública lleva `grant execute … to anon` explícito y entra en esa lista blanca.
- `crear_reserva` guarda `asignacion_automatica = true` cuando el peluquero se asignó con "Cualquiera disponible".
- Antiabuso: honeypot y límite de reservas activas por teléfono (ver `CLAUDE.md`).

---

## Sprint 3 — Página pública de reserva

Página pública de reserva, con los componentes de `herramientas/guia-estilos.html` y la zona de marca de `css/styles.css`. Flujo por pasos en una sola página:

1. Elegir uno o más servicios, mostrando la duración y el precio total en Gs.
2. Elegir peluquero o "Cualquiera disponible". Si el peluquero tiene bloqueado el día de hoy, su tarjeta muestra la etiqueta **"No disponible hoy"**.
3. Calendario con los días sin disponibilidad deshabilitados. Un peluquero con un día bloqueado sigue apareciendo en la lista, pero ese día queda desactivado en su calendario. Con "Cualquiera disponible", el peluquero bloqueado directamente no se tiene en cuenta.
4. Grilla de horarios.
5. Nombre + WhatsApp, con validación de número paraguayo.
6. Pantalla de confirmación con:
   - el resumen;
   - el botón "Agregar a mi calendario" (`.ics`);
   - el enlace de cancelación.

Crear también la página de cancelación por token.

Incluir:
- estados de carga;
- errores amigables (por ejemplo, "ese horario se acaba de ocupar, elige otro");
- honeypot;
- navegación hacia atrás entre pasos sin perder datos.

Mobile-first. Textos al cliente con *tú*. Primero el plan.

---

## Sprint 4 — Panel del dueño

Login con Supabase Auth: email y contraseña, sin registro público. Documentar cómo crear el usuario admin, que es la cuenta de Auth **más** su fila en `administradores`.

Secciones:
- Agenda del día y de la semana, con una columna por peluquero.
- Crear reserva manual (cliente que llama o llega al local).
- Marcar completada / no asistió / cancelar.
- Servicios: CRUD, precio editable, activar/desactivar, orden.
- Peluqueros: CRUD y horarios semanales. Todos hacen todos los servicios.
- Bloqueos y feriados.
- Clientes:
  - buscar por nombre o teléfono;
  - historial y cantidad de visitas;
  - botón para abrir el chat de WhatsApp.
- Estadísticas: turnos por mes, ingresos estimados en Gs., servicios más pedidos, turnos por peluquero, tasa de cancelación y de no asistencia. El detalle está en el Sprint 4B.
- Acción rápida **"Deshabilitar por hoy / por un día"**:
  - **Dónde:** desde la agenda (en la columna de cada peluquero) y desde la ficha del peluquero.
  - **Qué marca:** un día libre en dos clics, eligiendo día completo o franja horaria, y opcionalmente un rango de días (vacaciones).
  - **Volver atrás:** también puede volver a habilitarlo.
  - **Si ya hay turnos ese día:** mostrarlos antes de confirmar y ofrecer, para cada uno:
    - reasignarlo a otro peluquero libre en el mismo horario, o
    - cancelarlo, con aviso por WhatsApp cuando exista el Sprint 5.
  - **En la agenda:** los días deshabilitados se ven marcados.

Mismo estilo visual, utilizable desde el celular. Primero el plan.

**Notas acordadas para el plan:**
- **Cómo lo ve el cliente:** en el flujo público primero se elige al peluquero y después la fecha. El peluquero deshabilitado sigue en la lista, pero ese día queda desactivado en su calendario. Con "Cualquiera disponible", directamente no se lo tiene en cuenta (ver Sprint 3, pasos 2 y 3).
- **Al reasignar un turno:** si `asignacion_automatica` es `false` (el cliente pidió a ese peluquero), el panel lo avisa antes de cambiarlo.
- **Componentes:** el selector de peluquero de la guía de estilos sirve para asignar y reasignar.

---

## Sprint 4B — Estadísticas del negocio

Sección "Estadísticas" en el panel del dueño. Se hace junto al Sprint 4. Leer `CLAUDE.md`.

### Filtros generales
- **Rango de fechas**, con atajos: esta semana, este mes, últimos 3 meses, este año, personalizado.
- **Peluquero:** todos o uno.
- Cada métrica se compara con el período anterior equivalente (por ejemplo, "+12% vs mes pasado").

### Métricas
1. **Resumen (tarjetas):**
   - total de turnos atendidos;
   - clientes únicos;
   - clientes nuevos vs recurrentes;
   - ingresos estimados en Gs.;
   - ticket promedio;
   - tasa de cancelación y de no asistencia.
2. **Clientes por día:** gráfico de línea o barras con la cantidad de clientes atendidos cada día del rango.
3. **Mapa de calor "día de la semana × hora":**
   - filas de lunes a domingo, y columnas por franja horaria del horario de atención;
   - el color indica el promedio de clientes en esa franja;
   - tiene que responder de un vistazo "¿a qué hora tengo más clientes cada día?";
   - debajo, una lista con la hora pico de cada día de la semana.
4. **Día de la semana más fuerte y más flojo**, por promedio de clientes por día.
5. **Servicios más pedidos**, por cantidad y por ingresos.
6. **Rendimiento por peluquero:** turnos, ingresos y porcentaje de ocupación (horas reservadas / horas disponibles según su horario y sus bloqueos).
7. **Clientes frecuentes:** top 10 por cantidad de visitas, con la fecha de la última visita.
8. **Clientes inactivos:** los que vinieron 2 o más veces pero no volvieron en los últimos 60 días, con un botón para abrir WhatsApp (sirve para recuperarlos).
9. **Anticipación de reserva:** cuántos reservan el mismo día, 1–2 días antes o con más anticipación.

### Reglas técnicas
- Los cálculos se hacen en la base de datos, con funciones SQL (RPC) accesibles solo para el admin autenticado. No se traen todas las reservas al navegador.
- Agrupar siempre por fecha y hora en America/Asuncion, nunca en UTC: si no, las horas pico salen corridas.
- Como "atendidos" cuentan solo los turnos con estado `completada`, más los `confirmada` ya pasados si el dueño no los marcó. Los cancelados y los no asistidos (`ausente`) se cuentan aparte.
- Gráficos:
  - Chart.js desde CDN con versión fijada, o SVG/CSS propio para el mapa de calor;
  - con los colores de la marca (variables de `css/styles.css`): una escala del color de acento sobre el fondo oscuro.
- Estados vacíos amables cuando todavía no hay datos ("Aún no hay suficientes turnos para mostrar esta estadística").
- Botón para exportar a CSV los datos del rango.
- Usable desde el celular: en pantallas chicas, tarjetas apiladas y el mapa de calor con scroll horizontal.
- Agregar al seed de prueba unos 3 meses de reservas ficticias con patrones realistas (más movimiento viernes y sábados por la tarde), para ver las estadísticas funcionando.

Primero el plan.

---

## Sprint 5 — WhatsApp: confirmación, recordatorio y cancelación

Notificaciones por WhatsApp con la WhatsApp Cloud API de Meta.

- **Edge Function `enviar-whatsapp`**, que use plantillas aprobadas. Proponer el texto en castellano de las plantillas (categoría *utility*):
  - confirmación de turno, con el enlace de cancelación;
  - recordatorio del día;
  - aviso de cancelación.
- **Disparos:** la confirmación al crear una reserva y el aviso al cancelar.
- **Recordatorio:** un job con pg_cron que corra cada mañana, en hora de Asunción, y envíe el recordatorio a los turnos del día que todavía no lo tengan. Usar `recordatorio_enviado_en` para no duplicar.
- **Registro:** una tabla de mensajes (enviado / fallido / error) y un reintento simple.
- **MODO SIN API:** si no hay credenciales configuradas, no se envía nada. En el panel del dueño aparece un botón por turno que abre wa.me con el mensaje ya redactado, para enviarlo a mano. Así una peluquería puede usar el sistema sin pagar la API.
- **Credenciales:** solo como secretos de Supabase.
- **Documentación:** paso a paso de cómo configurar Meta Business, el número y las plantillas.

Primero el plan.

**Nota técnica para el plan:** pg_cron programa en UTC. La hora "de cada mañana en Asunción" tiene que salir de la zona `America/Asuncion`, no de un offset fijo. Por ejemplo, el job puede correr cada hora y enviar solo cuando en Asunción sea la hora elegida.

---

## Sprint 6 — Cierre

1. **Auditoría de seguridad:** revisar todas las políticas RLS y funciones RPC buscando fugas de datos o abusos posibles, y corregirlas.
2. **Pulido:**
   - favicon;
   - meta tags y Open Graph, para que se vea bien al compartir el enlace por WhatsApp;
   - página 404;
   - rendimiento y accesibilidad.
3. **Deploy** del frontend en hosting estático. Publicar **solo los archivos públicos**: no deben quedar accesibles `CLAUDE.md`, `DESIGN.md`, `README.md`, `SPRINTS.md`, `INSTALAR-NUEVO-CLIENTE.md`, `supabase/` ni `herramientas/`.
4. **`INSTALAR-NUEVO-CLIENTE.md`**, con un checklist completo para entregar una copia nueva:
   1. Crear el proyecto de Supabase.
   2. Aplicar las migraciones (`supabase db push`). **Nunca** correr `seed.sql`: es solo para desarrollo.
   3. Comprobar la zona horaria de la base en la nube con la consulta del test de zona horaria (Sprint 2). Esa base es otra compilación de Postgres y podría traer datos viejos.
   4. Desactivar el registro de cuentas en el panel de Supabase.
   5. Crear el usuario admin: la cuenta de Auth más su fila en `administradores`.
   6. Completar `config.js`, la zona de marca de `css/styles.css` y `assets/marca/`. Verificar el contraste con `herramientas/guia-estilos.html`.
   7. Cargar servicios y peluqueros.
   8. Configurar WhatsApp o el modo sin API.
   9. Deploy y dominio propio.

   Si algún paso se puede automatizar con un script, crearlo.

Primero el plan.
