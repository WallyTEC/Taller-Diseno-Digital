// =============================================================================
// top.sv
// -----------------------------------------------------------------------------
// Top-level temporal del Lab 2 - Allan (parte del core).
// Conecta clk_rst_gen + riscv_core + rom_program.
//
// Esta version NO incluye RAM, UART, LEDs ni Switches/Botones.
// Cuando se integren los modulos de Esteban, Alex y Walter, este archivo
// se actualiza para incluir el bus_driver y los perifericos.
//
// Para esta etapa de validacion del core:
//   - DataIn_i del core esta conectado a 0 (no hay RAM aun)
//   - we_o se lleva a un LED para ver actividad de escritura
//   - DataAddress_o[15:0] se llevan a los otros LEDs como debug
// =============================================================================

module top (
    // Entradas fisicas de la Nexys4 DDR
    input  logic        sys_clk_i,    // 100 MHz, pin E3
    input  logic        rst_n_i,      // BTNC, pin N17

    // Salidas de debug a LEDs
    output logic [15:0] led_o
);

    // -------------------------------------------------------------------------
    // Senales internas
    // -------------------------------------------------------------------------
    logic        clk_i;
    logic        rst_i;
   
   
    // Bus de programa (core <-> ROM)
    logic [31:0] prog_address;
    logic [31:0] prog_data;

    // Bus de datos (core <-> mundo exterior)
    logic [31:0] data_address;
    logic [31:0] data_out;
    logic [31:0] data_in;
    logic        we;

    // -------------------------------------------------------------------------
    // Generador de reloj y reset
    // -------------------------------------------------------------------------
    clk_rst_gen u_clk_rst (
        .sys_clk_i (sys_clk_i),
        .rst_n_i   (rst_n_i),
        .clk_i     (clk_i),
        .rst_i     (rst_i)
    );

    // -------------------------------------------------------------------------
    // Core RISC-V (PicoRV32 envuelto)
    // -------------------------------------------------------------------------
    riscv_core u_core (
        .clk_i         (clk_i),
        .rst_i         (rst_i),
        .ProgAddress_o (prog_address),
        .ProgIn_i      (prog_data),
        .DataAddress_o (data_address),
        .DataOut_o     (data_out),
        .DataIn_i      (data_in),
        .we_o          (we)
    );

    // -------------------------------------------------------------------------
    // ROM de programa
    // -------------------------------------------------------------------------
    // El IP tiene addra de 9 bits (512 palabras de 32 bits).
    // Las direcciones del PicoRV32 son por byte, asi que tomamos
    // prog_address[10:2] (descartamos los 2 bits menos significativos
    // porque cada instruccion ocupa 4 bytes).
    rom_program u_rom (
        .clka  (clk_i),
        .addra (prog_address[10:2]),
        .douta (prog_data)
    );

    // -------------------------------------------------------------------------
    // Bus de datos: temporalmente sin RAM ni perifericos
    // -------------------------------------------------------------------------
    // DataIn_i se mantiene en 0 (no hay nada que leer todavia).
    // Cuando se ejecute el sw del programa de prueba, la escritura se
    // "pierde" pero we y data_address son visibles en los LEDs.
    assign data_in = 32'h0000_0000;

    // -------------------------------------------------------------------------
    // Debug: LEDs
    // -------------------------------------------------------------------------
    // led_o[15]   = we (parpadea cuando hay una escritura)
    // led_o[14:0] = parte baja de data_address (para ver movimiento)
    assign led_o[15]   = we;
    assign led_o[14:0] = data_address[14:0];

endmodule