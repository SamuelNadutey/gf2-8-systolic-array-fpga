 module shifter #(
    parameter TOTAL_BITS = 56,
    parameter SHIFT_BITS = 8
)(
    input  logic clk,
    input  logic reset,        
    input  logic load_enable,
    input  logic shift_enable,
    input  logic [TOTAL_BITS-1:0] data_in,
    output logic [SHIFT_BITS-1:0] current_chunk
);

    logic [TOTAL_BITS-1:0] stored_data;

    assign current_chunk = stored_data[SHIFT_BITS-1:0];

    
    always_ff @(posedge clk) begin
        if (reset) begin
            stored_data <= '0;
        end
        else if (load_enable) begin
            stored_data <= data_in;
        end
        else if (shift_enable) begin
            stored_data <= stored_data >> SHIFT_BITS;
        end
    end

endmodule