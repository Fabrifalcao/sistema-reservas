// Maqueta: los horarios ocupados son inventados y las reservas no se guardan
const SERVICIOS = [
    { id: "corte", nombre: "Corte", dientes: 1, precio: 14000 },
    { id: "barba", nombre: "Corte y barba", dientes: 2, precio: 20000 },
    { id: "brushing", nombre: "Lavado y brushing", dientes: 2, precio: 16000 },
    { id: "color", nombre: "Color", dientes: 4, precio: 45000 },
    { id: "mechas", nombre: "Mechas", dientes: 6, precio: 68000 }
];
const PERSONAS = ["Mara", "Nico"];
const CUALQUIERA = "Quien esté libre";
const TOTAL_DIENTES = 20;
const APERTURA = 9 * 60;
const MEDIA_HORA = 30;
const DIAS_CERRADOS = [0, 1];

const $ = (id) => document.getElementById(id);
const precio = (n) => "$" + n.toLocaleString("es-AR");
const hora = (minutos) =>
    String(Math.floor(minutos / 60)).padStart(2, "0") + ":" + String(minutos % 60).padStart(2, "0");
const horaDiente = (i) => hora(APERTURA + i * MEDIA_HORA);
const fechaLarga = (d) => {
    const texto = d.toLocaleDateString("es-AR", { weekday: "long", day: "numeric", month: "long" });
    return texto.charAt(0).toUpperCase() + texto.slice(1).replace(",", "");
};
const duracion = (dientes) => {
    const minutos = dientes * MEDIA_HORA;
    if (minutos < 60) return minutos + " min";
    const horas = minutos / 60;
    return (horas + (horas === 1 ? " hora" : " horas")).replace(".", ",");
};

const hoy = new Date();
hoy.setHours(0, 0, 0, 0);
const DIAS = Array.from({ length: 7 }, (_, n) => {
    const d = new Date(hoy);
    d.setDate(hoy.getDate() + n);
    return d;
});

const reservados = new Set();
const estado = { servicio: SERVICIOS[0], persona: CUALQUIERA, dia: null, elegido: null };

function ocupadoInventado(dia, persona, i) {
    const semilla = dia.getDate() * 12.9898 + (PERSONAS.indexOf(persona) + 1) * 78.233 + i * 37.719;
    const valor = Math.sin(semilla) * 43758.5453;
    return valor - Math.floor(valor) < 0.55;
}

function libre(dia, persona, i) {
    if (i >= TOTAL_DIENTES) return false;
    if (reservados.has(dia.getTime() + "|" + persona + "|" + i)) return false;
    const yaPaso = dia.getTime() === hoy.getTime() &&
        APERTURA + i * MEDIA_HORA <= new Date().getHours() * 60 + new Date().getMinutes();
    return !yaPaso && !ocupadoInventado(dia, persona, i);
}

const candidatos = () => (estado.persona === CUALQUIERA ? PERSONAS : [estado.persona]);

function quienPuede(dia, i, dientes) {
    return candidatos().find((persona) => {
        for (let n = 0; n < dientes; n++) {
            if (!libre(dia, persona, i + n)) return false;
        }
        return true;
    });
}

function estadoDiente(dia, i) {
    if (quienPuede(dia, i, estado.servicio.dientes)) return "libre";
    return candidatos().some((p) => libre(dia, p, i)) ? "justo" : "roto";
}

const cerrado = (d) => DIAS_CERRADOS.includes(d.getDay());
const hayLugar = (d) => {
    for (let i = 0; i < TOTAL_DIENTES; i++) {
        if (quienPuede(d, i, estado.servicio.dientes)) return true;
    }
    return false;
};

function opcion(nombre, valor, contenido, marcada, alElegir, deshabilitada) {
    const label = document.createElement("label");
    label.className = "opcion" + (deshabilitada ? " cerrado" : "");
    label.innerHTML = '<input type="radio" name="' + nombre + '">' + contenido;
    const input = label.querySelector("input");
    input.value = valor;
    input.checked = marcada;
    input.disabled = !!deshabilitada;
    input.addEventListener("change", alElegir);
    return label;
}

function armarOpciones() {
    SERVICIOS.forEach((s) => {
        $("servicios").append(opcion("servicio", s.id,
            '<span class="servicio"><span>' + s.nombre + '</span><span class="duracion">' +
            duracion(s.dientes) + '</span><span class="precio">' + precio(s.precio) + "</span></span>",
            s === estado.servicio, () => { estado.servicio = s; revisarEleccion(); }));
    });

    [CUALQUIERA, ...PERSONAS].forEach((p) => {
        $("personas").append(opcion("persona", p, '<span class="pastilla">' + p + "</span>",
            p === estado.persona, () => { estado.persona = p; revisarEleccion(); }));
    });

    estado.dia = DIAS.find((d) => !cerrado(d) && hayLugar(d)) || DIAS.find((d) => !cerrado(d));

    DIAS.forEach((d) => {
        const corto = d.toLocaleDateString("es-AR", { weekday: "short" }).replace(".", "");
        $("dias").append(opcion("dia", d.getTime(),
            '<span class="pastilla"><small>' + corto + "</small><b>" + d.getDate() + "</b></span>",
            d === estado.dia, () => { estado.dia = d; revisarEleccion(); }, cerrado(d)));
    });

    for (let i = 0; i < TOTAL_DIENTES; i++) {
        const diente = document.createElement("button");
        diente.type = "button";
        diente.className = "diente";
        diente.style.setProperty("--i", i);
        diente.textContent = horaDiente(i);
        diente.addEventListener("click", () => elegir(i));
        diente.addEventListener("pointerenter", () => marcarPrevia(i));
        diente.addEventListener("pointerleave", () => marcarPrevia(null));
        diente.addEventListener("focus", () => marcarPrevia(i));
        diente.addEventListener("blur", () => marcarPrevia(null));
        $("dientes").append(diente);
    }
}

function marcarPrevia(i) {
    const dientes = [...$("dientes").children];
    dientes.forEach((d) => d.classList.remove("previa"));
    if (i === null || dientes[i].disabled) return;
    dientes.slice(i, i + estado.servicio.dientes).forEach((d) => d.classList.add("previa"));
}

// Si el turno elegido ya no entra con el nuevo servicio, persona o día, se suelta
function revisarEleccion() {
    let aviso = "";
    if (estado.elegido) {
        const quien = quienPuede(estado.dia, estado.elegido.i, estado.servicio.dientes);
        if (quien) estado.elegido.persona = quien;
        else {
            aviso = "El horario que tenías ya no está disponible. Elegí otro. ";
            estado.elegido = null;
        }
    }
    pintar(aviso);
}

function elegir(i) {
    estado.elegido = { i, persona: quienPuede(estado.dia, i, estado.servicio.dientes) };
    pintar();
}

function pintar(aviso = "") {
    const { servicio, dia, elegido, persona } = estado;
    $("lomo-dia").textContent = fechaLarga(dia);

    [...$("dientes").children].forEach((diente, i) => {
        const est = estadoDiente(dia, i);
        const marcado = elegido && i >= elegido.i && i < elegido.i + servicio.dientes;
        diente.dataset.estado = est;
        diente.toggleAttribute("data-elegido", !!marcado);
        diente.disabled = est !== "libre";
        diente.setAttribute("aria-pressed", marcado ? "true" : "false");
        diente.setAttribute("aria-label", horaDiente(i) + (est === "roto" ? ", ocupado" :
            est === "justo" ? ", no alcanza el tiempo para " + servicio.nombre : ", libre"));
    });

    const mensaje = $("mensaje");
    mensaje.classList.toggle("alerta", !!aviso);
    if (elegido) {
        const fin = APERTURA + (elegido.i + servicio.dientes) * MEDIA_HORA;
        mensaje.textContent = "De " + horaDiente(elegido.i) + " a " + hora(fin) + " con " + elegido.persona + ".";
    } else if (!hayLugar(dia)) {
        mensaje.textContent = aviso + "No queda lugar para " + servicio.nombre.toLowerCase() + " este día con " +
            (persona === CUALQUIERA ? "nadie" : persona) + ". Probá otro día.";
    } else {
        mensaje.textContent = aviso || "Tocá un diente libre. " + servicio.nombre + " lleva " + duracion(servicio.dientes) + ".";
    }

    const filas = [
        ["Servicio", servicio.nombre],
        ["Con quién", elegido ? elegido.persona : persona],
        ["Cuándo", elegido ? fechaLarga(dia) + ", " + horaDiente(elegido.i) : null],
        ["Precio", precio(servicio.precio)]
    ];
    $("resumen").replaceChildren(...filas.map(([titulo, valor]) => {
        const fila = document.createElement("div");
        const dt = document.createElement("dt");
        const dd = document.createElement("dd");
        dt.textContent = titulo;
        dd.textContent = valor || "Falta elegir el horario";
        dd.classList.toggle("pendiente", !valor);
        fila.append(dt, dd);
        return fila;
    }));
}

function validarCampo(input, error, texto) {
    const vacio = !input.value.trim();
    input.setAttribute("aria-invalid", vacio);
    $(error).textContent = vacio ? texto : "";
    return !vacio;
}

$("formulario").addEventListener("submit", (e) => {
    e.preventDefault();
    const nombreOk = validarCampo($("nombre"), "error-nombre", "Escribí tu nombre para saber a quién esperamos.");
    const telefonoOk = validarCampo($("telefono"), "error-telefono", "Escribí un teléfono para avisarte si hay cambios.");

    if (!estado.elegido) {
        pintar("Falta elegir el horario: tocá un diente libre del peine. ");
        $("titulo-hora").scrollIntoView({ behavior: "smooth", block: "start" });
        return;
    }
    if (!nombreOk || !telefonoOk) return;

    const { servicio, dia, elegido } = estado;
    for (let n = 0; n < servicio.dientes; n++) {
        reservados.add(dia.getTime() + "|" + elegido.persona + "|" + (elegido.i + n));
    }
    $("listo-texto").textContent = servicio.nombre + " con " + elegido.persona + ", " +
        fechaLarga(dia).toLowerCase() + " a las " + horaDiente(elegido.i) + ".";
    $("formulario").hidden = true;
    $("listo").hidden = false;
    $("listo-titulo").focus();
    estado.elegido = null;
    pintar();
});

$("otro").addEventListener("click", () => {
    $("formulario").reset();
    $("formulario").hidden = false;
    $("listo").hidden = true;
    $("nombre").focus();
});

armarOpciones();
pintar();
setTimeout(() => $("dientes").classList.remove("entrada"), 1200);
