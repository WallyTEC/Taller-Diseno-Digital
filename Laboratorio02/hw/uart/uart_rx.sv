// ============================================================
// File: uart_rx.sv
// Purpose:
//   Receptor UART 8N1 con oversampling 16x.
// ============================================================
module uart_rx #(
    parameter int unsigned OVERSAMPLE = 16
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tick_16x,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_framing_error
);

    logic rx_meta;
    logic rx_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
    rx_state_t state;

    logic [$clog2(OVERSAMPLE)-1:0] os_cnt;
    logic [2:0] bit_idx;
    logic [7:0] shreg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= RX_IDLE;
            os_cnt           <= '0;
            bit_idx          <= '0;
            shreg            <= '0;
            rx_data          <= '0;
            rx_valid         <= 1'b0;
            rx_framing_error <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                RX_IDLE: begin
                    os_cnt           <= '0;
                    bit_idx          <= '0;
                    rx_framing_error <= 1'b0;
                    if (rx_sync == 1'b0) begin
                        state  <= RX_START;
                        os_cnt <= '0;
                    end
                end

                RX_START: begin
                    if (tick_16x) begin
                        if (os_cnt == (OVERSAMPLE/2 - 1)) begin
                            if (rx_sync == 1'b0) begin
                                state   <= RX_DATA;
                                os_cnt  <= '0;
                                bit_idx <= '0;
                            end else begin
                                state <= RX_IDLE;
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

                RX_DATA: begin
                    if (tick_16x) begin
                        if (os_cnt == OVERSAMPLE-1) begin
                            os_cnt         <= '0;
                            shreg[bit_idx] <= rx_sync;
                            if (bit_idx == 3'd7) begin
                                state <= RX_STOP;
                            end else begin
                                bit_idx <= bit_idx + 1'b1;
                            end
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

                RX_STOP: begin
                    if (tick_16x) begin
                        if (os_cnt == OVERSAMPLE-1) begin
                            os_cnt <= '0;
                            if (rx_sync == 1'b1) begin
                                rx_data          <= shreg;
                                rx_valid         <= 1'b1;
                                rx_framing_error <= 1'b0;
                            end else begin
                                rx_framing_error <= 1'b1;
                            end
                            state <= RX_IDLE;
                        end else begin
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

                default: state <= RX_IDLE;
            endcase
        end
    end
endmodule
