// =============================================================================
// Archivo      : sim/tb_uart_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : TB self-checking del wrapper uart_axil con loopback
//                TX -> RX. Estilo procedural plano: para esperar
//                eventos del HW usamos polling con un contador de
//                seguridad, en lugar de fork/join_any/wait que en XSim
//                pueden interactuar mal.
// =============================================================================

`timescale 1ns/1ps


module tb_uart_axil;

    localparam int CLK_FREQ = 50_000_000;
    localparam int BAUD     = 1_000_000;
    localparam int BIT_PER  = CLK_FREQ / BAUD;

    logic clk = 0;
    always #10 clk = ~clk;
    logic rst_n;

    // Bus
    logic [AXIL_ADDR_WIDTH-1:0]  awaddr, araddr;
    logic                        awvalid, awready, arvalid, arready;
    logic [AXIL_DATA_WIDTH-1:0]  wdata, rdata;
    logic [AXIL_STRB_WIDTH-1:0]  wstrb;
    logic                        wvalid, wready, bvalid, bready, rvalid, rready;
    logic [1:0]                  bresp, rresp;

    logic uart_tx_line;
    logic uart_rx_line;
    assign uart_rx_line = uart_tx_line;     // loopback

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

    uart_axil #(.CLK_FREQ_HZ(CLK_FREQ), .BAUD_RATE(BAUD)) u_dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .uart_rx_i (uart_rx_line),
        .uart_tx_o (uart_tx_line)
    );

    int errors=0, checks=0;
    task automatic check(input bit cond, input string msg);
        checks++;
        if (cond) $display("[PASS] %s", msg);
        else begin errors++; $display("[FAIL] %s", msg); end
    endtask

    initial begin #2_000_000; $fatal(1, "Timeout 2 ms"); end

    localparam logic [AXIL_ADDR_WIDTH-1:0] ADDR_CTRL = UART_BASE + UART_OFFSET_CTRL;
    localparam logic [AXIL_ADDR_WIDTH-1:0] ADDR_TX   = UART_BASE + UART_OFFSET_TX;
    localparam logic [AXIL_ADDR_WIDTH-1:0] ADDR_RX   = UART_BASE + UART_OFFSET_RX;

    initial begin
        logic [AXIL_DATA_WIDTH-1:0] rb;
        logic [1:0]                 resp;
        int                         max_polls;
        bit                         got_it;

        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        $display("==== tb_uart_axil (baud=%0d) ====", BAUD);

        // T1: lectura de CTRL post-reset
        u_m.axil_read(ADDR_CTRL, rb, resp);
        check(rb == 32'h0, $sformatf("T1 Reset CTRL = 0x%08h", rb));

        // T2: cargar byte 0x5A en TX y disparar send
        u_m.axil_write_simple(ADDR_TX, 32'h0000_005A, resp);
        check(resp == AXI_RESP_OKAY, "T2 Write TX OKAY");

        u_m.axil_write_simple(ADDR_CTRL, 32'h0000_0001, resp);
        check(resp == AXI_RESP_OKAY, "T2 Write CTRL send=1 OKAY");

        // T3: polling esperando que send vuelva a 0 (HW lo bajó)
        got_it = 0;
        max_polls = BIT_PER * 4;       // muy poco: el TX arranca en pocos ciclos
        for (int i = 0; i < max_polls; i++) begin
            u_m.axil_read(ADDR_CTRL, rb, resp);
            if (rb[0] == 1'b0) begin
                got_it = 1;
                break;
            end
        end
        check(got_it, "T3 HW bajó send tras arrancar TX");

        // T4: polling esperando que new_rx suba (loopback completó)
        got_it = 0;
        max_polls = BIT_PER * 15;      // 15 períodos de bit de margen
        for (int i = 0; i < max_polls; i++) begin
            u_m.axil_read(ADDR_CTRL, rb, resp);
            if (rb[1] == 1'b1) begin
                got_it = 1;
                break;
            end
        end
        check(got_it, "T4 HW subió new_rx (byte recibido)");

        // T5: leer RX y comparar
        u_m.axil_read(ADDR_RX, rb, resp);
        check(rb[7:0] == 8'h5A,
              $sformatf("T5 byte recibido = 0x%02h (esp 0x5A)", rb[7:0]));

        // T6: limpiar new_rx escribiendo 0
        u_m.axil_write_simple(ADDR_CTRL, 32'h0, resp);
        u_m.axil_read(ADDR_CTRL, rb, resp);
        check(rb[1] == 1'b0, "T6 new_rx limpiado por SW");

        $display("==== Resumen ====");
        $display("Checks: %0d · Fallos: %0d", checks, errors);
        if (errors == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL");
        $finish((errors==0)?0:1);
    end

endmodule : tb_uart_axil

