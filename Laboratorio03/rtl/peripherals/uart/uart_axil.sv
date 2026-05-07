// =============================================================================
// Archivo      : rtl/peripherals/uart/uart_axil.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : Wrapper AXI-Lite para el periférico UART. Conecta las
//                unidades uart_baud_gen (TX), uart_tx y uart_rx
//                (autosuficiente) al bus y expone los registros del Lab 2:
//
//                  Offset 0x0 (addr abs 0x02010)  UART_CTRL
//                    [0] send     (W/R) - SW pone 1 para disparar TX.
//                                        HW lo baja al terminar.
//                    [1] new_rx   (W/R) - HW pone 1 al recibir un byte.
//                                        SW lo baja escribiendo 0.
//                    [31:2]       0
//                  Offset 0x8 (addr abs 0x02018)  UART_TX
//                    [7:0] byte a enviar
//                  Offset 0xC (addr abs 0x0201C)  UART_RX
//                    [7:0] último byte recibido
//
// Asistencia IA: Estructura y revisión con Claude (Anthropic).
// =============================================================================



module uart_axil #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 9600
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
    input  logic                         s_axi_rready,

    input  logic                         uart_rx_i,
    output logic                         uart_tx_o
);

    // Registros internos
    logic        reg_ctrl_send_q;
    logic        reg_ctrl_newrx_q;
    logic [7:0]  reg_tx_data_q;
    logic [7:0]  reg_rx_data_q;

    // Lógica UART
    logic tx_tick;
    logic rx_sync;
    logic tx_start, tx_busy, tx_done;
    logic rx_byte_valid;
    logic [7:0] rx_byte;

    uart_baud_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_baud (
        .clk_i     (s_axi_aclk),
        .rst_n_i   (s_axi_aresetn),
        .tx_active_i (tx_busy),
        .tx_tick_o (tx_tick)
    );

    synchronizer #(.WIDTH(1), .STAGES(2)) u_rx_sync (
        .clk_i   (s_axi_aclk),
        .rst_n_i (s_axi_aresetn),
        .async_i (uart_rx_i),
        .sync_o  (rx_sync)
    );

    uart_tx u_tx (
        .clk_i     (s_axi_aclk),
        .rst_n_i   (s_axi_aresetn),
        .tx_tick_i (tx_tick),
        .start_i   (tx_start),
        .data_i    (reg_tx_data_q),
        .busy_o    (tx_busy),
        .done_o    (tx_done),
        .tx_o      (uart_tx_o)
    );

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_rx (
        .clk_i        (s_axi_aclk),
        .rst_n_i      (s_axi_aresetn),
        .rx_i         (rx_sync),
        .byte_valid_o (rx_byte_valid),
        .data_o       (rx_byte)
    );
    // tx_start: pulso de 1 ciclo en el flanco de subida de send (0->1).
    // Sin esto, después del done el TX volvería a S_IDLE viendo start=1 todavía,
    // y arrancaría una segunda transmisión del mismo dato.
    logic reg_send_d1;
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) reg_send_d1 <= 1'b0;
        else                reg_send_d1 <= reg_ctrl_send_q;
    end
    assign tx_start = reg_ctrl_send_q & ~reg_send_d1;

    // Write path
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

    logic [3:0] w_offset;
    assign w_offset = w_addr_q[3:0];

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            w_state_q        <= W_IDLE;
            w_addr_q         <= '0;
            reg_ctrl_send_q  <= 1'b0;
            reg_ctrl_newrx_q <= 1'b0;
            reg_tx_data_q    <= '0;
        end else begin
            w_state_q <= w_state_d;

            if (w_state_q == W_IDLE && s_axi_awvalid && s_axi_awready) begin
                w_addr_q <= s_axi_awaddr;
            end

            if (w_state_q == W_DATA && s_axi_wvalid && s_axi_wready) begin
                unique case (w_offset)
                    UART_OFFSET_CTRL: begin
                        if (s_axi_wstrb[0]) begin
                            reg_ctrl_send_q  <= s_axi_wdata[UART_CTRL_BIT_SEND];
                            reg_ctrl_newrx_q <= s_axi_wdata[UART_CTRL_BIT_NEW_RX];
                        end
                    end
                    UART_OFFSET_TX: begin
                        if (s_axi_wstrb[0]) reg_tx_data_q <= s_axi_wdata[7:0];
                    end
                    default: ;
                endcase
            end

            // Eventos de HW (prioridad sobre SW)
            // send se baja cuando el TX TERMINA (no cuando empieza),
            // así el SW puede polling de send=0 para saber que el byte ya salió.
            if (tx_done && reg_ctrl_send_q) begin
                reg_ctrl_send_q <= 1'b0;
            end
            // Solo aceptar RX cuando NO estamos transmitiendo (evita falsos
            // bytes producidos por crosstalk de la línea TX al sincronizador RX).
// Solo aceptar RX cuando NO estamos transmitiendo. Cubrimos toda
            // la ventana: desde que el SW solicita send hasta que el TX vuelve
            // a IDLE, incluyendo los ciclos de propagación entre ambos.
            if (rx_byte_valid && !tx_busy && !reg_ctrl_send_q) begin
                reg_ctrl_newrx_q <= 1'b1;
            end
        end
    end

    assign s_axi_awready = (w_state_q == W_IDLE);
    assign s_axi_wready  = (w_state_q == W_DATA);
    assign s_axi_bvalid  = (w_state_q == W_RESP);
    assign s_axi_bresp   = AXI_RESP_OKAY;

always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)                                          reg_rx_data_q <= '0;
        else if (rx_byte_valid && !tx_busy && !reg_ctrl_send_q)      reg_rx_data_q <= rx_byte;
    end
    // Read path
    typedef enum logic {R_IDLE, R_RESP} r_state_e;
    r_state_e r_state_q, r_state_d;
    logic [AXIL_DATA_WIDTH-1:0] rdata_q;

    always_comb begin
        r_state_d = r_state_q;
        unique case (r_state_q)
            R_IDLE: if (s_axi_arvalid && s_axi_arready) r_state_d = R_RESP;
            R_RESP: if (s_axi_rvalid  && s_axi_rready)  r_state_d = R_IDLE;
            default: r_state_d = R_IDLE;
        endcase
    end

    logic [3:0] r_offset;
    assign r_offset = s_axi_araddr[3:0];

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state_q <= R_IDLE;
            rdata_q   <= '0;
        end else begin
            r_state_q <= r_state_d;
            if (r_state_q == R_IDLE && s_axi_arvalid && s_axi_arready) begin
                unique case (r_offset)
                    UART_OFFSET_CTRL: rdata_q <= {30'h0, reg_ctrl_newrx_q, reg_ctrl_send_q};
                    UART_OFFSET_TX:   rdata_q <= {24'h0, reg_tx_data_q};
                    UART_OFFSET_RX:   rdata_q <= {24'h0, reg_rx_data_q};
                    default:          rdata_q <= '0;
                endcase
            end
        end
    end

    assign s_axi_arready = (r_state_q == R_IDLE);
    assign s_axi_rvalid  = (r_state_q == R_RESP);
    assign s_axi_rdata   = rdata_q;
    assign s_axi_rresp   = AXI_RESP_OKAY;

endmodule : uart_axil
