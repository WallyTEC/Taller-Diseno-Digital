// =============================================================================
// Archivo      : rtl/memory/rom_axil_with_ip.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite para la ROM de programa, envolviendo el
//                IP rom_program (Block Memory Generator de Vivado, modo
//                Single Port ROM, 512 palabras × 32 bits, inicializado
//                desde main.coe).
//
//                El IP rom_program tiene puertos:
//                  clka   : reloj
//                  addra  : dirección (9 bits = log2(512))
//                  douta  : dato leído (32 bits, latencia 1 ciclo)
//
//                Este wrapper expone una interfaz AXI-Lite estándar y
//                serializa el acceso al puerto único del IP.
//
//                Write: la ROM es read-only. Aceptamos AW y W para no
//                bloquear al master, y respondemos con SLVERR.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module rom_axil_with_ip (
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

    localparam int ROM_INDEX_W = 9;   // log2(512)
    localparam int ADDR_LSB    = 2;

    // -------------------------------------------------------------------------
    // Instancia del IP Block Memory Generator
    // -------------------------------------------------------------------------
    logic [ROM_INDEX_W-1:0] rom_addr;
    logic [31:0]            rom_dout;

    rom_program u_rom_ip (
        .clka  (s_axi_aclk),
        .addra (rom_addr),
        .douta (rom_dout)
    );

    // =========================================================================
    // WRITE PATH — read-only: acepta y devuelve SLVERR
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
    assign s_axi_bresp   = AXI_RESP_SLVERR;

    // =========================================================================
    // READ PATH — usa el IP, latencia 1 ciclo
    // =========================================================================
    typedef enum logic {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state_q, r_state_d;
    logic [31:0] rdata_q;

    always_comb begin
        r_state_d = r_state_q;
        unique case (r_state_q)
            R_IDLE: if (s_axi_arvalid && s_axi_arready) r_state_d = R_RESP;
            R_RESP: if (s_axi_rvalid  && s_axi_rready)  r_state_d = R_IDLE;
            default: r_state_d = R_IDLE;
        endcase
    end

    // El IP latcheará el dato un ciclo después de presentar la dirección.
    // Por eso pasamos a R_RESP y leemos rom_dout en ese estado.
    assign rom_addr = s_axi_araddr[ADDR_LSB +: ROM_INDEX_W];

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state_q <= R_IDLE;
            rdata_q   <= '0;
        end else begin
            r_state_q <= r_state_d;
            // Capturamos el dato del IP en el ciclo siguiente al handshake AR
            if (r_state_q == R_RESP) rdata_q <= rom_dout;
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rom_dout;
    assign s_axi_rresp   = AXI_RESP_OKAY;

endmodule : rom_axil_with_ip

