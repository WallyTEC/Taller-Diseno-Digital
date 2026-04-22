// =============================================================================
// Archivo      : rtl/util/reset_sync.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Sincronizador de reset para usar en el dominio del reloj
//                del sistema. Implementa la práctica estándar de:
//                  - Asserción asíncrona: cuando la señal externa de reset
//                    baja (rst_n_async_i = 0), la salida baja inmediatamente.
//                  - Deasserción síncrona: cuando la señal externa sube, la
//                    salida espera STAGES ciclos de reloj antes de subir.
//
//                Esto evita que el deasserción del reset caiga muy cerca
//                del flanco del reloj y produzca recovery/removal timing
//                violations en todos los flip-flops del diseño.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================


module reset_sync #(
    parameter int STAGES = 3
) (
    input  logic clk_i,
    input  logic rst_n_async_i,   // reset externo (asíncrono, activo-bajo)
    output logic rst_n_sync_o     // reset sincronizado al dominio clk_i
);

    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_chain_q;

    always_ff @(posedge clk_i or negedge rst_n_async_i) begin
        if (!rst_n_async_i) begin
            sync_chain_q <= '0;
        end else begin
            sync_chain_q <= {sync_chain_q[STAGES-2:0], 1'b1};
        end
    end

    assign rst_n_sync_o = sync_chain_q[STAGES-1];

endmodule : reset_sync

