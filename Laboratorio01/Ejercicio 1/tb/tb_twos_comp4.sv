// tb_twos_comp4.sv
module tb_twos_comp4;
    logic [3:0] sw;
    logic [3:0] led;
    logic [3:0] expected;
    twos_comp4 dut (
        .sw (sw),
        .led(led)
    );

    initial begin
        // Recorre todos los valores posibles de 4 bits
        sw = 0;
        expected = 0;
        for (int i = 0; i < 16; i++) begin
            sw = $unsigned(i[3:0]);
            expected = (~sw) + 4'd1; // o expected = -sw;
            #1;
            
            if (led !== expected) begin
                $error("FALLO: sw=%0d (0x%0h) -> led=0x%0h, esperado=0x%0h",
                       sw, sw, led, expected);
                $finish;
            end
        end

        $display("OK: todas las combinaciones pasaron.");
        $finish;
    end
endmodule
