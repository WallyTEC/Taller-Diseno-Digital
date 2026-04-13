// ============================================================
// File: uart_peripheral.sv
// Purpose:
//   Periférico UART mapeado en memoria para el sistema RISC-V.
//   El procesador se comunica escribiendo/leyendo estos registros:
//
//   0x02010 -> Registro de control
//              bit 0: send   (1 = enviar byte por TX)
//              bit 1: new_rx (1 = hay byte nuevo en RX)
//   0x02018 -> Registro de datos TX (byte a enviar)
//   0x0201C -> Registro de datos RX (byte recibido)
// ============================================================

module uart_peripheral #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD        = 9600,
    parameter int unsigned OVERSAMPLE  = 16
)(
    // --- Señales del sistema ---
    input  logic        clk,
    input  logic        rst_n,

    // --- Interfaz con el bus (viene del procesador RISC-V) ---
    input  logic [31:0] address,   // dirección que el procesador accede
    input  logic [31:0] data_in,   // dato que el procesador escribe
    input  logic        we,        // write enable: 1=escribir, 0=leer
    output logic [31:0] data_out,  // dato que el periférico devuelve al leer

    // --- Señales físicas UART ---
    input  logic        uart_rx,   // línea RX (viene de la laptop)
    output logic        uart_tx    // línea TX (va hacia la laptop)
);

    // =========================================================
    // 1) REGISTROS INTERNOS
    //    Estos son los 3 registros que el procesador puede
    //    leer y escribir por medio del mapa de memoria
    // =========================================================

    logic [31:0] reg_control;  // 0x02010: bit0=send, bit1=new_rx
    logic [31:0] reg_data_tx;  // 0x02018: byte a enviar
    logic [31:0] reg_data_rx;  // 0x0201C: byte recibido

    // Aliases para los bits importantes del registro de control
    // Esto es solo para que el código sea más legible
    logic send;    // bit 0 del registro de control
    logic new_rx;  // bit 1 del registro de control

    assign send   = reg_control[0];
    assign new_rx = reg_control[1];

    // =========================================================
    // 2) INSTANCIAS DE SUBMODULOS
    //    Conectamos baudgen, uart_rx y uart_tx
    // =========================================================

    // --- Tick 16x para baudrate ---
    logic tick_16x;

    uart_baudgen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_baudgen (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick_16x(tick_16x)
    );

    // --- Receptor UART ---
    logic [7:0] rx_data;   // byte que acaba de recibir uart_rx
    logic       rx_valid;  // pulso 1 ciclo: hay byte nuevo
    logic       rx_ferr;   // framing error (no lo usamos pero lo conectamos)

    uart_rx #(
        .OVERSAMPLE(OVERSAMPLE)
    ) u_rx (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick_16x        (tick_16x),
        .rx              (uart_rx),
        .rx_data         (rx_data),
        .rx_valid        (rx_valid),
        .rx_framing_error(rx_ferr)
    );

    // --- Transmisor UART ---
    logic [7:0] tx_data;   // byte que queremos enviar
    logic       tx_start;  // pulso 1 ciclo para arrancar envío
    logic       tx_busy;   // 1 mientras está transmitiendo
    logic       tx_ready;  // 1 cuando está libre

    uart_tx #(
        .OVERSAMPLE(OVERSAMPLE)
    ) u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick_16x(tick_16x),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx      (uart_tx),
        .tx_busy (tx_busy),
        .tx_ready(tx_ready)
    );

    // =========================================================
    // 3) LOGICA DE ESCRITURA (procesador -> periférico)
    //    Cuando we=1, el procesador está escribiendo en
    //    alguna de las direcciones del mapa de memoria
    // =========================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_control <= 32'h0;
            reg_data_tx <= 32'h0;
            // reg_data_rx no se resetea aquí porque lo maneja la lógica RX
        end else begin

            // Por defecto tx_start está apagado
            // (se enciende solo 1 ciclo cuando se detecta send=1)
            tx_start <= 1'b0;

            // ---- Escrituras del procesador ----
            if (we) begin
                case (address)

                    // Procesador escribe en registro de control
                    32'h02010: begin
                        reg_control <= data_in;
                    end

                    // Procesador escribe el byte que quiere enviar
                    32'h02018: begin
                        reg_data_tx <= data_in;
                    end

                    // 0x0201C es solo lectura (RX), el procesador
                    // no debería escribir aquí, lo ignoramos

                    default: ; // otras direcciones no son de este módulo

                endcase
            end

            // ---- Lógica del bit SEND ----
            // Si el procesador activó send=1 y el transmisor está listo,
            // arrancamos la transmisión
            if (send && tx_ready) begin
                tx_data       <= reg_data_tx[7:0]; // tomamos los 8 bits bajos
                tx_start      <= 1'b1;             // pulso para arrancar TX
                reg_control[0]<= 1'b0;             // bajamos send automáticamente
            end

            // ---- Lógica del bit NEW_RX ----
            // Si uart_rx recibió un byte nuevo, lo guardamos
            // y activamos new_rx=1 para avisar al procesador
            if (rx_valid) begin
                reg_data_rx    <= {24'h0, rx_data}; // guardamos el byte (extendido a 32 bits)
                reg_control[1] <= 1'b1;             // new_rx = 1
            end

            // El procesador puede limpiar new_rx escribiendo 0
            // en el bit 1 del registro de control
            // (eso ya queda cubierto por el case de escritura arriba)

        end
    end

    // =========================================================
    // 4) LOGICA DE LECTURA (periférico -> procesador)
    //    Cuando we=0, el procesador está leyendo.
    //    Según la dirección, devolvemos el registro correcto.
    // =========================================================

    always_comb begin
        case (address)
            32'h02010: data_out = reg_control;  // leer control
            32'h02018: data_out = reg_data_tx;  // leer dato TX
            32'h0201C: data_out = reg_data_rx;  // leer dato RX
            default:   data_out = 32'h0;        // dirección no reconocida
        endcase
    end

endmodule
