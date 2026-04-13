// ============================================================
// File: uart_baudgen.sv
// Purpose:
//   Generar un pulso (tick_16x) a frecuencia BAUD*OVERSAMPLE.
//   Ese tick funciona como "reloj lento" para TX y RX.
// ============================================================
module uart_baudgen #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD        = 9600,
    parameter int unsigned OVERSAMPLE  = 16
) (
    input  logic clk,
    input  logic rst_n,
    output logic tick_16x
);
    localparam int unsigned TICK_RATE = BAUD * OVERSAMPLE;
    localparam int unsigned DIVISOR =
        (CLK_FREQ_HZ + (TICK_RATE/2)) / TICK_RATE;

    logic [$clog2(DIVISOR)-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt      <= '0;
            tick_16x <= 1'b0;
        end else begin
            if (cnt == DIVISOR-1) begin
                cnt      <= '0;
                tick_16x <= 1'b1;
            end else begin
                cnt      <= cnt + 1'b1;
                tick_16x <= 1'b0;
            end
        end
    end
endmodule
