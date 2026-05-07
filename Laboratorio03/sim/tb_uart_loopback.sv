// =============================================================================
// Archivo      : sim/tb_uart_loopback.sv
// Autor        : WallyCR
// Fecha        : 20 de abril de 2026
// Curso        : EL3313 - Taller de Diseño Digital (TEC, VII semestre)
// Descripción  : TB loopback TX -> RX con múltiples bytes.
//                Entre cada byte, espera explícitamente a que tx_busy=0
//                y agrega margen adicional para que el RX termine de
//                procesar el stop bit antes de iniciar el siguiente
//                envío. Polling plano (sin wait/fork).
// =============================================================================

`timescale 1ns/1ps

module tb_uart_loopback;

    localparam int CLK_FREQ = 50_000_000;
    localparam int BAUD     = 1_000_000;
    localparam int BIT_PER  = CLK_FREQ / BAUD;
    localparam int N_BYTES  = 8;

    logic clk = 0;
    always #10 clk = ~clk;

    logic       rst_n;
    logic       tx_tick;
    logic       line;
    logic       tx_busy, tx_done;
    logic [7:0] tx_data_r;
    logic       tx_start_r;
    logic       rx_byte_valid;
    logic [7:0] rx_byte;

    logic [7:0] sent_bytes [N_BYTES] = '{
        8'h5A, 8'hA5, 8'h00, 8'hFF,
        8'h01, 8'h80, 8'h55, 8'hAA
    };

    logic [7:0]   recv_bytes_r [N_BYTES];
    int unsigned  rx_count_r;

    uart_baud_gen #(.CLK_FREQ_HZ(CLK_FREQ), .BAUD_RATE(BAUD)) u_baud (
        .clk_i(clk), .rst_n_i(rst_n),
        .tx_tick_o(tx_tick)
    );

    uart_tx u_tx (
        .clk_i(clk), .rst_n_i(rst_n),
        .tx_tick_i(tx_tick),
        .start_i(tx_start_r), .data_i(tx_data_r),
        .busy_o(tx_busy), .done_o(tx_done),
        .tx_o(line)
    );

    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ), .BAUD_RATE(BAUD)) u_rx (
        .clk_i(clk), .rst_n_i(rst_n),
        .rx_i(line),
        .byte_valid_o(rx_byte_valid), .data_o(rx_byte)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rx_count_r <= 0;
            for (int i = 0; i < N_BYTES; i++) recv_bytes_r[i] <= '0;
        end else if (rx_byte_valid) begin
            if (rx_count_r < N_BYTES) recv_bytes_r[rx_count_r] <= rx_byte;
            rx_count_r <= rx_count_r + 1;
            $display("[t=%0t] RX[%0d] = 0x%02h", $time, rx_count_r, rx_byte);
        end
    end

    initial begin
        #3_000_000;
        $display("[FATAL] Timeout 3 ms");
        $fatal(1, "timeout");
    end

    initial begin
        int errors;
        int safety;
        rst_n      = 1'b0;
        tx_start_r = 1'b0;
        tx_data_r  = 8'h00;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);

        $display("==== tb_uart_loopback (baud=%0d, %0d bytes) ====", BAUD, N_BYTES);

        for (int i = 0; i < N_BYTES; i++) begin
            // Esperar a que el TX esté libre (debería estarlo ya)
            safety = 0;
            while (tx_busy && safety < 20 * BIT_PER) begin
                @(posedge clk);
                safety++;
            end
            if (safety >= 20 * BIT_PER) begin
                $display("[FAIL] TX nunca quedó libre antes de byte %0d", i);
                $finish(1);
            end

            // Disparar envío
            @(posedge clk);
            tx_data_r  <= sent_bytes[i];
            tx_start_r <= 1'b1;
            @(posedge clk);
            tx_start_r <= 1'b0;

            // Esperar a que el TX arranque (busy sube)
            safety = 0;
            while (!tx_busy && safety < 10) begin
                @(posedge clk);
                safety++;
            end

            // Esperar a que el TX termine (busy baja). Polling plano.
            safety = 0;
            while (tx_busy && safety < 15 * BIT_PER) begin
                @(posedge clk);
                safety++;
            end
            if (safety >= 15 * BIT_PER) begin
                $display("[FAIL] TX nunca terminó byte %0d", i);
                $finish(1);
            end

            // Margen para que el RX procese el stop bit completo y
            // vuelva a IDLE antes del próximo start. 3 bits es de sobra.
            repeat (3 * BIT_PER) @(posedge clk);
        end

        // Margen final por las dudas
        repeat (2 * BIT_PER) @(posedge clk);

        // Verificación
        errors = 0;
        $display("==== Verificación ====");
        if (rx_count_r != N_BYTES) begin
            $display("[FAIL] Recibí %0d bytes, esperaba %0d", rx_count_r, N_BYTES);
            errors++;
        end
        for (int i = 0; i < N_BYTES; i++) begin
            if (recv_bytes_r[i] == sent_bytes[i]) begin
                $display("[PASS] [%0d] enviado=0x%02h recibido=0x%02h",
                         i, sent_bytes[i], recv_bytes_r[i]);
            end else begin
                $display("[FAIL] [%0d] enviado=0x%02h recibido=0x%02h",
                         i, sent_bytes[i], recv_bytes_r[i]);
                errors++;
            end
        end

        $display("==== Resumen ====");
        $display("Total bytes: %0d · Errores: %0d", N_BYTES, errors);
        if (errors == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL");
        $finish(errors == 0 ? 0 : 1);
    end

endmodule : tb_uart_loopback

