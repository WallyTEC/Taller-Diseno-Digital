// =============================================================================
// Archivo      : sim/common/axil_master_bfm.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Bus Functional Model (BFM) de master AXI-Lite para uso
//                exclusivo en simulación. Expone tareas bloqueantes para
//                realizar lecturas y escrituras y dejar los canales en
//                estado de reposo correctamente. No es sintetizable.
//
//                Tareas expuestas (llamadas por el TB vía la instancia):
//                  - axil_write(addr, data, strb, resp)
//                  - axil_read (addr, data, resp)
//                  - axil_write_simple(addr, data, resp)  // strb = '1
//
//                Notas de uso:
//                  - Llamar las tareas sólo después de liberar reset.
//                  - Para concurrencia (write a X + read a Y), invocar
//                    axil_write y axil_read dentro de fork/join en el TB:
//                    los dos canales de escritura y el canal de lectura
//                    son físicamente disjuntos, así que no hay conflicto
//                    sobre las líneas del bus.
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module axil_master_bfm (
    input  logic                         s_axi_aclk,
    input  logic                         s_axi_aresetn,

    // Salidas hacia el DUT (el BFM conduce la interfaz master)
    output logic [AXIL_ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic                         m_axi_awvalid,
    input  logic                         m_axi_awready,
    output logic [AXIL_DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [AXIL_STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                         m_axi_wvalid,
    input  logic                         m_axi_wready,
    input  logic [1:0]                   m_axi_bresp,
    input  logic                         m_axi_bvalid,
    output logic                         m_axi_bready,
    output logic [AXIL_ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic                         m_axi_arvalid,
    input  logic                         m_axi_arready,
    input  logic [AXIL_DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]                   m_axi_rresp,
    input  logic                         m_axi_rvalid,
    output logic                         m_axi_rready
);

    // -------------------------------------------------------------------------
    // Inicialización: todos los valids y readies en 0 para evitar X-propagation
    // -------------------------------------------------------------------------
    initial begin
        m_axi_awaddr  = '0;
        m_axi_awvalid = 1'b0;
        m_axi_wdata   = '0;
        m_axi_wstrb   = '0;
        m_axi_wvalid  = 1'b0;
        m_axi_bready  = 1'b0;
        m_axi_araddr  = '0;
        m_axi_arvalid = 1'b0;
        m_axi_rready  = 1'b0;
    end

    // =========================================================================
    // axil_write — escritura con strobes personalizados
    // =========================================================================
    task automatic axil_write(
        input  logic [AXIL_ADDR_WIDTH-1:0]  addr,
        input  logic [AXIL_DATA_WIDTH-1:0]  data,
        input  logic [AXIL_STRB_WIDTH-1:0]  strb,
        output logic [1:0]                  resp
    );
        // Lanzar AW y W en paralelo (AXI-Lite permite cualquier orden)
        fork
            begin : drive_aw
                @(posedge s_axi_aclk);
                m_axi_awaddr  <= addr;
                m_axi_awvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (!m_axi_awready) @(posedge s_axi_aclk);
                m_axi_awvalid <= 1'b0;
                m_axi_awaddr  <= '0;
            end
            begin : drive_w
                @(posedge s_axi_aclk);
                m_axi_wdata  <= data;
                m_axi_wstrb  <= strb;
                m_axi_wvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (!m_axi_wready) @(posedge s_axi_aclk);
                m_axi_wvalid <= 1'b0;
                m_axi_wdata  <= '0;
                m_axi_wstrb  <= '0;
            end
        join

        // Esperar respuesta B
        m_axi_bready <= 1'b1;
        @(posedge s_axi_aclk);
        while (!m_axi_bvalid) @(posedge s_axi_aclk);
        resp = m_axi_bresp;
        m_axi_bready <= 1'b0;
    endtask

    // =========================================================================
    // axil_write_simple — escritura con todos los strobes activos
    // =========================================================================
    task automatic axil_write_simple(
        input  logic [AXIL_ADDR_WIDTH-1:0]  addr,
        input  logic [AXIL_DATA_WIDTH-1:0]  data,
        output logic [1:0]                  resp
    );
        axil_write(addr, data, {AXIL_STRB_WIDTH{1'b1}}, resp);
    endtask

    // =========================================================================
    // axil_read — lectura con devolución de data y resp
    // =========================================================================
    task automatic axil_read(
        input  logic [AXIL_ADDR_WIDTH-1:0]  addr,
        output logic [AXIL_DATA_WIDTH-1:0]  data,
        output logic [1:0]                  resp
    );
        @(posedge s_axi_aclk);
        m_axi_araddr  <= addr;
        m_axi_arvalid <= 1'b1;
        @(posedge s_axi_aclk);
        while (!m_axi_arready) @(posedge s_axi_aclk);
        m_axi_arvalid <= 1'b0;
        m_axi_araddr  <= '0;

        m_axi_rready <= 1'b1;
        @(posedge s_axi_aclk);
        while (!m_axi_rvalid) @(posedge s_axi_aclk);
        data = m_axi_rdata;
        resp = m_axi_rresp;
        m_axi_rready <= 1'b0;
    endtask

endmodule : axil_master_bfm

