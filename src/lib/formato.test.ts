import { describe, expect, it } from "vitest";
import { formatearDuracion, formatearGuaranies } from "@/lib/formato";

describe("formatearGuaranies", () => {
  it("usa punto como separador de miles", () => {
    expect(formatearGuaranies(50000)).toBe("Gs. 50.000");
    expect(formatearGuaranies(1250000)).toBe("Gs. 1.250.000");
  });

  it("separa miles también en números de 4 cifras", () => {
    expect(formatearGuaranies(5000)).toBe("Gs. 5.000");
  });

  it("no muestra decimales", () => {
    expect(formatearGuaranies(0)).toBe("Gs. 0");
  });
});

describe("formatearDuracion", () => {
  it("muestra solo minutos por debajo de una hora", () => {
    expect(formatearDuracion(20)).toBe("20 min");
    expect(formatearDuracion(45)).toBe("45 min");
  });

  it("muestra horas justas sin minutos", () => {
    expect(formatearDuracion(60)).toBe("1 h");
    expect(formatearDuracion(120)).toBe("2 h");
  });

  it("combina horas y minutos", () => {
    expect(formatearDuracion(90)).toBe("1 h 30 min");
  });
});
