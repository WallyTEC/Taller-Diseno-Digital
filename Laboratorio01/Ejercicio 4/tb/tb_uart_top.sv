`timescale 1ns/1ps
module tb_uart_top;

    timeunit 1ns;
    timeprecision 1ps;

    // ========================================================
    // 1) Parámetros del diseño (deben coincidir con uart_top)
    // ========================================================
    localparam int unsigned CLK_FREQ_HZ = 100_000_000;
    localparam int unsigned BAUD        = 9600;
    localparam int unsigned OVERSAMPLE  = 16;

    localparam time CLK_PERIOD = 10ns; // 100 MHz

    // ========================================================
    // 2) Señales DUT
    // ========================================================
    logic clk;
    logic rst_n;
    logic btn_send;
    logic uart_rx;
    logic uart_tx;
    logic [7:0] leds;

    // ========================================================
    // 3) Instancia DUT
    // ========================================================
    uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(BAUD),
        .OVERSAMPLE(OVERSAMPLE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_send(btn_send),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .leds(leds)
    );

    // ========================================================
    // 4) Clock generator
    // ========================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ========================================================
    // 5)
    // Usamos el tick_16x REAL del DUT (sin desfase).
    // ========================================================
    logic tick_16x_dut;
    assign tick_16x_dut = dut.tick_16x; // acceso jerárquico

    // ========================================================
    // 6) "PC RX" real: decodifica lo que manda la FPGA por uart_tx
    // ========================================================
    logic [7:0] pc_rx_data;
    logic       pc_rx_valid;
    logic       pc_rx_ferr;

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) pc_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .tick_16x(tick_16x_dut),
        .rx(uart_tx),
        .rx_data(pc_rx_data),
        .rx_valid(pc_rx_valid),
        .rx_framing_error(pc_rx_ferr)
    );

    // ========================================================
    // 7) Tiempo de bit (para PC->FPGA, no afecta Plan B del TX)
    // ========================================================
    localparam int unsigned TICK_RATE = BAUD * OVERSAMPLE;
    localparam int unsigned DIVISOR   = (CLK_FREQ_HZ + (TICK_RATE/2)) / TICK_RATE;
    localparam time BIT_TIME = OVERSAMPLE * DIVISOR * CLK_PERIOD;

    // ========================================================
    // 8) Task: presionar botón
    // ========================================================
    task automatic press_button();
        begin
            btn_send <= 1'b1;
            repeat (5) @(posedge clk);
            btn_send <= 1'b0;
        end
    endtask

    // ========================================================
    // 9) Task: PC -> FPGA (enviar 1 byte por uart_rx)
    // ========================================================
    task automatic pc_send_byte(input logic [7:0] b);
        int i;
        begin
            uart_rx <= 1'b1; #(BIT_TIME); // idle un bit

            uart_rx <= 1'b0; #(BIT_TIME); // start

            for (i = 0; i < 8; i++) begin
                uart_rx <= b[i];
                #(BIT_TIME);
            end

            uart_rx <= 1'b1; #(BIT_TIME); // stop
        end
    endtask

    // ========================================================
    // 10) Task: esperar 1 byte del "PC RX" con timeout
    //     - evita que el TB se quede pegado si algo se rompe
    // ========================================================
    task automatic pc_wait_byte(output logic [7:0] b, input int timeout_cycles);
        int t;
        begin
            b = 8'h00;

            // Espera por pc_rx_valid con timeout
            t = 0;
            while ((pc_rx_valid !== 1'b1) && (t < timeout_cycles)) begin
                @(posedge clk);
                t++;
            end

            if (t >= timeout_cycles) begin
                $display("[TB] ERROR: Timeout esperando byte del UART TX.");
                $fatal;
            end

            // Si hay framing error, reventamos
            if (pc_rx_ferr) begin
                $display("[TB] ERROR: Framing error detectado por pc_uart_rx.");
                $fatal;
            end

            b = pc_rx_data;

            // Consumimos el pulso (1 ciclo extra)
            @(posedge clk);
        end
    endtask

    // ========================================================
    // 11) Mensaje esperado
    // ========================================================
    logic [7:0] exp [0:11];
    int k;

    // ========================================================
    // 12) TESTS
    // ========================================================
    initial begin
        logic [7:0] got;
        int timeout;

        $display("=================================================");
        $display(" TB UART TOP START");
        $display(" INFO: CLK=%0d Hz BAUD=%0d OVERSAMPLE=%0d", CLK_FREQ_HZ, BAUD, OVERSAMPLE);
        $display(" INFO: DIVISOR=%0d BIT_TIME=%0t", DIVISOR, BIT_TIME);
        $display("=================================================");

        // Init
        btn_send = 1'b0;
        uart_rx  = 1'b1;
        rst_n    = 1'b0;

        // Mensaje esperado: "Hola mundo\r\n"
        exp[0]  = "H";
        exp[1]  = "o";
        exp[2]  = "l";
        exp[3]  = "a";
        exp[4]  = " ";
        exp[5]  = "m";
        exp[6]  = "u";
        exp[7]  = "n";
        exp[8]  = "d";
        exp[9]  = "o";
        exp[10] = 8'h0D;
        exp[11] = 8'h0A;

        // Reset release
        repeat (20) @(posedge clk);
        rst_n = 1'b1;

        // Esperar a que el baudgen / sistema se estabilice
        repeat (500) @(posedge clk);

        // Timeout en ciclos (suficiente para 12 bytes a 9600)
        // 1 byte ~ (10 bits) * BIT_TIME
        // BIT_TIME ~ 104.16 us => 1 byte ~ 1.0416 ms
        // 12 bytes ~ 12.5 ms => damos margen grande
        timeout = 3_000_000; // 3e6 ciclos @100MHz => 30ms

        // ====================================================
        // TEST 1: botón envía mensaje
        // ====================================================
        $display("=== TEST 1: Button sends 'Hola mundo\\r\\n' ===");
        press_button();

        // ---- SINCRONIZACIÓN CLAVE ----
        // En vez de asumir que el primer byte es 'H',
        // buscamos 'H' y a partir de ahí comparamos el mensaje.
        do begin
            pc_wait_byte(got, timeout);
        end while (got !== "H");

        // Ya encontramos la H -> ahora validamos los 11 bytes restantes
        for (k = 1; k < 12; k++) begin
            pc_wait_byte(got, timeout);
            if (got !== exp[k]) begin
                $display("[TB] ERROR msg1 byte %0d: got 0x%02h exp 0x%02h", k, got, exp[k]);
                $fatal;
            end
        end
        $display("[TB] PASS: message matched (1st press).");

        // ====================================================
        // TEST 2: botón dos veces
        // ====================================================
        $display("=== TEST 2: Button pressed twice ===");
        press_button();

        // sincronizar de nuevo buscando 'H'
        do begin
            pc_wait_byte(got, timeout);
        end while (got !== "H");

        for (k = 1; k < 12; k++) begin
            pc_wait_byte(got, timeout);
            if (got !== exp[k]) begin
                $display("[TB] ERROR msg2 byte %0d: got 0x%02h exp 0x%02h", k, got, exp[k]);
                $fatal;
            end
        end
        $display("[TB] PASS: message matched (2nd press).");

        // ====================================================
        // TEST 3: PC->FPGA, LEDs reflejan
        // ====================================================
        $display("=== TEST 3: PC sends bytes, LEDs reflect ===");

        pc_send_byte("A"); #(BIT_TIME*2);
        if (leds !== "A") begin $display("[TB] ERROR LEDs exp 'A' got 0x%02h", leds); $fatal; end

        pc_send_byte("0"); #(BIT_TIME*2);
        if (leds !== "0") begin $display("[TB] ERROR LEDs exp '0' got 0x%02h", leds); $fatal; end

        pc_send_byte("z"); #(BIT_TIME*2);
        if (leds !== "z") begin $display("[TB] ERROR LEDs exp 'z' got 0x%02h", leds); $fatal; end

        $display("[TB] PASS: RX->LEDs OK.");

        $display("=================================================");
        $display(" ALL TESTS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule
