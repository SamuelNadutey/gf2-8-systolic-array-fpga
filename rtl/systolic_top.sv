`timescale 1ns / 1ps

// Top-level systolic array controller.
// FSM: IDLE -> POP_WAIT -> LOAD -> SHIFT (3N-2 cycles) -> DRAIN -> IDLE
// Accumulators are cleared during LOAD; output_valid asserts in DRAIN
// after all PEs have settled.

module systolic_top #(
    parameter N = 4,
    parameter WIDTH = 8,
    parameter [WIDTH-1:0] POLY = 8'h1B,
    parameter FIFO_ADDR_WIDTH = 2,              // was hardcoded 8 (depth 256); MUST be >= 2 (see header)
    parameter MATRIX_BITS = N * N * WIDTH,
    parameter shifter_width = WIDTH * (2*N - 1)
)(
    input  logic clk,
    input  logic reset,

    input  logic push_A,
    input  logic push_B,
    input  logic [MATRIX_BITS-1:0] matrix_A_in,
    input  logic [MATRIX_BITS-1:0] matrix_B_in,

    output logic ready,
    input logic result_ready = 1'b1,

    output logic [WIDTH-1:0] C_out [N-1:0][N-1:0],
    output logic output_valid
);

    initial begin
        if (N < 2 || WIDTH != 8 || FIFO_ADDR_WIDTH < 2)
            $fatal(1, "Core requires N>=2, WIDTH=8, FIFO_ADDR_WIDTH>=2");
    end
    logic pop_A, pop_B;
    logic empty_A, empty_B;
    logic full_A, full_B;
    logic [MATRIX_BITS-1:0] fifo_A_out, fifo_B_out;

    logic load_enable, shift_enable;
    logic clear_acc, accumulate_en;

    logic [shifter_width-1:0] A_row_padded [N-1:0];
    logic [shifter_width-1:0] B_row_padded [N-1:0];
    logic [WIDTH-1:0] skewed_A [N-1:0];
    logic [WIDTH-1:0] skewed_B [N-1:0];

    localparam MAX_SHIFTS = (3*N - 2);
    logic [$clog2(MAX_SHIFTS):0] shift_count;

    typedef enum logic [2:0] {IDLE, POP_WAIT, LOAD, SHIFT, DRAIN} state_t;
    state_t current_state, next_state;

    sync_fifo #( .DATA_WIDTH(MATRIX_BITS), .ADDR_WIDTH(FIFO_ADDR_WIDTH) ) fifo_A (
        .clk(clk), .reset(reset),
        .push(push_A), .data_in(matrix_A_in), .full(full_A),
        .pop(pop_A),   .data_out(fifo_A_out), .empty(empty_A)
    );

    sync_fifo #( .DATA_WIDTH(MATRIX_BITS), .ADDR_WIDTH(FIFO_ADDR_WIDTH) ) fifo_B (
        .clk(clk), .reset(reset),
        .push(push_B), .data_in(matrix_B_in), .full(full_B),
        .pop(pop_B),   .data_out(fifo_B_out), .empty(empty_B)
    );

    // Matrix A is packed row-major; matrix B MUST be packed column-major (see F9).
    always_comb begin
        for (int i = 0; i < N; i++) begin
            A_row_padded[i] = fifo_A_out[i * (N*WIDTH) +: (N*WIDTH)];
            B_row_padded[i] = fifo_B_out[i * (N*WIDTH) +: (N*WIDTH)];
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            current_state <= IDLE;
            shift_count   <= '0;
        end else begin
            current_state <= next_state;

            if (current_state == SHIFT)
                shift_count <= shift_count + 1'b1;
            else
                shift_count <= '0;
        end
    end

    always_comb begin
        load_enable   = 0;
        shift_enable  = 0;
        pop_A         = 0;
        pop_B         = 0;
        output_valid  = 0;
        clear_acc     = 0;
        accumulate_en = 0;
        next_state    = current_state;

        case (current_state)
            IDLE: begin
                if (!empty_A && !empty_B) begin
                    pop_A = 1;
                    pop_B = 1;
                    next_state = POP_WAIT;
                end
            end

            POP_WAIT: begin
                next_state = LOAD;
            end

            // Latch operands into the skew shift registers and, at the same
            // edge, zero every accumulator so this operation starts clean (F1).
            LOAD: begin
                load_enable  = 1;
                shift_enable = 0;
                clear_acc    = 1;
                next_state   = SHIFT;
            end

            SHIFT: begin
                load_enable   = 0;
                shift_enable  = 1;
                accumulate_en = 1;

                if (shift_count == (MAX_SHIFTS - 1))
                    next_state = DRAIN;
                else
                    next_state = SHIFT;
            end

            // The deepest PE registers its final product on the edge that ends
            // the last SHIFT cycle, so C_out is only stable here (F2).
            DRAIN: begin
                output_valid = 1;
                if (result_ready) next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    assign ready = (!full_A && !full_B);

    skew_logic #(
        .N(N), .WIDTH(WIDTH), .shifter_width(shifter_width)
    ) skew_unit (
        .clk(clk), .reset(reset),
        .load_enable(load_enable), .shift_enable(shift_enable),
        .A_row(A_row_padded), .B_row(B_row_padded),
        .skewed_A(skewed_A), .skewed_B(skewed_B)
    );

    Systolic_array #(
        .N(N), .WIDTH(WIDTH), .POLY(POLY)
    ) array_unit (
        .clk(clk), .reset(reset),
        .clear(clear_acc), .en(accumulate_en),
        .A(skewed_A), .B(skewed_B), .C(C_out)
    );

endmodule
