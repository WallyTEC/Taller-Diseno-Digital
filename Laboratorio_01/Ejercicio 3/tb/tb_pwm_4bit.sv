module tb_pwm_4bit;

    // ================================
    // Parámetros SOLO para simulación
    // ================================

    // Reloj de 100 MHz (10 ns)
    localparam int unsigned CLK_HZ = 100_000_000;

    // PWM mucho más rápido para poder verlo en ns
    // 1 MHz en vez de 1 kHz
    // Eso da periodo = 1 us (mucho más visible)
    localparam int unsigned PWM_HZ = 1_000_000;

    localparam int unsigned PERIOD_CYCLES = CLK_HZ / PWM_HZ;

    logic clk;
    logic rst;
    logic [3:0] duty_code;
    logic pwm_out;

    // ================================
    // Instancia del DUT
    // ================================
    pwm_4bit #(
        .CLK_HZ(CLK_HZ),
        .PWM_HZ(PWM_HZ)  // 👈 Solo cambiamos esto para simular
    ) dut (
        .clk(clk),
        .rst(rst),
        .duty_code(duty_code),
        .pwm_out(pwm_out)
    );

    // ================================
    // Generación de reloj 100 MHz
    // ================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================================
    // Test simple visual
    // ================================
    initial begin
        rst = 1;
        duty_code = 0;

        repeat (5) @(posedge clk);
        rst = 0;

        // Probar varios valores visibles
        duty_code = 4'd0;   #5_000;
        duty_code = 4'd4;   #5_000;
        duty_code = 4'd8;   #5_000;
        duty_code = 4'd12;  #5_000;
        duty_code = 4'd15;  #5_000;

        $finish;
    end

endmodule
