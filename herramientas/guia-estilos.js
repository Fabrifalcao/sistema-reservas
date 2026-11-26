// =============================================================================
// Guía de estilos
//
// No tiene colores propios: lee la marca de config.js y las variables de la
// ZONA DE MARCA de css/styles.css. Así sirve para validar la instalación en una
// peluquería nueva: si un color de la marca no llega a WCAG AA, la tabla de
// contraste lo marca sin tocar este archivo.
// =============================================================================

import config from '../config.js';

const raiz = document.documentElement;
const leerVariable = (token) => getComputedStyle(raiz).getPropertyValue(token).trim();

// --- Marca (desde config.js) ---
function pintarMarca() {
  const { nombre, logo } = config.negocio;
  document.title = `Guía de estilos · ${nombre}`;
  document.querySelectorAll('[data-config="nombre"]').forEach((el) => {
    el.textContent = nombre;
  });
  const lugarLogo = document.querySelector('[data-config="logo"]');
  if (lugarLogo && logo) {
    const img = new Image(40, 40);
    img.src = logo;
    img.alt = ''; // decorativo: el nombre aparece al lado
    img.className = 'marca__logo';
    lugarLogo.replaceWith(img);
  }
  document.querySelectorAll('[data-fuente]').forEach((el) => {
    // Primera familia del stack, sin comillas: es la que la marca eligió.
    el.textContent = leerVariable(el.dataset.fuente).split(',')[0].replace(/['"]/g, '').trim();
  });
}

// --- Paleta ---
const PALETA = [
  {
    grupo: 'Superficies',
    tokens: [
      ['--color-fondo-hundido', 'Fondo hundido', 'Campos, horarios ocupados, pie'],
      ['--color-fondo', 'Fondo', 'Lienzo de la página'],
      ['--color-superficie', 'Superficie', 'Tarjetas y paneles'],
      ['--color-superficie-hover', 'Superficie hover', 'Botón secundario con el cursor encima'],
      ['--color-inactivo', 'Inactivo', 'Solo superficie, nunca texto'],
    ],
  },
  {
    grupo: 'Texto',
    tokens: [
      ['--color-titulos', 'Títulos', 'Títulos y nombres de servicio'],
      ['--color-texto', 'Texto', 'Cuerpo y ayudas'],
      ['--color-enfasis', 'Énfasis', 'Etiquetas de campos y énfasis'],
      ['--color-cita', 'Cita', 'Testimonios'],
    ],
  },
  {
    grupo: 'Acentos',
    tokens: [
      ['--color-acento', 'Acento', 'Precios en Gs. y cifras'],
      ['--color-destello', 'Destello', 'Servicio elegido'],
      ['--gradiente-cta', 'Degradé del botón principal', 'Una vez por pantalla'],
      ['--color-sobre-cta', 'Texto sobre el degradé', 'Texto del botón principal'],
      ['--gradiente-decorativo', 'Degradé decorativo', 'Nunca con texto encima'],
    ],
  },
  {
    grupo: 'Formularios y estados',
    tokens: [
      ['--color-borde-campo', 'Borde de campo', 'Campos, horarios y opciones'],
      ['--color-separador', 'Separador', 'Solo líneas decorativas'],
      ['--color-ocupado', 'Ocupado', 'Horarios no disponibles y placeholders'],
      ['--color-seleccion-fondo', 'Selección: fondo', 'Peluquero u horario elegido'],
      ['--color-seleccion-texto', 'Selección: texto', 'Texto de la opción elegida'],
      ['--color-foco', 'Foco', 'Anillo de foco con teclado'],
      ['--color-exito', 'Éxito', 'Confirmaciones'],
      ['--color-error', 'Error', 'Errores, siempre con texto'],
    ],
  },
];

function crear(etiqueta, clase, texto) {
  const el = document.createElement(etiqueta);
  if (clase) el.className = clase;
  if (texto !== undefined) el.textContent = texto;
  return el;
}

function pintarPaleta() {
  const contenedor = document.getElementById('paleta-grupos');
  for (const { grupo, tokens } of PALETA) {
    const bloque = crear('div');
    bloque.append(crear('h3', 'guia-subtitulo', grupo));
    const grilla = crear('div', 'guia-muestras');
    for (const [token, nombre, uso] of tokens) {
      const muestra = crear('div', 'guia-muestra');
      const color = crear('span');
      color.style.background = `var(${token})`;
      const texto = crear('span', 'guia-muestra__texto');
      texto.append(crear('b', '', nombre), crear('code', '', token), crear('code', '', leerVariable(token)), crear('span', '', uso));
      muestra.append(color, texto);
      grilla.append(muestra);
    }
    bloque.append(grilla);
    contenedor.append(bloque);
  }
}

// --- Contraste WCAG ---
// [texto o elemento, fondo, mínimo, uso]
const PARES = [
  ['--color-titulos', '--color-fondo', 4.5, 'Títulos sobre el fondo'],
  ['--color-titulos', '--color-superficie', 4.5, 'Títulos y botón secundario sobre superficie'],
  ['--color-texto', '--color-fondo', 4.5, 'Texto sobre el fondo'],
  ['--color-texto', '--color-superficie', 4.5, 'Texto sobre tarjetas'],
  ['--color-texto', '--color-fondo-hundido', 4.5, 'Texto sobre fondo hundido'],
  ['--color-enfasis', '--color-fondo', 4.5, 'Etiquetas de campos sobre el fondo'],
  ['--color-enfasis', '--color-superficie', 4.5, 'Énfasis sobre tarjetas'],
  ['--color-acento', '--color-superficie', 4.5, 'Precios sobre tarjetas'],
  ['--color-acento', '--color-fondo', 4.5, 'Precios sobre el fondo'],
  ['--color-sobre-cta', '--gradiente-cta', 4.5, 'Texto del botón principal'],
  ['--color-seleccion-texto', '--color-seleccion-fondo', 4.5, 'Opción elegida'],
  ['--color-ocupado', '--color-fondo-hundido', 4.5, 'Horario ocupado y placeholders'],
  ['--color-error', '--color-fondo', 4.5, 'Error sobre el fondo'],
  ['--color-error', '--color-superficie', 4.5, 'Error sobre tarjetas'],
  ['--color-exito', '--color-superficie', 4.5, 'Confirmación sobre tarjetas'],
  ['--color-borde-campo', '--color-fondo', 3, 'Borde de campo sobre el fondo'],
  ['--color-borde-campo', '--color-superficie', 3, 'Borde de campo sobre tarjetas'],
  ['--color-borde-campo', '--color-fondo-hundido', 3, 'Borde de campo contra su relleno'],
  ['--color-foco', '--color-fondo', 3, 'Anillo de foco sobre el fondo'],
  ['--color-foco', '--color-superficie', 3, 'Anillo de foco sobre tarjetas'],
];

// El navegador convierte cualquier color CSS (hex, rgb, nombre) a rgb()/rgba()
// en el estilo computado: usamos un elemento sonda para no parsear formatos.
let sonda;
function aRgb(valorCss) {
  sonda.style.color = '';
  sonda.style.color = valorCss;
  const numeros = getComputedStyle(sonda).color.match(/[\d.]+/g);
  if (!numeros || numeros.length < 3) return null;
  const [r, g, b, a = 1] = numeros.map(Number);
  return { r, g, b, a };
}

// Un degradé se evalúa en cada una de sus paradas de color.
function coloresDe(token) {
  const valor = leerVariable(token);
  if (valor.includes('gradient')) {
    return valor.match(/#[0-9a-f]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\)/gi) ?? [];
  }
  return [valor];
}

// Un color semitransparente se ve mezclado con lo que tiene debajo.
function componer(color, debajo) {
  const a = color.a;
  return {
    r: color.r * a + debajo.r * (1 - a),
    g: color.g * a + debajo.g * (1 - a),
    b: color.b * a + debajo.b * (1 - a),
    a: 1,
  };
}

function luminancia({ r, g, b }) {
  const lineal = (c) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * lineal(r) + 0.7152 * lineal(g) + 0.0722 * lineal(b);
}

function ratio(c1, c2) {
  const [claro, oscuro] = [luminancia(c1), luminancia(c2)].sort((x, y) => y - x);
  return (claro + 0.05) / (oscuro + 0.05);
}

// Devuelve NaN si algún color no se pudo leer (variable vacía o mal escrita).
function peorRatio(tokenTexto, tokenFondo) {
  const base = aRgb(leerVariable('--color-fondo'));
  const fondos = coloresDe(tokenFondo).map(aRgb);
  const textos = coloresDe(tokenTexto).map(aRgb);
  if (!base || !fondos.length || !textos.length || [...fondos, ...textos].includes(null)) return NaN;
  let peor = Infinity;
  for (const colorFondo of fondos) {
    const fondo = componer(colorFondo, base);
    for (const colorTexto of textos) {
      peor = Math.min(peor, ratio(componer(colorTexto, fondo), fondo));
    }
  }
  return peor;
}

const formatoRatio = (n) => (Number.isNaN(n) ? 'sin leer' : n.toFixed(2).replace('.', ','));

function pintarContraste() {
  sonda = crear('span');
  sonda.hidden = true;
  document.body.append(sonda);

  const filas = document.getElementById('contraste-filas');
  let fallas = 0;
  for (const [texto, fondo, minimo, uso] of PARES) {
    const valor = peorRatio(texto, fondo);
    const pasa = valor >= minimo;
    if (!pasa) fallas += 1;

    const fila = crear('tr');
    const celdaUso = crear('td');
    const par = crear('span', 'guia-par');
    const puntos = crear('span', 'guia-par__puntos');
    for (const token of [texto, fondo]) {
      const punto = crear('span');
      punto.style.background = `var(${token})`;
      puntos.append(punto);
    }
    const descripcion = crear('span');
    descripcion.append(document.createTextNode(`${uso} `), crear('code', '', `${texto} / ${fondo}`));
    par.append(puntos, descripcion);
    celdaUso.append(par);

    const celdaResultado = crear('td');
    celdaResultado.append(crear('span', `guia-resultado guia-resultado--${pasa ? 'ok' : 'falla'}`, pasa ? 'Pasa' : 'Falla'));

    fila.append(celdaUso, crear('td', 'cifra', formatoRatio(valor)), crear('td', 'cifra', formatoRatio(minimo)), celdaResultado);
    filas.append(fila);
  }
  document.getElementById('contraste-resumen').textContent = fallas
    ? `${fallas} de ${PARES.length} pares no llegan al mínimo AA: revisar la zona de marca.`
    : `Los ${PARES.length} pares cumplen WCAG AA.`;
}

// --- Resumen de servicios elegidos ---
// Formato propio de guaraníes: Intl con 'es' no agrupa números de 4 cifras
// (5000 en vez de 5.000), así que se agrupa a mano con punto.
const formatoGs = (n) => `Gs. ${String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;

function activarServicios() {
  const casillas = [...document.querySelectorAll('input[name="servicios"]')];
  const resumen = document.getElementById('resumen-servicios');
  const actualizar = () => {
    const elegidos = casillas.filter((c) => c.checked);
    const minutos = elegidos.reduce((total, c) => total + Number(c.dataset.minutos), 0);
    const precio = elegidos.reduce((total, c) => total + Number(c.dataset.precio), 0);
    resumen.replaceChildren(
      crear('span', '', elegidos.length ? `${minutos} min seguidos` : 'Ningún servicio elegido'),
      crear('span', 'precio', elegidos.length ? formatoGs(precio) : ''),
    );
  };
  casillas.forEach((c) => c.addEventListener('change', actualizar));
  actualizar();
}

document.getElementById('form-guia').addEventListener('submit', (e) => e.preventDefault());

// Esperar a las fuentes evita leer variables antes de que el CSS esté aplicado.
await document.fonts.ready;
pintarMarca();
pintarPaleta();
pintarContraste();
activarServicios();
