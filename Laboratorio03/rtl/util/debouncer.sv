// =============================================================================
// Archivo      : rtl/util/debouncer.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Anti-rebote para entradas mecánicas (botones y switches).
//
//                Funcionamiento:
//                  - Toma la entrada ya sincronizada al dominio de reloj.
//                  - Un contador cuenta ciclos mientras la entrada se
//                    mantenga igual al valor capturado.
//                  - Si el contador llega al umbral STABLE_CYCLES, ese
//                    valor se considera estable y se actualiza la salida.
//                  - Si la entrada cambia antes del umbral, el contador
//                    se reinicia.
//
//                Parámetros:
//                  WIDTH          : bits de la entrada (1 para un botón,
//                                   16 para el banco de switches)
//                  STABLE_CYCLES  : ciclos de reloj requeridos de estabilidad.
//                                   A 50 MHz, 500 000 ciclos = 10 ms,
//                                   valor típico para rebotes mecánicos.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================


module debouncer #(
    parameter int WIDTH         = 1,
    parameter int STABLE_CYCLES = 500_000  // 10 ms @ 50 MHz
) (
    input  logic             clk_i,
    input  logic             rst_n_i,
    input  logic [WIDTH-1:0] in_sync_i,   // ya sincronizada
    output logic [WIDTH-1:0] stable_o
);

    localparam int CNT_W = $clog2(STABLE_CYCLES + 1);

    logic [WIDTH-1:0] candidate_q;
    logic [CNT_W-1:0] count_q;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            candidate_q <= '0;
            count_q     <= '0;
            stable_o    <= '0;
        end else begin
            if (in_sync_i != candidate_q) begin
                // La entrada cambió: reinicio la ventana de estabilidad
                candidate_q <= in_sync_i;
                count_q     <= '0;
            end else if (count_q < CNT_W'(STABLE_CYCLES)) begin
                count_q <= count_q + CNT_W'(1);
            end else begin
                // Valor estable durante suficiente tiempo
                stable_o <= candidate_q;
            end
        end
    end

endmodule : debouncer

