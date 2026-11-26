// =============================================================================
// config.js — DATOS DE LA PELUQUERÍA
//
// Junto con la ZONA DE MARCA de css/styles.css, es el ÚNICO lugar donde viven
// datos de una peluquería concreta. Para instalar el sistema en una peluquería
// nueva se edita este archivo; el resto del código no se toca.
//
// Los valores actuales son de una peluquería FICTICIA de ejemplo.
// =============================================================================

export default Object.freeze({
  negocio: {
    nombre: 'Ónix Peluquería',
    eslogan: 'Cortes, color y barba con turno, sin esperas',
    // La ruta es absoluta porque las páginas del panel (/admin/) también la usan.
    logo: '/assets/marca/logo.svg',
  },

  contacto: {
    // Formato internacional sin espacios (+595…). Se usa para armar los enlaces
    // wa.me; el formato legible para mostrarlo se genera en el código.
    whatsapp: '+595981000000', // número ficticio
    direccion: 'Calle Ejemplo 123 c/ Calle Ficticia, Asunción',
    mapaUrl: '', // enlace de Google Maps (opcional)
  },

  // Dejar vacía la red que no se use: la página no la mostrará.
  redes: {
    instagram: 'https://www.instagram.com/onix.peluqueria.ejemplo',
    facebook: '',
    tiktok: '',
  },

  supabase: {
    // Valores del Supabase LOCAL de desarrollo (`npx supabase status`).
    // En cada deploy se reemplazan por los del proyecto de esa peluquería
    // (panel de Supabase → Project Settings → API Keys).
    //
    // publishableKey es la "Publishable key" (sb_publishable_…); en proyectos con las
    // claves antiguas equivale a la "anon key". Es pública por diseño: lo que protege
    // los datos son RLS y las funciones RPC. La Secret key (sb_secret_…) o service_role
    // NUNCA va acá ni en ningún archivo del repositorio.
    url: 'http://127.0.0.1:44321',
    publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  },
});
