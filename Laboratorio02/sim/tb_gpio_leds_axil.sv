// =============================================================================
// Archivo      : sim/tb_gpio_leds_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Testbench self-checking para gpio_leds_axil.
//
//                Casos:
//                  T1  Reset: leds_o en 0
//                  T2  Write 0x0000_AAAA -> leds_o == 16'hAAAA
//                  T3  Readback del registro
//                  T4  Write 0xFFFF_1234 (descarta bits altos) -> leds_o = 0x1234
//                  T5  Write parcial con wstrb = 4'b0010 sobre 0x0000_AABB
//                      Partiendo de 0x1234 queda {0xAA, 0x34} = 0xAA34
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================

`timescale 1ns/1ps


module tb_gpio_leds_axil;

    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // Bus
    logic [AXIL_ADDR_WIDTH-1:0]  awaddr, araddr;
    logic                        awvalid, awready, arvalid, arready;
    logic [AXIL_DATA_WIDTH-1:0]  wdata, rdata;
    logic [AXIL_STRB_WIDTH-1:0]  wstrb;
    logic                        wvalid, wready, bvalid, bready, rvalid, rready;
    logic [1:0]                  bresp, rresp;

    logic [15:0] leds;

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

    gpio_leds_axil u_dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .leds_o(leds)
    );

    int errors = 0, checks = 0;
    task automatic check(input bit cond, input string msg);
        checks++;
        if (cond) $display("[PASS] %s", msg);
        else    begin errors++; $display("[FAIL] %s", msg); end
    endtask

    initial begin
        #10_000; $fatal(1, "Timeout");
    end

    logic [1:0]  resp;
    logic [AXIL_DATA_WIDTH-1:0] rb;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);
        $display("==== tb_gpio_leds_axil ====");

        // T1
        check(leds == 16'h0000, "T1 Reset -> leds = 0");

        // T2
        u_m.axil_write_simple(GPIO_LED_BASE, 32'h0000_AAAA, resp);
        repeat (2) @(posedge clk);
        check(resp == AXI_RESP_OKAY, "T2 Write OKAY");
        check(leds == 16'hAAAA,      $sformatf("T2 leds = 0x%04h (esperado 0xAAAA)", leds));

        // T3
        u_m.axil_read(GPIO_LED_BASE, rb, resp);
        check(resp == AXI_RESP_OKAY,      "T3 Read OKAY");
        check(rb == 32'h0000_AAAA,        $sformatf("T3 readback = 0x%08h", rb));

        // T4
        u_m.axil_write_simple(GPIO_LED_BASE, 32'hFFFF_1234, resp);
        repeat (2) @(posedge clk);
        check(leds == 16'h1234, $sformatf("T4 bits altos ignorados, leds = 0x%04h", leds));

        // T5: wstrb parcial (sólo escribe byte 1 = bits [15:8])
        u_m.axil_write(GPIO_LED_BASE, 32'h0000_AABB, 4'b0010, resp);
        repeat (2) @(posedge clk);
        check(leds == 16'hAA34, $sformatf("T5 wstrb parcial -> 0x%04h (esperado 0xAA34)", leds));

        $display("==== Resumen ====");
        $display("Checks: %0d · Fallos: %0d", checks, errors);
        if (errors == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL");
        $finish((errors==0)?0:1);
    end

endmodule : tb_gpio_leds_axil

