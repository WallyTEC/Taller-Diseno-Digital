// =============================================================================
// Archivo      : rtl/peripherals/gpio_sw_btn_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite de sólo-lectura para switches y botones
//                de la Nexys4 DDR. Mapea ambos bancos a un registro de
//                32 bits en dirección 0x02000:
//
//                  [15: 0]  switches_i (16 switches)
//                  [20:16]  buttons_i  (5 botones: centro, arriba, abajo,
//                                       izq, der)
//                  [31:21]  0
//
//                Todas las entradas pasan por:
//                  1. Sincronizador de 2 flip-flops para evitar
//                     metaestabilidad.
//                  2. Debouncer con umbral de estabilidad configurable
//                     (por defecto 10 ms a 50 MHz).
//
//                - Writes: ACEPTADAS pero ignoradas, respondidas con OKAY.
//                  Podríamos devolver SLVERR (el periférico es lógicamente
//                  RO), pero por simplicidad del programa ASM se acepta.
//                  Alternativa: SLVERR; descomenta la línea indicada más
//                  abajo si se quiere enforcement estricto.
//                - Reads: 1 ciclo de latencia, devuelve snapshot del estado
//                  actual debounceado.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module gpio_sw_btn_axil #(
    parameter int DEBOUNCE_CYCLES = 500_000  // 10 ms @ 50 MHz
) (
    input  logic                         s_axi_aclk,
    input  logic                         s_axi_aresetn,

    // AXI-Lite slave
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
    input  logic                         s_axi_rready,

    // Entradas físicas
    input  logic [15:0]                  switches_i,
    input  logic [4:0]                   buttons_i    // BTNC, BTNU, BTND, BTNL, BTNR
);

    // =========================================================================
    // Sincronización y anti-rebote
    // =========================================================================
    logic [15:0] sw_sync, sw_stable;
    logic [4:0]  btn_sync, btn_stable;

    synchronizer #(.WIDTH(16), .STAGES(2)) u_sync_sw (
        .clk_i   (s_axi_aclk),
        .rst_n_i (s_axi_aresetn),
        .async_i (switches_i),
        .sync_o  (sw_sync)
    );

    synchronizer #(.WIDTH(5), .STAGES(2)) u_sync_btn (
        .clk_i   (s_axi_aclk),
        .rst_n_i (s_axi_aresetn),
        .async_i (buttons_i),
        .sync_o  (btn_sync)
    );

    debouncer #(.WIDTH(16), .STABLE_CYCLES(DEBOUNCE_CYCLES)) u_deb_sw (
        .clk_i     (s_axi_aclk),
        .rst_n_i   (s_axi_aresetn),
        .in_sync_i (sw_sync),
        .stable_o  (sw_stable)
    );

    debouncer #(.WIDTH(5), .STABLE_CYCLES(DEBOUNCE_CYCLES)) u_deb_btn (
        .clk_i     (s_axi_aclk),
        .rst_n_i   (s_axi_aresetn),
        .in_sync_i (btn_sync),
        .stable_o  (btn_stable)
    );

    // Palabra empaquetada para el bus
    logic [AXIL_DATA_WIDTH-1:0] pack_word;
    assign pack_word = {11'h000, btn_stable, sw_stable};

    // =========================================================================
    // WRITE PATH — aceptar y descartar (RO de facto)
    // =========================================================================
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
        if (!s_axi_aresetn) w_state_q <= W_IDLE;
        else                w_state_q <= w_state_d;
    end

    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;  // cambiar a AXI_RESP_SLVERR para RO estricto

    // =========================================================================
    // READ PATH
    // =========================================================================
    typedef enum logic {R_IDLE, R_RESP} r_state_e;
    r_state_e                   r_state_q, r_state_d;
    logic [AXIL_DATA_WIDTH-1:0] rdata_q;

    always_comb begin
        r_state_d = r_state_q;
        unique case (r_state_q)
            R_IDLE: if (s_axi_arvalid && s_axi_arready) r_state_d = R_RESP;
            R_RESP: if (s_axi_rvalid  && s_axi_rready)  r_state_d = R_IDLE;
            default: r_state_d = R_IDLE;
        endcase
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state_q <= R_IDLE;
            rdata_q   <= '0;
        end else begin
            r_state_q <= r_state_d;
            if (r_state_q == R_IDLE && s_axi_arvalid && s_axi_arready) begin
                rdata_q <= pack_word;
            end
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rdata_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;

endmodule : gpio_sw_btn_axil

