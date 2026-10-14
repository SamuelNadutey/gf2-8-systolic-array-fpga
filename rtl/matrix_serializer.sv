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
    output logic result_ready,
    
    // Interface to standard UART TX
    input  logic tx_busy,
    output logic [7:0] tx_data,
    output logic tx_start
);

    typedef enum logic [1:0] {IDLE, SEND, WAIT_TX} state_t;
    state_t state;
    assign result_ready = (state == IDLE);

    // Flattened buffer to hold N*N bytes
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
                        for (int i = 0; i < N; i++)
                            for (int j = 0; j < N; j++)
                                data_buffer[i*N+j] <= C_out[i][j];
                        state <= SEND;
                    end
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
                            // All N*N bytes sent!
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