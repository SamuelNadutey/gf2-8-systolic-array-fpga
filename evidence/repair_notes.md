# Integration repairs and claim boundaries

The existing repository core already cleared its processing elements between operations and included a drain state. The existing reference test also formatted N-dependent filenames. Those features differ from some older Vivado source copies and are not new fixes in this revision.

The repaired integration addresses:

- **Array size propagation:** the UART top previously retained 16-byte/128-bit defaults when N changed. Matrix byte and bus sizes now derive from N, with checks for inconsistent overrides.
- **Result ownership:** the core now holds result-valid and its matrix until the serializer accepts it. The serializer snapshots the whole matrix on that handshake, so a later operation cannot overwrite a result being transmitted.
- **Blocked input FIFOs:** a completed input matrix is retained until its FIFO can accept it. This does not add UART flow control; the supported host protocol still waits for the complete result before sending another pair.
- **Reset and BRAM controls:** the board reset releases synchronously. FIFO pointers and the controllers that drive BRAM enables use synchronous reset to remove Vivado asynchronous-control DRC violations. UART receive synchronizer registers are marked for placement, and invalid stop bits are rejected.
- **Reproducible verification:** golden vectors use relative paths in isolated test directories; missing vectors, mismatches and timeouts fail. Core, UART, burst-result and blocked-accumulator tests run at each supported size. A missing-output-file negative test checks that absent expected data cannot produce a false PASS.
- **Reproducible implementation:** scripts build the complete system into separate directories for each N and preserve source hashes, routed timing, utilization, DRC and estimated-power reports. They read this checkout's RTL rather than the external sources referenced by the historical XPR projects.
- **Host tests and claims:** board-test scripts require an explicit serial port and can save every expected/observed result. Documentation distinguishes historical core synthesis, complete-system implementation, simulation, cycle-derived latency and physical-board observations. Unsupported sustained-throughput, maximum-frequency, speedup and measured-power claims were removed.

## Remaining boundaries

Historical N=8/N=16 board captures have not been recovered. Fresh place-and-route and simulation results do not replace those physical observations. To archive new board evidence, use a bitstream generated from the matching routed checkpoint and retain the board-test JSON output for each N.

The 100 MHz timing result concerns constrained internal clocked paths. Timing reports contain no unconstrained internal endpoints, but the asynchronous UART/reset inputs and UART/LED outputs have no external input/output delay constraints. It is not a timing guarantee for a synchronous external interface.

Power reports are Vivado estimates with incomplete activity information, not measurements. The matrix-wide FIFO organization is expensive in BRAM at larger N; this revision preserves that architecture rather than claiming a memory optimization.
