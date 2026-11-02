## R[3:0]
set_property PACKAGE_PIN U15 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN U16 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN U17 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN V15 [get_ports {vga_r[0]}]

## G[3:0]
set_property PACKAGE_PIN AA17 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN AB17 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN AA16 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN AB16 [get_ports {vga_g[0]}]

## B[3:0]
set_property PACKAGE_PIN W15  [get_ports {vga_b[3]}]
set_property PACKAGE_PIN Y15  [get_ports {vga_b[2]}]
set_property PACKAGE_PIN AA14 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN AB15 [get_ports {vga_b[0]}]
## VGA ͬ���ź�
set_property PACKAGE_PIN W16 [get_ports hsync]
set_property PACKAGE_PIN Y16 [get_ports vsync]

set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]


set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*] vga_g[*] vga_b[*] hsync vsync sys_clk}]
# ϵͳʱ�ӣ�PL 100MHz��
set_property PACKAGE_PIN AA18 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
# ���� Vivado�����ǵ���ʱ�����룬����ר�ò�ֲ���
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sys_clk_IBUF]
create_clock -period 10.000 [get_ports sys_clk]

## === Mode switch button on H17 ===
set_property PACKAGE_PIN H17       [get_ports {key_in}]
set_property IOSTANDARD LVCMOS33   [get_ports {key_in}]
set_property PULLUP true           [get_ports {key_in}]

## === Mode switch button on C19 ===
set_property PACKAGE_PIN C19     [get_ports {key_model}]
set_property IOSTANDARD LVCMOS33   [get_ports {key_model}]
set_property PULLUP true           [get_ports {key_model}]

## key_count1 on A22
set_property PACKAGE_PIN A22 [get_ports {ped_sw_1}]
set_property IOSTANDARD LVCMOS33 [get_ports {ped_sw_1}]
set_property PULLUP true [get_ports {ped_sw_1}]
## key_count1 on D22
set_property PACKAGE_PIN D22 [get_ports {car_sw}]
set_property IOSTANDARD LVCMOS33 [get_ports {car_sw}]
set_property PULLUP true [get_ports {car_sw}]
## key_count1 on D22
set_property PACKAGE_PIN C22 [get_ports {car_sw2}]
set_property IOSTANDARD LVCMOS33 [get_ports {car_sw2}]
set_property PULLUP true [get_ports {car_sw2}]

set_property PACKAGE_PIN E21 [get_ports {mode_adapt_sw}]
set_property IOSTANDARD LVCMOS33 [get_ports {mode_adapt_sw}]
set_property PULLUP true [get_ports {mode_adapt_sw}]
# UART接收：FPGA从CP2102的TXD(引脚26)接收数据，连接到V17
set_property PACKAGE_PIN V17 [get_ports {uart_rx_pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx_pin}]
set_property PULLUP true [get_ports {uart_rx_pin}]
set_false_path -from [get_ports {uart_rx_pin}]

# The intersection vehicle coordinates only update on the internal move_tick
# (once per 2^19 VGA clocks).  Their large queue/turn calculations therefore
# have multiple clock cycles to settle even though Vivado otherwise assumes a
# one-pixel-clock path.
set cross_motion_regs [get_cells -hier -quiet -regexp {.*u_intersection/(st|rt|lt|stR|rt2|lt2|tsd|tl|tr|bs_st|br|bl)_(x|y|state)_reg.*} -filter {IS_SEQUENTIAL == 1}]
set_multicycle_path 8 -setup -to $cross_motion_regs
set_multicycle_path 7 -hold  -to $cross_motion_regs

# UART发送：FPGA到CP2102 RXD（EDK_Z7_TCC用户手册第20页：UART_RXD/W18）。
set_property PACKAGE_PIN W18 [get_ports {uart_tx_pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx_pin}]
