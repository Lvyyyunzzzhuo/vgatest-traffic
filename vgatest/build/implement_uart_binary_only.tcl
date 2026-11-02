set root [file normalize "D:/vivado/vgatest"]
open_project "$root/vgatest.xpr"
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 failed"
}
set source_bit [get_property BITSTREAM.FILE [get_runs impl_1]]
set output_bit "$root/vgatest_UART_BINARY_ONLY_FINAL.bit"
file copy -force $source_bit $output_bit
open_run impl_1
report_route_status -file "$root/vga_colorbar_uart_binary_only_route_status.rpt"
report_timing_summary -file "$root/vga_colorbar_uart_binary_only_timing.rpt"
report_utilization -file "$root/vga_colorbar_uart_binary_only_utilization.rpt"
puts "BITSTREAM_READY: $output_bit"
close_project
exit
