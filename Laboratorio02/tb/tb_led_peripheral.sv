// =============================================================================
// tb_led_peripheral.sv
// =============================================================================

module tb_led_peripheral;

    logic        clk_i, rst_i, we_i, sel_i;
    logic [31:0] data_i;
    logic [15:0] leds_o;

    led_peripheral dut (.*);

    // Clock
    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 0; rst_i = 1; we_i = 0; sel_i = 0; data_i = 0;
        @(posedge clk_i); #1;

        // Reset
        rst_i = 0;
        @(posedge clk_i); #1;
        assert (leds_o === 16'h0000) else $error("FALLO: reset no limpia LEDs");

        // Escritura normal con sel activo
        sel_i = 1; we_i = 1; data_i = 32'hABCD_1234;
        @(posedge clk_i); #1;
        assert (leds_o === 16'h1234) else $error("FALLO: LEDs no toman bits [15:0]");

        // Sin sel_i no debe cambiar
        sel_i = 0; we_i = 1; data_i = 32'hFFFF_FFFF;
        @(posedge clk_i); #1;
        assert (leds_o === 16'h1234) else $error("FALLO: cambió sin sel_i activo");

        // Sin we_i no debe cambiar
        sel_i = 1; we_i = 0; data_i = 32'hFFFF_FFFF;
        @(posedge clk_i); #1;
        assert (leds_o === 16'h1234) else $error("FALLO: cambió sin we_i activo");

        // Reset en cualquier momento limpia
        rst_i = 1;
        @(posedge clk_i); #1;
        assert (leds_o === 16'h0000) else $error("FALLO: reset no funciona");

        $display("OK: todos los casos pasaron.");
        $finish;
    end

endmodule
