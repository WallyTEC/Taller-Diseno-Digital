// =============================================================================
// Archivo      : sim/tb_gpio_sw_btn_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Testbench self-checking para gpio_sw_btn_axil.
//
//                Se usa DEBOUNCE_CYCLES pequeño (16 ciclos) para que la
//                simulación sea rápida. El diseño real usa 500 000.
//
//                Casos:
//                  T1  Reset: lectura devuelve 0
//                  T2  Aplico SW = 0xA5A5 y botones = 5'b10101, espero el
//                      tiempo de debounce y leo: debe devolver el patrón.
//                  T3  Cambio de entrada y verifico que NO se refleja
//                      antes de completarse el tiempo de debounce.
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================

`timescale 1ns/1ps


module tb_gpio_sw_btn_axil;

    localparam int DEB = 16;  // debounce pequeño para simulación

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic [AXIL_ADDR_WIDTH-1:0]  awaddr, araddr;
    logic                        awvalid, awready, arvalid, arready;
    logic [AXIL_DATA_WIDTH-1:0]  wdata, rdata;
    logic [AXIL_STRB_WIDTH-1:0]  wstrb;
    logic                        wvalid, wready, bvalid, bready, rvalid, rready;
    logic [1:0]                  bresp, rresp;

    logic [15:0] sw_in;
    logic [4:0]  btn_in;

    axil_master_bfm u_m (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .m_axi_awaddr(awaddr), .m_axi_awvalid(awvalid), .m_axi_awready(awready),
        .m_axi_wdata(wdata), .m_axi_wstrb(wstrb),
        .m_axi_wvalid(wvalid), .m_axi_wready(wready),
        .m_axi_bresp(bresp), .m_axi_bvalid(bvalid), .m_axi_bready(bready),
        .m_axi_araddr(araddr), .m_axi_arvalid(arvalid), .m_axi_arready(arready),
        .m_axi_rdata(rdata), .m_axi_rresp(rresp),
        .m_axi_rvalid(rvalid), .m_axi_rready(rready)
    );

    gpio_sw_btn_axil #(.DEBOUNCE_CYCLES(DEB)) u_dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .switches_i(sw_in), .buttons_i(btn_in)
    );

    int errors=0, checks=0;
    task automatic check(input bit cond, input string msg);
        checks++;
        if (cond) $display("[PASS] %s", msg);
        else begin errors++; $display("[FAIL] %s", msg); end
    endtask

    initial begin #10_000; $fatal(1, "Timeout"); end

    logic [1:0] resp;
    logic [AXIL_DATA_WIDTH-1:0] rb;
    logic [AXIL_DATA_WIDTH-1:0] expected;

    initial begin
        sw_in  = '0;
        btn_in = '0;
        rst_n  = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        $display("==== tb_gpio_sw_btn_axil ====");

        // T1
        u_m.axil_read(GPIO_SW_BASE, rb, resp);
        check(rb == 32'h0, $sformatf("T1 Reset -> readback 0x%08h", rb));

        // T2: aplicar entrada y esperar debounce
        sw_in  = 16'hA5A5;
        btn_in = 5'b10101;
        repeat (DEB + 10) @(posedge clk);  // margen para sync + debounce
        expected = {11'h0, 5'b10101, 16'hA5A5};
        u_m.axil_read(GPIO_SW_BASE, rb, resp);
        check(rb == expected, $sformatf("T2 readback 0x%08h (esp 0x%08h)", rb, expected));

        // T3: cambio la entrada y verifico que NO se refleja inmediatamente
        sw_in = 16'h1234;
        @(posedge clk);
        u_m.axil_read(GPIO_SW_BASE, rb, resp);
        check(rb == expected, "T3 cambio sin esperar debounce mantiene lectura anterior");

        // Ahora espero y vuelve a reflejarse
        repeat (DEB + 10) @(posedge clk);
        expected = {11'h0, 5'b10101, 16'h1234};
        u_m.axil_read(GPIO_SW_BASE, rb, resp);
        check(rb == expected, $sformatf("T3 tras debounce readback 0x%08h", rb));

        $display("==== Resumen ====");
        $display("Checks: %0d · Fallos: %0d", checks, errors);
        if (errors == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL");
        $finish((errors==0)?0:1);
    end

endmodule : tb_gpio_sw_btn_axil

