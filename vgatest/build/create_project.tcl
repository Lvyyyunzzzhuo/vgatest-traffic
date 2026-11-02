# Recreate a clean Vivado project from the repository layout.
# Run from the Vivado Tcl Console or with: vivado -mode batch -source create_project.tcl

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $repo_root board generated_project]
file mkdir $project_dir

create_project vgatest $project_dir -part xc7z020clg484-1 -force

set rtl_files [glob -nocomplain -directory [file join $repo_root src rtl] *.v]
if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 $rtl_files
}

set ip_files [glob -nocomplain -directory [file join $repo_root src ip] *.xci]
if {[llength $ip_files] > 0} {
    add_files -fileset sources_1 $ip_files
}

set constraint_files [glob -nocomplain -directory [file join $repo_root src constraints] *.xdc]
if {[llength $constraint_files] > 0} {
    add_files -fileset constrs_1 $constraint_files
}
set board_constraint [file join $repo_root board dont_touch.xdc]
if {[file exists $board_constraint]} {
    add_files -fileset constrs_1 $board_constraint
}

set sim_files [glob -nocomplain -directory [file join $repo_root sim] *.v]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
}

set_property top vga_colorbar [get_filesets sources_1]
set_property top tb_vga_colorbar [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

foreach ip [get_files -quiet *.xci] {
    generate_target all $ip
}
save_project_as vgatest $project_dir/vgatest.xpr -force
puts "Project created at $project_dir"
