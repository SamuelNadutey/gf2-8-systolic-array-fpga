`timescale 1ns / 1ps

module skew_logic #(
    parameter N = 4,
    parameter WIDTH = 8,
    parameter shifter_width = WIDTH * (2*N - 1)
)(
    input  logic clk, reset, load_enable, shift_enable,
    input  logic [shifter_width-1:0] A_row [N-1:0],
    input  logic [shifter_width-1:0] B_row [N-1:0],
    
    
    output logic [WIDTH-1:0] skewed_A [N-1:0],
    output logic [WIDTH-1:0] skewed_B [N-1:0]
);
    
    
    genvar i;
    
    // Skewing Matrix A rows
    generate
        for( i=0; i < N; i++)begin
            shifter #(
            .TOTAL_BITS(shifter_width),
            .SHIFT_BITS(WIDTH)) A_shifter(
                .clk,
                .reset,
                .load_enable,
                .shift_enable,
                .data_in(A_row[i] << (i * WIDTH)),
                .current_chunk(skewed_A[i])
            );
        end
    endgenerate
    
    // Skewing Matrix B columns
    generate
        for( i=0; i < N; i++)begin
            shifter #(
            .TOTAL_BITS(shifter_width),
            .SHIFT_BITS(WIDTH)) B_shifter(
                .clk,
                .reset,
                .load_enable,
                .shift_enable,
                .data_in(B_row[i] << (i * WIDTH)),
                .current_chunk(skewed_B[i])
            );
        end
    endgenerate
    

endmodule