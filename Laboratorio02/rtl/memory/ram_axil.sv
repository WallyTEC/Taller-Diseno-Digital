// =============================================================================
// Archivo      : rtl/memory/ram_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite para la RAM de datos del SoC RISC-V.
//
//                - 25 600 palabras de 32 bits (100 KiB) por defecto, según
//                  el enunciado del Lab 2. El rango reservado en el mapa de
//                  memoria es de 256 KiB (0x40000–0x7FFFF); accesos a
//                  direcciones físicas fuera de RAM_WORDS tienen comportamiento
//                  indefinido (tal como lo documenta el README del Lab 2).
//                - Memoria inferrable como Block RAM con byte-write-enable
//                  usando s_axi_wstrb, patrón estándar reconocido por Vivado.
//                - Read: latencia 1 ciclo desde handshake AR hasta rvalid.
//                - Write: FSM AW -> W -> B. Asume que el interconnect
//                  serializa AW y W (lo que hace nuestro interconnect).
//                - RAM_INIT_FILE permite pre-cargar la memoria en simulación.
//                  En FPGA no hay inicialización explícita (se deja en 0).
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic). El diseño
//                final es responsabilidad del autor.
// =============================================================================



module ram_axil #(
    parameter int    RAM_WORDS     = 25600,
    parameter string RAM_INIT_FILE = ""
) (
    input  logic                         s_axi_aclk,
    input  logic                         s_axi_aresetn,

    // Write address channel
    input  logic [AXIL_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                         s_axi_awvalid,
    output logic                         s_axi_awready,

    // Write data channel
    input  logic [AXIL_DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [AXIL_STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic                         s_axi_wvalid,
    output logic                         s_axi_wready,

    // Write response channel
    output logic [1:0]                   s_axi_bresp,
    output logic                         s_axi_bvalid,
    input  logic                         s_axi_bready,

    // Read address channel
    input  logic [AXIL_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                         s_axi_arvalid,
    output logic                         s_axi_arready,

    // Read data channel
    output logic [AXIL_DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]                   s_axi_rresp,
    output logic                         s_axi_rvalid,
    input  logic                         s_axi_rready
);

    localparam int ADDR_LSB = 2;
    localparam int INDEX_W  = $clog2(RAM_WORDS);

    // -------------------------------------------------------------------------
    // Memoria RAM inferrable con byte-write-enable
    // -------------------------------------------------------------------------
    (* ram_style = "block" *) logic [AXIL_DATA_WIDTH-1:0] ram [0:RAM_WORDS-1];

    initial begin
        if (RAM_INIT_FILE != "") begin
            $readmemh(RAM_INIT_FILE, ram);
        end else begin
            for (int i = 0; i < RAM_WORDS; i++) ram[i] = '0;
        end
    end

    // =========================================================================
    // WRITE PATH — FSM AW -> W -> B, con latching del índice entre AW y W
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_RESP
    } w_state_e;

    w_state_e               w_state_q, w_state_d;
    logic [INDEX_W-1:0]     w_index_q;

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
            w_index_q <= '0;
        end else begin
            w_state_q <= w_state_d;
            if (w_state_q == W_IDLE && s_axi_awvalid && s_axi_awready) begin
                w_index_q <= s_axi_awaddr[ADDR_LSB +: INDEX_W];
            end
        end
    end

    // Escritura con byte-strobe: patrón inferrable por Vivado
    always_ff @(posedge s_axi_aclk) begin
        if (w_state_q == W_DATA && s_axi_wvalid && s_axi_wready) begin
            for (int b = 0; b < AXIL_STRB_WIDTH; b++) begin
                if (s_axi_wstrb[b]) begin
                    ram[w_index_q][8*b +: 8] <= s_axi_wdata[8*b +: 8];
                end
            end
        end
    end

    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;

    // =========================================================================
    // READ PATH — BRAM sincrónica con 1 ciclo de latencia
    // =========================================================================
    typedef enum logic {
        R_IDLE,
        R_RESP
    } r_state_e;

    r_state_e                    r_state_q, r_state_d;
    logic [AXIL_DATA_WIDTH-1:0]  rdata_q;

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
            r_state_q <= R_IDLE;
            rdata_q   <= '0;
        end else begin
            r_state_q <= r_state_d;
            if (r_state_q == R_IDLE && s_axi_arvalid && s_axi_arready) begin
                rdata_q <= ram[s_axi_araddr[ADDR_LSB +: INDEX_W]];
            end
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rdata_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;

endmodule : ram_axil

