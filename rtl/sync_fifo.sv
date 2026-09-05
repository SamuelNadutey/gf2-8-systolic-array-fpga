`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH = 128, // Default for 4x4 of 8-bit values
    parameter ADDR_WIDTH = 8    // Depth of 256
)(
    input  logic clk,
    input  logic reset,
    
    // Write interface
    input  logic push,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic full,
    
    // Read interface
    input  logic pop,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic empty
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0 : (1<<ADDR_WIDTH)-1];
    
    // Pointers
    logic [ADDR_WIDTH-1:0] head; // Write pointer
    logic [ADDR_WIDTH-1:0] tail; // Read pointer
    
    // Next head calculation for full flag (wrap-around handled naturally by bit width)
    wire [ADDR_WIDTH-1:0] next_head = head + 1'b1;
    
    assign empty = (head == tail);
    assign full  = (next_head == tail);

    // Write Logic
    always_ff @(posedge clk) begin
        if (push && !full) begin
            mem[head] <= data_in;
        end
    end

    // Read Logic
    always_ff @(posedge clk) begin
        if (pop && !empty) begin
            data_out <= mem[tail];
        end
    end

    // Pointer Management
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= '0;
            tail <= '0;
        end else begin
            if (push && !full)  head <= head + 1'b1;
            if (pop && !empty)  tail <= tail + 1'b1;
        end
    end

endmodule