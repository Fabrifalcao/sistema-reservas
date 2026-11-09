import { formatearDuracion, formatearGuaranies } from "@/lib/formato";

export type ServicioResumen = {
  id: string;
  nombre: string;
  duracion_min: number;
  precio_gs: number;
};

export function ListaServicios({ servicios }: { servicios: ServicioResumen[] }) {
  return (
    <ul className="divide-y divide-border border-y border-border">
      {servicios.map((servicio) => (
        <li key={servicio.id} className="flex items-baseline justify-between gap-4 py-4">
          <div>
            <p className="font-medium">{servicio.nombre}</p>
            <p className="mt-0.5 text-sm text-muted-foreground">
              {formatearDuracion(servicio.duracion_min)}
            </p>
          </div>
          <p className="shrink-0 tabular-nums">{formatearGuaranies(servicio.precio_gs)}</p>
        </li>
      ))}
    </ul>
  );
}
