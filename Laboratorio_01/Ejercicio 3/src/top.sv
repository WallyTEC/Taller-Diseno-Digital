module top (
    input  logic        CLK100MHZ,   // reloj principal de la tarjeta
    input  logic [15:0]  SW,          // switches físicos
    input  logic         BTNC,        // botón central (usado como reset)
    output logic [15:0]  LED          // LEDs físicos
);

    logic pwm_sig; // señal PWM interna

    // Instancia del módulo PWM
    pwm_4bit #(
        .CLK_HZ(100_000_000),
        .PWM_HZ(1_000)
    ) u_pwm (
        .clk      (CLK100MHZ), // conecta reloj de la tarjeta
        .rst      (BTNC),      // reset con el botón central
        .duty_code(SW[3:0]),   // usa los 4 switches como código duty
        .pwm_out  (pwm_sig)    // salida PWM
    );

    // LED[0] muestra el PWM
    assign LED[0] = pwm_sig;

    // el resto apagados
    assign LED[15:1] = '0;

endmodule
