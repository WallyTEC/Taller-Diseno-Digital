// =============================================================================
// Archivo      : rtl/util/synchronizer.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Sincronizador de N etapas para eliminar metaestabilidad al
//                muestrear señales asíncronas (switches, botones, RX del
//                UART) en el dominio de reloj del sistema. La primera etapa
//                puede volverse metaestable; la cadena posterior le da
//                tiempo a resolverse antes de que el valor sea usado por
//                la lógica aguas abajo.
//
//                Parámetros:
//                  WIDTH   : ancho del vector de entrada
//                  STAGES  : número de etapas (mínimo 2, recomendado 2-3)
//
//                Se agregan atributos Xilinx `ASYNC_REG` para que la
//                herramienta coloque los flip-flops físicamente juntos
//                en la misma slice y no se propaguen pulsos glitcheados.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================


module synchronizer #(
    parameter int WIDTH  = 1,
    parameter int STAGES = 2
) (
    input  logic             clk_i,
    input  logic             rst_n_i,
    input  logic [WIDTH-1:0] async_i,
    output logic [WIDTH-1:0] sync_o
);

    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_chain_q [STAGES-1:0];

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            for (int s = 0; s < STAGES; s++) sync_chain_q[s] <= '0;
        end else begin
            sync_chain_q[0] <= async_i;
            for (int s = 1; s < STAGES; s++) sync_chain_q[s] <= sync_chain_q[s-1];
        end
    end

    assign sync_o = sync_chain_q[STAGES-1];

endmodule : synchronizer

