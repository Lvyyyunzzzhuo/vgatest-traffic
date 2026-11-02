// Periodchange.v
// 第二层状态机
module Periodchange
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key_second_level,   // 建议接 key_filter.key_flag 脉冲
    output reg  [1:0] modenum             // 0:LOW 1:NORM 2:PEAK
);
    // 状态常量
    localparam [1:0] LOW  = 2'd0;
    localparam [1:0] NORMAL = 2'd1;
    localparam [1:0] MANY = 2'd2;

    // 边沿检测（防止持续高电平多次触发）
    reg key_d1;//寄存器存上一拍电平
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            key_d1 <= 1'b0;
        else
            key_d1 <= key_second_level;
    end
    wire key_rise = key_second_level & ~key_d1;  // 检测上升沿

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            modenum <= NORMAL; // 默认
        else if (key_rise) begin
            case(modenum)
                LOW:   modenum <= NORMAL;
                NORMAL:  modenum <= MANY;
                default: modenum <= LOW;   
            endcase
        end
    end
endmodule
