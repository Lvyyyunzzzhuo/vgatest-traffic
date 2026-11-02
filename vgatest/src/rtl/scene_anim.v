// scene_anim.v - 车/行人速度改为可注入
`timescale 1ns/1ps
module scene_anim(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,          // ~30Hz
    input  wire       main_R,
    input  wire       main_G,
    input  wire       side_G,
    input  wire [3:0] car_speed,     //新增
    input  wire [3:0] ped_speed,     //新增
    output reg  [9:0] car_x,
    output reg  [9:0] ped_y
);
    localparam [9:0] HMAX=10'd639, VMAX=10'd479;
    localparam [9:0] CAR_X0=10'd10, PED_Y0=10'd20;
    localparam [3:0] CAR_DEF=4'd2, PED_DEF=4'd1;

    wire [3:0] CS = (car_speed==0)? CAR_DEF : car_speed;
    wire [3:0] PS = (ped_speed==0)? PED_DEF : ped_speed;

    localparam [9:0] Y_TOP=10'd200, Y_BOTTOM=10'd280, PED_WAIT_Y = Y_TOP - 10'd3;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            car_x <= CAR_X0;
            ped_y <= PED_Y0;
        end else if (tick) begin
            // 车：黄/绿走，红停
            if (!main_R) begin
                if (car_x >= (HMAX - CS))
                    car_x <= car_x + CS - (HMAX + 10'd1);
                else
                    car_x <= car_x + CS;
            end

            // 行人：红/黄在等待线前逼近；绿或已过路口则继续向下，底部回顶
            if (side_G) begin
                if (ped_y >= (VMAX - PS)) ped_y <= 10'd0;
                else                       ped_y <= ped_y + PS;
            end else begin
                if (ped_y < PED_WAIT_Y) begin
                    ped_y <= ped_y + PS;                   // 靠近等待线
                end else if (ped_y > Y_BOTTOM) begin
                    if (ped_y >= (VMAX - PS)) ped_y <= 10'd0;
                    else                       ped_y <= ped_y + PS; // 过线后继续
                end else begin
                    ped_y <= ped_y;                         // 等绿
                end
            end
        end
    end
endmodule
