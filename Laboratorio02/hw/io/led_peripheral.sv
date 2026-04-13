// =============================================================================
// led_peripheral.sv
// -----------------------------------------------------------------------------
// Periférico de LEDs mapeado en memoria en la dirección 0x02004.
// El CPU escribe un valor de 32 bits y los 16 bits menos significativos
// se muestran en los LEDs físicos de la Nexys4 DDR.
// =============================================================================

module led_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,      // Active high

    // Interfaz con el Bus Driver
    input  logic        we_i,       // Write enable del CPU
    input  logic        sel_i,      // Bus Driver activa esto cuando addr = 0x02004
    input  logic [31:0] data_i,     // Dato que escribe el CPU

    // Salida física a los LEDs de la Nexys4
    output logic [15:0] leds_o
);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            leds_o <= 16'h0000;
        end else if (sel_i && we_i) begin
            leds_o <= data_i[15:0];
        end
    end

endmodule
