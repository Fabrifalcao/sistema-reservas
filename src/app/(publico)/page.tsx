import { ListaServicios, type ServicioResumen } from "@/components/lista-servicios";

// Etapa 3: estos datos pasan a leerse de Supabase (tabla servicios).
const servicios: ServicioResumen[] = [
  { id: "corte-caballero", nombre: "Corte caballero", duracion_min: 30, precio_gs: 50000 },
  { id: "corte-dama", nombre: "Corte dama", duracion_min: 45, precio_gs: 80000 },
  { id: "color", nombre: "Color", duracion_min: 90, precio_gs: 200000 },
  { id: "barba", nombre: "Barba", duracion_min: 20, precio_gs: 30000 },
];

export default function Inicio() {
  return (
    <>
      <h1 className="text-4xl leading-tight font-semibold text-balance font-stretch-expanded">
        Reservá tu turno
      </h1>
      <p className="mt-3 max-w-prose text-muted-foreground">
        Elegí el servicio, el peluquero y el horario. No hace falta crear una cuenta.
      </p>

      <h2 className="mt-10 mb-2 text-sm text-muted-foreground">Servicios</h2>
      <ListaServicios servicios={servicios} />
    </>
  );
}
