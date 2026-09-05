`timescale 1ns / 1ps
// FPGA top-level: UART RX -> matrix_accumulator -> systolic_top -> matrix_serializer -> UART TX.
// Change N to scale the array (N=4, 8, 16). BYTES_PER_MATRIX and MATRIX_BITS follow automatically.
module fpga_top #(
    parameter N = 4,
    parameter WIDTH = 8,
    parameter BYTES_PER_MATRIX = 16,
    parameter MATRIX_BITS = 128
)(
    input  logic clk_100mhz,
    input  logic reset_btn,
    input  logic uart_rx_pin,
    output logic uart_tx_pin,
    output logic led_ready,
    output logic led_busy
);

    // --- Internal Routing Wires ---
    logic [7:0] rx_byte;
    logic rx_ready;

    logic push_A;
    logic push_B;
    logic [MATRIX_BITS-1:0] matrix_A_bus;
    logic [MATRIX_BITS-1:0] matrix_B_bus;
    logic system_ready;

    logic [WIDTH-1:0] C_out_matrix [N-1:0][N-1:0];
    logic output_valid;

    logic tx_start;
    logic [7:0] tx_byte;
    logic tx_busy;

    assign led_ready = system_ready;
    assign led_busy  = (!system_ready || tx_busy);

    // --- 1. UART Receiver ---
    uart_rx #(
        .CLKS_PER_BIT(868) // 100MHz / 115200 Baud
    ) rx_inst (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .rx(uart_rx_pin),
        .rx_data(rx_byte),
        .rx_ready(rx_ready)
    );

    // --- 2. Accumulator ---
    matrix_accumulator #(
        .BYTES_PER_MATRIX(BYTES_PER_MATRIX)
    ) accumulator_inst (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .rx_data(rx_byte),
        .rx_ready(rx_ready),
        .fifo_ready(system_ready),
        .push_A(push_A),
        .push_B(push_B),
        .matrix_A_out(matrix_A_bus),
        .matrix_B_out(matrix_B_bus)
    );

    // --- 3. Systolic Array & Memory ---
    systolic_top #(
        .N(N),
        .WIDTH(WIDTH)
    ) core_inst (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .push_A(push_A),
        .push_B(push_B),
        .matrix_A_in(matrix_A_bus),
        .matrix_B_in(matrix_B_bus),
        .ready(system_ready),
        .C_out(C_out_matrix),
        .output_valid(output_valid)
    );

    // --- 4. Serializer ---
    matrix_serializer #(
        .N(N),
        .WIDTH(WIDTH)
    ) serializer_inst (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .C_out(C_out_matrix),
        .output_valid(output_valid),
        .tx_busy(tx_busy),
        .tx_data(tx_byte),
        .tx_start(tx_start)
    );

    // --- 5. UART Transmitter ---
    uart_tx #(
        .CLKS_PER_BIT(868)
    ) tx_inst (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .tx_start(tx_start),
        .tx_data(tx_byte),
        .tx_busy(tx_busy),
        .tx(uart_tx_pin)
    );

endmodule
