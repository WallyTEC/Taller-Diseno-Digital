// =============================================================================
// tb_sw_btn_peripheral.sv
// =============================================================================

module tb_sw_btn_peripheral;

    logic        clk_i, rst_i, sel_i;
    logic [15:0] sw_i;
    logic [31:0] data_o;

    // Para simulación usamos debounce corto
    sw_btn_peripheral #() dut (.*);

    always #5 clk_i = ~clk_i;

    // Tarea: esperar N ciclos
    task wait_cycles(input int n);
        repeat(n) @(posedge clk_i);
        #1;
    endtask

    initial begin
        clk_i = 0; rst_i = 1; sel_i = 0; sw_i = 16'h0000;
        wait_cycles(5);

        // Reset
        rst_i = 0;
        wait_cycles(2);
        assert (data_o === 32'h0000_0000) else $error("FALLO: reset");

        // Sin sel_i la salida debe ser 0 aunque haya switches
        sw_i  = 16'hAAAA;
        sel_i = 0;
        wait_cycles(600_000);   // esperar debounce
        assert (data_o === 32'h0000_0000) else $error("FALLO: sin sel debe ser 0");

        // Con sel_i debe ver el valor estabilizado
        sel_i = 1;
        #1;
        assert (data_o[15:0] === 16'hAAAA) else $error("FALLO: valor de switches");
        assert (data_o[31:16] === 16'h0000) else $error("FALLO: bits altos no son 0");

        // Cambio de switches — debe esperar debounce
        sw_i = 16'h5555;
        wait_cycles(10);        // muy poco tiempo
        assert (data_o[15:0] === 16'hAAAA) else $error("FALLO: debounce no retiene valor");

        wait_cycles(600_000);   // esperar debounce completo
        assert (data_o[15:0] === 16'h5555) else $error("FALLO: nuevo valor no se actualiza");

        $display("OK: todos los casos pasaron.");
        $finish;
    end

endmodule
