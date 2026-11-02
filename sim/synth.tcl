# Out-of-context synthesis of the full datapath for an Artix-7 (100 MHz target).
#   vivado -mode batch -source sim/synth.tcl
set root [file dirname [file dirname [file normalize [info script]]]]
foreach f {multiplier16 alu32 seq_detector packet_checker datapath_top} {
    read_vhdl [file join $root rtl $f.vhd]
}
synth_design -top datapath_top -part xc7a35tcpg236-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
report_utilization -file [file join $root sim build utilization.txt]
report_timing_summary -file [file join $root sim build timing.txt]
