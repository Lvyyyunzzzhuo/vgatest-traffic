set root [file normalize "D:/vivado/vgatest"]
open_project "$root/vgatest.xpr"
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 failed"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 failed"
}

set source_bit [get_property BITSTREAM.FILE [get_runs impl_1]]
set output_bit "$root/vgatest_UART_PROTOCOL_FIXED.bit"
file copy -force $source_bit $output_bit
open_run impl_1
report_route_status -file "$root/vga_colorbar_uart_protocol_fixed_route_status.rpt"
report_timing_summary -file "$root/vga_colorbar_uart_protocol_fixed_timing.rpt"
puts "BITSTREAM_READY: $output_bit"
close_project
exit
