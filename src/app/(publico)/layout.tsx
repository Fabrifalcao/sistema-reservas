import type { Viewport } from "next";
import { Marca } from "@/components/marca";

export const viewport: Viewport = {
  themeColor: "#000000",
};

// El sitio público usa el tema oscuro (negro y dorado); el admin usa el claro.
export default function LayoutPublico({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <div className="dark tema-publico flex min-h-dvh flex-col bg-background text-foreground">
      <header className="mx-auto w-full max-w-md px-4 pt-5 pb-8">
        <Marca />
      </header>
      <main className="mx-auto w-full max-w-md flex-1 px-4 pb-12">{children}</main>
    </div>
  );
}
