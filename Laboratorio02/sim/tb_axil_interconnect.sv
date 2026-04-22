// =============================================================================
// Archivo      : sim/tb_axil_interconnect.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Testbench self-checking para axil_interconnect.
//
//                Topología del TB:
//
//                  axil_master_bfm
//                        |
//                        v  (s_axi_*)
//                  axil_interconnect  <-- DUT
//                        |
//                        v  (m_axi_*[NUM_SLAVES-1:0])
//                  5 x axil_slave_bfm (inline en este archivo)
//
//                Casos de prueba:
//                  T1  Estado tras reset - todos los outputs en 0
//                  T2  Write + read a cada slave válido, en su base
//                  T3  Write + read a offsets válidos dentro del rango
//                  T4  DECERR en write (dirección no mapeada)
//                  T5  DECERR en read  (dirección no mapeada)
//                  T6  Dos writes consecutivos al mismo slave
//                  T7  Dos reads  consecutivos al mismo slave
//                  T8  Write a slave X y read a slave Y concurrentes
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================
 
`timescale 1ns/1ps
 
 
// =============================================================================
// Slave BFM interno: memoria asociativa indexada por dirección de palabra.
// Usado exclusivamente por este TB. Devuelve OKAY en todas las transacciones;
// lecturas a direcciones nunca escritas devuelven 0.
// =============================================================================
module axil_slave_bfm_local #(
    parameter int unsigned SLAVE_ID = 0
) (
    input  logic                         s_axi_aclk,
    input  logic                         s_axi_aresetn,
 
    input  logic [AXIL_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                         s_axi_awvalid,
    output logic                         s_axi_awready,
    input  logic [AXIL_DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [AXIL_STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic                         s_axi_wvalid,
    output logic                         s_axi_wready,
    output logic [1:0]                   s_axi_bresp,
    output logic                         s_axi_bvalid,
    input  logic                         s_axi_bready,
    input  logic [AXIL_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                         s_axi_arvalid,
    output logic                         s_axi_arready,
    output logic [AXIL_DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]                   s_axi_rresp,
    output logic                         s_axi_rvalid,
    input  logic                         s_axi_rready
);
    // Memoria asociativa indexada por dirección de palabra (addr >> 2).
    // Se usa un array asociativo para no consumir memoria por todas las
    // direcciones posibles; crece dinámicamente según los accesos.
    logic [AXIL_DATA_WIDTH-1:0] mem [int unsigned];
 
    // Latch de la dirección de escritura entre AW y W (AXI-Lite permite
    // AW y W desordenados, así que hay que capturarla explícitamente).
    logic [AXIL_ADDR_WIDTH-1:0] w_addr_q;
 
    // Contadores de accesos, útiles para observar qué slave fue tocado
    // durante transacciones concurrentes.
    int unsigned write_count_q;
    int unsigned read_count_q;
 
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_e;
    w_state_e w_state_q, w_state_d;
 
    always_comb begin
        w_state_d = w_state_q;
        unique case (w_state_q)
            W_IDLE: if (s_axi_awvalid && s_axi_awready) w_state_d = W_DATA;
            W_DATA: if (s_axi_wvalid  && s_axi_wready)  w_state_d = W_RESP;
            W_RESP: if (s_axi_bvalid  && s_axi_bready)  w_state_d = W_IDLE;
            default: w_state_d = W_IDLE;
        endcase
    end
 
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            w_state_q     = W_IDLE;
            w_addr_q      = '0;
            write_count_q = 0;
        end else begin
            w_state_q <= w_state_d;
            if (w_state_q == W_IDLE && s_axi_awvalid && s_axi_awready) begin
                w_addr_q <= s_axi_awaddr;
            end
            if (w_state_q == W_DATA && s_axi_wvalid && s_axi_wready) begin
                // Array asociativo: asignación bloqueante por limitación de XSim
                // en Vivado 2024.1 (no soporta NBA a associative arrays).
                mem[int'(w_addr_q >> 2)] = s_axi_wdata;
                write_count_q <= write_count_q + 1;
            end
        end
    end
 
    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;
 
    typedef enum logic {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state_q, r_state_d;
 
    // Latch de la dirección y del dato de lectura en el handshake de AR
    logic [AXIL_DATA_WIDTH-1:0] r_data_q;
 
    always_comb begin
        r_state_d = r_state_q;
        unique case (r_state_q)
            R_IDLE:  if (s_axi_arvalid && s_axi_arready) r_state_d = R_RESP;
            R_RESP:  if (s_axi_rvalid  && s_axi_rready)  r_state_d = R_IDLE;
            default: r_state_d = R_IDLE;
        endcase
    end
 
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state_q    <= R_IDLE;
            read_count_q <= 0;
            r_data_q     <= '0;
        end else begin
            r_state_q <= r_state_d;
            if (r_state_q == R_IDLE && s_axi_arvalid && s_axi_arready) begin
                // Lookup en la memoria asociativa; default 0 si nunca escrita
                if (mem.exists(int'(s_axi_araddr >> 2)))
                    r_data_q <= mem[int'(s_axi_araddr >> 2)];
                else
                    r_data_q <= '0;
                read_count_q <= read_count_q + 1;
            end
        end
    end
 
    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = r_data_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;
 
endmodule : axil_slave_bfm_local
 
 
// =============================================================================
// Testbench principal
// =============================================================================
module tb_axil_interconnect;
 
    // ----------- Clock & reset -----------
    logic clk;
    logic rst_n;
 
    initial clk = 1'b0;
    always #5 clk = ~clk;       // 100 MHz en sim (periodo 10 ns)
 
    // ----------- Buses master<->interconnect -----------
    logic [AXIL_ADDR_WIDTH-1:0]  m_awaddr;
    logic                        m_awvalid, m_awready;
    logic [AXIL_DATA_WIDTH-1:0]  m_wdata;
    logic [AXIL_STRB_WIDTH-1:0]  m_wstrb;
    logic                        m_wvalid, m_wready;
    logic [1:0]                  m_bresp;
    logic                        m_bvalid, m_bready;
    logic [AXIL_ADDR_WIDTH-1:0]  m_araddr;
    logic                        m_arvalid, m_arready;
    logic [AXIL_DATA_WIDTH-1:0]  m_rdata;
    logic [1:0]                  m_rresp;
    logic                        m_rvalid, m_rready;
 
    // ----------- Buses interconnect<->slaves (empaquetados) -----------
    logic [NUM_SLAVES-1:0][AXIL_ADDR_WIDTH-1:0] s_awaddr;
    logic [NUM_SLAVES-1:0]                      s_awvalid, s_awready;
    logic [NUM_SLAVES-1:0][AXIL_DATA_WIDTH-1:0] s_wdata;
    logic [NUM_SLAVES-1:0][AXIL_STRB_WIDTH-1:0] s_wstrb;
    logic [NUM_SLAVES-1:0]                      s_wvalid, s_wready;
    logic [NUM_SLAVES-1:0][1:0]                 s_bresp;
    logic [NUM_SLAVES-1:0]                      s_bvalid, s_bready;
    logic [NUM_SLAVES-1:0][AXIL_ADDR_WIDTH-1:0] s_araddr;
    logic [NUM_SLAVES-1:0]                      s_arvalid, s_arready;
    logic [NUM_SLAVES-1:0][AXIL_DATA_WIDTH-1:0] s_rdata;
    logic [NUM_SLAVES-1:0][1:0]                 s_rresp;
    logic [NUM_SLAVES-1:0]                      s_rvalid, s_rready;
 
    // ----------- Master BFM -----------
    axil_master_bfm u_master (
        .s_axi_aclk   (clk),
        .s_axi_aresetn(rst_n),
        .m_axi_awaddr (m_awaddr),  .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata  (m_wdata),   .m_axi_wstrb (m_wstrb),
        .m_axi_wvalid (m_wvalid),  .m_axi_wready (m_wready),
        .m_axi_bresp  (m_bresp),   .m_axi_bvalid (m_bvalid),  .m_axi_bready (m_bready),
        .m_axi_araddr (m_araddr),  .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rdata  (m_rdata),   .m_axi_rresp  (m_rresp),
        .m_axi_rvalid (m_rvalid),  .m_axi_rready (m_rready)
    );
 
    // ----------- DUT: interconnect -----------
    axil_interconnect u_dut (
        .s_axi_aclk   (clk),
        .s_axi_aresetn(rst_n),
        .s_axi_awaddr (m_awaddr),  .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata  (m_wdata),   .s_axi_wstrb (m_wstrb),
        .s_axi_wvalid (m_wvalid),  .s_axi_wready (m_wready),
        .s_axi_bresp  (m_bresp),   .s_axi_bvalid (m_bvalid),  .s_axi_bready (m_bready),
        .s_axi_araddr (m_araddr),  .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_rdata  (m_rdata),   .s_axi_rresp  (m_rresp),
        .s_axi_rvalid (m_rvalid),  .s_axi_rready (m_rready),
        .m_axi_awaddr (s_awaddr),  .m_axi_awvalid(s_awvalid), .m_axi_awready(s_awready),
        .m_axi_wdata  (s_wdata),   .m_axi_wstrb (s_wstrb),
        .m_axi_wvalid (s_wvalid),  .m_axi_wready (s_wready),
        .m_axi_bresp  (s_bresp),   .m_axi_bvalid (s_bvalid),  .m_axi_bready (s_bready),
        .m_axi_araddr (s_araddr),  .m_axi_arvalid(s_arvalid), .m_axi_arready(s_arready),
        .m_axi_rdata  (s_rdata),   .m_axi_rresp  (s_rresp),
        .m_axi_rvalid (s_rvalid),  .m_axi_rready (s_rready)
    );
 
    // ----------- 5 slave BFMs via generate -----------
    genvar gi;
    generate
        for (gi = 0; gi < NUM_SLAVES; gi++) begin : g_slv
            axil_slave_bfm_local #(.SLAVE_ID(gi)) u_slv (
                .s_axi_aclk   (clk),
                .s_axi_aresetn(rst_n),
                .s_axi_awaddr (s_awaddr [gi]), .s_axi_awvalid(s_awvalid[gi]), .s_axi_awready(s_awready[gi]),
                .s_axi_wdata  (s_wdata  [gi]), .s_axi_wstrb (s_wstrb [gi]),
                .s_axi_wvalid (s_wvalid [gi]), .s_axi_wready (s_wready [gi]),
                .s_axi_bresp  (s_bresp  [gi]), .s_axi_bvalid (s_bvalid [gi]), .s_axi_bready (s_bready [gi]),
                .s_axi_araddr (s_araddr [gi]), .s_axi_arvalid(s_arvalid[gi]), .s_axi_arready(s_arready[gi]),
                .s_axi_rdata  (s_rdata  [gi]), .s_axi_rresp  (s_rresp  [gi]),
                .s_axi_rvalid (s_rvalid [gi]), .s_axi_rready (s_rready [gi])
            );
        end
    endgenerate
 
    // =========================================================================
    // Infraestructura de checks
    // =========================================================================
    int unsigned errors   = 0;
    int unsigned checks   = 0;
 
    task automatic check(input bit cond, input string msg);
        checks++;
        if (cond) begin
            $display("[PASS] %s", msg);
        end else begin
            errors++;
            $display("[FAIL] %s", msg);
        end
    endtask
 
    // Tabla auxiliar: dirección base válida por slave
    function automatic logic [AXIL_ADDR_WIDTH-1:0] base_of(input int unsigned idx);
        unique case (idx)
            SLAVE_IDX_ROM:      return ROM_BASE;
            SLAVE_IDX_RAM:      return RAM_BASE;
            SLAVE_IDX_GPIO_SW:  return GPIO_SW_BASE;
            SLAVE_IDX_GPIO_LED: return GPIO_LED_BASE;
            SLAVE_IDX_UART:     return UART_BASE;
            default:            return '0;
        endcase
    endfunction
 
    function automatic string name_of(input int unsigned idx);
        unique case (idx)
            SLAVE_IDX_ROM:      return "ROM";
            SLAVE_IDX_RAM:      return "RAM";
            SLAVE_IDX_GPIO_SW:  return "GPIO_SW";
            SLAVE_IDX_GPIO_LED: return "GPIO_LED";
            SLAVE_IDX_UART:     return "UART";
            default:            return "???";
        endcase
    endfunction
 
    // Watchdog de simulación (timeout global)
    initial begin
        #100_000;  // 100 us
        $display("[FATAL] Timeout global alcanzado");
        $fatal(1, "Timeout");
    end
 
    // =========================================================================
    // Secuencia principal
    // =========================================================================
    logic [AXIL_DATA_WIDTH-1:0] rdata;
    logic [1:0]                 resp;
    logic [AXIL_DATA_WIDTH-1:0] patt;
 
    initial begin
        // Reset
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        $display("==== Inicio de tests ====");
 
        // -------- T1: Estado tras reset --------
        // Nota: awready y arready DEBEN estar en 1 en IDLE (el slave está
        // listo para aceptar una nueva transacción). Lo que verificamos es
        // que no haya respuestas pendientes ni valids hacia los slaves.
        check(m_bvalid   == 1'b0, "T1 bvalid  en 0 post-reset");
        check(m_rvalid   == 1'b0, "T1 rvalid  en 0 post-reset");
        check(|s_awvalid == 1'b0, "T1 ningún m_axi_awvalid[i] activo post-reset");
        check(|s_wvalid  == 1'b0, "T1 ningún m_axi_wvalid[i]  activo post-reset");
        check(|s_arvalid == 1'b0, "T1 ningún m_axi_arvalid[i] activo post-reset");
        check(m_awready  == 1'b1, "T1 awready en 1 post-reset (listo para recibir)");
        check(m_arready  == 1'b1, "T1 arready en 1 post-reset (listo para recibir)");
 
        // -------- T2: Write + read a cada slave en su base --------
        for (int s = 0; s < NUM_SLAVES; s++) begin
            patt = $urandom();
            u_master.axil_write_simple(base_of(s), patt, resp);
            check(resp == AXI_RESP_OKAY,
                  $sformatf("T2 %s: write base resp=OKAY", name_of(s)));
 
            u_master.axil_read(base_of(s), rdata, resp);
            check(resp == AXI_RESP_OKAY,
                  $sformatf("T2 %s: read base resp=OKAY", name_of(s)));
            check(rdata == patt,
                  $sformatf("T2 %s: readback 0x%08h == 0x%08h",
                            name_of(s), rdata, patt));
        end
 
        // -------- T3: Offsets dentro del rango (sólo RAM, tiene rango amplio) --------
        begin
            logic [AXIL_ADDR_WIDTH-1:0] a;
            a    = RAM_BASE + 20'h00400;   // offset 1 KiB
            patt = 32'hCAFEBABE;
            u_master.axil_write_simple(a, patt, resp);
            check(resp == AXI_RESP_OKAY, "T3 RAM offset 0x400: write OKAY");
            u_master.axil_read(a, rdata, resp);
            check(resp == AXI_RESP_OKAY, "T3 RAM offset 0x400: read  OKAY");
            check(rdata == patt,         $sformatf("T3 RAM offset 0x400: readback 0x%08h", rdata));
        end
 
        // -------- T4: DECERR en write a dirección no mapeada --------
        u_master.axil_write_simple(20'h30000, 32'hDEADBEEF, resp);
        check(resp == AXI_RESP_DECERR, "T4 Write a 0x30000 -> DECERR");
 
        // -------- T5: DECERR en read de dirección no mapeada --------
        u_master.axil_read(20'h30000, rdata, resp);
        check(resp == AXI_RESP_DECERR, "T5 Read  de 0x30000 -> DECERR");
        check(rdata == 32'h0,          "T5 rdata=0 en DECERR");
 
        // -------- T6: Dos writes consecutivos al mismo slave (RAM) --------
        u_master.axil_write_simple(RAM_BASE + 20'h00100, 32'h11111111, resp);
        check(resp == AXI_RESP_OKAY, "T6 Write #1 RAM OKAY");
        u_master.axil_write_simple(RAM_BASE + 20'h00200, 32'h22222222, resp);
        check(resp == AXI_RESP_OKAY, "T6 Write #2 RAM OKAY");
        u_master.axil_read(RAM_BASE + 20'h00200, rdata, resp);
        check(rdata == 32'h22222222, $sformatf("T6 Readback último write = 0x%08h", rdata));
 
        // -------- T7: Dos reads consecutivos al mismo slave (RAM) --------
        u_master.axil_read(RAM_BASE + 20'h00100, rdata, resp);
        check(rdata == 32'h11111111, $sformatf("T7 Read #1 = 0x%08h", rdata));
        u_master.axil_read(RAM_BASE + 20'h00200, rdata, resp);
        check(rdata == 32'h22222222, $sformatf("T7 Read #2 = 0x%08h", rdata));
 
        // -------- T8: Write a GPIO_LED y read de RAM concurrentes --------
        begin
            logic [1:0] resp_w, resp_r;
            logic [AXIL_DATA_WIDTH-1:0] rdata_r;
            fork
                u_master.axil_write_simple(GPIO_LED_BASE, 32'hABCD1234, resp_w);
                u_master.axil_read        (RAM_BASE + 20'h00100, rdata_r, resp_r);
            join
            check(resp_w  == AXI_RESP_OKAY, "T8 Write concurrente GPIO_LED OKAY");
            check(resp_r  == AXI_RESP_OKAY, "T8 Read  concurrente RAM      OKAY");
            check(rdata_r == 32'h11111111,  $sformatf("T8 Read concurrente valor = 0x%08h", rdata_r));
        end
 
        // -------- Reporte final --------
        $display("==== Resumen ====");
        $display("Checks ejecutados: %0d", checks);
        $display("Fallos:            %0d", errors);
        if (errors == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL");
 
        $finish((errors == 0) ? 0 : 1);
    end
 
endmodule : tb_axil_interconnect
 
