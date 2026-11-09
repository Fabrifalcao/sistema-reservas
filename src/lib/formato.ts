// "always" fuerza el separador de miles también en números de 4 cifras
// (en español, por defecto, 5000 se escribiría sin punto).
const guaranies = new Intl.NumberFormat("es-PY", {
  maximumFractionDigits: 0,
  useGrouping: "always",
});

/** 50000 → "Gs. 50.000" */
export function formatearGuaranies(monto: number): string {
  return `Gs. ${guaranies.format(monto)}`;
}

/** 30 → "30 min", 60 → "1 h", 90 → "1 h 30 min" */
export function formatearDuracion(minutos: number): string {
  const horas = Math.floor(minutos / 60);
  const resto = minutos % 60;
  if (horas === 0) return `${resto} min`;
  if (resto === 0) return `${horas} h`;
  return `${horas} h ${resto} min`;
}
