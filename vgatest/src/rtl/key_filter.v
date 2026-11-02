// key_filter.v  -- Verilog-2001 版：同步 + 去抖 + 单脉冲
`timescale 1ns/1ps
module key_filter #(
    parameter integer CLK_HZ      = 100_000_000,  // sys_clk 频率：按你的板子填写
    parameter integer DEBOUNCE_MS = 20,           // 去抖时长：毫秒
    parameter integer ACTIVE_LOW  = 1             // 1=按下为低(上拉键)；0=按下为高
)(
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_in,       // 原始按键信号

    output reg  key_flag      // 已去抖、确认"按下"的单周期脉冲（sys_clk 域）
);

    // -------- 工具函数：clog2（Verilog-2001 实现） --------
    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    // -------- 常量与计数位宽 --------
    localparam integer CNT_MAX = (CLK_HZ/1000)*DEBOUNCE_MS - 1;
    localparam integer W       = (CNT_MAX > 0) ? clog2(CNT_MAX+1) : 1;

    // 统一成"按下=1"的逻辑电平
    wire key_raw_press = (ACTIVE_LOW != 0) ? ~key_in : key_in;

    // 两级同步（防亚稳）
    reg key_sync0, key_sync1;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            key_sync0 <= 1'b0;
            key_sync1 <= 1'b0;
        end else begin
            key_sync0 <= key_raw_press;
            key_sync1 <= key_sync0;
        end
    end

    // -------- 去抖状态机（Verilog-2001 写法） --------
    localparam [1:0] S_IDLE        = 2'd0;
    localparam [1:0] S_WAIT_PRESS  = 2'd1;
    localparam [1:0] S_PRESSED     = 2'd2;
    localparam [1:0] S_WAIT_REL    = 2'd3;

    reg [1:0]  state;
    reg [W-1:0] cnt;
    reg         stable_press;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            state        <= S_IDLE;
            cnt          <= {W{1'b0}};
            stable_press <= 1'b0;
            key_flag     <= 1'b0;
        end else begin
            key_flag <= 1'b0; // 默认无脉冲

            case(state)
            S_IDLE: begin
                stable_press <= 1'b0;
                cnt          <= {W{1'b0}};
                if (key_sync1) state <= S_WAIT_PRESS;
            end

            S_WAIT_PRESS: begin
                if (key_sync1) begin
                    if (cnt == CNT_MAX[W-1:0]) begin
                        stable_press <= 1'b1;
                        key_flag     <= 1'b1;       // 确认按下：打一拍脉冲
                        cnt          <= {W{1'b0}};
                        state        <= S_PRESSED;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end else begin
                    cnt   <= {W{1'b0}};            // 抖回去了
                    state <= S_IDLE;
                end
            end

            S_PRESSED: begin
                if (!key_sync1) begin
                    cnt   <= {W{1'b0}};
                    state <= S_WAIT_REL;
                end
            end

            S_WAIT_REL: begin
                if (!key_sync1) begin
                    if (cnt == CNT_MAX[W-1:0]) begin
                        stable_press <= 1'b0;      // 确认松开
                        cnt          <= {W{1'b0}};
                        state        <= S_IDLE;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end else begin
                    cnt   <= {W{1'b0}};            // 又抖回按下
                    state <= S_PRESSED;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
