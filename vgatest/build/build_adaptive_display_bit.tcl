set root D:/vivado/vgatest
open_checkpoint $root/vga_colorbar.dcp
read_checkpoint -cell u_clk $root/vgatest.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.dcp
read_xdc $root/vgatest.srcs/constrs_1/imports/new/vga.xdc

opt_design
write_checkpoint -force $root/vga_colorbar_adaptive_display_opt.dcp

read_checkpoint -incremental $root/vga_colorbar_routed.dcp
place_design -directive Explore
write_checkpoint -force $root/vga_colorbar_adaptive_display_placed.dcp

route_design -directive Explore
write_checkpoint -force $root/vga_colorbar_adaptive_display_routed.dcp
report_route_status -file $root/vga_colorbar_adaptive_display_route_status.rpt
report_timing_summary -file $root/vga_colorbar_adaptive_display_timing.rpt

write_bitstream -force $root/vgatest_ADAPTIVE_DISPLAY_FINAL.bit
exit
