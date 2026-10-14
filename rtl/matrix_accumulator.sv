`timescale 1ns / 1ps
// UART byte accumulator. Receives 'A' + N*N bytes, then 'B' + N*N bytes,
// assembles them into MATRIX_BITS-wide buses, and pushes to the systolic FIFOs.
module matrix_accumulator #(
    parameter BYTES_PER_MATRIX = 16,
    parameter MATRIX_BITS      = BYTES_PER_MATRIX * 8
)(
    input  logic clk,
    input  logic reset,

    // Interface from UART RX
    input  logic [7:0] rx_data,
    input  logic rx_ready,

    // Status from systolic_top (ensure we don't push into a full FIFO)
    input  logic fifo_ready,

    // Outputs to systolic_top FIFOs
    output logic push_A,
    output logic push_B,
    output logic [MATRIX_BITS-1:0] matrix_A_out,
    output logic [MATRIX_BITS-1:0] matrix_B_out
);

    // Command Codes
    localparam CMD_LOAD_A = 8'h41;
    localparam CMD_LOAD_B = 8'h42;

    // Wide enough to hold the value BYTES_PER_MATRIX (with one bit of headroom)
    localparam int CNT_W = $clog2(BYTES_PER_MATRIX + 1);

    typedef enum logic [1:0] {WAIT_CMD, LOAD_A, LOAD_B, WAIT_PUSH} state_t;
    state_t state;

    logic [CNT_W-1:0] byte_count;
    logic [MATRIX_BITS-1:0] shift_buffer;
    logic pending_b;
    initial begin
        if (BYTES_PER_MATRIX < 2 || MATRIX_BITS != BYTES_PER_MATRIX*8)
            $fatal(1, "Inconsistent UART matrix dimensions");
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= WAIT_CMD;
            pending_b <= 0;
            byte_count <= '0;
            shift_buffer <= '0;
            push_A <= 0;
            push_B <= 0;
            matrix_A_out <= '0;
            matrix_B_out <= '0;
        end else begin
            // Default pulse states
            push_A <= 0;
            push_B <= 0;

            case (state)
                WAIT_CMD: begin
                    byte_count <= '0;
                    if (rx_ready) begin
                        if (rx_data == CMD_LOAD_A) state <= LOAD_A;
                        else if (rx_data == CMD_LOAD_B) state <= LOAD_B;
                    end
                end

                LOAD_A: begin
                    if (rx_ready) begin
                        // Shift old bytes DOWN, insert new byte at the TOP.
                        // The FIRST byte sent ends up at [7:0] (the bottom).
                        shift_buffer <= {rx_data, shift_buffer[MATRIX_BITS-1:8]};
                        byte_count <= byte_count + 1'b1;

                        // Last byte of the matrix?
                        if (byte_count == BYTES_PER_MATRIX - 1) begin
                            if (fifo_ready) begin
                                matrix_A_out <= {rx_data, shift_buffer[MATRIX_BITS-1:8]};
                                push_A <= 1;
                                state <= WAIT_CMD;
                            end else begin
                                pending_b <= 0;
                                state <= WAIT_PUSH;
                            end
                        end
                    end
                end

                LOAD_B: begin
                    if (rx_ready) begin
                        shift_buffer <= {rx_data, shift_buffer[MATRIX_BITS-1:8]};
                        byte_count <= byte_count + 1'b1;

                        if (byte_count == BYTES_PER_MATRIX - 1) begin
                            if (fifo_ready) begin
                                matrix_B_out <= {rx_data, shift_buffer[MATRIX_BITS-1:8]};
                                push_B <= 1;
                                state <= WAIT_CMD;
                            end else begin
                                pending_b <= 1;
                                state <= WAIT_PUSH;
                            end
                        end
                    end
                end

                WAIT_PUSH: begin
                    if (fifo_ready) begin
                        if (pending_b) begin
                            matrix_B_out <= shift_buffer; push_B <= 1;
                        end else begin
                            matrix_A_out <= shift_buffer; push_A <= 1;
                        end
                        state <= WAIT_CMD;
                    end
                end
                default: state <= WAIT_CMD;
            endcase
        end
    end
endmodule
