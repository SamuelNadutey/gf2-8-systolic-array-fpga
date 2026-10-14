`timescale 1ns / 1ps
// End-to-end UART regression: three different operations without reset.
module tb_fpga_top;
    parameter N = 4;
    parameter CLKS_PER_BIT = 16;
    localparam COUNT = 3;
    logic clk = 0, reset = 1, uart_rx_pin = 1;
    wire uart_tx_pin, led_ready, led_busy;
    always #5 clk = ~clk;
    fpga_top #(.N(N), .CLKS_PER_BIT(CLKS_PER_BIT)) dut (.*,.clk_100mhz(clk),.reset_btn(reset));
    byte unsigned gold_A [0:COUNT*N*N-1];
    byte unsigned gold_B [0:COUNT*N*N-1];
    byte unsigned gold_C [0:COUNT*N*N-1];
    integer received = 0;
    byte unsigned observed;
    task automatic send_byte(input byte unsigned data);
        @(negedge clk); uart_rx_pin = 0;
        repeat(CLKS_PER_BIT) @(negedge clk);
        for(int b=0;b<8;b++) begin
            uart_rx_pin=data[b]; repeat(CLKS_PER_BIT) @(negedge clk);
        end
        uart_rx_pin=1; repeat(CLKS_PER_BIT) @(negedge clk);
    endtask
    initial begin
        $readmemh($sformatf("golden_vectors/A_n%0d_tb.hex",N),gold_A);
        $readmemh($sformatf("golden_vectors/B_n%0d_tb.hex",N),gold_B);
        $readmemh($sformatf("golden_vectors/C_n%0d_tb.hex",N),gold_C);
        repeat(20) @(negedge clk); reset=0;
        for(int v=0;v<COUNT;v++) begin
            send_byte(8'h41);
            for(int i=0;i<N*N;i++) send_byte(gold_A[v*N*N+i]);
            send_byte(8'h42);
            for(int j=0;j<N;j++)
                for(int k=0;k<N;k++) send_byte(gold_B[v*N*N+k*N+j]);
        end
        wait(received==COUNT*N*N);
        repeat(CLKS_PER_BIT*12) @(negedge clk);
        $display("RESULT: PASS UART N=%0d matrices=%0d elements=%0d",N,COUNT,received);
        $finish;
    end
    initial begin
        wait(!reset);
        forever begin
            @(negedge uart_tx_pin);
            repeat(CLKS_PER_BIT+CLKS_PER_BIT/2) @(negedge clk);
            for(int b=0;b<8;b++) begin
                observed[b]=uart_tx_pin; repeat(CLKS_PER_BIT) @(negedge clk);
            end
            if(uart_tx_pin!==1) $fatal(1,"UART invalid stop bit");
            if(received>=COUNT*N*N) $fatal(1,"Extra UART result byte");
            if(observed!==gold_C[received])
                $fatal(1,"UART N=%0d index=%0d got=%02x expected=%02x",N,received,observed,gold_C[received]);
            received++;
        end
    end
    initial begin
        #20000000; $fatal(1,"UART timeout N=%0d received=%0d",N,received);
    end
endmodule
