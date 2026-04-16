
Copiar

// =============================================================================
// top.sv  (v2.0 — Sistema completo integrado)
// -----------------------------------------------------------------------------
// Top-level del Lab 2: Microcontrolador RISC-V con periféricos.
//
// Conecta:
//   - clk_rst_gen      : PLL 100→50 MHz + reset sincronizado
//   - riscv_core       : PicoRV32 wrapper (buses separados)
//   - rom_program      : IP Core ROM (512 x 32 = 2 KiB)
//   - bus_driver       : decodificador de direcciones + RAM (100 KiB)
//   - led_peripheral   : 16 LEDs mapeados en 0x02004
//   - sw_btn_peripheral: 16 switches mapeados en 0x02000
//   - uart_peripheral  : UART A mapeado en 0x02010/18/1C
// =============================================================================
 
module top (
    // --- Entradas físicas de la Nexys4 DDR ---
    input  logic        sys_clk_i,    // 100 MHz, pin E3
    input  logic        rst_n_i,      // CPU_RESETN, pin C12 (active low)
 
    // --- Switches ---
    input  logic [15:0] sw_i,         // 16 switches
 
    // --- LEDs ---
    output logic [15:0] led_o,        // 16 LEDs
 
    // --- UART ---
    input  logic        uart_rx_i,    // UART RX desde PC (pin C4)
    output logic        uart_tx_o     // UART TX hacia PC (pin D4)
);
 
    // =========================================================================
    // Señales internas
    // =========================================================================
 
    // Reloj y reset del sistema
    logic        clk;
    logic        rst;       // active high
 
    // Bus de programa (core <-> ROM)
    logic [31:0] prog_address;
    logic [31:0] prog_data;
 
    // Bus de datos (core <-> bus_driver)
    logic [31:0] data_address;
    logic [31:0] data_out;
    logic [31:0] data_in;
    logic        we;
 
    // Bus driver <-> SW/BTN
    logic        sw_sel;
    logic [31:0] sw_data;
 
    // Bus driver <-> LED
    logic        led_sel;
    logic        led_we;
    logic [31:0] led_data;
 
    // Bus driver <-> UART
    logic [31:0] uart_addr;
    logic [31:0] uart_wdata;
    logic        uart_we;
    logic [31:0] uart_rdata;
 
    // =========================================================================
    // 1. Generador de reloj y reset
    // =========================================================================
    clk_rst_gen u_clk_rst (
        .sys_clk_i (sys_clk_i),
        .rst_n_i   (rst_n_i),
        .clk_i     (clk),
        .rst_i     (rst)
    );
 
    // =========================================================================
    // 2. Core RISC-V (PicoRV32 wrapper)
    // =========================================================================
    riscv_core u_core (
        .clk_i         (clk),
        .rst_i         (rst),
        .ProgAddress_o (prog_address),
        .ProgIn_i      (prog_data),
        .DataAddress_o (data_address),
        .DataOut_o     (data_out),
        .DataIn_i      (data_in),
        .we_o          (we)
    );
 
    // =========================================================================
    // 3. ROM de programa (IP Core, 512 palabras x 32 bits = 2 KiB)
    // =========================================================================
    // PicoRV32 genera direcciones por byte. La ROM tiene 9 bits de address
    // (512 palabras), asi que tomamos prog_address[10:2] para alinear a word.
    rom_program u_rom (
        .clka  (clk),
        .addra (prog_address[10:2]),
        .douta (prog_data)
    );
 
    // =========================================================================
    // 4. Bus Driver (decodificador de direcciones + RAM interna)
    // =========================================================================
    bus_driver u_bus (
        .clk_i        (clk),
        .rst_i        (rst),
 
        // Lado del core
        .core_addr_i  (data_address),
        .core_wdata_i (data_out),
        .core_we_i    (we),
        .core_rdata_o (data_in),
 
        // SW/BTN
        .sw_sel_o     (sw_sel),
        .sw_data_i    (sw_data),
 
        // LED
        .led_sel_o    (led_sel),
        .led_we_o     (led_we),
        .led_data_o   (led_data),
 
        // UART
        .uart_addr_o  (uart_addr),
        .uart_data_o  (uart_wdata),
        .uart_we_o    (uart_we),
        .uart_data_i  (uart_rdata)
    );
 
    // =========================================================================
    // 5. Periférico de Switches/Botones (0x02000, read-only)
    // =========================================================================
    sw_btn_peripheral u_sw_btn (
        .clk_i  (clk),
        .rst_i  (rst),
        .sw_i   (sw_i),
        .sel_i  (sw_sel),
        .data_o (sw_data)
    );
 
    // =========================================================================
    // 6. Periférico de LEDs (0x02004, write-only)
    // =========================================================================
    led_peripheral u_led (
        .clk_i  (clk),
        .rst_i  (rst),
        .we_i   (led_we),
        .sel_i  (led_sel),
        .data_i (led_data),
        .leds_o (led_o)
    );
 
    // =========================================================================
    // 7. Periférico UART (0x02010/18/1C)
    // =========================================================================
    // NOTA: uart_peripheral usa rst_n (active low), el sistema usa rst (active high).
    //       Se invierte la señal de reset.
    // NOTA: CLK_FREQ_HZ debe coincidir con la frecuencia real del reloj (50 MHz),
    //       no con el oscilador de entrada (100 MHz).
    uart_peripheral #(
        .CLK_FREQ_HZ (50_000_000),   // clk_rst_gen genera 50 MHz
        .BAUD        (9600),
        .OVERSAMPLE  (16)
    ) u_uart (
        .clk      (clk),
        .rst_n    (~rst),             // Invertir: sistema es active high
        .address  (uart_addr),
        .data_in  (uart_wdata),
        .we       (uart_we),
        .data_out (uart_rdata),
        .uart_rx  (uart_rx_i),
        .uart_tx  (uart_tx_o)
    );
 
endmodule
 
