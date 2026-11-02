open_checkpoint D:/vivado/vgatest/vga_colorbar_routed.dcp
set c [get_cells -hier -filter {ORIG_REF_NAME == scene_cross || REF_NAME == scene_cross}]
puts "CELLS=$c"
foreach x $c { puts "PORTS=[get_pins -of_objects $x]" }
close_design
