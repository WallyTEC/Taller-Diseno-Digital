// ============================================================
// File: uart_baudgen.sv
// Purpose:
//   Generar un pulso (tick_16x) a frecuencia BAUD*OVERSAMPLE.
//   Ese tick funciona como "reloj lento" para TX y RX.
// ============================================================

module uart_baudgen #(
    // Frecuencia del reloj principal de la FPGA (Nexys4 DDR = 100 MHz)
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    // Baud rate deseado (bits/segundo)
    parameter int unsigned BAUD        = 9600,
    // Oversampling (RX suele usar 16x para muestrear con más precisión)
    parameter int unsigned OVERSAMPLE  = 16
) (
    input  logic clk,       // reloj del sistema (100 MHz)
    input  logic rst_n,     // reset activo en bajo
    output logic tick_16x   // pulso 1 ciclo cuando toca muestrear/avanzar
);

    // TICK_RATE = BAUD * OVERSAMPLE
    // Ej: 9600 * 16 = 153600 ticks por segundo
    localparam int unsigned TICK_RATE = BAUD * OVERSAMPLE;

    // DIVISOR = CLK_FREQ_HZ / TICK_RATE (aprox)
    // Se suma (TICK_RATE/2) para redondear y reducir error de división
    localparam int unsigned DIVISOR =
        (CLK_FREQ_HZ + (TICK_RATE/2)) / TICK_RATE;

    // Contador para contar ciclos del reloj rápido hasta DIVISOR-1
    // $clog2(DIVISOR) calcula cuántos bits se ocupan para contar hasta DIVISOR
    logic [$clog2(DIVISOR)-1:0] cnt;

    // Lógica secuencial: se ejecuta en cada flanco positivo del reloj
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Si reset está activo, reiniciamos contador
            cnt      <= '0;
            // Y bajamos el tick (no hay pulso)
            tick_16x <= 1'b0;
        end else begin
            // Si llegamos al final del conteo...
            if (cnt == DIVISOR-1) begin
                // reiniciamos el contador
                cnt      <= '0;
                // y sacamos un pulso de 1 ciclo
                tick_16x <= 1'b1;
            end else begin
                // si no hemos llegado, seguimos contando
                cnt      <= cnt + 1'b1;
                // y tick permanece en 0
                tick_16x <= 1'b0;
            end
        end
    end

endmodule
