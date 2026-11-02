set root [file normalize "D:/vivado/vgatest"]
open_project "$root/vgatest.xpr"
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 failed"
}
open_run synth_1
report_utilization -file "$root/vga_colorbar_uart_minimal_utilization_synth.rpt"
write_checkpoint -force "$root/vga_colorbar_uart_minimal_synth.dcp"
puts "SYNTHESIS_READY"
close_project
exit
