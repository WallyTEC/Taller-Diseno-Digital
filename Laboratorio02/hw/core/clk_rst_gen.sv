// =============================================================================
// clk_rst_gen.sv
// -----------------------------------------------------------------------------
// Genera el reloj del sistema (clk_i) y el reset sincronizado (rst_i)
// a partir del oscilador de 100 MHz de la Nexys4 y el botón CPU_RESETN.
//
// - clk_i:  50 MHz, generado por el MMCM (clk_wiz_main)
// - rst_i:  active high, sincronizado a clk_i
//           Se mantiene en 1 mientras el PLL no esté locked o el botón
//           CPU_RESETN esté presionado (rst_n_i = 0).
// =============================================================================

module clk_rst_gen (
    input  logic sys_clk_i,   // 100 MHz desde el oscilador de la Nexys4 (pin E3)
    input  logic rst_n_i,     // CPU_RESETN, active low (pin C12)
    output logic clk_i,       // 50 MHz al sistema
    output logic rst_i        // Reset active high, sincronizado a clk_i
);

    // -------------------------------------------------------------------------
    // Instancia del MMCM (PLL)
    // -------------------------------------------------------------------------
    logic locked;
    logic mmcm_reset;

    // El MMCM se resetea cuando el botón CPU_RESETN está presionado.
    // El puerto 'reset' del MMCM es active high, por eso se invierte rst_n_i.
    assign mmcm_reset = ~rst_n_i;

    clk_wiz_main u_pll (
        .clk_in1 (sys_clk_i),
        .reset   (mmcm_reset),
        .locked  (locked),
        .clk_out1(clk_i)
    );

    // -------------------------------------------------------------------------
    // Sincronizador de reset
    // -------------------------------------------------------------------------
    // El reset asincrónico se genera cuando:
    //   - el PLL no ha alcanzado el lock (locked = 0), o
    //   - el botón CPU_RESETN está presionado (rst_n_i = 0).
    //
    // Esa señal asincrónica se sincroniza a clk_i con dos flip-flops para
    // evitar metastabilidad cuando el reset se libera.
    // -------------------------------------------------------------------------
    logic rst_async;
    logic rst_meta, rst_sync;

    assign rst_async = ~locked | ~rst_n_i;

    always_ff @(posedge clk_i or posedge rst_async) begin
        if (rst_async) begin
            rst_meta <= 1'b1;
            rst_sync <= 1'b1;
        end else begin
            rst_meta <= 1'b0;
            rst_sync <= rst_meta;
        end
    end

    assign rst_i = rst_sync;

endmodule