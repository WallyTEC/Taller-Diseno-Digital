// =============================================================================
// Archivo      : rtl/memory/rom_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Slave AXI-Lite para la ROM de programa del SoC RISC-V.
//
//                - 512 palabras de 32 bits (2 KiB) por defecto.
//                - Memoria inferrable como Block RAM por Vivado (synchronous
//                  read con registro de salida). Opcionalmente se puede
//                  sustituir por el IP `rom_program` instanciado desde Tcl,
//                  pero el estilo inferrable permite simular sin IP.
//                - Inicialización desde archivo hex vía $readmemh (parámetro
//                  ROM_INIT_FILE). Formato: una palabra hex de 32 bits por
//                  línea, en big-endian lógico (palabra 0 en la primera
//                  línea). El script rv32i_asm.py genera el .coe para el IP
//                  y un .hex compañero para simulación.
//                - Read: latencia 1 ciclo desde handshake AR hasta rvalid=1.
//                - Write: la ROM es read-only. Aceptamos AW y W para no
//                  bloquear al master y respondemos con SLVERR en el canal B.
//                  Es responsabilidad del interconnect y del programador
//                  tratar esta respuesta como un error.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic). El diseño
//                final es responsabilidad del autor.
// =============================================================================



module rom_axil #(
    parameter int    ROM_WORDS     = 512,
    parameter string ROM_INIT_FILE = ""
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

    localparam int ADDR_LSB = 2;                  // palabras de 4 bytes
    localparam int INDEX_W  = $clog2(ROM_WORDS);  // bits de índice de palabra

    // -------------------------------------------------------------------------
    // Memoria ROM inferrable
    // -------------------------------------------------------------------------
    (* rom_style = "block" *) logic [AXIL_DATA_WIDTH-1:0] rom [0:ROM_WORDS-1];

    initial begin
        if (ROM_INIT_FILE != "") begin
            $readmemh(ROM_INIT_FILE, rom);
        end else begin
            for (int i = 0; i < ROM_WORDS; i++) rom[i] = '0;
        end
    end

    // =========================================================================
    // WRITE PATH — read-only: aceptar AW/W y responder SLVERR
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_RESP
    } w_state_e;

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
    // READ PATH — BRAM sincrónica, 1 ciclo de latencia
    //   T0: AR handshake -> rdata_q <= rom[index]
    //   T1: rvalid = 1, rdata = rdata_q
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
                rdata_q <= rom[s_axi_araddr[ADDR_LSB +: INDEX_W]];
            end
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rdata_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;

endmodule : rom_axil

