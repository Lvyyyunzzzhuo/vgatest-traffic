`timescale 1ns / 1ps

module tb_vga_colorbar();

reg sys_clk;

wire key_in        = 1'b0;
wire key_model     = 1'b0;
wire ped_sw_1      = 1'b0;
wire car_sw        = 1'b0;
wire car_sw2       = 1'b0;
wire mode_adapt_sw = 1'b0;
wire uart_rx_pin   = 1'b1;

wire hsync;
wire vsync;
wire [3:0] vga_r;
wire [3:0] vga_g;
wire [3:0] vga_b;

// 100 MHz clock
initial begin
    sys_clk = 1'b0;
end

always #5 sys_clk = ~sys_clk;

// DUT
vga_colorbar vga_colorbar_inst (
    .sys_clk       (sys_clk),
    .key_in        (key_in),
    .key_model     (key_model),
    .ped_sw_1      (ped_sw_1),
    .car_sw        (car_sw),
    .car_sw2       (car_sw2),
    .mode_adapt_sw (mode_adapt_sw),
    .uart_rx_pin   (uart_rx_pin),
    .hsync         (hsync),
    .vsync         (vsync),
    .vga_r         (vga_r),
    .vga_g         (vga_g),
    .vga_b         (vga_b)
);

// 仿真 2 ms 后停止
initial begin
    #2_000_000;
    $stop;
end

endmodule