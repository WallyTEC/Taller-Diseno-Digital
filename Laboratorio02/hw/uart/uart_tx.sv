// ============================================================
// File: uart_tx.sv
// Purpose:
//   Transmisor UART 8N1
// ============================================================
module uart_tx #(
    parameter int unsigned OVERSAMPLE = 16
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tick_16x,
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx,
    output logic       tx_busy,
    output logic       tx_ready
);

    typedef enum logic [0:0] {IDLE, SEND} state_t;
    state_t state;

    logic [9:0] frame;
    logic [$clog2(OVERSAMPLE)-1:0] os_cnt;
    logic [3:0] bit_idx;

    always_comb begin
        tx_busy  = (state == SEND);
        tx_ready = (state == IDLE);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx      <= 1'b1;
            frame   <= 10'h3FF;
            os_cnt  <= '0;
            bit_idx <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    os_cnt  <= '0;
                    bit_idx <= '0;
                    if (tx_start) begin
                        frame <= {1'b1, tx_data, 1'b0};
                        tx    <= 1'b0;
                        state <= SEND;
                    end
                end

                SEND: begin
                    if (tick_16x) begin
                        if (os_cnt == OVERSAMPLE-1) begin
                            os_cnt <= '0;
                            if (bit_idx == 9) begin
                                tx      <= 1'b1;
                                bit_idx <= '0;
                                state   <= IDLE;
                            end else begin
                                bit_idx <= bit_idx + 1'b1;
                                tx      <= frame[bit_idx + 1'b1];
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule
