# Validation evidence

`historical/` preserves the original core OOC synthesis reports and the October 12 N=4 complete-system reports. They describe the historical RTL, not the repaired checkout. The larger OOC reports are listed separately from complete-system place-and-route evidence.

`regression/` contains fresh XSim logs and `validation_index.json` with RTL and relevant testbench SHA-256 hashes. All three sizes passed 100 core matrix pairs without reset (33,600 output elements), three full UART matrix pairs, a three-pair burst into a core/serializer pipeline, and two accumulator transfers while the FIFO was blocked. Core tests assert the no-stall 3N+1-cycle input-enqueue-to-valid latency and hold outputs under backpressure. UART simulation uses CLKS_PER_BIT=16 for speed; physical hardware defaults to 868. Removing expected-output data in a negative test correctly caused a fatal failure.

The accumulator tests check two input-matrix transfers at each size. These are simulation results, not physical-board captures.

Fresh complete-system implementation reports are archived under `implementation/`. All three sizes meet 100 MHz internal setup and hold constraints and report zero DRC violations. Build source manifests accompany them. Positive setup and hold slack establishes timing closure at a 100MHz constraint, not a board frequency measurement or measured maximum clock rate.

The constraint-file hash in those build manifests refers to `implementation/constraints_used.xdc`. An inaccurate attribution in one comment in the checkout's XDC was corrected after the builds started; the constraint commands are identical. RTL and build-script hashes refer to the checked-in files. The [repair notes](repair_notes.md) explain internal timing and external-interface scope.

## Historical artifact search

The available historical full-system project reports and archived bitstreams elaborated N=4. Historical backup logs retain larger-core simulation PASS messages, and OOC synthesis reports exist for N=8 and N=16. I performed board tests at those sizes, but matching historical full-system routed reports and serial PASS captures were not recovered during the artifact search. The new implementation reports document the current builds and do not reconstruct those earlier board runs.

Vivado run folders are reused when a project is rebuilt. The original Git ignore rules exclude *.runs directories, *.bit, *.dcp and *.log files. Consequently, the public Git history cannot recover ignored build artifacts that were never committed. Preserve a distinct build directory and a board-test JSON capture for every array size going forward.
