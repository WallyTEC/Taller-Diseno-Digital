// ============================================================
// File: uart_top.sv
// Purpose:
//   Top de integración del ejercicio:
//     - UART 9600 8N1
//     - Botón -> envía "Hola mundo\r\n"
//     - RX -> muestra byte recibido en leds[7:0]
// ============================================================

module uart_top #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD        = 9600,
    parameter int unsigned OVERSAMPLE  = 16
) (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       btn_send,  // botón físico
    input  logic       uart_rx,   // entrada UART desde PC
    output logic       uart_tx,   // salida UART hacia PC

    output logic [7:0] leds      // LEDs muestran último byte recibido
);

    // -------------------------
    // 1) Generar tick 16x
    // -------------------------
    logic tick_16x;

    uart_baudgen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_baud (
        .clk(clk),
        .rst_n(rst_n),
        .tick_16x(tick_16x)
    );

    // -------------------------
    // 2) UART RX
    // -------------------------
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_ferr;

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .tick_16x(tick_16x),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_framing_error(rx_ferr)
    );

    // Cada vez que llega un byte válido, lo mostramos en LEDs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leds <= 8'h00; // LEDs apagados al reset
        end else if (rx_valid) begin
            leds <= rx_data; // mostrar ASCII recibido
        end
    end

    // -------------------------
    // 3) UART TX
    // -------------------------
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_busy;
    logic       tx_ready;

    uart_tx #(.OVERSAMPLE(OVERSAMPLE)) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tick_16x(tick_16x),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(uart_tx),
        .tx_busy(tx_busy),
        .tx_ready(tx_ready)
    );

    // -------------------------
    // 4) Botón: sincronizar + detectar flanco
    // -------------------------
    logic btn_meta;
    logic btn_sync;
    logic btn_sync_d;
    logic btn_rise;

    // Sincronización en 2 FF para evitar metastabilidad
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_meta   <= 1'b0;
            btn_sync   <= 1'b0;
            btn_sync_d <= 1'b0;
        end else begin
            btn_meta   <= btn_send; // muestreo 1
            btn_sync   <= btn_meta; // muestreo 2
            btn_sync_d <= btn_sync; // guardar valor anterior para detectar flanco
        end
    end

    // Flanco de subida: ahora=1 y antes=0
    always_comb begin
        btn_rise = btn_sync & ~btn_sync_d;
    end

      // -------------------------
    // 5) Máquina para enviar "Hola mundo\r\n"
    // -------------------------

localparam int MSG_LEN = 12;

logic [7:0] MSG [0:MSG_LEN-1];

initial begin
    MSG[0]  = "H";
    MSG[1]  = "o";
    MSG[2]  = "l";
    MSG[3]  = "a";
    MSG[4]  = " ";
    MSG[5]  = "m";
    MSG[6]  = "u";
    MSG[7]  = "n";
    MSG[8]  = "d";
    MSG[9]  = "o";
    MSG[10] = 8'h0D;
    MSG[11] = 8'h0A;
end

typedef enum logic [1:0] {
    S_IDLE,
    S_SEND,
    S_WAIT
} send_state_t;

send_state_t state;

logic [3:0] msg_idx;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state    <= S_IDLE;
        msg_idx  <= 0;
        tx_start <= 0;
        tx_data  <= 0;
    end
    else begin

        tx_start <= 0;

        case(state)

        // -----------------
        S_IDLE: begin
            if(btn_rise) begin
                msg_idx <= 0;
                state   <= S_SEND;
            end
        end

        // -----------------
        S_SEND: begin
            if(tx_ready) begin
                tx_data  <= MSG[msg_idx];
                tx_start <= 1;
                state    <= S_WAIT;
            end
        end

        // -----------------
        S_WAIT: begin
            if(!tx_busy) begin
                if(msg_idx == MSG_LEN-1) begin
                    state <= S_IDLE;
                end
                else begin
                    msg_idx <= msg_idx + 1;
                    state   <= S_SEND;
                end
            end
        end

        endcase

    end
end
endmodule
