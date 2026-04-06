// ============================================================
// TASK 2: PRUEBAS WIDTH=8
// (misma lógica que WIDTH=4 pero con 8 bits)
// ============================================================

task automatic test_width8;

    logic [W8-1:0] expected;
    int errors = 0;
    int checks = 0;

    for (int i = 0; i < 50; i++) begin

        d0_8 = $urandom;
        d1_8 = $urandom;
        d2_8 = $urandom;
        d3_8 = $urandom;

        for (int s = 0; s < 4; s++) begin

            sel_8 = s;
            #1;

            case (sel_8)
                2'b00: expected = d0_8;
                2'b01: expected = d1_8;
                2'b10: expected = d2_8;
                2'b11: expected = d3_8;
                default: expected = '0;
            endcase

            checks++;

            if (y_8 !== expected) begin
                errors++;
                $display("ERROR W=8 i=%0d sel=%b y=%h exp=%h",
                         i, sel_8, y_8, expected);
            end
        end
    end

    if (errors == 0)
        $display("PASS WIDTH=8 (checks=%0d)", checks);
    else
        $fatal(1, "FAIL WIDTH=8 (checks=%0d errors=%0d)", checks, errors);

endtask


// ============================================================
// TASK 3: PRUEBAS WIDTH=16
// ============================================================

task automatic test_width16;

    logic [W16-1:0] expected;
    int errors = 0;
    int checks = 0;

    for (int i = 0; i < 50; i++) begin

        d0_16 = $urandom;
        d1_16 = $urandom;
        d2_16 = $urandom;
        d3_16 = $urandom;

        for (int s = 0; s < 4; s++) begin

            sel_16 = s;
            #1;

            case (sel_16)
                2'b00: expected = d0_16;
                2'b01: expected = d1_16;
                2'b10: expected = d2_16;
                2'b11: expected = d3_16;
                default: expected = '0;
            endcase

            checks++;

            if (y_16 !== expected) begin
                errors++;
                $display("ERROR W=16 i=%0d sel=%b y=%h exp=%h",
                         i, sel_16, y_16, expected);
            end
        end
    end

    if (errors == 0)
        $display("PASS WIDTH=16 (checks=%0d)", checks);
    else
        $fatal(1, "FAIL WIDTH=16 (checks=%0d errors=%0d)", checks, errors);

endtask


// ============================================================
// BLOQUE INITIAL (INICIO DE SIMULACIÓN)
// ============================================================

initial begin

    $display("\n=== INICIO TESTBENCH MUX 4:1 ===");
    // Mensaje de inicio.

    test_width4();
    // Ejecuta pruebas para 4 bits.

    test_width8();
    // Ejecuta pruebas para 8 bits.

    test_width16();
    // Ejecuta pruebas para 16 bits.

    $display("\n=== TODAS LAS PRUEBAS PASARON (4, 8, 16) ===");
    // Si llegamos aquí, ninguna prueba falló.

    $finish;
    // Finaliza la simulación correctamente.

end

endmodule
