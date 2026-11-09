import type { Metadata } from "next";
import { Archivo } from "next/font/google";
import { NOMBRE_NEGOCIO } from "@/lib/negocio";
import "./globals.css";

// Archivo es variable en peso y en ancho: el ancho expandido (font-stretch-expanded)
// se usa para la marca, los títulos y los horarios grandes.
const archivo = Archivo({
  variable: "--font-sans",
  subsets: ["latin"],
  axes: ["wdth"],
});

export const metadata: Metadata = {
  title: {
    default: `${NOMBRE_NEGOCIO} · Reservá tu turno`,
    template: `%s · ${NOMBRE_NEGOCIO}`,
  },
  description: `Reservá tu turno en ${NOMBRE_NEGOCIO} desde el celular, sin crear una cuenta.`,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="es-PY" className={`${archivo.variable} antialiased`}>
      <body className="min-h-dvh">{children}</body>
    </html>
  );
}
