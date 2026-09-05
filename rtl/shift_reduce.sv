`timescale 1ns / 1ps

module shift_reduce #(
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] POLY = 8'h1B
)(
    input logic[WIDTH-1:0] A,
    output logic[WIDTH-1:0] A_shifted
);

assign A_shifted = (A[WIDTH-1] == 1'b0)? A<<1: ((A<<1) ^ POLY);

endmodule