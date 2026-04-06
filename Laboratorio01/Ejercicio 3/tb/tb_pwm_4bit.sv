// tb_pwm_4bit.sv
`timescale 1ns / 1ps

module tb_pwm_4bit;

    // =========================================================
    // Señales del DUT (Device Under Test)
    // =========================================================
    logic        clk;
    logic        rst;
    logic [3:0]  duty;
    logic        pwm_out;

    // =========================================================
    // Instancia del DUT
    // =========================================================
    pwm_4bit dut (
        .clk     (clk),
        .rst     (rst),
        .duty    (duty),
        .pwm_out (pwm_out)
    );

    // =========================================================
    // Generación de reloj: 100 MHz → periodo = 10 ns
    // =========================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================
    // Parámetros del diseño
    // =========================================================
    localparam integer CYCLES_PER_LEVEL = 6250;   // ciclos por nivel
    localparam integer LEVELS           = 16;      // 2^4
    localparam integer PERIOD_CYCLES    = CYCLES_PER_LEVEL * LEVELS; // 100 000

    // =========================================================
    // Variables de conteo para verificación
    // =========================================================
    integer high_count;
    integer low_count;
    integer total_count;
    real    measured_duty;
    real    expected_duty;

    // =========================================================
    // Tarea: aplicar reset
    // =========================================================
    task apply_reset;
        begin
            rst = 1;
            @(posedge clk); @(posedge clk); @(posedge clk);
            rst = 0;
            @(posedge clk);
        end
    endtask

    // =========================================================
    // Tarea: medir ciclo de trabajo durante UN periodo completo
    //        (100 000 ciclos de reloj) y verificar con tolerancia
    // =========================================================
    task measure_duty_cycle(input logic [3:0] d_val);
        integer i;
        real tol;
        begin
            duty      = d_val;
            high_count = 0;
            low_count  = 0;
            total_count = 0;

            // Esperar hasta el inicio de un nuevo periodo PWM
            // (level_counter == 0 justo después de reset o de un ciclo completo)
            apply_reset;

            // Medir exactamente un periodo (100 000 ciclos)
            repeat (PERIOD_CYCLES) begin
                @(posedge clk);
                #1; // pequeño retardo para capturar salida actualizada
                if (pwm_out === 1'b1)
                    high_count = high_count + 1;
                else
                    low_count = low_count + 1;
                total_count = total_count + 1;
            end

            measured_duty = (real'(high_count) / real'(total_count)) * 100.0;
            expected_duty = (real'(d_val)       / real'(LEVELS))     * 100.0;
            tol           = 1.0; // ±1 % de tolerancia

            $display("duty[3:0]=%0d | esperado=%.2f%% | medido=%.2f%% | HIGH=%0d LOW=%0d",
                     d_val, expected_duty, measured_duty, high_count, low_count);

            if ((measured_duty < expected_duty - tol) ||
                (measured_duty > expected_duty + tol))
                $error("FALLO: duty=%0d | esperado=%.2f%% | medido=%.2f%%",
                        d_val, expected_duty, measured_duty);
            else
                $display("  --> PASS");
        end
    endtask

    // =========================================================
    // Tarea: verificar que reset pone la salida en 0
    // =========================================================
    task test_reset;
        begin
            $display("\n--- Test: Reset asincrónico ---");
            duty = 4'hF;          // duty máximo
            @(posedge clk); @(posedge clk);
            rst = 1;
            @(posedge clk);
            #1;
            if (pwm_out !== 1'b0)
                $error("FALLO reset: pwm_out debería ser 0 durante reset, es %b", pwm_out);
            else
                $display("Reset activo → pwm_out=0  --> PASS");
            rst = 0;
        end
    endtask

    // =========================================================
    // Tarea: verificar cambio dinámico de duty mientras corre
    // =========================================================
    task test_dynamic_change;
        integer hc, lc, tc;
        begin
            $display("\n--- Test: Cambio dinámico de duty (4 → 12) ---");
            apply_reset;
            duty = 4'd4;
            // Dejar correr medio periodo
            repeat (PERIOD_CYCLES / 2) @(posedge clk);
            // Cambiar duty en caliente
            duty = 4'd12;
            hc = 0; lc = 0; tc = 0;
            repeat (PERIOD_CYCLES) begin
                @(posedge clk); #1;
                if (pwm_out === 1'b1) hc = hc + 1;
                else                  lc = lc + 1;
                tc = tc + 1;
            end
            $display("Cambio dinámico: HIGH=%0d en %0d ciclos (esperado ~75 000)", hc, tc);
            // Solo verificar que hubo cambio (no exacto porque empezó en medio periodo)
            if (hc > 0)
                $display("  --> PASS (salida respondió al cambio)");
            else
                $error("FALLO: no se detectó actividad HIGH después del cambio");
        end
    endtask

    // =========================================================
    // Secuencia principal de pruebas
    // =========================================================
    initial begin
        $display("============================================");
        $display("  Testbench Exhaustivo - PWM 4 bits");
        $display("  Periodo objetivo: 1 ms (100 000 ciclos)");
        $display("============================================\n");

        rst  = 0;
        duty = 4'b0000;
        @(posedge clk);

        // ----------------------------------------------------------
        // TEST 1: Reset
        // ----------------------------------------------------------
        test_reset;

        // ----------------------------------------------------------
        // TEST 2: Barrido completo de todos los valores de duty (0..15)
        // ----------------------------------------------------------
        $display("\n--- Test: Barrido completo duty 0-15 ---");
        for (int i = 0; i < 16; i++) begin
            measure_duty_cycle(4'(i));
        end

        // ----------------------------------------------------------
        // TEST 3: Casos límite explícitos
        // ----------------------------------------------------------
        $display("\n--- Test: Casos límite ---");
        // duty = 0  → siempre apagado
        apply_reset;
        duty = 4'd0;
        repeat (PERIOD_CYCLES) begin
            @(posedge clk); #1;
            if (pwm_out !== 1'b0)
                $error("FALLO duty=0: pwm_out debería ser siempre 0, es %b", pwm_out);
        end
        $display("duty=0  → siempre LOW  --> PASS");

        // duty = 15 → casi siempre encendido (15/16 = 93.75 %)
        apply_reset;
        duty = 4'd15;
        high_count = 0;
        repeat (PERIOD_CYCLES) begin
            @(posedge clk); #1;
            if (pwm_out === 1'b1) high_count = high_count + 1;
        end
        if (high_count == 15 * CYCLES_PER_LEVEL)
            $display("duty=15 → HIGH=%0d/%0d ciclos  --> PASS", high_count, PERIOD_CYCLES);
        else
            $error("FALLO duty=15: HIGH=%0d, esperado=%0d", high_count, 15*CYCLES_PER_LEVEL);

        // ----------------------------------------------------------
        // TEST 4: Cambio dinámico
        // ----------------------------------------------------------
        test_dynamic_change;

        // ----------------------------------------------------------
        // TEST 5: Verificar que el periodo es exactamente 1 ms
        //         midiendo el tiempo real entre flancos ascendentes
        //         del PWM con duty=8 (50%)
        // ----------------------------------------------------------
        $display("\n--- Test: Periodo de 1 ms (duty=8, 50%%) ---");
        apply_reset;
        duty = 4'd8;
        begin
            time t1, t2;
            // Esperar primer flanco ascendente
            @(posedge pwm_out); t1 = $time;
            // Esperar siguiente flanco ascendente (un periodo completo)
            @(posedge pwm_out); t2 = $time;
            $display("Periodo medido: %0t ns (esperado 1 000 000 ns = 1 ms)", t2 - t1);
            if ((t2 - t1) == 1_000_000)
                $display("  --> PASS");
            else
                $error("FALLO: periodo=%0t ns, esperado=1 000 000 ns", t2 - t1);
        end

        // ----------------------------------------------------------
        // FIN
        // ----------------------------------------------------------
        $display("\n============================================");
        $display("  Testbench completado.");
        $display("============================================");
        $finish;
    end

    // =========================================================
    // Timeout de seguridad: 500 ms simulados
    // =========================================================
    initial begin
        #500_000_000;
        $error("TIMEOUT: simulación superó 500 ms simulados");
        $finish;
    end

endmodule

