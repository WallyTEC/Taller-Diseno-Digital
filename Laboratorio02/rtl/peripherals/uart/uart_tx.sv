// =============================================================================
// Archivo      : rtl/peripherals/uart/uart_tx.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Transmisor UART 8N1.
//
//                FSM:
//                  IDLE  : tx_o = 1. Si start_i=1, latchea data_i y
//                          baja la línea (start bit) en el siguiente
//                          ciclo, pasando a S_START.
//                  START : tx_o = 0 durante 1 slot.
//                  DATA  : envía 8 bits LSB primero, uno por tx_tick.
//                  STOP  : tx_o = 1 durante 1 slot, pulsa done_o.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================


module uart_tx (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       tx_tick_i,   // 1 pulso/bit
    input  logic       start_i,
    input  logic [7:0] data_i,
    output logic       busy_o,
    output logic       done_o,
    output logic       tx_o
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_e;

    state_e     state_q;
    logic [7:0] shreg_q;
    logic [2:0] bit_idx_q;

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            state_q   <= S_IDLE;
            shreg_q   <= '0;
            bit_idx_q <= '0;
            tx_o      <= 1'b1;
            done_o    <= 1'b0;
        end else begin
            done_o <= 1'b0;

            unique case (state_q)
                S_IDLE: begin
                    tx_o <= 1'b1;
                    if (start_i) begin
                        shreg_q   <= data_i;
                        bit_idx_q <= '0;
                        tx_o      <= 1'b0;        // start bit
                        state_q   <= S_START;
                    end
                end

                S_START: begin
                    tx_o <= 1'b0;
                    if (tx_tick_i) begin
                        tx_o      <= shreg_q[0];
                        shreg_q   <= {1'b0, shreg_q[7:1]};
                        bit_idx_q <= 3'd1;
                        state_q   <= S_DATA;
                    end
                end

                S_DATA: begin
                    if (tx_tick_i) begin
                        if (bit_idx_q == 3'd0) begin
                            // Acabamos de mandar el bit 7 (cuando bit_idx_q
                            // wrap-eó). Pasamos a STOP.
                            tx_o    <= 1'b1;
                            state_q <= S_STOP;
                        end else begin
                            tx_o      <= shreg_q[0];
                            shreg_q   <= {1'b0, shreg_q[7:1]};
                            bit_idx_q <= bit_idx_q + 3'd1;   // 1->2->...->7->0
                        end
                    end
                end

                S_STOP: begin
                    tx_o <= 1'b1;
                    if (tx_tick_i) begin
                        done_o  <= 1'b1;
                        state_q <= S_IDLE;
                    end
                end

                default: state_q <= S_IDLE;
            endcase
        end
    end

    assign busy_o = (state_q != S_IDLE);

endmodule : uart_tx

