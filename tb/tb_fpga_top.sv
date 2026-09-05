`timescale 1ns / 1ps
// Full-chain UART-level testbench for fpga_top.
// Drives UART bytes into the design (exactly like test_accelerator.py),
// captures the transmitted result, and compares against a golden reference.
module tb_fpga_top;

    localparam int CLKS_PER_BIT = 868;   // must match fpga_top's uart instances
    localparam int N = 4;

    logic clk = 0;
    logic reset;
    logic uart_rx_pin;      // PC -> FPGA  (we drive this)
    logic uart_tx_pin;      // FPGA -> PC  (we sample this)
    logic led_ready, led_busy;

    // 100 MHz
    always #5 clk = ~clk;

    fpga_top #(.N(N)) dut (
        .clk_100mhz (clk),
        .reset_btn  (reset),
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .led_ready  (led_ready),
        .led_busy   (led_busy)
    );

    // ---- exact bytes test_accelerator.py sends ----
    // A row-major
    byte unsigned A_bytes [0:15] = '{
        8'h06,8'h09,8'h02,8'h01, 8'h03,8'h04,8'h06,8'h02,
        8'h07,8'h03,8'h01,8'h05, 8'h02,8'h02,8'h00,8'h01};
    // B column-major
    byte unsigned B_bytes [0:15] = '{
        8'h07,8'h02,8'h09,8'h02, 8'h00,8'h04,8'h03,8'h01,
        8'h06,8'h01,8'h06,8'h03, 8'h02,8'h06,8'h02,8'h01};
    // golden C row-major (16 35 18 63 / 51 24 28 16 / 16 10 24 3 / 8 9 13 9)
    byte unsigned C_gold [0:15] = '{
        8'h10,8'h23,8'h12,8'h3f, 8'h33,8'h18,8'h1c,8'h10,
        8'h10,8'h0a,8'h18,8'h03, 8'h08,8'h09,8'h0d,8'h09};

    byte unsigned C_hw [0:15];

    // ---- UART transmit task (drive uart_rx_pin) ----
    task automatic send_byte(input byte unsigned data);
        int i;
        begin
            // start bit
            uart_rx_pin = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            // 8 data bits, LSB first
            for (i = 0; i < 8; i++) begin
                uart_rx_pin = data[i];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            // stop bit
            uart_rx_pin = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    // ---- UART receive task (sample uart_tx_pin) ----
    task automatic recv_byte(output byte unsigned data);
        int i;
        begin
            @(negedge uart_tx_pin);                       // start bit
            repeat (CLKS_PER_BIT + CLKS_PER_BIT/2) @(posedge clk); // to middle of bit0
            for (i = 0; i < 8; i++) begin
                data[i] = uart_tx_pin;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            // (stop bit ignored)
        end
    endtask

    // ---- receiver process: collect 16 bytes ----
    int rx_n = 0;
    initial begin
        byte unsigned b;
        forever begin
            recv_byte(b);
            if (rx_n < 16) C_hw[rx_n] = b;
            rx_n++;
        end
    end

    // ---- stimulus ----
    int k, errors;
    initial begin
        uart_rx_pin = 1'b1;   // UART idles high
        reset = 1'b1;
        repeat (20) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);

        $display("[TB] sending 'A' + 16 bytes ...");
        send_byte(8'h41);                 // 'A'
        for (k = 0; k < 16; k++) send_byte(A_bytes[k]);

        $display("[TB] sending 'B' + 16 bytes ...");
        send_byte(8'h42);                 // 'B'
        for (k = 0; k < 16; k++) send_byte(B_bytes[k]);

        $display("[TB] waiting for 16 result bytes ...");
        wait (rx_n >= 16);
        repeat (100) @(posedge clk);

        $display("\n--- Hardware C vs Golden ---");
        errors = 0;
        for (k = 0; k < 16; k++) begin
            if (k % 4 == 0) $write("  ");
            $write("%3d ", C_hw[k]);
            if (C_hw[k] !== C_gold[k]) errors++;
            if (k % 4 == 3) $write("\n");
        end
        $display("  golden: 16 35 18 63 / 51 24 28 16 / 16 10 24 3 / 8 9 13 9");
        if (errors == 0) $display("\n  RESULT: PASS  (RTL is correct -> board problem is physical)\n");
        else             $display("\n  RESULT: FAIL - %0d/16 wrong (bug is in the integrated RTL)\n", errors);
        $finish;
    end

    // safety timeout
    initial begin
        #6000000;  // 6 ms
        $display("\n[TB] TIMEOUT after 6 ms. Received %0d bytes so far.", rx_n);
        for (int i = 0; i < rx_n && i < 16; i++) $write("%3d ", C_hw[i]);
        $display("\n  -> design hangs / never transmits. led_ready=%b led_busy=%b", led_ready, led_busy);
        $finish;
    end

endmodule
