// ============================================================
// File: uart_tx.sv
// Purpose:
//   Transmisor UART 8N1 (8 bits, No parity, 1 stop).
//   Envía: START(0) + 8 bits (LSB first) + STOP(1)
//
// Handshake:
//   tx_ready = 1 cuando está libre y puede aceptar un nuevo byte
//   tx_busy  = 1 cuando está transmitiendo
// ============================================================

module uart_tx #(
    // Número de ticks por bit (si tick_16x es 16x, cada bit dura 16 ticks)
    parameter int unsigned OVERSAMPLE = 16
) (
    input  logic       clk,       // reloj principal
    input  logic       rst_n,     // reset activo en bajo
    input  logic       tick_16x,  // pulso del baudgen (16x)

    input  logic [7:0] tx_data,   // byte a enviar
    input  logic       tx_start,  // pulso 1 ciclo para arrancar envío

    output logic       tx,        // línea UART (idle = 1)
    output logic       tx_busy,   // 1 si está enviando
    output logic       tx_ready   // 1 si está listo para nuevo byte
);

    // Máquina de estados simple: IDLE (espera), SEND (transmitiendo)
    typedef enum logic [0:0] {IDLE, SEND} state_t;
    state_t state;

    // "frame" guarda la trama completa UART de 10 bits:
    // frame[0] = start bit (0)
    // frame[8:1] = datos (8 bits)
    // frame[9] = stop bit (1)
    logic [9:0] frame;

    // Contador para sostener cada bit durante OVERSAMPLE ticks
    // Si OVERSAMPLE=16, cuenta de 0..15
    logic [$clog2(OVERSAMPLE)-1:0] os_cnt;

    // Índice del bit actual dentro de frame (0..9)
    logic [3:0] bit_idx;

    // Salidas de estado (combinacional): dependen del estado actual
    always_comb begin
        tx_busy  = (state == SEND);
        tx_ready = (state == IDLE);
    end

    // Lógica secuencial
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Estado inicial: IDLE
            state   <= IDLE;
            // Línea UART en reposo es 1
            tx      <= 1'b1;
            // Valores de arranque
            frame   <= 10'h3FF;
            os_cnt  <= '0;
            bit_idx <= '0;
        end else begin
            case (state)

                // -------------------------
                // IDLE: esperando un tx_start
                // -------------------------
                IDLE: begin
                    // Mantener TX en idle alto
                    tx      <= 1'b1;
                    // Reiniciar contadores
                    os_cnt  <= '0;
                    bit_idx <= '0;

                    // Si nos piden iniciar transmisión...
                    if (tx_start) begin
                        // Construir la trama:
                        // {stop, data[7:0], start}
                        // stop = 1, start = 0
                        frame <= {1'b1, tx_data, 1'b0};

                        // Emitir inmediatamente el start bit en la línea
                        tx    <= 1'b0;

                        // Pasar a estado SEND
                        state <= SEND;
                    end
                end

                // -------------------------
                // SEND: transmitiendo
                // -------------------------
                SEND: begin
                    // Solo avanzamos cuando llega el tick_16x
                    if (tick_16x) begin
                        // ¿ya sostuvimos este bit por OVERSAMPLE ticks?
                        if (os_cnt == OVERSAMPLE-1) begin
                            // reiniciar contador de oversample para el siguiente bit
                            os_cnt <= '0;

                            // ¿ya se transmitieron los 10 bits? (0..9)
                            if (bit_idx == 9) begin
                                // terminamos stop bit -> volver a IDLE
                                tx      <= 1'b1;  // línea vuelve a idle
                                bit_idx <= '0;    // reset índice
                                state   <= IDLE;  // estado IDLE
                            end else begin
                                // pasar al siguiente bit
                                bit_idx <= bit_idx + 1'b1;

                                // colocar en tx el siguiente bit de la trama
                                // (bit_idx + 1) porque estamos moviéndonos al siguiente
                                tx      <= frame[bit_idx + 1'b1];
                            end
                        end else begin
                            // aún no completamos los 16 ticks del bit actual -> seguir contando
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

            endcase
        end
    end

endmodule
