module top (
    input  logic [15:0] SW,
    output logic [15:0] LED
);

    // Solo usamos los primeros 4
    twos_comp4 u0 (
        .sw (SW[3:0]),
        .led(LED[3:0])
    );

    // Apagamos los LEDs que no usamos
    assign LED[15:4] = 12'b0;

endmodule
