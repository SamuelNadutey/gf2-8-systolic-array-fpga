`timescale 1ns / 1ps

// Self-checking testbench for systolic_top.
// Reads golden vectors from gf_reference_model.py and runs NUM_VECTORS
// back-to-back multiplications without reset, verifying every element.

module tb_systolic_selfcheck;

    parameter N = 4;
    parameter WIDTH = 8;
    parameter MATRIX_BITS = N * N * WIDTH;
    parameter NUM_VECTORS = 100;
    // Absolute path with FORWARD slashes ('\' is a string escape in SystemVerilog).
    // Vivado/XSim accepts forward slashes on Windows.
    parameter string GOLDEN_DIR = "C:/Users/samue/OneDrive/Desktop/LASTDANCE/REVIEW_2026-07-17/python_model/golden_vectors";

    logic clk, reset;
    logic push_A, push_B;
    logic [MATRIX_BITS-1:0] tb_A_data, tb_B_data;
    logic ready, output_valid;
    logic [WIDTH-1:0] C_out [N-1:0][N-1:0];

    systolic_top #( .N(N), .WIDTH(WIDTH) ) dut (
        .clk(clk), .reset(reset),
        .push_A(push_A), .push_B(push_B),
        .matrix_A_in(tb_A_data), .matrix_B_in(tb_B_data),
        .ready(ready), .C_out(C_out), .output_valid(output_valid)
    );

    always #5 clk = ~clk;

    // Golden data as FLAT 1-D arrays. $readmemh is reliable into a 1-D memory;
    // loading into a 2-D unpacked array is tool-dependent and Vivado XSim often
    // leaves it as X. Index element (v, idx) as gold_X[v*N*N + idx].
    logic [WIDTH-1:0] gold_A [0:NUM_VECTORS*N*N-1];
    logic [WIDTH-1:0] gold_B [0:NUM_VECTORS*N*N-1];
    logic [WIDTH-1:0] gold_C [0:NUM_VECTORS*N*N-1];

    int errors = 0;
    int checked = 0;

    // Pack A row-major. Byte k of the stream sits at bits [8k +: 8], matching
    // matrix_accumulator's downward shift.
    function automatic logic [MATRIX_BITS-1:0] pack_A(input int v);
        logic [MATRIX_BITS-1:0] r;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++)
                r[((i*N)+j)*WIDTH +: WIDTH] = gold_A[v*N*N + (i*N)+j];
        return r;
    endfunction

    // Pack B COLUMN-major - the array feeds bus chunk i into array column i,
    // so B must be transposed on the way in (F9).
    function automatic logic [MATRIX_BITS-1:0] pack_B(input int v);
        logic [MATRIX_BITS-1:0] r;
        for (int j = 0; j < N; j++)
            for (int k = 0; k < N; k++)
                r[((j*N)+k)*WIDTH +: WIDTH] = gold_B[v*N*N + (k*N)+j];
        return r;
    endfunction

    task automatic run_vector(input int v);
        wait (ready == 1'b1);
        @(posedge clk);
        tb_A_data = pack_A(v);
        tb_B_data = pack_B(v);
        push_A = 1;
        push_B = 1;
        @(posedge clk);
        push_A = 0;
        push_B = 0;

        wait (output_valid == 1'b1);
        // Sample on the NEXT edge. If output_valid is asserted a cycle early
        // (F2) this still reads the settled value, so a mismatch here is a real
        // arithmetic or accumulator error rather than a sampling artefact.
        @(posedge clk);

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                checked++;
                if (C_out[i][j] !== gold_C[v*N*N + (i*N)+j]) begin
                    errors++;
                    $error("vector %0d: C[%0d][%0d] = 0x%02x, expected 0x%02x",
                           v, i, j, C_out[i][j], gold_C[v*N*N + (i*N)+j]);
                end
            end
        end
    endtask

    initial begin
        clk = 0; reset = 1; push_A = 0; push_B = 0;
        tb_A_data = '0; tb_B_data = '0;

        // Filenames follow N, so changing the N parameter switches size
        // (golden vectors exist for N = 4, 8, 16).
        $readmemh({GOLDEN_DIR, $sformatf("/A_n%0d_tb.hex", N)}, gold_A);
        $readmemh({GOLDEN_DIR, $sformatf("/B_n%0d_tb.hex", N)}, gold_B);
        $readmemh({GOLDEN_DIR, $sformatf("/C_n%0d_tb.hex", N)}, gold_C);

        // Load check: if the vectors didn't load, gold_A[0] is X. Fail loudly
        // instead of silently propagating X through the whole design.
        if (^gold_A[0] === 1'bx) begin
            $display("FATAL: golden vectors not loaded. Check GOLDEN_DIR:");
            $display("       %s", GOLDEN_DIR);
            $display("       It must point at the folder CONTAINING A_n4_tb.hex etc.");
            $finish;
        end else begin
            $display("Golden vectors loaded. gold_A[0]=0x%02x gold_C[0]=0x%02x",
                     gold_A[0], gold_C[0]);
        end

        repeat (4) @(posedge clk);
        reset = 0;

        // Deliberately no reset between vectors: that is what exposes F1.
        for (int v = 0; v < NUM_VECTORS; v++)
            run_vector(v);

        $display("\n========================================");
        $display("  checked %0d elements across %0d vectors", checked, NUM_VECTORS);
        if (errors == 0)
            $display("  RESULT: PASS");
        else
            $display("  RESULT: FAIL - %0d mismatches", errors);
        $display("========================================\n");
        $finish;
    end

    initial begin
        #500000;
        $display("RESULT: FAIL - timeout");
        $finish;
    end

endmodule
