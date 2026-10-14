`timescale 1ns/1ps
// Burst three matrix pairs into the core while UART serializes earlier results.
module tb_result_pipeline;
    parameter N=4;
    localparam COUNT=3, CLKS_PER_BIT=16, MATRIX_BITS=N*N*8;
    logic clk=0, reset=1, push_A=0, push_B=0;
    logic [MATRIX_BITS-1:0] matrix_A_in='0, matrix_B_in='0;
    wire ready, output_valid, result_ready, tx_start, tx_busy, tx;
    wire [7:0] tx_data;
    wire [7:0] C_out [N-1:0][N-1:0];
    byte unsigned a[0:COUNT*N*N-1], b[0:COUNT*N*N-1], c[0:COUNT*N*N-1];
    integer received=0;
    byte unsigned observed;
    always #5 clk=~clk;
    systolic_top #(.N(N)) core(.*);
    matrix_serializer #(.N(N)) serializer(.*);
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) transmitter(.*);
    initial begin
        $readmemh($sformatf("golden_vectors/A_n%0d_tb.hex",N),a);
        $readmemh($sformatf("golden_vectors/B_n%0d_tb.hex",N),b);
        $readmemh($sformatf("golden_vectors/C_n%0d_tb.hex",N),c);
        repeat(5) @(negedge clk); reset=0;
        for(int v=0;v<COUNT;v++) begin
            wait(ready); @(negedge clk);
            for(int i=0;i<N;i++) for(int j=0;j<N;j++) begin
                matrix_A_in[(i*N+j)*8+:8]=a[v*N*N+i*N+j];
                matrix_B_in[(j*N+i)*8+:8]=b[v*N*N+i*N+j];
            end
            push_A=1;push_B=1;
            @(negedge clk);push_A=0;push_B=0;
        end
        wait(received==COUNT*N*N);
        $display("RESULT: PASS pipeline N=%0d elements=%0d",N,received);
        $finish;
    end
    initial begin
        wait(!reset);
        forever begin
            @(negedge tx); repeat(CLKS_PER_BIT+CLKS_PER_BIT/2) @(negedge clk);
            for(int bitnum=0;bitnum<8;bitnum++) begin
                observed[bitnum]=tx; repeat(CLKS_PER_BIT) @(negedge clk);
            end
            if(observed!==c[received]) $fatal(1,"Pipeline lost or corrupted result at %0d",received);
            received++;
        end
    end
    initial begin #20000000; $fatal(1,"Pipeline timeout"); end
endmodule
