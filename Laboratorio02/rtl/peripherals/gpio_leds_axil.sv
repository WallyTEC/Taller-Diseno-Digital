// =============================================================================
// Archivo      : rtl/peripherals/gpio_leds_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite para los 12 LEDs accesibles por programa
//                de la Nexys4 DDR (LED0..LED11). Los LEDs LED12..LED15
//                están reservados en top.sv para mostrar bits altos del
//                PC del core (debug visual).
//
//                Un único registro de 32 bits en dirección 0x02004:
//                  [11:0] LEDs físicos
//                  [31:12] reservado, lee como 0
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module gpio_leds_axil (
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
    input  logic                         s_axi_rready,

    output logic [11:0]                  leds_o
);

    logic [11:0] leds_q;

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
            w_state_q <= W_IDLE;
            leds_q    <= '0;
        end else begin
            w_state_q <= w_state_d;
            if (w_state_q == W_DATA && s_axi_wvalid && s_axi_wready) begin
                if (s_axi_wstrb[0]) leds_q[7:0]  <= s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) leds_q[11:8] <= s_axi_wdata[11:8];
            end
        end
    end

    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;

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
                rdata_q <= {20'h0, leds_q};
            end
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rdata_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;

    assign leds_o = leds_q;

endmodule : gpio_leds_axil

