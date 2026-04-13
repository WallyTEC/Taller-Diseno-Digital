// =============================================================================
// sw_btn_peripheral.sv
// -----------------------------------------------------------------------------
// Periférico de Switches y Botones mapeado en 0x02000.
// Incluye sincronizador de 2 FF y antirrebote por contador.
// El CPU lee un registro de 32 bits donde los 16 bits bajos
// corresponden a los switches/botones físicos.
// =============================================================================

module sw_btn_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,      // Active high

    // Entradas físicas de la Nexys4
    input  logic [15:0] sw_i,       // 16 switches

    // Interfaz con el Bus Driver
    input  logic        sel_i,      // Bus Driver activa cuando addr = 0x02000
    output logic [31:0] data_o      // Dato que lee el CPU
);

    // -------------------------------------------------------------------------
    // Sincronizador de 2 flip-flops
    // Evita metaestabilidad al pasar señales asíncronas al dominio del reloj
    // -------------------------------------------------------------------------
    logic [15:0] sw_sync0, sw_sync1;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sw_sync0 <= 16'h0000;
            sw_sync1 <= 16'h0000;
        end else begin
            sw_sync0 <= sw_i;       // primer FF: captura
            sw_sync1 <= sw_sync0;   // segundo FF: estabiliza
        end
    end

    // -------------------------------------------------------------------------
    // Antirrebote por contador
    // Solo actualiza el valor estable si los switches no cambian
    // durante DEBOUNCE_COUNT ciclos consecutivos
    // -------------------------------------------------------------------------
    localparam int DEBOUNCE_COUNT = 500_000; // 5ms a 100MHz

    logic [15:0] sw_stable;         // valor estable actual
    logic [15:0] sw_last;           // último valor visto
    logic [19:0] debounce_cnt;      // contador de estabilidad

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sw_stable    <= 16'h0000;
            sw_last      <= 16'h0000;
            debounce_cnt <= '0;
        end else begin
            if (sw_sync1 !== sw_last) begin
                // Cambio detectado: reiniciar contador
                sw_last      <= sw_sync1;
                debounce_cnt <= '0;
            end else if (debounce_cnt < DEBOUNCE_COUNT) begin
                // Señal estable: incrementar contador
                debounce_cnt <= debounce_cnt + 1;
            end else begin
                // Estable por suficiente tiempo: actualizar valor
                sw_stable <= sw_last;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Salida al Bus Driver
    // Solo responde cuando sel_i está activo
    // Los 16 bits altos siempre son 0 (instructivo)
    // -------------------------------------------------------------------------
    assign data_o = sel_i ? {16'h0000, sw_stable} : 32'h0000_0000;

endmodule
