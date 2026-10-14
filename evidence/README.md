# Validation evidence

I preserved my original core OOC synthesis reports and the October 12 N=4 complete-system reports in `historical/`. They describe the historical RTL, not the repaired checkout. I keep the larger OOC reports separate from complete-system place-and-route evidence.

I saved fresh XSim logs and `validation_index.json` with RTL and relevant testbench SHA-256 hashes in `regression/`. All three sizes passed 100 core matrix pairs without reset (33,600 output elements), three full UART matrix pairs, a three-pair burst into a core/serializer pipeline, and two accumulator transfers while the FIFO was blocked. My core tests assert the no-stall 3N+1-cycle input-enqueue-to-valid latency and hold outputs under backpressure. I use CLKS_PER_BIT=16 in UART simulation for speed; physical hardware defaults to 868. I also checked that removing expected-output data correctly caused a fatal failure.

The accumulator tests check two input-matrix transfers at each size. These are simulation results, not physical-board captures.

I archived fresh complete-system implementation reports under `implementation/`. All three sizes meet 100 MHz internal setup and hold constraints and report zero DRC violations. Build source manifests accompany them. I report positive setup and hold slack as timing closure at a 100MHz constraint, not as a board frequency measurement or measured maximum clock rate.

The constraint-file hash in those build manifests refers to `implementation/constraints_used.xdc`. After the builds started, I corrected an inaccurate attribution in one comment in the checkout's XDC; the constraint commands are identical. RTL and build-script hashes refer to the checked-in files. I explain internal timing and external-interface scope in the [repair notes](repair_notes.md).

## Historical artifact search

The available historical full-system project reports and archived bitstreams elaborated N=4. My historical backup logs retain larger-core simulation PASS messages, and I have OOC synthesis reports for N=8 and N=16. I performed board tests at those sizes, but matching historical full-system routed reports and serial PASS captures were not recovered during the artifact search. I keep that gap explicit rather than treating the new implementation reports as evidence of my earlier board runs.

Vivado run folders are reused when a project is rebuilt. The original Git ignore rules exclude *.runs directories, *.bit, *.dcp and *.log files. Consequently, the public Git history cannot recover ignored build artifacts that were never committed. Preserve a distinct build directory and a board-test JSON capture for every array size going forward.
