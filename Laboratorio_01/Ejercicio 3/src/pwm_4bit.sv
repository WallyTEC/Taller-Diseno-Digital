module pwm_4bit #(
    parameter int unsigned CLK_HZ = 100_000_000,   // Frecuencia del reloj de FPGA (Hz). Ej: 100 MHz
    parameter int unsigned PWM_HZ = 1_000          // Frecuencia del PWM (Hz). 1000 Hz => periodo es 1 ms
)(
    input  logic        clk,        // Señal de reloj del FPGA
    input  logic        rst,        // Reset sincrónico: se evalúa en posedge clk
    input  logic [3:0]  duty_code,  // Código de 4 bits (0..15) para controlar el duty cycle
    output logic        pwm_out     // Salida PWM (1 o 0)
);

    // PERIOD_CYCLES = cuántos ciclos de reloj de la FPGA caben en UN periodo de PWM.
    // Ej: 100 MHz / 1 kHz = 100_000 ciclos por periodo (1 ms)
    localparam int unsigned PERIOD_CYCLES = CLK_HZ / PWM_HZ;

    // CNT_W = cantidad de bits necesarios del contador para contar hasta PERIOD_CYCLES-1.
    // $clog2(n) da los bits mínimos para representar n-1.
    // El if (?) evita casos raros cuando PERIOD_CYCLES es muy pequeño.
    localparam int unsigned CNT_W = (PERIOD_CYCLES <= 2) ? 2 : $clog2(PERIOD_CYCLES);

    // counter = contador que recorre un periodo: 0,1,2,...,PERIOD_CYCLES-1 y reinicia
    logic [CNT_W-1:0] counter;

    // threshold = el "umbral" que determina cuántos ciclos estará pwm_out en 1 dentro del periodo.
    // Tiene 1 bit extra (CNT_W:0) porque puede ser igual a PERIOD_CYCLES (caso 100%).
    logic [CNT_W:0]   threshold;

    // =========================
    // Cálculo combinacional del umbral (threshold)
    // =========================
    always_comb begin
        threshold = '0;  // Valor por defecto (evita latches)

        // Si duty_code=0 => 0% duty => siempre apagado
        if (duty_code == 4'd0) begin
            threshold = 0;
        end
        // Si duty_code=15 => 100% duty => siempre encendido
        else if (duty_code >= 4'd15) begin
            threshold = PERIOD_CYCLES;
        end
        // Para 1..14 => proporcional al periodo usando /15 para que 15 sea 100%
        else begin
            // threshold = floor(duty_code * PERIOD_CYCLES / 15)
            threshold = (duty_code * PERIOD_CYCLES) / 15;
        end
    end

    // =========================
    // Contador del periodo (secuencial con flip-flops)
    // =========================
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= '0;  // En reset, contador a 0
        end
        else begin
            // Si llegó al final del periodo, reinicia a 0
            if (counter == PERIOD_CYCLES-1) begin
                counter <= '0;
            end
            else begin
                counter <= counter + 1;  // Si no, incrementa
            end
        end
    end

    // =========================
    // Generación del PWM (comparación)
    // =========================
    always_comb begin
        pwm_out = 1'b0; // Valor por defecto (evita latches)

        // Caso especial: threshold=PERIOD_CYCLES => 100% duty => siempre 1
        if (threshold == PERIOD_CYCLES) begin
            pwm_out = 1'b1;
        end
        // Caso normal: pwm_out es 1 mientras counter<threshold
        else if (counter < threshold[CNT_W-1:0]) begin
            pwm_out = 1'b1;
        end
        // Si no, queda en 0 (tiempo apagado del PWM)
        else begin
            pwm_out = 1'b0;
        end
    end

endmodule
