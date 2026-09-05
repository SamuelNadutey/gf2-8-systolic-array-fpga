`timescale 1ns / 1ps

// Processing Element (PE) for the output-stationary systolic array.
// Performs GF(2^8) multiply-accumulate: C_result ^= A_in * B_in.
// clear: zeroes the accumulator before a new operation.
// en:    gates accumulation during the active shift phase.

module PE #(
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] POLY = 8'h1B
)(
    input clk, reset,
    input logic clear,
    input logic en,
    input logic [WIDTH-1:0] A_in,
    input logic [WIDTH-1:0] B_in,
    output logic[WIDTH-1:0] A_out,
    output logic [WIDTH-1:0] B_out,
    output logic [WIDTH-1:0] C_result
);

logic [WIDTH-1:0] product;

GF_multiplier #(
    .WIDTH(WIDTH),
    .POLY(POLY)
) multiplier_inst(
    .A(A_in),
    .B(B_in),
    .C(product)
);

always_ff@(posedge clk or posedge reset)begin
    if (reset)begin
        A_out <= '0;
        B_out <= '0;
        C_result <= '0;
    end else begin
        A_out <= A_in;
        B_out <= B_in;

        if (clear)
            C_result <= '0;
        else if (en)
            C_result <= C_result ^ product;
    end
end

endmodule
