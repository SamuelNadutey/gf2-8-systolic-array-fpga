`timescale 1ns / 1ps

// N x N output-stationary systolic array for GF(2^8) matrix multiplication.
// clear and en are broadcast to all PEs to zero accumulators between operations.

module Systolic_array #(
    parameter N = 4,
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] POLY = 8'h1B
)(
    input logic clk, reset,
    input logic clear,
    input logic en,
    input logic[WIDTH-1:0] A[N-1:0],
    input logic[WIDTH-1:0] B[N-1:0],
    output logic[WIDTH-1:0] C[N-1:0][N-1:0]
);

logic [WIDTH-1:0] A_wires[N-1:0][N:0];
logic [WIDTH-1:0] B_wires[N:0][N-1:0];

    genvar k;
    generate
        for (k = 0; k < N; k++) begin : input_map
            assign A_wires[k][0] = A[k];
            assign B_wires[0][k] = B[k];
        end
    endgenerate

    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : rows
            for (j = 0; j < N; j++) begin : cols
                PE #(
                    .WIDTH(WIDTH),
                    .POLY(POLY)
                ) pe_inst (
                    .clk      (clk),
                    .reset    (reset),
                    .clear    (clear),
                    .en       (en),
                    .A_in     (A_wires[i][j]),
                    .A_out    (A_wires[i][j+1]),
                    .B_in     (B_wires[i][j]),
                    .B_out    (B_wires[i+1][j]),
                    .C_result (C[i][j])
                );
            end
        end
    endgenerate

endmodule
