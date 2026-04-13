// ============================================================
// File: tb_uart.sv
// Purpose:
//   Testbench para uart_peripheral.sv
//   Simula el comportamiento del procesador RISC-V (escribiendo
//   y leyendo registros) y de la laptop (enviando bytes por RX).
//
//   Tests:
//     1) Escritura y lectura de registro TX
//     2) Transmisión: activar send y verificar byte en línea UART
//     3) Recepción: laptop envía byte, verificar new_rx y dato
//     4) Limpieza de new_rx por parte del procesador
// ============================================================

`timescale 1ns/1ps

module tb_uart;

    // =========================================================
    // 1) PARAMETROS
    //    Mismos valores que usará el diseño real
    // =========================================================
    localparam int unsigned CLK_FREQ_HZ = 100_000_000; // 100 MHz
    localparam int unsigned BAUD        = 9600;         // baudrate
    localparam int unsigned OVERSAMPLE  = 16;           // muestras por bit

    // Periodo del reloj: 1/100MHz = 10 ns
    localparam time CLK_PERIOD = 10ns;

    // Tiempo que dura 1 bit a 9600 baudios
    // BIT_TIME = (1/9600) segundos = ~104,166 ns
    // En simulación: OVERSAMPLE * DIVISOR * CLK_PERIOD
    localparam int unsigned TICK_RATE = BAUD * OVERSAMPLE;
    localparam int unsigned DIVISOR   = (CLK_FREQ_HZ + (TICK_RATE/2)) / TICK_RATE;
    localparam time         BIT_TIME  = OVERSAMPLE * DIVISOR * CLK_PERIOD;

    // =========================================================
    // 2) SEÑALES
    //    Estas son las señales que conectan el testbench
    //    con el módulo uart_peripheral (el DUT)
    // =========================================================

    // Señales del sistema
    logic clk;
    logic rst_n;

    // Señales del bus (simulan al procesador RISC-V)
    logic [31:0] address;   // dirección que el "procesador" accede
    logic [31:0] data_in;   // dato que el "procesador" escribe
    logic        we;        // 1 = escribir, 0 = leer
    logic [31:0] data_out;  // dato que el periférico devuelve

    // Señales físicas UART
    logic uart_rx;  // línea que simula venir de la laptop
    logic uart_tx;  // línea que sale hacia la laptop

    // =========================================================
    // 3) INSTANCIA DEL DUT
    //    DUT = Device Under Test = el módulo que estamos probando
    // =========================================================
    uart_peripheral #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .address (address),
        .data_in (data_in),
        .we      (we),
        .data_out(data_out),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx)
    );

    // =========================================================
    // 4) GENERADOR DE RELOJ
    //    Alterna entre 0 y 1 cada medio periodo = 100 MHz
    // =========================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================
    // 5) TAREAS (tasks)
    //    Son como funciones que usamos varias veces en los tests
    // =========================================================

    // ---------------------------------------------------------
    // Task: escribir un valor en una dirección del periférico
    // Simula lo que haría el procesador RISC-V al escribir
    // ---------------------------------------------------------
    task automatic bus_write(
        input logic [31:0] addr,  // dirección donde escribir
        input logic [31:0] data   // valor a escribir
    );
        @(posedge clk);           // esperar flanco del reloj
        address <= addr;          // poner la dirección
        data_in <= data;          // poner el dato
        we      <= 1'b1;          // indicar que es escritura
        @(posedge clk);           // esperar un ciclo para que se registre
        we      <= 1'b0;          // bajar write enable
        address <= 32'h0;         // limpiar dirección
        data_in <= 32'h0;         // limpiar dato
    endtask

    // ---------------------------------------------------------
    // Task: leer un valor de una dirección del periférico
    // Simula lo que haría el procesador RISC-V al leer
    // ---------------------------------------------------------
    task automatic bus_read(
        input  logic [31:0] addr,  // dirección donde leer
        output logic [31:0] data   // valor leído
    );
        @(posedge clk);            // esperar flanco
        address <= addr;           // poner la dirección
        we      <= 1'b0;           // indicar que es lectura
        @(posedge clk);            // esperar un ciclo
        data    = data_out;        // capturar el dato que devuelve el periférico
        address <= 32'h0;          // limpiar dirección
    endtask

    // ---------------------------------------------------------
    // Task: simular que la laptop envía 1 byte por UART
    // Construye la trama: start + 8 bits + stop
    // ---------------------------------------------------------
    task automatic laptop_send_byte(input logic [7:0] b);
        int i;
        uart_rx <= 1'b1; #(BIT_TIME); // línea idle antes de empezar
        uart_rx <= 1'b0; #(BIT_TIME); // bit de inicio (start bit = 0)

        // enviar los 8 bits, del menos significativo al más significativo
        for (i = 0; i < 8; i++) begin
            uart_rx <= b[i];
            #(BIT_TIME);
        end

        uart_rx <= 1'b1; #(BIT_TIME); // bit de parada (stop bit = 1)
    endtask

    // ---------------------------------------------------------
    // Task: esperar a que llegue un byte por uart_tx
    // con timeout para que el testbench no se quede pegado
    // ---------------------------------------------------------
    task automatic wait_tx_done(input int timeout_cycles);
        int t;
        // uart_tx en idle = 1, cuando empieza a transmitir baja a 0
        // esperamos a que baje (inicio de transmisión)
        t = 0;
        while (uart_tx !== 1'b0 && t < timeout_cycles) begin
            @(posedge clk);
            t++;
        end
        if (t >= timeout_cycles) begin
            $display("[TB] ERROR: Timeout esperando inicio de TX");
            $fatal;
        end
        // ahora esperamos a que vuelva a 1 (fin de transmisión)
        t = 0;
        while (uart_tx !== 1'b1 && t < timeout_cycles) begin
            @(posedge clk);
            t++;
        end
        if (t >= timeout_cycles) begin
            $display("[TB] ERROR: Timeout esperando fin de TX");
            $fatal;
        end
    endtask

    // =========================================================
    // 6) RECEPTOR DE VERIFICACION
    //    Instanciamos uart_rx para decodificar lo que sale
    //    por uart_tx y verificar que el byte es correcto
    // =========================================================
    logic [7:0] verify_rx_data;   // byte decodificado
    logic       verify_rx_valid;  // pulso cuando hay byte nuevo
    logic       verify_rx_ferr;   // error de framing

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) u_verify_rx (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick_16x        (dut.tick_16x), // usamos el tick interno del DUT
        .rx              (uart_tx),      // escuchamos la línea TX del periférico
        .rx_data         (verify_rx_data),
        .rx_valid        (verify_rx_valid),
        .rx_framing_error(verify_rx_ferr)
    );

    // =========================================================
    // 7) TESTS
    // =========================================================
    logic [31:0] read_val;  // variable para guardar lecturas del bus

    initial begin
        // ----- Inicialización -----
        rst_n   <= 1'b0;
        address <= 32'h0;
        data_in <= 32'h0;
        we      <= 1'b0;
        uart_rx <= 1'b1; // línea RX en idle (reposo = 1 en UART)

        $display("=================================================");
        $display(" TB UART PERIPHERAL - INICIO");
        $display(" CLK=%0d Hz  BAUD=%0d  BIT_TIME=%0t",
                  CLK_FREQ_HZ, BAUD, BIT_TIME);
        $display("=================================================");

        // Mantener reset por 20 ciclos
        repeat(20) @(posedge clk);
        rst_n <= 1'b1;

        // Esperar a que el sistema se estabilice
        repeat(100) @(posedge clk);

        // =====================================================
        // TEST 1: Escritura y lectura del registro TX
        // El procesador escribe 0x41 ('A') en 0x02018
        // y luego lo lee para verificar que se guardó
        // =====================================================
        $display("--- TEST 1: Escritura y lectura de registro TX ---");

        // Escribir 'A' (0x41) en el registro de datos TX
        bus_write(32'h02018, 32'h41);

        // Leer de vuelta para verificar
        bus_read(32'h02018, read_val);

        if (read_val[7:0] !== 8'h41) begin
            $display("[TB] FALLO Test 1: esperaba 0x41, got 0x%02h", read_val[7:0]);
            $fatal;
        end
        $display("[TB] PASO Test 1: registro TX contiene 0x%02h", read_val[7:0]);

        // =====================================================
        // TEST 2: Transmisión — activar send y verificar byte
        // El procesador activa send=1 y verifica que 'A'
        // sale correctamente por la línea uart_tx
        // =====================================================
        $display("--- TEST 2: Transmision de byte por UART TX ---");

        // Escribir 'A' en registro TX (por si acaso)
        bus_write(32'h02018, 32'h41);

        // Activar send: escribir 0x01 en registro de control
        // bit 0 = send = 1
        bus_write(32'h02010, 32'h01);

        // Esperar activamente el pulso verify_rx_valid con timeout
        // No usamos delay fijo porque rx_valid dura solo 1 ciclo
        begin
            int t;
            t = 0;
            while (verify_rx_valid !== 1'b1 && t < 200_000) begin
                @(posedge clk);
                t++;
            end
            if (t >= 200_000) begin
                $display("[TB] FALLO Test 2: timeout esperando rx_valid");
                $fatal;
            end
            // Capturamos el dato exactamente cuando rx_valid está en 1
            if (verify_rx_data !== 8'h41) begin
                $display("[TB] FALLO Test 2: esperaba 'A'(0x41), got 0x%02h",
                          verify_rx_data);
                $fatal;
            end
            $display("[TB] PASO Test 2: byte transmitido correctamente: 0x%02h",
                      verify_rx_data);
        end
        
        // =====================================================
        // TEST 3: Recepción — laptop envía byte
        // Simulamos que la laptop envía 'Z' (0x5A)
        // y verificamos que new_rx=1 y el dato está en 0x0201C
        // =====================================================
        $display("--- TEST 3: Recepcion de byte desde laptop ---");

        // La "laptop" envía el byte 'Z'
        laptop_send_byte(8'h5A);

        // Esperar varios ciclos para que el periférico procese
        repeat(200) @(posedge clk);

        // Verificar que new_rx=1 en el registro de control
        bus_read(32'h02010, read_val);
        if (read_val[1] !== 1'b1) begin
            $display("[TB] FALLO Test 3: new_rx no se activó");
            $fatal;
        end
        $display("[TB] PASO Test 3: new_rx=1 correctamente");

        // Leer el dato recibido en 0x0201C
        bus_read(32'h0201C, read_val);
        if (read_val[7:0] !== 8'h5A) begin
            $display("[TB] FALLO Test 3: esperaba 0x5A, got 0x%02h",
                      read_val[7:0]);
            $fatal;
        end
        $display("[TB] PASO Test 3: dato recibido correcto: 0x%02h",
                  read_val[7:0]);

        // =====================================================
        // TEST 4: Limpieza de new_rx
        // El procesador escribe 0 en el bit new_rx para
        // indicar que ya leyó el dato
        // =====================================================
        $display("--- TEST 4: Limpieza de new_rx ---");

        // Escribir 0x00 en registro de control (baja new_rx)
        bus_write(32'h02010, 32'h00);

        // Leer y verificar que new_rx = 0
        bus_read(32'h02010, read_val);
        if (read_val[1] !== 1'b0) begin
            $display("[TB] FALLO Test 4: new_rx no se limpió");
            $fatal;
        end
        $display("[TB] PASO Test 4: new_rx limpiado correctamente");

        // =====================================================
        // FIN
        // =====================================================
        $display("=================================================");
        $display(" TODOS LOS TESTS PASARON");
        $display("=================================================");
        $finish;
    end

endmodule
