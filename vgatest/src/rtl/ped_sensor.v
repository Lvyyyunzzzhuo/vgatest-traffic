`timescale 1ns/1ps
module ped_sensor #(
    parameter [9:0] Y_TOP        = 10'd170, // 上边线
    parameter [9:0] Y_BOTTOM     = 10'd330, // 下边线
    parameter [9:0] WAIT_MARGIN  = 10'd8,   // 等待线距离上边线
    parameter [9:0] CLEAR_MARGIN = 10'd4,   // 清除线距离下边线
    parameter [9:0] R            = 10'd6,   // 行人半径
    parameter integer MAX_PEOPLE = 32       // 硬件上限
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [9:0] ped_y,          // 单人基准纵坐标

    // 新增：多人复制控制
    input  wire [7:0] people_count,   // 行人数(0..MAX_PEOPLE)
    input  wire [9:0] phase_step,     // 相邻两人的"时间相位"步长

    output wire [9:0] ped_wait_y,     // 等待线位置（用于显示）
    output reg        wait_zone,      // 任意一个人在等待区
    output reg        in_crossing     // 任意一个人在斑马线范围内
);

    // -- 常量/函数 -- //
    // 兜底：phase_step 为 0 时避免重合
    wire [9:0] phase_step_eff = (phase_step == 10'd0) ? 10'd16 : phase_step;

    // 480 包裹
    function [9:0] wrap480; input [10:0] v;
    begin
        wrap480 = (v >= 11'd480) ? (v - 11'd480) : v[9:0];
    end
    endfunction

    // 等待线、清除线
    wire [9:0] wait_line  = Y_TOP    - WAIT_MARGIN;
    wire [9:0] clear_line = Y_BOTTOM + CLEAR_MARGIN;
    assign ped_wait_y = wait_line;

    // -- 提前声明临时量（不要在 always 里声明）--
    integer i;
    reg        wait_hit, cross_hit;
    reg [9:0]  ped_y_i;
    reg [9:0]  ped_bottom, ped_top;

    // -- 组合逻辑聚合（所有相位 OR）--
    always @* begin
        wait_hit  = 1'b0;
        cross_hit = 1'b0;

        for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
            if (i < people_count) begin
                // 第 i 个行人的 y（只用 y 即可完成区间判定）
                ped_y_i    = wrap480({1'b0, ped_y} + (i * phase_step_eff));
                ped_bottom = ped_y_i + R;
                ped_top    = ped_y_i - R;

                // 等待区：下边缘到等待线，上边缘仍在上边线之上
                if ( (ped_bottom >= wait_line) && (ped_top < Y_TOP) )
                    wait_hit = 1'b1;

                // 过街区：圆任意部分在 [Y_TOP, clear_line] 内
                if ( (ped_bottom >= Y_TOP) && (ped_top <= clear_line) )
                    cross_hit = 1'b1;
            end
        end

        wait_zone   = wait_hit;
        in_crossing = cross_hit;
    end

endmodule
