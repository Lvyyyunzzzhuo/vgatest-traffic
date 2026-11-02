# Continue the vgatest build through bitstream generation.
# Run from Vivado 2019.1 with the project open, or source this file directly.

set project_file [file normalize "D:/vivado/vgatest/vgatest.xpr"]
if {[current_project -quiet] eq ""} {
    open_project $project_file
}

# Ensure the ROM source added after the previous failed run is part of sources_1.
set rom_file [file normalize "D:/vivado/vgatest/vgatest.srcs/sources_1/new/green_wave_bg_rom.v"]
if {[llength [get_files -quiet $rom_file]] == 0} {
    add_files -norecurse $rom_file
}
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_progress [get_property PROGRESS [get_runs synth_1]]
if {$synth_progress ne "100%"} {
    error "synth_1 did not complete successfully (progress=$synth_progress)"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_progress [get_property PROGRESS [get_runs impl_1]]
if {$impl_progress ne "100%"} {
    error "impl_1 did not complete successfully (progress=$impl_progress)"
}

set bit_file [get_property BITSTREAM.FILE [get_runs impl_1]]
puts "BITSTREAM_READY: $bit_file"
