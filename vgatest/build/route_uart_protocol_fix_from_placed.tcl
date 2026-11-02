set root [file normalize "D:/vivado/vgatest"]
open_checkpoint "$root/vgatest.runs/impl_1/vga_colorbar_placed.dcp"

route_design -directive Explore
write_checkpoint -force "$root/vga_colorbar_uart_protocol_fixed_routed.dcp"
report_route_status -file "$root/vga_colorbar_uart_protocol_fixed_route_status.rpt"
report_timing_summary -file "$root/vga_colorbar_uart_protocol_fixed_timing.rpt"
write_bitstream -force "$root/vgatest_UART_PROTOCOL_FIXED.bit"
puts "BITSTREAM_READY: $root/vgatest_UART_PROTOCOL_FIXED.bit"
exit
