// =============================================================================
// Archivo      : rtl/bus/axil_interconnect.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Interconnect AXI4-Lite con 1 master entrante y 5 slaves
//                salientes para el SoC RISC-V del Laboratorio 2.
//
//                Funcionalidad:
//                  - Decodificación combinacional de direcciones según las
//                    máscaras y bases definidas en axil_defs.svh.
//                  - Ruteo independiente de los canales de write (AW/W/B)
//                    y read (AR/R): una escritura y una lectura a slaves
//                    distintos pueden ocurrir en paralelo.
//                  - Generación interna de respuesta DECERR (2'b11) cuando
//                    la dirección no matchea ningún slave. En ese caso el
//                    interconnect consume la transacción y emite B/R con
//                    DECERR sin reenviarla a ningún slave.
//                  - Serialización de hasta una transacción outstanding por
//                    canal (una write en vuelo + una read en vuelo). Esto
//                    es suficiente para el core picorv32_axi, que nunca
//                    emite más de una de cada tipo en simultáneo.
//
//                Política de access-control: este módulo NO valida si un
//                slave es RO/RW. Por ejemplo, una escritura a la ROM (que
//                es dirección válida) se reenvía normalmente; es la ROM
//                la que debe responder con SLVERR. Esto mantiene al
//                interconnect como un router puro de direcciones.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic). El diseño
//                final, las decisiones de arquitectura y la verificación
//                son responsabilidad del autor.
// =============================================================================



module axil_interconnect (
    input  logic                                             s_axi_aclk,
    input  logic                                             s_axi_aresetn,

    // ---- Slave interface (del master / core) ------------------------------
    input  logic [AXIL_ADDR_WIDTH-1:0]                       s_axi_awaddr,
    input  logic                                             s_axi_awvalid,
    output logic                                             s_axi_awready,
    input  logic [AXIL_DATA_WIDTH-1:0]                       s_axi_wdata,
    input  logic [AXIL_STRB_WIDTH-1:0]                       s_axi_wstrb,
    input  logic                                             s_axi_wvalid,
    output logic                                             s_axi_wready,
    output logic [1:0]                                       s_axi_bresp,
    output logic                                             s_axi_bvalid,
    input  logic                                             s_axi_bready,
    input  logic [AXIL_ADDR_WIDTH-1:0]                       s_axi_araddr,
    input  logic                                             s_axi_arvalid,
    output logic                                             s_axi_arready,
    output logic [AXIL_DATA_WIDTH-1:0]                       s_axi_rdata,
    output logic [1:0]                                       s_axi_rresp,
    output logic                                             s_axi_rvalid,
    input  logic                                             s_axi_rready,

    // ---- Master interfaces (hacia los 5 slaves), empaquetados -------------
    output logic [NUM_SLAVES-1:0][AXIL_ADDR_WIDTH-1:0]       m_axi_awaddr,
    output logic [NUM_SLAVES-1:0]                            m_axi_awvalid,
    input  logic [NUM_SLAVES-1:0]                            m_axi_awready,
    output logic [NUM_SLAVES-1:0][AXIL_DATA_WIDTH-1:0]       m_axi_wdata,
    output logic [NUM_SLAVES-1:0][AXIL_STRB_WIDTH-1:0]       m_axi_wstrb,
    output logic [NUM_SLAVES-1:0]                            m_axi_wvalid,
    input  logic [NUM_SLAVES-1:0]                            m_axi_wready,
    input  logic [NUM_SLAVES-1:0][1:0]                       m_axi_bresp,
    input  logic [NUM_SLAVES-1:0]                            m_axi_bvalid,
    output logic [NUM_SLAVES-1:0]                            m_axi_bready,
    output logic [NUM_SLAVES-1:0][AXIL_ADDR_WIDTH-1:0]       m_axi_araddr,
    output logic [NUM_SLAVES-1:0]                            m_axi_arvalid,
    input  logic [NUM_SLAVES-1:0]                            m_axi_arready,
    input  logic [NUM_SLAVES-1:0][AXIL_DATA_WIDTH-1:0]       m_axi_rdata,
    input  logic [NUM_SLAVES-1:0][1:0]                       m_axi_rresp,
    input  logic [NUM_SLAVES-1:0]                            m_axi_rvalid,
    output logic [NUM_SLAVES-1:0]                            m_axi_rready
);

    localparam int SEL_W = $clog2(NUM_SLAVES);

    // =========================================================================
    // Función auxiliar: convierte one-hot a índice binario
    // =========================================================================
    function automatic logic [SEL_W-1:0] oh_to_idx(input logic [NUM_SLAVES-1:0] oh);
        logic [SEL_W-1:0] idx;
        idx = '0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (oh[i]) idx = i[SEL_W-1:0];
        end
        return idx;
    endfunction

    // =========================================================================
    // DECODIFICADORES DE DIRECCIÓN (combinacionales)
    //
    // Para cada canal (write AW y read AR) se genera un vector one-hot con el
    // slave seleccionado. Si ninguna base matchea, el vector queda en 0 y
    // la bandera *_valid_decode = 0 dispara el flujo de DECERR.
    // =========================================================================
    logic [NUM_SLAVES-1:0] aw_sel_oh;
    logic                  aw_decode_valid;

    logic [NUM_SLAVES-1:0] ar_sel_oh;
    logic                  ar_decode_valid;

    always_comb begin
        aw_sel_oh = '0;
        if      ((s_axi_awaddr & ROM_MASK)      == ROM_BASE)      aw_sel_oh[SLAVE_IDX_ROM]      = 1'b1;
        else if ((s_axi_awaddr & RAM_MASK)      == RAM_BASE)      aw_sel_oh[SLAVE_IDX_RAM]      = 1'b1;
        else if ((s_axi_awaddr & GPIO_SW_MASK)  == GPIO_SW_BASE)  aw_sel_oh[SLAVE_IDX_GPIO_SW]  = 1'b1;
        else if ((s_axi_awaddr & GPIO_LED_MASK) == GPIO_LED_BASE) aw_sel_oh[SLAVE_IDX_GPIO_LED] = 1'b1;
        else if ((s_axi_awaddr & UART_MASK)     == UART_BASE)     aw_sel_oh[SLAVE_IDX_UART]     = 1'b1;
        aw_decode_valid = |aw_sel_oh;
    end

    always_comb begin
        ar_sel_oh = '0;
        if      ((s_axi_araddr & ROM_MASK)      == ROM_BASE)      ar_sel_oh[SLAVE_IDX_ROM]      = 1'b1;
        else if ((s_axi_araddr & RAM_MASK)      == RAM_BASE)      ar_sel_oh[SLAVE_IDX_RAM]      = 1'b1;
        else if ((s_axi_araddr & GPIO_SW_MASK)  == GPIO_SW_BASE)  ar_sel_oh[SLAVE_IDX_GPIO_SW]  = 1'b1;
        else if ((s_axi_araddr & GPIO_LED_MASK) == GPIO_LED_BASE) ar_sel_oh[SLAVE_IDX_GPIO_LED] = 1'b1;
        else if ((s_axi_araddr & UART_MASK)     == UART_BASE)     ar_sel_oh[SLAVE_IDX_UART]     = 1'b1;
        ar_decode_valid = |ar_sel_oh;
    end

    // =========================================================================
    // WRITE PATH
    //
    // FSM de 3 estados:
    //   W_IDLE : espera AW. En handshake, latchea sel/decerr y pasa a W_DATA.
    //   W_DATA : forwarda W (o la consume internamente si decerr). En
    //            handshake pasa a W_RESP.
    //   W_RESP : forwarda B (o genera DECERR interno). En handshake vuelve
    //            a W_IDLE.
    //
    // Se soporta UNA transacción write outstanding a la vez. El master
    // picorv32_axi nunca emite más de una, así que esto es suficiente.
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_RESP
    } w_state_e;

    w_state_e          w_state_q, w_state_d;
    logic [SEL_W-1:0]  w_sel_idx_q;
    logic              w_decerr_q;

    // Transiciones de estado
    always_comb begin
        w_state_d = w_state_q;
        unique case (w_state_q)
            W_IDLE:  if (s_axi_awvalid && s_axi_awready) w_state_d = W_DATA;
            W_DATA:  if (s_axi_wvalid  && s_axi_wready)  w_state_d = W_RESP;
            W_RESP:  if (s_axi_bvalid  && s_axi_bready)  w_state_d = W_IDLE;
            default: w_state_d = W_IDLE;
        endcase
    end

    // Registros de estado y latching de selección en el handshake de AW
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            w_state_q   <= W_IDLE;
            w_sel_idx_q <= '0;
            w_decerr_q  <= 1'b0;
        end else begin
            w_state_q <= w_state_d;
            if (w_state_q == W_IDLE && s_axi_awvalid && s_axi_awready) begin
                w_sel_idx_q <= oh_to_idx(aw_sel_oh);
                w_decerr_q  <= ~aw_decode_valid;
            end
        end
    end

    // Canal AW: ruta hacia el slave seleccionado, o acepta internamente si
    // la dirección es inválida (para poder generar DECERR).
    always_comb begin
        m_axi_awaddr  = '{default: '0};
        m_axi_awvalid = '0;
        s_axi_awready = 1'b0;

        if (w_state_q == W_IDLE) begin
            // Dirección: se conecta a todos; solo el slave válido ve awvalid=1.
            for (int i = 0; i < NUM_SLAVES; i++) begin
                m_axi_awaddr[i] = s_axi_awaddr;
            end

            if (aw_decode_valid) begin
                // Forwarding normal
                m_axi_awvalid = {NUM_SLAVES{s_axi_awvalid}} & aw_sel_oh;
                s_axi_awready = |(m_axi_awready & aw_sel_oh);
            end else begin
                // Dirección inválida: aceptamos internamente sin tocar slaves
                s_axi_awready = s_axi_awvalid;
            end
        end
    end

    // Canal W: usa la selección latcheada en w_sel_idx_q / w_decerr_q.
    always_comb begin
        m_axi_wdata  = '{default: '0};
        m_axi_wstrb  = '{default: '0};
        m_axi_wvalid = '0;
        s_axi_wready = 1'b0;

        if (w_state_q == W_DATA) begin
            for (int i = 0; i < NUM_SLAVES; i++) begin
                m_axi_wdata[i] = s_axi_wdata;
                m_axi_wstrb[i] = s_axi_wstrb;
            end

            if (!w_decerr_q) begin
                m_axi_wvalid[w_sel_idx_q] = s_axi_wvalid;
                s_axi_wready              = m_axi_wready[w_sel_idx_q];
            end else begin
                // Consumo interno de la W para no dejar colgado al master
                s_axi_wready = s_axi_wvalid;
            end
        end
    end

    // Canal B: devuelve la respuesta del slave, o DECERR interno.
    always_comb begin
        m_axi_bready = '0;
        s_axi_bvalid = 1'b0;
        s_axi_bresp  = AXI_RESP_OKAY;

        if (w_state_q == W_RESP) begin
            if (!w_decerr_q) begin
                s_axi_bvalid              = m_axi_bvalid[w_sel_idx_q];
                s_axi_bresp               = m_axi_bresp[w_sel_idx_q];
                m_axi_bready[w_sel_idx_q] = s_axi_bready;
            end else begin
                // DECERR generado internamente; siempre valido en este estado
                s_axi_bvalid = 1'b1;
                s_axi_bresp  = AXI_RESP_DECERR;
            end
        end
    end

    // =========================================================================
    // READ PATH
    //
    // FSM de 2 estados (no hay fase de data separada como en write):
    //   R_IDLE : espera AR. En handshake, latchea sel/decerr y pasa a R_RESP.
    //   R_RESP : forwarda R (o genera DECERR interno). En handshake vuelve
    //            a R_IDLE.
    //
    // Es independiente del write path: puede haber una lectura a slave Y
    // progresando mientras una escritura a slave X está en vuelo.
    // =========================================================================
    typedef enum logic {
        R_IDLE,
        R_RESP
    } r_state_e;

    r_state_e          r_state_q, r_state_d;
    logic [SEL_W-1:0]  r_sel_idx_q;
    logic              r_decerr_q;

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
            r_state_q   <= R_IDLE;
            r_sel_idx_q <= '0;
            r_decerr_q  <= 1'b0;
        end else begin
            r_state_q <= r_state_d;
            if (r_state_q == R_IDLE && s_axi_arvalid && s_axi_arready) begin
                r_sel_idx_q <= oh_to_idx(ar_sel_oh);
                r_decerr_q  <= ~ar_decode_valid;
            end
        end
    end

    // Canal AR
    always_comb begin
        m_axi_araddr  = '{default: '0};
        m_axi_arvalid = '0;
        s_axi_arready = 1'b0;

        if (r_state_q == R_IDLE) begin
            for (int i = 0; i < NUM_SLAVES; i++) begin
                m_axi_araddr[i] = s_axi_araddr;
            end

            if (ar_decode_valid) begin
                m_axi_arvalid = {NUM_SLAVES{s_axi_arvalid}} & ar_sel_oh;
                s_axi_arready = |(m_axi_arready & ar_sel_oh);
            end else begin
                s_axi_arready = s_axi_arvalid;
            end
        end
    end

    // Canal R
    always_comb begin
        m_axi_rready = '0;
        s_axi_rvalid = 1'b0;
        s_axi_rdata  = '0;
        s_axi_rresp  = AXI_RESP_OKAY;

        if (r_state_q == R_RESP) begin
            if (!r_decerr_q) begin
                s_axi_rvalid              = m_axi_rvalid[r_sel_idx_q];
                s_axi_rdata               = m_axi_rdata [r_sel_idx_q];
                s_axi_rresp               = m_axi_rresp [r_sel_idx_q];
                m_axi_rready[r_sel_idx_q] = s_axi_rready;
            end else begin
                // DECERR: data en 0, resp en DECERR
                s_axi_rvalid = 1'b1;
                s_axi_rdata  = '0;
                s_axi_rresp  = AXI_RESP_DECERR;
            end
        end
    end

endmodule : axil_interconnect

