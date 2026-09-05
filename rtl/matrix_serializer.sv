`timescale 1ns / 1ps

module matrix_serializer #(
    parameter N = 4,
    parameter WIDTH = 8
)(
    input  logic clk,
    input  logic reset,
    
    // Inputs from Systolic Top
    input  logic [WIDTH-1:0] C_out [N-1:0][N-1:0],
    input  logic output_valid,
    
    // Interface to standard UART TX
    input  logic tx_busy,
    output logic [7:0] tx_data,
    output logic tx_start
);

    typedef enum logic [1:0] {IDLE, LATCH, SEND, WAIT_TX} state_t;
    state_t state;

    // Flattened buffer to hold the 16 bytes
    logic [WIDTH-1:0] data_buffer [0:(N*N)-1];
    logic [$clog2(N*N):0] byte_index;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_start <= 1'b0;
            tx_data <= '0;
            byte_index <= '0;
        end else begin
            tx_start <= 1'b0; // Default to 0, pulse when needed

            case (state)
                IDLE: begin
                    byte_index <= '0;
                    if (output_valid) begin
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    // Flatten the 2D array into a 1D buffer so it's easy to iterate over.
                    // We send Row 0 first, then Row 1, etc.
                    for (int i = 0; i < N; i++) begin
                        for (int j = 0; j < N; j++) begin
                            data_buffer[(i*N) + j] <= C_out[i][j];
                        end
                    end
                    state <= SEND;
                end
                
                SEND: begin
                    // Check if the UART line is free
                    if (!tx_busy) begin
                        tx_data <= data_buffer[byte_index];
                        tx_start <= 1'b1; // Trigger the UART
                        state <= WAIT_TX;
                    end
                end
                
                WAIT_TX: begin
                    // Wait for tx_busy to go high (acknowledging the start), 
                    // then wait for it to go low (signaling completion)
                    if (!tx_busy && !tx_start) begin
                        // Transmission of one byte is done
                        if (byte_index == (N*N - 1)) begin
                            // All 16 bytes sent!
                            state <= IDLE;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state <= SEND;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule