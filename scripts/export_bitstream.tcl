# Export a checked routed design; does not program a physical board.
# vivado -mode batch -source scripts/export_bitstream.tcl -tclargs ROUTED_DCP OUTPUT_BIT
if {$argc != 2} { error "Expected ROUTED_DCP OUTPUT_BIT" }
lassign $argv checkpoint output
open_checkpoint [file normalize $checkpoint]
write_bitstream -force [file normalize $output]
close_design
