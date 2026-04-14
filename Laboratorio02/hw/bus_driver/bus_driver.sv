// =============================================================================
// bus_driver.sv  (v1.1)
// -----------------------------------------------------------------------------
// Bus Driver del sistema (Persona 2 - Alex)
//
// Interfaces de cada slave (REALES, ya implementados por el equipo):
//
//   RAM (BMG)   : clka, wea, addra[14:0], dina[31:0], douta[31:0]
//
//   SW/BTN (P4) : sel_i + data_o    -> read-only, decodificacion externa
//   LED    (P4) : sel_i + we_i + data_i  -> write-only
//   UART   (P3) : address + data_in + we + data_out  -> read/write,
//                 decodificacion interna del periferico
//
// Mapa de memoria:
//   0x02000         SW/BTN
//   0x02004         LEDs
//   0x02010/18/1C   UART
//   0x40000-0x7FFFF RAM
//
// Latencia uniforme de 1 ciclo en lecturas (alineado a la RAM y a lo que
// riscv_core.sv espera).
// =============================================================================

module bus_driver (
    // -------------------------------------------------------------------------
    // Reloj y reset (active high, igual que el core)
    // -------------------------------------------------------------------------
    input  logic        clk_i,
    input  logic        rst_i,

    // -------------------------------------------------------------------------
    // Lado del core (master)
    // -------------------------------------------------------------------------
    input  logic [31:0] core_addr_i,
    input  logic [31:0] core_wdata_i,
    input  logic        core_we_i,
    output logic [31:0] core_rdata_o,

    // -------------------------------------------------------------------------
    // SW/BTN (read-only)
    // -------------------------------------------------------------------------
    output logic        sw_sel_o,
    input  logic [31:0] sw_data_i,

    // -------------------------------------------------------------------------
    // LEDs (write-only)
    // -------------------------------------------------------------------------
    output logic        led_sel_o,
    output logic        led_we_o,
    output logic [31:0] led_data_o,

    // -------------------------------------------------------------------------
    // UART (read/write)
    // -------------------------------------------------------------------------
    output logic [31:0] uart_addr_o,
    output logic [31:0] uart_data_o,
    output logic        uart_we_o,
    input  logic [31:0] uart_data_i
);

    // =========================================================================
    // 1. SELECTORES COMBINACIONALES
    // =========================================================================
    logic sel_ram, sel_sw, sel_led, sel_uart;

    always_comb begin
        sel_ram  = 1'b0;
        sel_sw   = 1'b0;
        sel_led  = 1'b0;
        sel_uart = 1'b0;

        // Rango RAM: 0x40000-0x7FFFF
        if (core_addr_i[19:18] == 2'b01) begin
            sel_ram = 1'b1;
        end
        // Rango periféricos: 0x02000-0x02FFF
        else if (core_addr_i[19:12] == 8'h02) begin
            unique case (core_addr_i[7:0])
                8'h00:   sel_sw   = 1'b1;
                8'h04:   sel_led  = 1'b1;
                8'h10,
                8'h18,
                8'h1C:   sel_uart = 1'b1;
                default: ;
            endcase
        end
    end

    // =========================================================================
    // 2. RUTEO DE ESCRITURA
    // =========================================================================

    // SW/BTN: solo necesita la senal de seleccion
    assign sw_sel_o    = sel_sw;

    // LED: sel + we + data
    assign led_sel_o   = sel_led;
    assign led_we_o    = core_we_i;
    assign led_data_o  = core_wdata_i;

    // UART: interfaz con address completo
    assign uart_addr_o = core_addr_i;
    assign uart_data_o = core_wdata_i;
    assign uart_we_o   = core_we_i & sel_uart;

    // =========================================================================
    // 3. INSTANCIA DE LA RAM (BMG de Vivado)
    // =========================================================================
    logic        ram_we;
    logic [14:0] ram_addr;
    logic [31:0] ram_dout;

    assign ram_we   = core_we_i & sel_ram;
    assign ram_addr = core_addr_i[16:2];

    data_ram u_data_ram (
        .clka  (clk_i),
        .wea   (ram_we),
        .addra (ram_addr),
        .dina  (core_wdata_i),
        .douta (ram_dout)
    );

    // =========================================================================
    // 4. ALINEACION DE LATENCIA
    // =========================================================================
    logic        sel_ram_q, sel_sw_q, sel_uart_q;
    logic [31:0] sw_data_q, uart_data_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sel_ram_q   <= 1'b0;
            sel_sw_q    <= 1'b0;
            sel_uart_q  <= 1'b0;
            sw_data_q   <= 32'h0;
            uart_data_q <= 32'h0;
        end else begin
            sel_ram_q   <= sel_ram  & ~core_we_i;
            sel_sw_q    <= sel_sw   & ~core_we_i;
            sel_uart_q  <= sel_uart & ~core_we_i;
            sw_data_q   <= sw_data_i;
            uart_data_q <= uart_data_i;
        end
    end

    // =========================================================================
    // 5. MUX DE LECTURA
    // =========================================================================
    always_comb begin
        unique case (1'b1)
            sel_ram_q:  core_rdata_o = ram_dout;
            sel_sw_q:   core_rdata_o = sw_data_q;
            sel_uart_q: core_rdata_o = uart_data_q;
            default:    core_rdata_o = 32'h0000_0000;
        endcase
    end

endmodule
