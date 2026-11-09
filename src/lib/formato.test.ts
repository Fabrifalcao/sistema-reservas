import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { formatearDuracion, formatearGuaranies } from "./formato.ts";

describe("formatearGuaranies", () => {
  it("usa punto como separador de miles", () => {
    assert.equal(formatearGuaranies(50000), "Gs. 50.000");
    assert.equal(formatearGuaranies(1250000), "Gs. 1.250.000");
  });

  it("separa miles también en números de 4 cifras", () => {
    assert.equal(formatearGuaranies(5000), "Gs. 5.000");
  });

  it("no muestra decimales", () => {
    assert.equal(formatearGuaranies(0), "Gs. 0");
  });
});

describe("formatearDuracion", () => {
  it("muestra solo minutos por debajo de una hora", () => {
    assert.equal(formatearDuracion(20), "20 min");
    assert.equal(formatearDuracion(45), "45 min");
  });

  it("muestra horas justas sin minutos", () => {
    assert.equal(formatearDuracion(60), "1 h");
    assert.equal(formatearDuracion(120), "2 h");
  });

  it("combina horas y minutos", () => {
    assert.equal(formatearDuracion(90), "1 h 30 min");
  });
});
