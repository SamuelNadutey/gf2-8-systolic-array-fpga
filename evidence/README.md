# Validation evidence

`historical/` preserves the original core OOC synthesis reports and the October 12 N=4 complete-system reports. They describe the historical RTL, not the repaired checkout. The larger OOC reports are not complete-system place-and-route evidence.

`regression/` contains fresh XSim logs and `validation_index.json` with RTL and relevant testbench SHA-256 hashes. All three sizes passed 100 core matrix pairs without reset (33,600 output elements), three full UART matrix pairs, a three-pair burst into a core/serializer pipeline, and two accumulator transfers while the FIFO was blocked. Core tests assert the no-stall 3N+1-cycle input-enqueue-to-valid latency and hold outputs under backpressure. UART simulation uses CLKS_PER_BIT=16 for speed; physical hardware defaults to 868. Missing expected-output data was separately removed and correctly caused a fatal failure.

The accumulator tests check two input-matrix transfers at each size. These are simulation results, not physical-board captures.

Fresh complete-system implementation reports are archived under `implementation/`; all three sizes meet 100 MHz internal setup and hold constraints and report zero DRC violations. Build source manifests accompany them. Positive setup and hold slack at a 100MHz clock establish timing closure at that constraint; they are not board frequency measurements or measured maximum clock rates.

The constraint-file hash in those build manifests refers to `implementation/constraints_used.xdc`. After the builds started, an inaccurate attribution in one comment was removed from the checkout's XDC; the constraint commands are identical. RTL and build-script hashes refer to the checked-in files. Internal timing and external-interface scope are explained in [repair notes](repair_notes.md).

## Historical artifact search

The available historical full-system project reports and archived bitstreams elaborated N=4. Historical backup logs retain larger-core simulation PASS messages, and OOC synthesis reports exist for N=8 and N=16. No archived full-system N=8/N=16 routed report or saved serial PASS capture was recovered in this search. The author reports having performed those board runs; lack of an archived artifact does not establish that the run did not occur.

Vivado run folders are reused when a project is rebuilt. The original Git ignore rules exclude *.runs directories, *.bit, *.dcp and *.log files. Consequently, the public Git history cannot recover ignored build artifacts that were never committed. Preserve a distinct build directory and a board-test JSON capture for every array size going forward.
