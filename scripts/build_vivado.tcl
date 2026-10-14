# vivado -mode batch -source scripts/build_vivado.tcl -tclargs N PART OUTPUT_DIR
# Every invocation uses a separate directory. Historical reports are never reused.
if {$argc != 3} { error "Expected N PART OUTPUT_DIR" }
lassign $argv n part outdir
if {$n ni {4 8 16}} { error "N must be 4, 8 or 16" }
set root [file normalize [file join [file dirname [info script]] ..]]
set outdir [file normalize $outdir]
if {[file exists [file join $outdir routed.dcp]]} { error "Output already contains a build; choose a new directory" }
file mkdir $outdir
create_project -in_memory -part $part
read_verilog -sv [glob [file join $root rtl *.sv]]
read_xdc [file join $root constraints nexys_a7.xdc]
synth_design -top fpga_top -part $part -generic N=$n
report_utilization -file [file join $outdir utilization_synth.rpt]
write_checkpoint -force [file join $outdir synthesized.dcp]
opt_design
place_design
report_utilization -file [file join $outdir utilization_placed.rpt]
route_design
report_timing_summary -report_unconstrained -file [file join $outdir timing_routed.rpt]
report_utilization -file [file join $outdir utilization_routed.rpt]
report_power -file [file join $outdir power_estimate.rpt]
report_drc -file [file join $outdir drc.rpt]
write_checkpoint -force [file join $outdir routed.dcp]
set meta [open [file join $outdir configuration.txt] w]
puts $meta "N=$n\npart=$part\nVivado=[version -short]\nclock_period_ns=10\nPower is a tool estimate, not a board measurement."
close $meta

close_project
