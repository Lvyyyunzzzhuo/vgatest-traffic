// cfg_uart_ascii.v
// ���� ASCII ָ�LRS/LRL/LRR/TBS/TBL/TBR=ʮ����(0..255) + ������(\n/\r/;)
// ���ã�ֻд��"�̶���ʱ"�Ĵ���������ÿ·��1�ĸ�������

`timescale 1ns/1ps
module cfg_uart_simple #(
  parameter [7:0] DEF_LRS = 8'd40,  // LR ֱ��
  parameter [7:0] DEF_LRL = 8'd30,  // LR ��ת
  parameter [7:0] DEF_LRR = 8'd20,  // LR ��ת
  parameter [7:0] DEF_TBS = 8'd40,  // TB ֱ��
  parameter [7:0] DEF_TBL = 8'd30,  // TB ��ת
  parameter [7:0] DEF_TBR = 8'd20   // TB ��ת
)(
  input  wire        clk,
  input  wire        rst_n,

  // ���� UART ��������rx_valid=1 ��ʾ���� rx_data ��Ч��1�ֽڣ�
  input  wire        rx_valid,
  input  wire [7:0]  rx_data,

  // ��·�̶���ʱ�Ĵ����������?
  output reg  [7:0]  LRS, LRL, LRR, TBS, TBL, TBR,

  // ÿ·���ĸ������壨����"д���¼�"ָʾ��
  output reg         LRS_up, LRL_up, LRR_up, TBS_up, TBL_up, TBR_up
);

  // ============ �򵥽��� FSM ============
  localparam S_IDLE=0, S_T1=1, S_T2=2, S_T3=3, S_EQ=4, S_NUM=5;
  reg [2:0]   st;
  reg [7:0]   t1,t2,t3;       // ��ǩ3��ĸ
  reg [9:0]   acc;            // �ۼ� 0..255
  reg         neg_flag;       // Ԥ��������Ŀ���ã�
  wire        is_digit = (rx_data>="0" && rx_data<="9");
  wire        is_end   = (rx_data==8'h0A || rx_data==8'h0D || rx_data==8'h3B); // \n \r ;
  reg binary_header_wait;
  reg [3:0] binary_remaining;
  wire cfg_rx_valid = rx_valid && !binary_header_wait &&
                      (binary_remaining==0) && (rx_data!=8'hAA);

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin binary_header_wait<=0; binary_remaining<=0; end
    else if(rx_valid) begin
      if(binary_remaining!=0) binary_remaining<=binary_remaining-1'b1;
      else if(binary_header_wait) begin
        binary_header_wait<=0;
        if(rx_data==8'h55) binary_remaining<=4'd8;
      end else if(rx_data==8'hAA) binary_header_wait<=1'b1;
    end
  end

  // ��һ�θ�������
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // ��λʱ����Ϊĭ��ֵ
      LRS <= DEF_LRS; LRL <= DEF_LRL; LRR <= DEF_LRR;
      TBS <= DEF_TBS; TBL <= DEF_TBL; TBR <= DEF_TBR;
      LRS_up<=0; LRL_up<=0; LRR_up<=0; TBS_up<=0; TBL_up<=0; TBR_up<=0;
      st<=S_IDLE; t1<=0; t2<=0; t3<=0; acc<=0; neg_flag<=0;
    end else begin
      LRS_up<=0; LRL_up<=0; LRR_up<=0; TBS_up<=0; TBL_up<=0; TBR_up<=0;

      if (cfg_rx_valid) begin
        case (st)
          S_IDLE: begin
            // ֻ���� L �� T ��ͷ
            if (rx_data=="L" || rx_data=="T") begin t1<=rx_data; st<=S_T1; end
            else st<=S_IDLE;
          end
          S_T1: begin
            // �ڶ�����ĸ�̶���L �� B
            t2 <= rx_data;
            st <= S_T2;
          end
          S_T2: begin
            // ��������ĸ�̶���S/L/R
            t3 <= rx_data;
            st <= S_T3;
          end
          S_T3: begin
            // ���� '='
            if (rx_data=="=") begin acc<=0; neg_flag<=0; st<=S_EQ; end
            else st<=S_IDLE;
          end
          S_EQ: begin
            // ֧�ֿ�ѡ���ţ�����Ŀ���ã���������
            if (rx_data=="-") begin neg_flag<=1'b1; st<=S_NUM; end
            else if (is_digit) begin acc <= rx_data - "0"; st<=S_NUM; end
            else st<=S_IDLE;
          end
          S_NUM: begin
            if (is_digit) begin
              // acc = acc*10 + d ���������? 255
              acc <= (acc*10 + (rx_data-"0") > 10'd255) ? 10'd255 : (acc*10 + (rx_data-"0"));
            end else if (is_end) begin
              // д���Ӧ�Ĵ�����������?
              // ��ǩֻ������LRS/LRL/LRR/TBS/TBL/TBR
              if (t1=="L" && t2=="R" && t3=="S") begin LRS <= acc[7:0]; LRS_up<=1'b1; end
              else if (t1=="L" && t2=="R" && t3=="L") begin LRL <= acc[7:0]; LRL_up<=1'b1; end
              else if (t1=="L" && t2=="R" && t3=="R") begin LRR <= acc[7:0]; LRR_up<=1'b1; end
              else if (t1=="T" && t2=="B" && t3=="S") begin TBS <= acc[7:0]; TBS_up<=1'b1; end
              else if (t1=="T" && t2=="B" && t3=="L") begin TBL <= acc[7:0]; TBL_up<=1'b1; end
              else if (t1=="T" && t2=="B" && t3=="R") begin TBR <= acc[7:0]; TBR_up<=1'b1; end
              st<=S_IDLE;
            end else begin
              st<=S_IDLE; // �Ƿ��ַ���������֡
            end
          end
          default: st<=S_IDLE;
        endcase
      end
    end
  end
endmodule
