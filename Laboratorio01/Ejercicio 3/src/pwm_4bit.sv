module pwm_4bit (
    input logic clk,           // Reloj de 100MHz
    input logic rst,           // Reset
    input logic [3:0] duty,    // Entrada de 4 bits (switches)
    output logic pwm_out       // Salida al LED
);

    // Para un periodo de 1ms a 100MHz: 100,000 ciclos de reloj totales.
    // Como tenemos 16 niveles (4 bits), cada nivel dura 100,000 / 16 = 6250 ciclos.
    
    integer counter;           // Contador para el tiempo de cada nivel
    logic [3:0] level_counter; // Contador de niveles (0 a 15)

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            level_counter <= 0;
        end else begin
            if (counter >= 6249) begin 
                counter <= 0;
                level_counter <= level_counter + 1;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // Si el contador de niveles es menor al valor de los switches, el LED se enciende
    assign pwm_out = (level_counter < duty) ? 1'b1 : 1'b0;

endmodule
