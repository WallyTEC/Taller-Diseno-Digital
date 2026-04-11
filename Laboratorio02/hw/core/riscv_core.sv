// =============================================================================
// riscv_core.sv
// -----------------------------------------------------------------------------
// Wrapper del core PicoRV32 que adapta su interfaz de memoria unica
// a los buses separados que pide el laboratorio (Figura 3):
//
//   - Bus de programa: ProgAddress_o[31:0] -> ROM
//                      ProgIn_i[31:0]      <- ROM
//
//   - Bus de datos:    DataAddress_o[31:0] -> RAM/perifericos
//                      DataOut_o[31:0]     -> RAM/perifericos
//                      DataIn_i[31:0]      <- RAM/perifericos
//                      we_o                -> indica escritura
// =============================================================================

module riscv_core (
    input  logic        clk_i,
    input  logic        rst_i,        // Active high

    // Bus de programa (a ROM)
    output logic [31:0] ProgAddress_o,
    input  logic [31:0] ProgIn_i,

    // Bus de datos (al Bus Driver -> RAM/perifericos)
    output logic [31:0] DataAddress_o,
    output logic [31:0] DataOut_o,
    input  logic [31:0] DataIn_i,
    output logic        we_o
);

    // -------------------------------------------------------------------------
    // Senales internas que conectan al PicoRV32
    // -------------------------------------------------------------------------
    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;

    // -------------------------------------------------------------------------
    // Instancia del PicoRV32
    // -------------------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS    (0),
        .ENABLE_COUNTERS64  (0),
        .ENABLE_REGS_16_31  (1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA  (0),
        .TWO_STAGE_SHIFT    (1),
        .BARREL_SHIFTER     (0),
        .TWO_CYCLE_COMPARE  (0),
        .TWO_CYCLE_ALU      (0),
        .COMPRESSED_ISA     (0),
        .CATCH_MISALIGN     (1),
        .CATCH_ILLINSN      (1),
        .ENABLE_PCPI        (0),
        .ENABLE_MUL         (0),
        .ENABLE_FAST_MUL    (0),
        .ENABLE_DIV         (0),
        .ENABLE_IRQ         (0),
        .ENABLE_IRQ_QREGS   (0),
        .ENABLE_IRQ_TIMER   (0),
        .ENABLE_TRACE       (0),
        .REGS_INIT_ZERO     (0),
        .PROGADDR_RESET     (32'h0000_0000),
        .STACKADDR          (32'h0007_FFFC)
    ) u_picorv32 (
        .clk         (clk_i),
        .resetn      (~rst_i),       // PicoRV32 usa reset active low
        .trap        (),

        // Interfaz de memoria
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),

        // Look-ahead interface (no usada)
        .mem_la_read (),
        .mem_la_write(),
        .mem_la_addr (),
        .mem_la_wdata(),
        .mem_la_wstrb(),

        // PCPI co-processor interface (no usado)
        .pcpi_valid  (),
        .pcpi_insn   (),
        .pcpi_rs1    (),
        .pcpi_rs2    (),
        .pcpi_wr     (1'b0),
        .pcpi_rd     (32'b0),
        .pcpi_wait   (1'b0),
        .pcpi_ready  (1'b0),

        // Interrupciones (no usadas)
        .irq         (32'b0),
        .eoi         (),

        // Trace (no usado)
        .trace_valid (),
        .trace_data  ()
    );

    // -------------------------------------------------------------------------
    // Separacion de buses
    // -------------------------------------------------------------------------
    assign ProgAddress_o = mem_addr;
    assign DataAddress_o = mem_addr;
    assign DataOut_o     = mem_wdata;

    // we_o se activa solo cuando hay acceso a datos con escritura
    assign we_o = mem_valid & ~mem_instr & (|mem_wstrb);

    // Mux de retorno: ProgIn_i si es fetch, DataIn_i si es dato
    assign mem_rdata = mem_instr ? ProgIn_i : DataIn_i;

    // -------------------------------------------------------------------------
    // Generacion de mem_ready (latencia 1 ciclo)
    // -------------------------------------------------------------------------
    logic mem_valid_d;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            mem_valid_d <= 1'b0;
        end else begin
            mem_valid_d <= mem_valid & ~mem_ready;
        end
    end

    assign mem_ready = mem_valid_d;

endmodule