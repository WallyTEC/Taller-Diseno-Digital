// =============================================================================
// Archivo      : rtl/memory/ram_axil_with_ip.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite para la RAM de datos, envolviendo el IP
//                data_ram (Block Memory Generator de Vivado, modo Single
//                Port RAM con byte write enable, 25 600 palabras × 32
//                bits = 100 KiB).
//
//                Puertos del IP data_ram:
//                  clka  : reloj
//                  ena   : enable
//                  wea   : write enable por byte (4 bits)
//                  addra : dirección (15 bits = ceil(log2(25600)))
//                  dina  : dato a escribir (32)
//                  douta : dato leído (32, latencia 1 ciclo)
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module ram_axil_with_ip (
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

    localparam int RAM_INDEX_W = 15;  // ceil(log2(25600))
    localparam int ADDR_LSB    = 2;

    logic                   ram_en;
    logic [3:0]             ram_we;
    logic [RAM_INDEX_W-1:0] ram_addr;
    logic [31:0]            ram_din;
    logic [31:0]            ram_dout;

    data_ram u_ram_ip (
        .clka  (s_axi_aclk),
        .ena   (ram_en),
        .wea   (ram_we),
        .addra (ram_addr),
        .dina  (ram_din),
        .douta (ram_dout)
    );

    // =========================================================================
    // WRITE PATH
    // =========================================================================
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_e;
    w_state_e w_state_q, w_state_d;
    logic [AXIL_ADDR_WIDTH-1:0] w_addr_q;

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
            w_addr_q  <= '0;
        end else begin
            w_state_q <= w_state_d;
            if (w_state_q == W_IDLE && s_axi_awvalid && s_axi_awready) begin
                w_addr_q <= s_axi_awaddr;
            end
        end
    end

    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;

    // =========================================================================
    // READ PATH
    // =========================================================================
    typedef enum logic {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state_q, r_state_d;

    always_comb begin
        r_state_d = r_state_q;
        unique case (r_state_q)
            R_IDLE: if (s_axi_arvalid && s_axi_arready) r_state_d = R_RESP;
            R_RESP: if (s_axi_rvalid  && s_axi_rready)  r_state_d = R_IDLE;
            default: r_state_d = R_IDLE;
        endcase
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) r_state_q <= R_IDLE;
        else                r_state_q <= r_state_d;
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rresp   = AXI_RESP_OKAY;
    assign s_axi_rdata   = ram_dout;

    // =========================================================================
    // Multiplexación de la dirección/control hacia el puerto único del IP
    //
    // Política: si hay write en curso (W_DATA), priorizar la escritura
    //           sobre cualquier read pendiente. AXI-Lite permite que el
    //           interconnect serialice las transacciones, así que las
    //           lecturas concurrentes esperan implícitamente.
    // =========================================================================
    always_comb begin
        ram_en   = 1'b0;
        ram_we   = 4'b0000;
        ram_addr = '0;
        ram_din  = '0;

        if (w_state_q == W_DATA && s_axi_wvalid) begin
            ram_en   = 1'b1;
            ram_we   = s_axi_wstrb;
            ram_addr = w_addr_q[ADDR_LSB +: RAM_INDEX_W];
            ram_din  = s_axi_wdata;
        end else if (r_state_q == R_IDLE && s_axi_arvalid) begin
            ram_en   = 1'b1;
            ram_we   = 4'b0000;
            ram_addr = s_axi_araddr[ADDR_LSB +: RAM_INDEX_W];
        end
    end

endmodule : ram_axil_with_ip

