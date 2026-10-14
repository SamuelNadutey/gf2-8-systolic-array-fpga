# GF(2^8) systolic-array matrix multiplier

I built an output-stationary SystemVerilog array for matrix multiplication over GF(2^8), using the AES polynomial 0x11B. The datapath uses XOR accumulation and shift-and-reduce multiplication without DSP slices. I include the core, a UART wrapper, a Python reference model, and reproducible Vivado tests and builds in this repository.

## Evidence and scope

I preserved my earlier results under [evidence/historical](evidence/historical). These reports describe the RTL before the integration fixes. I keep their metrics separate from the rebuilt results for the current sources.

| Historical build | LUTs | Registers | BRAM tiles | DSPs | Evidence stage |
|---|---:|---:|---:|---:|---|
| N=4 complete UART system, 12 October 2026 | 1,134 | 1,537 | 0 | 0 | Placed utilization; routed timing meets 100 MHz |
| N=4 core | 1,044 | 950 | 0 | 0 | Out-of-context synthesis |
| N=8 core | 3,453 | 2,899 | 15 | 0 | Out-of-context synthesis |
| N=16 core | 13,835 | 11,924 | 57 | 0 | Out-of-context synthesis |

I tested the UART system on an FPGA board at N=4, N=8, and N=16. Historical serial captures from those runs are not archived in this repository. I distinguish those board tests from the evidence included here: synthesis and routed implementation reports document the builds, while regression logs document simulation correctness.

My historical N=4 power report estimates 0.078 W on-chip power with Medium confidence and incomplete activity inputs. I report this as a Vivado estimate, not measured board power. I do not claim measured end-to-end speedup, sustained throughput or maximum clock frequency from these reports. Positive slack at 100 MHz establishes timing closure at that constraint.

## Current complete-system implementation

I rebuilt the complete systems in Vivado 2024.2 for xc7a50tcsg324-1. All three meet the 100 MHz routed internal setup and hold constraints and report zero DRC violations. I archived the reports and source hashes in [evidence/implementation](evidence/implementation).

| N | Routed LUTs | Registers | BRAM tiles | DSPs | Setup slack (ns) | Hold slack (ns) |
|---|---:|---:|---:|---:|---:|---:|
| 4 | 1,293 | 1,552 | 0 | 0 | +1.483 | +0.027 |
| 8 | 4,197 | 5,058 | 15 | 0 | +1.563 | +0.024 |
| 16 | 16,544 | 20,241 | 57 | 0 | +0.863 | +0.022 |

These are my new implementation results for the revised integration. They do not recover measurements from my earlier board runs. I checked 33,600 output elements in the core regression, and complete UART and burst-pipeline simulations passed at all three sizes. I saved the [validation logs and hashes](evidence/regression/validation_index.json) separately from physical-board captures.

The reports contain no unconstrained internal timing endpoints. I have not specified external input/output delays for the asynchronous UART/reset and UART/LED interfaces, so my timing results concern the internal clocked paths. I explain the changes and evidence limits in the [repair notes](evidence/repair_notes.md).

## Architecture and protocol

UART RX -> matrix accumulator -> A/B FIFOs -> skew registers -> N*N processing elements -> result serializer -> UART TX.

Send ASCII `A` (0x41), followed by N*N bytes in row-major order, then ASCII `B` (0x42), followed by N*N bytes in **column-major** order. Read N*N result bytes in row-major order. Payload bytes may contain any value, including command bytes. Default UART is 115200 baud, 8N1 at a 100 MHz clock.

The host must wait for the complete result before sending the next matrix pair. There is no RTS/CTS or packet acknowledgement; an unlimited input stream is not supported. The accumulator retains a completed matrix while its FIFO is full. The core holds a valid result until the serializer can accept it, and the serializer captures the entire result on that handshake.

The core clears accumulators on LOAD and accumulates for 3N-2 SHIFT cycles. With empty input queues and no output stall, the final input enqueue edge to result-valid latency is 3N+1 cycles: 13, 25, and 49 cycles for N=4,8,16 (130, 250, 490 ns at 100 MHz). Queuing, result backpressure, UART transfer and host delays increase system latency. A GF multiply-accumulate means one finite-field product combined by XOR, not a floating-point operation.

## Run reference checks and HDL regression

Python 3.8+ and Vivado/XSim are required for simulation; pyserial is needed only for physical-board tests. Run from the repository root:

```powershell
python scripts/run_regression.py --vivado-bin 'C:\path\to\Vivado\2024.2\bin'
```

I use deterministic golden vectors in isolated temporary directories and check the Python model against AES MixColumns known answers. The runner tests each N in 4,8,16. My core tests check 100 different matrix pairs without reset and exercise result backpressure. My UART tests check three complete matrix transactions without reset, using a shorter simulated baud divisor for speed. Compile errors, mismatches, missing data and timeouts fail the runner. Logs and a source-hash manifest are saved under `build/regression`; use `--outdir` to preserve a separate run.

## Reproducible implementation

I supply an XDC for Nexys A7 pins. Confirm the actual board part before programming; these constraints do not target Basys 3. All UART matrix dimensions derive from N. My supported interface configuration is WIDTH=8 and N>=2.

```powershell
vivado -mode batch -source scripts/build_vivado.tcl -tclargs 8 xc7a50tcsg324-1 build/n8_run1
```

Repeat with N=4 or N=16 and a different output directory. The script synthesizes, places and routes the complete system, exporting utilization, timing, DRC, estimated power and checkpoints. It does not program a board. Preserve each build directory rather than rerunning multiple sizes into the same `impl_1` directory. Timing and DRC reports must be inspected before generating/programming a bitstream. Export the routed checkpoint with:

```powershell
vivado -mode batch -source scripts/export_bitstream.tcl -tclargs build/n8_run1/routed.dcp build/n8_run1/fpga_top.bit
```

This generates a local bitstream; program only the matching physical board.

## Physical-board validation

```powershell
python -m pip install pyserial
python python/test_accelerator_n8.py --port COM5 --count 100 --output build/board_n8.json
```

Use the matching bitstream and N-specific script. The script compares every returned element with a Python reference, returns a failing exit status on a mismatch or incomplete response, and can save input matrices, expected/observed bytes and UART round-trip times. These timings include the serial link; they are not core compute latency. `test_accelerator.py` defaults to N=4 and `test_accelerator_n16.py` to N=16.

## Files

- `rtl/`: synthesizable arithmetic, control, UART and buffering.
- `tb/`: core and complete UART self-checking regressions.
- `python/`: reference model, physical-board tests, illustrative software benchmark.
- `scripts/`: isolated XSim regression and Vivado implementation flow.
- `evidence/`: selected archived reports and validation notes.
- `constraints/`: Nexys A7 pin and 100 MHz clock constraints.

I developed this project for my undergraduate Computer Engineering capstone at KNUST. It is an arithmetic accelerator, not a masked cryptographic implementation, and I do not claim side-channel resistance.
