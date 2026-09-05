`timescale 1ns / 1ps

module GF_multiplier #(
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] POLY = 8'h1B
)(
    input logic [WIDTH-1:0] A,
    input logic [WIDTH-1:0] B,
    output logic [WIDTH-1:0] C
);

logic [WIDTH-1:0] A_shifted[WIDTH-1:0];
logic [WIDTH-1:0] partial_product [WIDTH-1:0];

assign A_shifted[0] = A;

genvar i;
generate
    for (i=0; i<WIDTH-1; i++)begin
        shift_reduce #(
            .WIDTH(WIDTH),
            .POLY(POLY)
        ) sr_inst(
            .A(A_shifted[i]),
            .A_shifted(A_shifted[i+1])
        );
    end
endgenerate

genvar j;
generate
    for(j = 0; j <WIDTH; j++)begin
        assign partial_product[j] = (B[j]== 1'b1)? A_shifted[j]: {WIDTH{1'b0}};
    end
endgenerate

always_comb begin
    C = partial_product[0];
    for(int k = 1; k < WIDTH; k++)begin
        C = C ^ partial_product[k];
    end
end
endmodule