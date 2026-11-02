// traffic_ctrl_adaptive.v - ���˹��߼����ٷų���S_SG ����������Ҵ�����̺�ֱ�ӻ� S_MG
// ���� clk ֱ�Ӽ�ʱ�������� tick_01s������д�㣬���������
`timescale 1ns/1ps
module traffic_ctrl_adaptive #(
    parameter integer CLK_HZ      = 25_175_000, // �ﰴ��� vga_clk ʵ��Ƶ����д
    // ����λʱ�䣨�룩
    parameter integer MIN_GREEN_S = 5,
    parameter integer MAX_GREEN_S = 12,
    parameter integer YELLOW_S    = 1,
    parameter integer ALL_RED_S   = 1,
    parameter integer GAP_S       = 1,
    // �Ƿ�����"���ٷų�"�����������ֱ�ӻ����̣�
    parameter FAST_RELEASE        = 1          // 1=����, 0=�رգ����־����̣���ơ�ȫ������̣�
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tick,         // ���ݶ˿ڣ���ʹ��
    input  wire det_main,     // ��·��⣨����һֱ1��
    input  wire det_side,     // ���˵��ȴ���=1��ͨ���±߽����0
    input  wire in_crossing,  // ���˹���ͨ����=1��ֻ�ڹ���ʱ��ʱ

    output reg  main_G, main_Y, main_R,
    output reg  side_G, side_Y, side_R,

    output reg [7:0] cur_sec,     // ��������ʾ
    output reg [2:0] state        // 0:MainG,1:MainY,2:AllRed1,3:SideG,4:SideY,5:AllRed2
);
    // ====== ��"��"תΪ"clk������ֵ" ======
    localparam integer MIN_GREEN_C = MIN_GREEN_S * CLK_HZ;
    localparam integer MAX_GREEN_C = MAX_GREEN_S * CLK_HZ;
    localparam integer YELLOW_C    = YELLOW_S    * CLK_HZ;
    localparam integer ALL_RED_C   = ALL_RED_S   * CLK_HZ;
    localparam integer GAP_C       = GAP_S       * CLK_HZ;

    // ====== ״̬���� ======
    localparam S_MG=3'd0, S_MY=3'd1, S_AR1=3'd2, S_SG=3'd3, S_SY=3'd4, S_AR2=3'd5;

    // ====== ������ ======
    reg [31:0] phase_cnt;  // ��ǰ��λ�ѹ���clk��
    reg [31:0] gap_cnt;    // ��ǰ��λ"������"�ۼ�clk��
    reg [31:0] sec_div;    // 1���Ƶ

    // ====== �����ɫ����ϣ� ======
    always @* begin
        main_G=0; main_Y=0; main_R=0;
        side_G=0; side_Y=0; side_R=0;
        case(state)
            S_MG:  begin main_G=1; side_R=1; end
            S_MY:  begin main_Y=1; side_R=1; end
            S_AR1: begin main_R=1; side_R=1; end
            S_SG:  begin side_G=1; main_R=1; end
            S_SY:  begin side_Y=1; main_R=1; end
            S_AR2: begin main_R=1; side_R=1; end
            default: begin main_R=1; side_R=1; end
        endcase
    end

    // ====== ��һʱ��飺���� state / ���� / ����ʾ����д�㣩 ======
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state     <= S_MG;
            phase_cnt <= 32'd0;
            gap_cnt   <= 32'd0;
            sec_div   <= 32'd0;
            cur_sec   <= 8'd0;
        end else begin
            // -- ��λ������ÿ��+1
            phase_cnt <= phase_cnt + 1'b1;

            // -- gap���������̿� det_side��������λ�� det_main������������0���������ۼ�
            if ( (state==S_SG) ? det_side : det_main )
                gap_cnt <= 32'd0;
            else
                gap_cnt <= gap_cnt + 1'b1;

            // -- ����ʾ��ÿ��1��+1����Ӱ����ƣ�ֻ�ڹ���ʱ��ʱ
            if (sec_div >= CLK_HZ-1) begin
                sec_div <= 32'd0;
                if ((state == S_SG) && in_crossing && (cur_sec != 8'hFF))
                    cur_sec <= cur_sec + 1'b1;
            end else begin
                if ((state == S_SG) && in_crossing)
                    sec_div <= sec_div + 1'b1;
                else if (state != S_SG)
                    sec_div <= sec_div + 1'b1;
            end

            // -- ״̬������������ + ���̱��� + ���ٷų���--
            case(state)
                // ���̣�a)������ռ����ת���ƣ�b)���� gap/���
                S_MG: begin
                    if ( det_side || ((phase_cnt >= MIN_GREEN_C && gap_cnt >= GAP_C) || (phase_cnt >= MAX_GREEN_C)) ) begin
                        state     <= S_MY;
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end

                // ���� -> ȫ��1
                S_MY: begin
                    if (phase_cnt >= YELLOW_C) begin
                        state     <= S_AR1;
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end

                // ȫ��1 -> ����
                S_AR1: begin
                    if (phase_cnt >= ALL_RED_C) begin
                        state     <= S_SG;
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end

                // ���̣��������򱣳֣�
                //       ����������Ѵ�����̣�
                //          FAST_RELEASE=1 �� ֱ�����̣����ٲ��/ȫ�죩
                //          FAST_RELEASE=0 �� �������̽�����
                //       ��̶����Խ�����
                S_SG: begin
                    if (!det_side && (phase_cnt >= MIN_GREEN_C)) begin
                        if (FAST_RELEASE) begin
                            state     <= S_MG;        // ����ٷų�
                            phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                            sec_div   <= 32'd0; cur_sec <= 8'd0;
                        end else begin
                            state     <= S_SY;        // ������
                            phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                            sec_div   <= 32'd0; cur_sec <= 8'd0;
                        end
                    end else if (phase_cnt >= MAX_GREEN_C) begin
                        state     <= S_SY;            // ��ʱ�ޱ���ת���
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end

                // ��� -> ȫ��2
                S_SY: begin
                    if (phase_cnt >= YELLOW_C) begin
                        state     <= S_AR2;
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end

                // ȫ��2 -> ����
                S_AR2: begin
                    if (phase_cnt >= ALL_RED_C) begin
                        state     <= S_MG;
                        phase_cnt <= 32'd0; gap_cnt <= 32'd0;
                        sec_div   <= 32'd0; cur_sec <= 8'd0;
                    end
                end
            endcase
        end
    end
endmodule
