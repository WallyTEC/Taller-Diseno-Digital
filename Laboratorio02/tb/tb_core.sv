// =============================================================================
// tb_core.sv
// -----------------------------------------------------------------------------
// Testbench del top del Lab 2 (parte de Allan).
// Verifica que el riscv_core lea el programa desde la ROM, ejecute las
// instrucciones, y haga el store del resultado de la suma 5+10=15.
//
// Programa esperado en la ROM (program_test.coe):
//   PC=0x00:  addi x1, x0, 5     -> x1 = 5
//   PC=0x04:  addi x2, x0, 10    -> x2 = 10
//   PC=0x08:  add  x3, x1, x2    -> x3 = 15
//   PC=0x0C:  lui  x4, 0x40000   -> x4 = 0x40000000
//   PC=0x10:  sw   x3, 0(x4)     -> mem[0x40000000] = 15
//   PC=0x14:  jal  x0, 0         -> loop infinito
//
// Lo que esperamos ver en la simulacion:
//   - ProgAddress_o avanza 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x14, ...
//   - En el ciclo del SW: we_o=1, DataAddress_o=0x40000000, DataOut_o=15
// =============================================================================

`timescale 1ns / 1ps

module tb_core;

    // -------------------------------------------------------------------------
    // Senales conectadas al DUT (Device Under Test = top)
    // -------------------------------------------------------------------------
    logic        sys_clk_i;
    logic        rst_n_i;
    logic [15:0] led_o;

    // -------------------------------------------------------------------------
    // Instancia del DUT
    // -------------------------------------------------------------------------
    top u_dut (
        .sys_clk_i (sys_clk_i),
        .rst_n_i   (rst_n_i),
        .led_o     (led_o)
    );

    // -------------------------------------------------------------------------
    // Generacion del reloj de 100 MHz (periodo 10 ns)
    // -------------------------------------------------------------------------
    initial sys_clk_i = 0;
    always #5 sys_clk_i = ~sys_clk_i;   // toggle cada 5 ns -> periodo 10 ns

    // -------------------------------------------------------------------------
    // Secuencia de reset y observacion
    // -------------------------------------------------------------------------
    initial begin
        // Reset activo (rst_n_i = 0 = boton presionado)
        rst_n_i = 1'b0;

        // Mantener reset durante 200 ns para que el MMCM alcance lock
        // y el sincronizador de reset se libere correctamente
        #200;
        rst_n_i = 1'b1;

        // Dejar correr la simulacion 5 us para ver varios ciclos del programa
        #5000;

        $display("=================================================");
        $display("Simulacion completada en t=%0t ns", $time);
        $display("=================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor: imprime cuando hay una escritura en el bus de datos
    // -------------------------------------------------------------------------
    // Accedemos a las senales internas a traves de la jerarquia del DUT
    always @(posedge u_dut.clk_i) begin
        if (u_dut.we) begin
            $display("[t=%0t ns] WRITE detectado: addr=0x%08h, data=0x%08h (%0d)",
                     $time, u_dut.data_address, u_dut.data_out, u_dut.data_out);

            // Verificacion automatica de la suma esperada
            if (u_dut.data_address == 32'h4000_0000 && u_dut.data_out == 32'd15) begin
                $display(">>> TEST PASSED: 5 + 10 = 15 verificado correctamente <<<");
            end
        end
    end

    // -------------------------------------------------------------------------
    // Monitor: imprime el PC cuando cambia (para debug del fetch)
    // -------------------------------------------------------------------------
    logic [31:0] last_pc;
    initial last_pc = 32'hFFFF_FFFF;

    always @(posedge u_dut.clk_i) begin
        if (u_dut.prog_address !== last_pc) begin
            $display("[t=%0t ns] FETCH: PC=0x%08h", $time, u_dut.prog_address);
            last_pc <= u_dut.prog_address;
        end
    end

endmodule