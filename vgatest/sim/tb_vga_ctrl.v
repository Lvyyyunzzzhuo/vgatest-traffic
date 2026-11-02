`timescale 1ns / 1ps

module tb_vga_ctrl();

reg sys_clk;
reg sys_rst_n;
wire [15:0]  pix_data;
wire    vga_clk;
wire    locked;
wire rst_n;

wire    [9:0]               pix_x  ;
wire    [9:0]               pix_y   ;
wire                          hsync   ;
wire                          vsync    ;
wire    [15:0]            vga_rgb   ;


initial
    begin 
            sys_clk = 1'b1;
            sys_rst_n <= 1'b0;
            #20
            sys_rst_n <= 1'b1;          
    end
    
always  #5 sys_clk =~sys_clk;

assign rst_n = (sys_rst_n && locked);

//always@(posedge sys_clk or negedge sys_rst_n)
//        if(sys_rst_n == 1'b0)
//            pix_data <= 16'h0000;
//        else    if (pix_x>=10'd0  &&  pix_x<=10'd639
//                 && pix_y>=10'd0 && pix_y<=10'd479 )
//            pix_data   <=  16'hffff;
//        else
//            pix_data <= 16'h0000;
            
  clk_wiz_0 instance_name
   (
    // Clock out ports
    .clk_out1(vga_clk),     // output clk_out1
    // Status and control signals
    .reset(~sys_rst_n), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(sys_clk));      // input clk_in1
// INST_TAG_END ------ End INSTANTIATION Template ---------

vga_ctrl    vga_ctrl_inst
(
    .vga_clk    ( vga_clk),
    .sys_rst_n  (rst_n),
    .pix_data       (pix_data),
    .pix_x            (pix_x ),
     .pix_y           (pix_y),
    .hsync            (hsync),
    .vsync            (vsync),
    .vga_rgb        (vga_rgb)
);
vga_pic    vga_pic_inst
(
    .vga_clk      (vga_clk) ,
    .sys_rst_n    (rst_n),
    .pix_x           (pix_x),
    .pix_y          (pix_y) ,

    .pix_data       (pix_data)
    );
endmodule
