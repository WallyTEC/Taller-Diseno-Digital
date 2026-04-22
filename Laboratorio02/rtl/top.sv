// =============================================================================
// Archivo      : rtl/top.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Top-level del SoC RISC-V para FPGA Nexys4 DDR.
//                Integra:
//                  - PLL clk_wiz_main (100 MHz -> 50 MHz)
//                  - reset_sync para deasserción síncrona
//                  - picorv32_axi (variante AXI4-Lite del core RV32I)
//                  - axil_interconnect (1 master, 5 slaves)
//                  - rom_axil + IP rom_program (programa)
//                  - ram_axil + IP data_ram (datos)
//                  - gpio_leds_axil (LEDs 0..11)
//                  - gpio_sw_btn_axil (switches + 4 botones, sin BTNC)
//                  - uart_axil (9600 8N1)
//
//                LEDs físicos:
//                  LED[11:0]  -> controlados por el programa via gpio_leds
//                  LED[15:12] -> debug = pc[31:28] del core
//
//                Reset físico: BTNC (activo-alto en placa) se invierte
//                              y se pasa por reset_sync.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module top (
    input  logic        clk_100mhz_i,   // E3 - oscilador 100 MHz
    input  logic        btnc_i,         // N17 - botón centro = reset (activo-alto)

    input  logic [15:0] sw_i,           // 16 switches
    input  logic        btnu_i,         // botón arriba
    input  logic        btnd_i,         // botón abajo
    input  logic        btnl_i,         // botón izquierda
    input  logic        btnr_i,         // botón derecha

    input  logic        uart_rxd_i,     // C4 - UART RX (desde el puente USB-UART)
    output logic        uart_txd_o,     // D4 - UART TX (hacia el puente USB-UART)

    output logic [15:0] leds_o
);

    // -------------------------------------------------------------------------
    // Reloj y reset
    // -------------------------------------------------------------------------
    logic clk_50mhz;
    logic pll_locked;
    logic rst_n_async;
    logic rst_n;

    // BTNC es activo-alto en la placa; lo invertimos. AND con pll_locked
    // mantiene el sistema en reset hasta que el PLL haya bloqueado.
    assign rst_n_async = ~btnc_i & pll_locked;

    // PLL: 100 MHz -> 50 MHz (instancia del IP clk_wiz_main creado por Tcl)
    clk_wiz_main u_pll (
        .clk_in1  (clk_100mhz_i),
        .clk_out1 (clk_50mhz),
        .locked   (pll_locked)
    );

    reset_sync #(.STAGES(3)) u_rst_sync (
        .clk_i         (clk_50mhz),
        .rst_n_async_i (rst_n_async),
        .rst_n_sync_o  (rst_n)
    );

    // -------------------------------------------------------------------------
    // Buses AXI-Lite
    // -------------------------------------------------------------------------
    // Master (core) <-> Interconnect
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

    // Interconnect <-> Slaves (empaquetados)
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

    // -------------------------------------------------------------------------
    // Core PicoRV32 (variante AXI4-Lite Master)
    // -------------------------------------------------------------------------
    // Nota: picorv32_axi expone una interfaz master AXI-Lite ya empaquetada.
    // Se conecta directamente a las señales m_axi_* del interconnect.
    // Los anchos de dirección del core son 32 bits; los conectamos a los
    // 20 bits inferiores del interconnect (los superiores se ignoran porque
    // el mapa de memoria del Lab cabe en 20 bits).
    logic [31:0] core_awaddr_full;
    logic [31:0] core_araddr_full;
    logic        core_trap;

    assign m_awaddr = core_awaddr_full[AXIL_ADDR_WIDTH-1:0];
    assign m_araddr = core_araddr_full[AXIL_ADDR_WIDTH-1:0];

    picorv32_axi #(
        .ENABLE_COUNTERS    (1),
        .ENABLE_REGS_16_31  (1),
        .ENABLE_REGS_DUALPORT(1),
        .COMPRESSED_ISA     (0),
        .BARREL_SHIFTER     (1),
        .TWO_STAGE_SHIFT    (1),
        .ENABLE_MUL         (0),
        .ENABLE_DIV         (0),
        .ENABLE_FAST_MUL    (0),
        .ENABLE_IRQ         (0),
        .STACKADDR          (32'h0005_8FFC),  // tope de RAM (alineado)
        .PROGADDR_RESET     (32'h0000_0000)   // arranca en ROM
    ) u_core (
        .clk            (clk_50mhz),
        .resetn         (rst_n),
        .trap           (core_trap),

        // AXI-Lite Master
        .mem_axi_awvalid (m_awvalid),
        .mem_axi_awready (m_awready),
        .mem_axi_awaddr  (core_awaddr_full),
        .mem_axi_awprot  (),

        .mem_axi_wvalid  (m_wvalid),
        .mem_axi_wready  (m_wready),
        .mem_axi_wdata   (m_wdata),
        .mem_axi_wstrb   (m_wstrb),

        .mem_axi_bvalid  (m_bvalid),
        .mem_axi_bready  (m_bready),

        .mem_axi_arvalid (m_arvalid),
        .mem_axi_arready (m_arready),
        .mem_axi_araddr  (core_araddr_full),
        .mem_axi_arprot  (),

        .mem_axi_rvalid  (m_rvalid),
        .mem_axi_rready  (m_rready),
        .mem_axi_rdata   (m_rdata),

        // Interrupciones (no usadas)
        .irq             (32'h0),
        .eoi             (),

        // Trace (no usado)
        .trace_valid     (),
        .trace_data      ()
    );

    // -------------------------------------------------------------------------
    // Interconnect AXI-Lite
    // -------------------------------------------------------------------------
    axil_interconnect u_xbar (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),

        // Slave (del core)
        .s_axi_awaddr  (m_awaddr), .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata   (m_wdata),  .s_axi_wstrb (m_wstrb),
        .s_axi_wvalid  (m_wvalid), .s_axi_wready (m_wready),
        .s_axi_bresp   (m_bresp),  .s_axi_bvalid (m_bvalid), .s_axi_bready (m_bready),
        .s_axi_araddr  (m_araddr), .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_rdata   (m_rdata),  .s_axi_rresp  (m_rresp),
        .s_axi_rvalid  (m_rvalid), .s_axi_rready (m_rready),

        // Masters (a los slaves)
        .m_axi_awaddr  (s_awaddr), .m_axi_awvalid(s_awvalid), .m_axi_awready(s_awready),
        .m_axi_wdata   (s_wdata),  .m_axi_wstrb (s_wstrb),
        .m_axi_wvalid  (s_wvalid), .m_axi_wready (s_wready),
        .m_axi_bresp   (s_bresp),  .m_axi_bvalid (s_bvalid), .m_axi_bready (s_bready),
        .m_axi_araddr  (s_araddr), .m_axi_arvalid(s_arvalid), .m_axi_arready(s_arready),
        .m_axi_rdata   (s_rdata),  .m_axi_rresp  (s_rresp),
        .m_axi_rvalid  (s_rvalid), .m_axi_rready (s_rready)
    );

    // -------------------------------------------------------------------------
    // ROM (IP rom_program envuelto en rom_axil)
    // -------------------------------------------------------------------------
    // Usamos un wrapper local que adapta el IP rom_program (BRAM con .coe)
    // a la interfaz AXI-Lite. El wrapper rom_axil con $readmemh es
    // alternativo para simulación; en síntesis usamos el IP.
    //
    // Si se prefiere RTL inferrable, comentar el bloque rom_program_inst
    // y cambiar a rom_axil con ROM_INIT_FILE.
    rom_axil_with_ip u_rom (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_awaddr [SLAVE_IDX_ROM]),
        .s_axi_awvalid (s_awvalid[SLAVE_IDX_ROM]),
        .s_axi_awready (s_awready[SLAVE_IDX_ROM]),
        .s_axi_wdata   (s_wdata  [SLAVE_IDX_ROM]),
        .s_axi_wstrb   (s_wstrb  [SLAVE_IDX_ROM]),
        .s_axi_wvalid  (s_wvalid [SLAVE_IDX_ROM]),
        .s_axi_wready  (s_wready [SLAVE_IDX_ROM]),
        .s_axi_bresp   (s_bresp  [SLAVE_IDX_ROM]),
        .s_axi_bvalid  (s_bvalid [SLAVE_IDX_ROM]),
        .s_axi_bready  (s_bready [SLAVE_IDX_ROM]),
        .s_axi_araddr  (s_araddr [SLAVE_IDX_ROM]),
        .s_axi_arvalid (s_arvalid[SLAVE_IDX_ROM]),
        .s_axi_arready (s_arready[SLAVE_IDX_ROM]),
        .s_axi_rdata   (s_rdata  [SLAVE_IDX_ROM]),
        .s_axi_rresp   (s_rresp  [SLAVE_IDX_ROM]),
        .s_axi_rvalid  (s_rvalid [SLAVE_IDX_ROM]),
        .s_axi_rready  (s_rready [SLAVE_IDX_ROM])
    );

    // -------------------------------------------------------------------------
    // RAM (IP data_ram envuelto en ram_axil)
    // -------------------------------------------------------------------------
    ram_axil_with_ip u_ram (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_awaddr [SLAVE_IDX_RAM]),
        .s_axi_awvalid (s_awvalid[SLAVE_IDX_RAM]),
        .s_axi_awready (s_awready[SLAVE_IDX_RAM]),
        .s_axi_wdata   (s_wdata  [SLAVE_IDX_RAM]),
        .s_axi_wstrb   (s_wstrb  [SLAVE_IDX_RAM]),
        .s_axi_wvalid  (s_wvalid [SLAVE_IDX_RAM]),
        .s_axi_wready  (s_wready [SLAVE_IDX_RAM]),
        .s_axi_bresp   (s_bresp  [SLAVE_IDX_RAM]),
        .s_axi_bvalid  (s_bvalid [SLAVE_IDX_RAM]),
        .s_axi_bready  (s_bready [SLAVE_IDX_RAM]),
        .s_axi_araddr  (s_araddr [SLAVE_IDX_RAM]),
        .s_axi_arvalid (s_arvalid[SLAVE_IDX_RAM]),
        .s_axi_arready (s_arready[SLAVE_IDX_RAM]),
        .s_axi_rdata   (s_rdata  [SLAVE_IDX_RAM]),
        .s_axi_rresp   (s_rresp  [SLAVE_IDX_RAM]),
        .s_axi_rvalid  (s_rvalid [SLAVE_IDX_RAM]),
        .s_axi_rready  (s_rready [SLAVE_IDX_RAM])
    );

    // -------------------------------------------------------------------------
    // GPIO Switches + Botones (sin BTNC, que es reset)
    // -------------------------------------------------------------------------
    logic [11:0] led_prog;

    gpio_sw_btn_axil #(.DEBOUNCE_CYCLES(500_000)) u_gpio_sw (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_awaddr [SLAVE_IDX_GPIO_SW]),
        .s_axi_awvalid (s_awvalid[SLAVE_IDX_GPIO_SW]),
        .s_axi_awready (s_awready[SLAVE_IDX_GPIO_SW]),
        .s_axi_wdata   (s_wdata  [SLAVE_IDX_GPIO_SW]),
        .s_axi_wstrb   (s_wstrb  [SLAVE_IDX_GPIO_SW]),
        .s_axi_wvalid  (s_wvalid [SLAVE_IDX_GPIO_SW]),
        .s_axi_wready  (s_wready [SLAVE_IDX_GPIO_SW]),
        .s_axi_bresp   (s_bresp  [SLAVE_IDX_GPIO_SW]),
        .s_axi_bvalid  (s_bvalid [SLAVE_IDX_GPIO_SW]),
        .s_axi_bready  (s_bready [SLAVE_IDX_GPIO_SW]),
        .s_axi_araddr  (s_araddr [SLAVE_IDX_GPIO_SW]),
        .s_axi_arvalid (s_arvalid[SLAVE_IDX_GPIO_SW]),
        .s_axi_arready (s_arready[SLAVE_IDX_GPIO_SW]),
        .s_axi_rdata   (s_rdata  [SLAVE_IDX_GPIO_SW]),
        .s_axi_rresp   (s_rresp  [SLAVE_IDX_GPIO_SW]),
        .s_axi_rvalid  (s_rvalid [SLAVE_IDX_GPIO_SW]),
        .s_axi_rready  (s_rready [SLAVE_IDX_GPIO_SW]),
        .switches_i    (sw_i),
        .buttons_i     ({btnu_i, btnd_i, btnl_i, btnr_i, 1'b0})  // 5 bits, BTNC=0
    );

    // -------------------------------------------------------------------------
    // GPIO LEDs (12 LEDs accesibles por programa)
    // -------------------------------------------------------------------------
    gpio_leds_axil u_gpio_led (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_awaddr [SLAVE_IDX_GPIO_LED]),
        .s_axi_awvalid (s_awvalid[SLAVE_IDX_GPIO_LED]),
        .s_axi_awready (s_awready[SLAVE_IDX_GPIO_LED]),
        .s_axi_wdata   (s_wdata  [SLAVE_IDX_GPIO_LED]),
        .s_axi_wstrb   (s_wstrb  [SLAVE_IDX_GPIO_LED]),
        .s_axi_wvalid  (s_wvalid [SLAVE_IDX_GPIO_LED]),
        .s_axi_wready  (s_wready [SLAVE_IDX_GPIO_LED]),
        .s_axi_bresp   (s_bresp  [SLAVE_IDX_GPIO_LED]),
        .s_axi_bvalid  (s_bvalid [SLAVE_IDX_GPIO_LED]),
        .s_axi_bready  (s_bready [SLAVE_IDX_GPIO_LED]),
        .s_axi_araddr  (s_araddr [SLAVE_IDX_GPIO_LED]),
        .s_axi_arvalid (s_arvalid[SLAVE_IDX_GPIO_LED]),
        .s_axi_arready (s_arready[SLAVE_IDX_GPIO_LED]),
        .s_axi_rdata   (s_rdata  [SLAVE_IDX_GPIO_LED]),
        .s_axi_rresp   (s_rresp  [SLAVE_IDX_GPIO_LED]),
        .s_axi_rvalid  (s_rvalid [SLAVE_IDX_GPIO_LED]),
        .s_axi_rready  (s_rready [SLAVE_IDX_GPIO_LED]),
        .leds_o        (led_prog)
    );

    // -------------------------------------------------------------------------
    // UART
    // -------------------------------------------------------------------------
    uart_axil #(.CLK_FREQ_HZ(50_000_000), .BAUD_RATE(9600)) u_uart (
        .s_axi_aclk    (clk_50mhz),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (s_awaddr [SLAVE_IDX_UART]),
        .s_axi_awvalid (s_awvalid[SLAVE_IDX_UART]),
        .s_axi_awready (s_awready[SLAVE_IDX_UART]),
        .s_axi_wdata   (s_wdata  [SLAVE_IDX_UART]),
        .s_axi_wstrb   (s_wstrb  [SLAVE_IDX_UART]),
        .s_axi_wvalid  (s_wvalid [SLAVE_IDX_UART]),
        .s_axi_wready  (s_wready [SLAVE_IDX_UART]),
        .s_axi_bresp   (s_bresp  [SLAVE_IDX_UART]),
        .s_axi_bvalid  (s_bvalid [SLAVE_IDX_UART]),
        .s_axi_bready  (s_bready [SLAVE_IDX_UART]),
        .s_axi_araddr  (s_araddr [SLAVE_IDX_UART]),
        .s_axi_arvalid (s_arvalid[SLAVE_IDX_UART]),
        .s_axi_arready (s_arready[SLAVE_IDX_UART]),
        .s_axi_rdata   (s_rdata  [SLAVE_IDX_UART]),
        .s_axi_rresp   (s_rresp  [SLAVE_IDX_UART]),
        .s_axi_rvalid  (s_rvalid [SLAVE_IDX_UART]),
        .s_axi_rready  (s_rready [SLAVE_IDX_UART]),
        .uart_rx_i     (uart_rxd_i),
        .uart_tx_o     (uart_txd_o)
    );

// -------------------------------------------------------------------------
    // Heartbeat: contador libre SIN reset, para validar que clk_50mhz vive
    // aunque el reset del sistema esté atascado.
    // -------------------------------------------------------------------------
    logic [25:0] heartbeat_cnt = '0;
    always_ff @(posedge clk_50mhz) begin
        heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    // -------------------------------------------------------------------------
    // LEDs de debug (4 altos):
    //   LED15 = heartbeat       (~1.5 Hz si clk_50mhz corre)
    //   LED14 = core_trap       (DEBE estar apagado)
    //   LED13 = rst_n           (encendido cuando NO hay reset)
    //   LED12 = pll_locked      (encendido cuando el PLL estabilizó)
    // LEDs 0..11 = led_prog (los que controla el programa)
    // -------------------------------------------------------------------------
    assign leds_o = {
        heartbeat_cnt[25],  // LED15
        core_trap,          // LED14
        rst_n,              // LED13
        pll_locked,         // LED12
        led_prog            // LED11..0
    };
endmodule : top

