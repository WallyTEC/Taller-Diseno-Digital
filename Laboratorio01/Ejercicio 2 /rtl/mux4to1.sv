`timescale 1ns/1ps  
// Define la escala de tiempo para simulación.
// No afecta síntesis, solo simulación.
// 1ns = unidad de tiempo.
// 1ps = precisión.

module mux4to1 #(
    parameter int WIDTH = 8
    // Parámetro configurable que define el ancho del bus.
    // Si no se especifica, por defecto es 8 bits.
    // Permite que el módulo sea reutilizable.
)(
    input  logic [WIDTH-1:0] d0,
    // Entrada 0 del multiplexor.
    // Tiene WIDTH bits.

    input  logic [WIDTH-1:0] d1,
    // Entrada 1 del multiplexor.

    input  logic [WIDTH-1:0] d2,
    // Entrada 2 del multiplexor. 
    
    input  logic [WIDTH-1:0] d3,
    // Entrada 3 del multiplexor.

    input  logic [1:0] sel,
    // Señal selectora de 2 bits.
    // Permite elegir entre 4 entradas (2^2 = 4 combinaciones).

    output logic [WIDTH-1:0] y
    // Salida del multiplexor.
    // Tiene el mismo ancho que las entradas.
);

    // ============================================================
    // LÓGICA COMBINACIONAL
    // ============================================================

    always_comb begin
    // always_comb indica que este bloque es lógica combinacional pura.
    // SystemVerilog garantiza que:
    // - No se infieran latches.
    // - Se actualice automáticamente ante cualquier cambio en entradas.
    // Es mejor práctica que usar always @(*).

        case (sel)
        // Evaluamos el valor del selector.
        // Esto representa directamente la tabla de verdad del MUX 4:1.

            2'b00:   y = d0;
            // Si sel = 00, la salida es la entrada d0.

            2'b01:   y = d1;
            // Si sel = 01, la salida es la entrada d1.

            2'b10:   y = d2;
            // Si sel = 10, la salida es la entrada d2.

            2'b11:   y = d3;
            // Si sel = 11, la salida es la entrada d3.

            default: y = '0;
            // Caso por seguridad.
            // Si sel tuviera un valor indeterminado (X/Z),
            // se asigna 0 para evitar inferencia de latches.
            // Esto garantiza diseño completamente combinacional.
        endcase
    end

endmodule
