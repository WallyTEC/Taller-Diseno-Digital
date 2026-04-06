module top (
    input logic CLK100MHZ,     // Reloj interno de la tarjeta
    input logic CPU_RESETN,    // Botón de reset (rojo)
    input logic [3:0] sw,      // Los primeros 4 switches
    output logic [0:0] led     // LED 0
);

    // La Nexys 4 DDR usa lógica negativa para el botón de reset (0 al presionar)
    logic rst;
    assign rst = ~CPU_RESETN;

    // Instancia del módulo PWM con el nombre de archivo solicitado
    pwm_4bit inst_pwm (
        .clk(CLK100MHZ),
        .rst(rst),
        .duty(sw),
        .pwm_out(led[0])
    );

endmodule
