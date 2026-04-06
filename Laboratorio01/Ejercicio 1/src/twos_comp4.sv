module twos_comp4 (
    input  logic [3:0] sw,
    output logic [3:0] led
);
    // Complemento a 2: -sw (en 4 bits) == (~sw + 1)
    always_comb begin
        led = (~sw) + 4'd1;
        // Alternativa equivalente: led = -sw;
    end
endmodule
