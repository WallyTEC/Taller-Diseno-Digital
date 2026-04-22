// =============================================================================
// Archivo      : rtl/peripherals/uart/uart_baud_gen.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Generador de tick de baudrate para el TX.
//
//                Un pulso de 1 ciclo cada CLK_FREQ_HZ/BAUD_RATE ciclos.
//
//                NOTA: el RX NO usa este módulo. El RX tiene su propio
//                contador que arranca en el flanco del start bit y mide
//                tiempos absolutos en ciclos de reloj. Así se evita el
//                problema de drift por divisores no enteros entre dos
//                generadores independientes.
//
//                Para 9600 8N1 @ 50 MHz: TX_DIV = 5208 ciclos/bit.
//                Para 1 Mbps @ 50 MHz:    TX_DIV = 50 ciclos/bit.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================


module uart_baud_gen #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 9600
) (
    input  logic clk_i,
    input  logic rst_n_i,
    output logic tx_tick_o
);

    localparam int TX_DIV = CLK_FREQ_HZ / BAUD_RATE;
    localparam int CW     = ($clog2(TX_DIV) > 0) ? $clog2(TX_DIV) : 1;

    logic [CW-1:0] cnt_q;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            cnt_q     <= '0;
            tx_tick_o <= 1'b0;
        end else if (cnt_q == CW'(TX_DIV - 1)) begin
            cnt_q     <= '0;
            tx_tick_o <= 1'b1;
        end else begin
            cnt_q     <= cnt_q + CW'(1);
            tx_tick_o <= 1'b0;
        end
    end

endmodule : uart_baud_gen

