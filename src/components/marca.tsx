import Link from "next/link";
import { NOMBRE_NEGOCIO } from "@/lib/negocio";

export function Marca() {
  return (
    <Link
      href="/"
      className="inline-flex items-center gap-3 rounded-sm outline-offset-4 focus-visible:outline-2"
    >
      {/* Lugar reservado para el logo definitivo */}
      <span aria-hidden="true" className="size-10 border border-dorado-oscuro" />
      <span className="text-lg font-semibold tracking-wide font-stretch-expanded">
        {NOMBRE_NEGOCIO}
      </span>
    </Link>
  );
}
