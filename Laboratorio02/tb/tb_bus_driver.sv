// =============================================================================
// tb_bus_driver.sv  (v1.1)
// -----------------------------------------------------------------------------
// Testbench del bus_driver usando los modulos REALES:
//   - led_peripheral.sv     (Persona 4)
//   - sw_btn_peripheral.sv  (Persona 4, simplificado para sim - sin debounce)
//   - uart_stub             (modelo simple del UART para no instanciar todo)
//   - data_ram_sim.sv       (modelo behavioral de la RAM)
//
// Nota: el sw_btn_peripheral real tiene un contador de debounce de 5ms.
// Para no esperar 5ms en simulacion, instanciamos un "sw_btn_for_sim" que
// expone solo el path de lectura (sin debounce). El bus driver se prueba
// igual; el debounce se valida en el testbench propio del modulo.
// =============================================================================

`timescale 1ns/1ps

module tb_bus_driver;

    // -------------------------------------------------------------------------
    // Senales
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst;

    logic [31:0] core_addr;
    logic [31:0] core_wdata;
    logic        core_we;
    logic [31:0] core_rdata;

    // SW
    logic        sw_sel;
    logic [31:0] sw_data;
    logic [15:0] sw_phys;

    // LED
    logic        led_sel, led_we;
    logic [31:0] led_data_to_periph;
    logic [15:0] leds_phys;

    // UART
    logic [31:0] uart_addr, uart_data_o;
    logic        uart_we;
    logic [31:0] uart_data_i;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    bus_driver dut (
        .clk_i        (clk),
        .rst_i        (rst),
        .core_addr_i  (core_addr),
        .core_wdata_i (core_wdata),
        .core_we_i    (core_we),
        .core_rdata_o (core_rdata),

        .sw_sel_o     (sw_sel),
        .sw_data_i    (sw_data),

        .led_sel_o    (led_sel),
        .led_we_o     (led_we),
        .led_data_o   (led_data_to_periph),

        .uart_addr_o  (uart_addr),
        .uart_data_o  (uart_data_o),
        .uart_we_o    (uart_we),
        .uart_data_i  (uart_data_i)
    );

    // -------------------------------------------------------------------------
    // LED real (Persona 4)
    // -------------------------------------------------------------------------
    led_peripheral u_led (
        .clk_i  (clk),
        .rst_i  (rst),
        .we_i   (led_we),
        .sel_i  (led_sel),
        .data_i (led_data_to_periph),
        .leds_o (leds_phys)
    );

    // -------------------------------------------------------------------------
    // SW/BTN simplificado (sin debounce, para que el TB no tarde 5ms)
    // -------------------------------------------------------------------------
    logic [15:0] sw_sync0, sw_sync1;
    always_ff @(posedge clk) begin
        if (rst) begin sw_sync0 <= 16'h0; sw_sync1 <= 16'h0; end
        else    begin sw_sync0 <= sw_phys; sw_sync1 <= sw_sync0; end
    end
    assign sw_data = sw_sel ? {16'h0, sw_sync1} : 32'h0;

    // -------------------------------------------------------------------------
    // UART stub (responde con patrones reconocibles)
    // -------------------------------------------------------------------------
    logic [31:0] uart_reg_ctrl, uart_reg_tx;
    always_ff @(posedge clk) begin
        if (rst) begin
            uart_reg_ctrl <= 32'h0;
            uart_reg_tx   <= 32'h0;
        end else if (uart_we) begin
            case (uart_addr)
                32'h02010: uart_reg_ctrl <= uart_data_o;
                32'h02018: uart_reg_tx   <= uart_data_o;
                default: ;
            endcase
        end
    end
    assign uart_data_i = (uart_addr == 32'h02010) ? uart_reg_ctrl :
                         (uart_addr == 32'h02018) ? uart_reg_tx   :
                         (uart_addr == 32'h0201C) ? 32'hCAFE_001C :
                         32'h0;

    // -------------------------------------------------------------------------
    // Reloj 100 MHz
    // -------------------------------------------------------------------------
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Tareas
    // -------------------------------------------------------------------------
    task automatic bus_write(input [31:0] addr, input [31:0] data);
        @(negedge clk);
        core_addr = addr; core_wdata = data; core_we = 1'b1;
        @(negedge clk);
        core_we = 1'b0;
    endtask

    task automatic bus_read(input [31:0] addr, output [31:0] data);
        @(negedge clk);
        core_addr = addr; core_we = 1'b0;
        @(negedge clk);
        data = core_rdata;
    endtask

    int errors = 0;
    task automatic check(input string name, input [31:0] got, input [31:0] expected);
        if (got === expected) $display("[PASS] %s: 0x%08h", name, got);
        else begin
            $display("[FAIL] %s: got=0x%08h, expected=0x%08h", name, got, expected);
            errors++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Estimulos
    // -------------------------------------------------------------------------
    logic [31:0] data;

    initial begin
        clk = 0; rst = 1;
        core_addr = 0; core_wdata = 0; core_we = 0;
        sw_phys = 16'h0;
        repeat (5) @(posedge clk);
        rst = 0;
        @(posedge clk);

        $display("=== TEST 1: RAM (escritura/lectura) ===");
        bus_write(32'h0004_0000, 32'hDEAD_BEEF);
        bus_write(32'h0004_0004, 32'h1234_5678);
        bus_write(32'h0004_0100, 32'hA5A5_5A5A);
        bus_read (32'h0004_0000, data); check("RAM[0x40000]", data, 32'hDEAD_BEEF);
        bus_read (32'h0004_0004, data); check("RAM[0x40004]", data, 32'h1234_5678);
        bus_read (32'h0004_0100, data); check("RAM[0x40100]", data, 32'hA5A5_5A5A);

        $display("\n=== TEST 2: SW/BTN (lectura del valor fisico) ===");
        sw_phys = 16'hABCD;
        @(posedge clk); @(posedge clk); @(posedge clk); // sincronizar
        bus_read(32'h0000_2000, data); check("SW[0x02000]=0xABCD", data, 32'h0000_ABCD);

        sw_phys = 16'h1234;
        @(posedge clk); @(posedge clk); @(posedge clk);
        bus_read(32'h0000_2000, data); check("SW[0x02000]=0x1234", data, 32'h0000_1234);

        $display("\n=== TEST 3: LED (escritura llega al pin fisico) ===");
        bus_write(32'h0000_2004, 32'h0000_FFFF);
        @(posedge clk);
        check("LED phys=0xFFFF", {16'h0, leds_phys}, 32'h0000_FFFF);
        bus_write(32'h0000_2004, 32'hDEAD_5A5A);
        @(posedge clk);
        check("LED phys=0x5A5A (low 16 bits)", {16'h0, leds_phys}, 32'h0000_5A5A);

        $display("\n=== TEST 4: UART (3 registros) ===");
        bus_write(32'h0000_2010, 32'h0000_0001);  // escribir control
        bus_read (32'h0000_2010, data); check("UART_CTRL", data, 32'h0000_0001);
        bus_write(32'h0000_2018, 32'h0000_0041);  // 'A'
        bus_read (32'h0000_2018, data); check("UART_TX",   data, 32'h0000_0041);
        bus_read (32'h0000_201C, data); check("UART_RX",   data, 32'hCAFE_001C);

        $display("\n=== TEST 5: Direccion no mapeada ===");
        bus_read(32'h0000_3000, data); check("UNMAPPED 0x03000", data, 32'h0);
        bus_read(32'h0008_0000, data); check("UNMAPPED 0x80000", data, 32'h0);

        $display("\n=== TEST 6: Aislamiento (escritura no mapeada no afecta perifericos) ===");
        bus_write(32'h0000_3000, 32'hFFFF_FFFF);
        @(posedge clk);
        check("LED no afectado", {16'h0, leds_phys}, 32'h0000_5A5A);

        $display("\n=== TEST 7: RAM tras tocar perifericos ===");
        bus_write(32'h0004_0200, 32'h1111_2222);
        bus_read (32'h0004_0200, data); check("RAM[0x40200]", data, 32'h1111_2222);

        $display("\n=== TEST 8: Limites de la RAM ===");
        bus_write(32'h0004_0000, 32'hAAAA_AAAA);  // primera direccion
        bus_read (32'h0004_0000, data); check("RAM inicio", data, 32'hAAAA_AAAA);
        bus_write(32'h0005_8FFC, 32'hBBBB_BBBB);  // ~ultima palabra (25599)
        bus_read (32'h0005_8FFC, data); check("RAM fin",    data, 32'hBBBB_BBBB);

        $display("\n========================================");
        if (errors == 0) $display("=== TODOS LOS TESTS PASARON ===");
        else             $display("=== %0d TESTS FALLARON ===", errors);
        $display("========================================");
        $finish;
    end

    initial begin
        #500000;
        $display("[ERROR] Timeout!");
        $finish;
    end

endmodule
