`timescale 1ns/1ps
module tb_accumulator;
    parameter N=4;
    localparam BYTES=N*N, BITS=BYTES*8;
    logic clk=0,reset=1,rx_ready=0,fifo_ready=0;
    logic [7:0] rx_data=0;
    wire push_A,push_B;
    wire [BITS-1:0] matrix_A_out,matrix_B_out;
    always #5 clk=~clk;
    matrix_accumulator #(.BYTES_PER_MATRIX(BYTES)) dut(.*);
    task automatic send(input byte unsigned value);
        @(negedge clk);rx_data=value;rx_ready=1;
        @(negedge clk);rx_ready=0;
    endtask
    initial begin
        repeat(4) @(negedge clk);reset=0;
        for(int which=0;which<2;which++) begin
            fifo_ready=0;
            send(which ? 8'h42 : 8'h41);
            for(int k=0;k<BYTES;k++) send((k+which)&255);
            repeat(4) begin
                @(negedge clk);
                if(push_A || push_B) $fatal(1,"Pushed into blocked FIFO");
            end
            fifo_ready=1;
            @(negedge clk);
            if(which ? !push_B : !push_A) $fatal(1,"Pending matrix was lost");
            for(int k=0;k<BYTES;k++)
                if(which ? matrix_B_out[k*8+:8]!==((k+which)&255) : matrix_A_out[k*8+:8]!==((k+which)&255))
                    $fatal(1,"Pending matrix corrupted index %0d",k);
            @(negedge clk);
            if(push_A || push_B) $fatal(1,"Duplicate push");
        end
        $display("RESULT: PASS accumulator N=%0d",N);$finish;
    end
    initial begin #200000; $fatal(1,"Accumulator timeout"); end
endmodule
