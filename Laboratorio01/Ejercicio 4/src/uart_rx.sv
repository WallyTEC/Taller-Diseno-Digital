// ============================================================
// File: uart_rx.sv
// Purpose:
//   Receptor UART 8N1 con oversampling 16x.
//   Procedimiento:
//     1) Espera start (rx baja a 0)
//     2) Espera medio bit (8 ticks) y confirma start
//     3) Cada 16 ticks muestrea 1 bit de datos (LSB first)
//     4) Verifica stop bit (debe ser 1)
//     5) Entrega rx_valid = 1 por 1 ciclo cuando el byte ya está listo
// ============================================================

module uart_rx #(
    parameter int unsigned OVERSAMPLE = 16
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tick_16x,

    input  logic       rx,              // línea serial de entrada
    output logic [7:0] rx_data,          // byte recibido
    output logic       rx_valid,         // pulso 1 ciclo: "rx_data es nuevo"
    output logic       rx_framing_error  // 1 si stop bit no fue 1
);

    // -------------------------
    // Sincronizador (2 flip-flops)
    // -------------------------
    // rx llega asíncrono respecto a clk, así que lo sincronizamos
    logic rx_meta; // primera etapa (puede metastable)
    logic rx_sync; // segunda etapa (más estable)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;  // idle típico en UART es 1
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;      // muestreo inicial
            rx_sync <= rx_meta; // muestreo final sincronizado
        end
    end

    // Estados del receptor
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
    rx_state_t state;

    // Contador 0..15 para saber cuándo muestrear dentro del bit
    logic [$clog2(OVERSAMPLE)-1:0] os_cnt;

    // Índice del bit de datos actual (0..7)
    logic [2:0] bit_idx;

    // Registro donde vamos armando el byte recibido
    logic [7:0] shreg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= RX_IDLE; // arrancar en espera
            os_cnt           <= '0;      // contador a 0
            bit_idx          <= '0;      // bit a 0
            shreg            <= '0;      // registro a 0
            rx_data          <= '0;      // salida a 0
            rx_valid         <= 1'b0;    // no hay dato
            rx_framing_error <= 1'b0;    // sin error
        end else begin
            // rx_valid debe ser un pulso de 1 ciclo,
            // por eso lo apagamos por defecto en cada ciclo
            rx_valid <= 1'b0;

            case (state)

                // -------------------------
                // RX_IDLE: esperando start bit (rx_sync == 0)
                // -------------------------
                RX_IDLE: begin
                    os_cnt           <= '0;    // reiniciar contador
                    bit_idx          <= '0;    // reiniciar bit index
                    rx_framing_error <= 1'b0;  // limpiar error previo

                    // Si detectamos línea baja, puede ser start
                    if (rx_sync == 1'b0) begin
                        state  <= RX_START; // ir a confirmar start
                        os_cnt <= '0;       // empezar conteo dentro del start
                    end
                end

                // -------------------------
                // RX_START: confirmar start bit en el centro
                // -------------------------
                RX_START: begin
                    if (tick_16x) begin
                        // Queremos muestrear a la mitad del bit start:
                        // OVERSAMPLE/2 = 8 ticks (si OVERSAMPLE=16)
                        if (os_cnt == (OVERSAMPLE/2 - 1)) begin
                            // muestreo al centro del start
                            if (rx_sync == 1'b0) begin
                                // start confirmado
                                state   <= RX_DATA; // pasar a leer datos
                                os_cnt  <= '0;      // reset para contar bits de datos
                                bit_idx <= '0;      // arrancar en bit 0
                            end else begin
                                // falso start: volvió a 1
                                state <= RX_IDLE;
                            end
                        end else begin
                            // todavía no llegamos al centro, seguir contando
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

                // -------------------------
                // RX_DATA: leer 8 bits de datos
                // -------------------------
                RX_DATA: begin
                    if (tick_16x) begin
                        // Cuando completamos 16 ticks, estamos en el punto de muestreo del siguiente bit
                        if (os_cnt == OVERSAMPLE-1) begin
                            os_cnt <= '0; // reset para el próximo bit

                            // Guardar el bit muestreado.
                            // LSB first: el primer bit recibido es el bit 0
                            shreg[bit_idx] <= rx_sync;

                            // Si ya fue el último bit (bit 7), vamos a stop
                            if (bit_idx == 3'd7) begin
                                state <= RX_STOP;
                            end else begin
                                // si no, avanzar al siguiente bit
                                bit_idx <= bit_idx + 1'b1;
                            end
                        end else begin
                            // seguir contando ticks dentro del bit actual
                            os_cnt <= os_cnt + 1'b1;
                        end
                    end
                end

                // -------------------------
                // RX_STOP: verificar stop bit y publicar el dato
                // -------------------------
                RX_STOP: begin
                    if (tick_16x) begin
                        if (os_cnt == OVERSAMPLE-1) begin
                            os_cnt <= '0; // reset

                            // El stop bit debe ser 1
                            if (rx_sync == 1'b1) begin
                                // Byte completo válido
                                rx_data  <= shreg;  // publicar el byte
                                rx_valid <= 1'b1;   // pulso: nuevo byte disponible
                                rx_framing_error <= 1'b0;
                            end else begin
                                // Stop incorrecto
                                rx_framing_error <= 1'b1;
                            end

                            // Volver a esperar un nuevo start
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
