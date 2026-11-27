-- =============================================================================
-- Seguridad base
--
-- Por defecto, Supabase da a anon y authenticated permisos completos sobre todo
-- lo que el rol postgres crea en el esquema public (tablas, secuencias y
-- funciones), y Postgres además deja ejecutar cualquier función nueva a PUBLIC.
-- Este sistema necesita lo contrario: el público (anon) solo entra por funciones
-- RPC habilitadas una por una. Desde esta migración, nada nuevo queda expuesto
-- sin un GRANT explícito.
--
-- El test supabase/tests/database/01_seguridad.test.sql verifica que siga así.
-- =============================================================================

-- btree_gist permite combinar "=" (mismo peluquero) con "&&" (rangos que se
-- solapan) en un mismo exclusion constraint.
create extension if not exists btree_gist with schema extensions;

-- Cerrar los permisos por defecto que Supabase da en el esquema public.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;

-- El EXECUTE para PUBLIC es un valor por defecto global de Postgres: solo se
-- puede quitar a nivel global, no por esquema.
alter default privileges for role postgres
  revoke execute on functions from public;

-- Esquema para funciones auxiliares internas. No figura en api.schemas de
-- supabase/config.jsonc, así que la API REST no lo publica.
create schema if not exists privado;
revoke all on schema privado from public;
