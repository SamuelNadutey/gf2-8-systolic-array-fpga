# Scalable Systolic Array Matrix Multiplier over GF(2⁸) on FPGA

A parameterizable **output-stationary 2D systolic array** that performs matrix multiplication in the Galois field GF(2⁸) with the AES irreducible polynomial (*x⁸ + x⁴ + x³ + x + 1*). Designed in SystemVerilog, validated on a **Xilinx Artix-7 FPGA** (Basys 3 / Nexys A7) at array sizes N = 4, 8, and 16.

> **Capstone Project** — BSc Computer Engineering, Kwame Nkrumah University of Science and Technology (KNUST), 2025–2027.

---

## Key Results

| Metric | N = 4 | N = 8 | N = 16 |
|--------|------:|------:|-------:|
| LUTs | 1,134 | 3,681 | 14,478 |
| Flip-Flops | 1,537 | 5,028 | 20,215 |
| BRAM (36 Kb) | 0 | 15 | 57 |
| DSP48E1 | 0 | 0 | 0 |
| F_max (MHz) | 168 | 115 | 118 |
| Board Clock | 100 MHz | 100 MHz | 100 MHz |
| Compute Latency | 130 ns | 370 ns | 1.46 µs |
| Throughput | 492 MMAC/s | 3.94 GMAC/s | 28.1 GMAC/s |
| Power | 78 mW | — | — |

All three sizes **validated on real hardware** via UART, producing correct GF(2⁸) results verified against a Python golden model.

---

## Architecture

```
  ┌─────────────────────────────────────────────────────────┐
  │                       fpga_top                          │
  │                                                         │
  │  UART RX ─► matrix_accumulator ─► systolic_top ─────┐  │
  │  (115200)    (byte → matrix)      │                  │  │
  │                                   ▼                  │  │
  │                            ┌─────────────┐           │  │
  │                            │ sync_fifo A │           │  │
  │                            │ sync_fifo B │           │  │
  │                            └──────┬──────┘           │  │
  │                                   ▼                  │  │
  │                            ┌─────────────┐           │  │
  │                            │ skew_logic  │           │  │
  │                            │ (row/col    │           │  │
  │                            │  skew nets) │           │  │
  │                            └──────┬──────┘           │  │
  │                                   ▼                  │  │
  │                     ┌───────────────────────┐        │  │
  │                     │   Systolic_array NxN  │        │  │
  │                     │                       │        │  │
  │                     │  PE──PE──PE──PE  ───►  │        │  │
  │                     │  │   │   │   │        │        │  │
  │                     │  PE──PE──PE──PE        │        │  │
  │                     │  │   │   │   │        │        │  │
  │                     │  PE──PE──PE──PE        │        │  │
  │                     │  │   │   │   │        │        │  │
  │                     │  PE──PE──PE──PE  ▼     │        │  │
  │                     └───────────────────────┘        │  │
  │                                   │                  │  │
  │                                   ▼                  │  │
  │                          matrix_serializer ──► UART TX │
  │                          (matrix → bytes)    (115200)  │
  └─────────────────────────────────────────────────────────┘
```

### How it works

1. **Host sends** command byte `'A'` (0x41) followed by N² data bytes (matrix A, row-major), then `'B'` (0x42) followed by N² bytes (matrix B, column-major).
2. **matrix_accumulator** shifts bytes into a wide register and pushes complete matrices into the input FIFOs.
3. **systolic_top FSM** pops both matrices, loads the skew shift registers, clears all PE accumulators, then shifts for 3N−2 cycles.
4. Each **PE** computes `C ^= A_in * B_in` in GF(2⁸) using a combinational shift-and-reduce multiplier — no DSPs needed.
5. After a one-cycle **DRAIN** state (ensuring the deepest PE has settled), `output_valid` pulses.
6. **matrix_serializer** reads the N×N result array and transmits it byte-by-byte over UART TX.

**Total compute latency:** 3N + 1 clock cycles (POP_WAIT + LOAD + 3N−2 SHIFT + DRAIN).

---

## Repository Structure

```
├── rtl/                        # Synthesizable SystemVerilog
│   ├── fpga_top.sv             # Board-level top (UART + controller + array)
│   ├── systolic_top.sv         # FSM controller (FIFO, skew, array orchestration)
│   ├── systolic_array.sv       # NxN PE grid with clear/en broadcast
│   ├── PE.sv                   # Processing element (GF multiply-accumulate)
│   ├── GF_multiplier.sv        # Combinational GF(2^8) multiplier
│   ├── shift_reduce.sv         # Single xtime (multiply by x) stage
│   ├── skew_logic.sv           # Row/column skew shift register network
│   ├── shifter.sv              # Parameterized shift register
│   ├── sync_fifo.sv            # Synchronous FIFO (pointer-based)
│   ├── matrix_accumulator.sv   # UART byte → matrix assembler
│   ├── matrix_serializer.sv    # Matrix → UART byte serializer
│   ├── uart_rx.sv              # UART receiver (with 2-flop synchronizer)
│   └── uart_tx.sv              # UART transmitter
│
├── tb/                         # Simulation testbenches
│   ├── tb_fpga_top.sv          # Full-chain UART-level test (mirrors host script)
│   └── tb_systolic_selfcheck.sv # 100-vector self-checking test with golden model
│
├── python/                     # Host scripts and reference model
│   ├── gf_reference_model.py   # GF(2^8) golden model + vector generator
│   ├── test_accelerator.py     # Board test script (N=4)
│   ├── test_accelerator_n8.py  # Board test script (N=8)
│   ├── test_accelerator_n16.py # Board test script (N=16)
│   └── cpu_benchmark.py        # CPU vs FPGA performance comparison
│
├── constraints/
│   └── nexys_a7.xdc            # Pin constraints (100 MHz, UART, LEDs, reset)
│
├── .gitignore
└── README.md
```

---

## Getting Started

### Prerequisites

- **Xilinx Vivado** 2023.1+ (any edition — WebPACK is free)
- **Python 3.8+** with `pyserial` (`pip install pyserial`)
- **FPGA board**: Basys 3 (xc7a35t) or Nexys A7 (xc7a50t / xc7a100t)

### Build (Vivado)

1. Create a new project targeting your board's part.
2. Add all files in `rtl/` as design sources.
3. Add `constraints/nexys_a7.xdc` as a constraints file.
4. Add files in `tb/` as simulation sources.
5. Set `fpga_top` as the top module.
6. Run Synthesis → Implementation → Generate Bitstream.
7. Program the FPGA.

### Changing the Array Size

To build for N = 8 or N = 16, change the parameter `N` in `fpga_top.sv`:

```systemverilog
module fpga_top #(
    parameter N = 8,          // change to 4, 8, or 16
    parameter WIDTH = 8,
    parameter BYTES_PER_MATRIX = N * N,
    parameter MATRIX_BITS = N * N * WIDTH
)(
```

Then re-synthesize and use the matching host script (`test_accelerator_n8.py` etc.).

### Run on Hardware

```bash
# Install pyserial
pip install pyserial

# Run the N=4 test (adjust COM port in the script)
python python/test_accelerator.py
```

Expected output:
```
[SUCCESS] Received 16 bytes from Systolic Array!

--- Output Matrix C (GF(2^8) Arithmetic) ---
[  16   35   18   63 ]
[  51   24   28   16 ]
[  16   10   24    3 ]
[   8    9   13    9 ]
```

### Simulate

In Vivado, set `tb_fpga_top` as the simulation top and run:

```tcl
run 6 ms
```

The testbench prints `RESULT: PASS` if the full UART chain produces the correct golden output.

---

## GF(2⁸) Arithmetic

All arithmetic is in GF(2⁸) mod the AES polynomial `P(x) = x⁸ + x⁴ + x³ + x + 1` (0x11B):

- **Addition** = bitwise XOR (no carry propagation)
- **Multiplication** = shift-and-reduce (the `xtime` operation), implemented as a chain of 8 `shift_reduce` stages feeding partial products that are XORed together

This makes the PE purely combinational with no DSP blocks — ideal for FPGA LUT-based implementation.

---

## Performance vs Software

The N = 4 array at 100 MHz computes a 4×4 GF(2⁸) matrix multiply in **130 ns** (13 cycles), compared to ~41 µs for an optimized Python implementation — a **300×+ speedup**. The design uses zero DSP blocks and consumes only 78 mW.

Throughput scales near-linearly with N²: each PE contributes one MAC per cycle during the active phase, yielding N² MACs every 3N+1 cycles.

---

## License

This project was developed as an undergraduate capstone at KNUST. Feel free to use and adapt for academic and educational purposes.
