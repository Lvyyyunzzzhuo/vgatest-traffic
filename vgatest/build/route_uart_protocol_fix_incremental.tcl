set root [file normalize "D:/vivado/vgatest"]
open_checkpoint "$root/vgatest.runs/synth_1/vga_colorbar.dcp"
read_checkpoint -cell u_clk "$root/vgatest.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.dcp"
read_xdc "$root/vgatest.srcs/constrs_1/imports/new/vga.xdc"

opt_design
read_checkpoint -incremental "$root/vga_colorbar_adaptive_display_routed.dcp"
place_design -directive Explore
write_checkpoint -force "$root/vga_colorbar_uart_protocol_fixed_placed.dcp"
route_design -directive Explore
write_checkpoint -force "$root/vga_colorbar_uart_protocol_fixed_routed.dcp"

report_route_status -file "$root/vga_colorbar_uart_protocol_fixed_route_status.rpt"
report_timing_summary -file "$root/vga_colorbar_uart_protocol_fixed_timing.rpt"
write_bitstream -force "$root/vgatest_UART_PROTOCOL_FIXED.bit"
puts "BITSTREAM_READY: $root/vgatest_UART_PROTOCOL_FIXED.bit"
exit
