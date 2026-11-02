`timescale 1ns/1ps

// ========================= TOP: traffic_adapt2 (no UART) =========================
module traffic_adapt2 #(
  // ��Щ����ֻ��Ϊ�ϵ�Ĭ��ֵ������ʱ���ϲ� cfg_* ����
  parameter BASE_S  = 40,
  parameter BASE_L  = 30,
  parameter BASE_R  = 20,
  parameter T_YEL   = 12,
  // �����ӳɣ�������Ӧģʽ��Ч��
  parameter EXT_BIG   = 10,
  parameter EXT_SMALL = 5,
  // ������ֵ��many / small �ֵ���������Ӧ��
  parameter PED_RT_TH = 5,
  // ����Ӱ�죨������Ӧ��
  parameter PED_EXT_S  = 8,
  parameter PED_RT_CUT = 6,
  parameter MIN_RIGHT  = 8,  // ��ת��Сʱ�����ޣ�clamp��

  // ��ת mini-FSM
  parameter RTY_S          = 1,
  parameter PED_ON_DB_S    = 2,  // ȥ����ȷ��"������"���л�
  parameter PED_OFF_DB_S   = 2,  // �������������������ͷţ�
  parameter MIN_RIGHT_FREE = 2   // ��ת��С���б���
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        sec_tick,      // 1Hz

  // ����ƫ�� & ����̬�ƣ����� scene_cross��
  input  wire [1:0]  car_bias,      // 00=���� 01=LR�� 10=TB��
  input  wire [4:0]  ped_n_lr,
  input  wire [4:0]  ped_n_tb,
  input  wire        ped_has_lr,
  input  wire        ped_has_tb,
  input  wire        ped_active_lr,  // �������ڲ�ʵʱռ��
  input  wire        ped_active_tb,
  input  wire        mode_adapt_sw,  // 1=����Ӧ

  // �ϲ㣨scene_cross������ֱͨ�����һ��һ�£�ÿ�ĸ���?
  input  wire [7:0]  cfg_LRS,  // LR ֱ��
  input  wire [7:0]  cfg_LRL,  // LR ��ת
  input  wire [7:0]  cfg_LRR,  // LR ��ת
  input  wire [7:0]  cfg_TBS,  // TB ֱ��
  input  wire [7:0]  cfg_TBL,  // TB ��ת
  input  wire [7:0]  cfg_TBR,  // TB ��ת

  output reg  [1:0]  col_LR_S,
  output reg  [1:0]  col_LR_L,
  output reg  [1:0]  col_LR_R,
  output reg  [1:0]  col_TB_S,
  output reg  [1:0]  col_TB_L,
  output reg  [1:0]  col_TB_R,

  // �̵�ʱ��ָʾ���룩
  output wire [7:0]  green_sec_LR_S,
  output wire [7:0]  green_sec_LR_L,
  output wire [7:0]  green_sec_LR_R,
  output wire [7:0]  green_sec_TB_S,
  output wire [7:0]  green_sec_TB_L,
  output wire [7:0]  green_sec_TB_R
);

  localparam [1:0] C_RED=2'd0, C_YEL=2'd1, C_GRN=2'd2;

  // ================= 基准时长：根据模式选择不同来源 =================
  // 自适应模式：使用内置参数BASE_*（不受UART影响）
  // 固定模式：使用cfg_*（UART配置）
  wire [7:0] base_LRS = mode_adapt_sw ? BASE_S : cfg_LRS;
  wire [7:0] base_LRL = mode_adapt_sw ? BASE_L : cfg_LRL;
  wire [7:0] base_LRR = mode_adapt_sw ? BASE_R : cfg_LRR;
  wire [7:0] base_TBS = mode_adapt_sw ? BASE_S : cfg_TBS;
  wire [7:0] base_TBL = mode_adapt_sw ? BASE_L : cfg_TBL;
  wire [7:0] base_TBR = mode_adapt_sw ? BASE_R : cfg_TBR;

  // ====== ��ʱ�Ĵ�����ԭʼ/��һ�ģ�======  -- ��ڶ��ݱ���ͬ��ͬ����?
  reg [7:0] add_S_LR, add_L_LR, add_R_LR;
  reg [7:0] add_S_TB, add_L_TB, add_R_TB;
  reg [7:0] n_add_S_LR, n_add_L_LR, n_add_R_LR;
  reg [7:0] n_add_S_TB, n_add_L_TB, n_add_R_TB;

  // === ģʽ�ſغ�ļ�ʱ���̶�ģʽ��?=0������Ӧ��= n_add_*��===
  wire [7:0] g_add_S_LR = mode_adapt_sw ? n_add_S_LR : 8'd0;
  wire [7:0] g_add_L_LR = mode_adapt_sw ? n_add_L_LR : 8'd0;
  wire [7:0] g_add_R_LR = mode_adapt_sw ? n_add_R_LR : 8'd0;
  wire [7:0] g_add_S_TB = mode_adapt_sw ? n_add_S_TB : 8'd0;
  wire [7:0] g_add_L_TB = mode_adapt_sw ? n_add_L_TB : 8'd0;
  wire [7:0] g_add_R_TB = mode_adapt_sw ? n_add_R_TB : 8'd0;

  // ====== ʱ�����̶�/����Ӧ�� ======
  reg [10:0] T0,T1,T2,T3,T4,T5,T6,T7,T8; // LR �̶���
  reg [10:0] U0,U1,U2,U3,U4,U5,U6,U7,U8; // TB �̶���
  reg [10:0] FULL_CYCLE;

  reg [10:0] A0,A1,A2,A3,A4,A5,A6,A7,A8; // LR ����Ӧ�� A
  reg [10:0] B0,B1,B2,B3,B4,B5,B6,B7,B8; // TB ����Ӧ�� B
  reg [10:0] FULL_CYCLE_ADAPT;

  reg [10:0] t_cnt;

  // ��ģ�ж�
  wire lr_many  = (mode_adapt_sw && (ped_n_lr >= PED_RT_TH));
  wire tb_many  = (mode_adapt_sw && (ped_n_tb >= PED_RT_TH));
  wire lr_small = (mode_adapt_sw && (ped_n_lr <  PED_RT_TH));
  wire tb_small = (mode_adapt_sw && (ped_n_tb <  PED_RT_TH));

  // �̶���λ�Ƿ�������ת�Σ��̶�ģʽ����ר����ת����
  wire rt_phase_enable_LR = (!mode_adapt_sw);
  wire rt_phase_enable_TB = (!mode_adapt_sw);

  // ����Ӧ�Ƿ����� A/B ����
  wire use_any_AB = (mode_adapt_sw && (lr_small || tb_small));

  function in_range; input [10:0] s0, s1, x; begin in_range = (x>=s0) && (x<s1); end endfunction
  function [7:0] clamp_right; input [7:0] val; begin clamp_right = (val < MIN_RIGHT) ? MIN_RIGHT : val; end endfunction

  // ====== ѡ�� ======
  wire useA_LR = (mode_adapt_sw && lr_small);
  wire useB_TB = (mode_adapt_sw && tb_small);

  wire lr_in_S = useA_LR ? in_range(A0,A1,t_cnt) : in_range(T0,T1,t_cnt);
  wire lr_in_L = useA_LR ? in_range(A3,A4,t_cnt) : in_range(T3,T4,t_cnt);
  wire tb_in_S = useB_TB ? in_range(B0,B1,t_cnt) : in_range(U0,U1,t_cnt);
  wire tb_in_L = useB_TB ? in_range(B3,B4,t_cnt) : in_range(U3,U4,t_cnt);

  // ====== ʱ��/��ʱ���㣺ֻ�� sec_tick ���£�����ڶ��ݵĽ���? ======
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      t_cnt <= 0;

      add_S_LR<=0; add_L_LR<=0; add_R_LR<=0;
      add_S_TB<=0; add_L_TB<=0; add_R_TB<=0;
      n_add_S_LR<=0; n_add_L_LR<=0; n_add_R_LR<=0;
      n_add_S_TB<=0; n_add_L_TB<=0; n_add_R_TB<=0;

      // �ϵ�Ĭ�ϣ�����������λ��ܿ�ᱻ base_* + g_add_* ����
      T0<=0;
      T1<=BASE_S;
      T2<=BASE_S+T_YEL;
      T3<=BASE_S+T_YEL;
      T4<=BASE_S+T_YEL+BASE_L;
      T5<=BASE_S+T_YEL+BASE_L+T_YEL;
      T6<=BASE_S+T_YEL+BASE_L+T_YEL;
      T7<=BASE_S+T_YEL+BASE_L+T_YEL+BASE_R;
      T8<=BASE_S+T_YEL+BASE_L+T_YEL+BASE_R+T_YEL;

      U0<=BASE_S+BASE_L+BASE_R+3*T_YEL;
      U1<=2*BASE_S+BASE_L+BASE_R+3*T_YEL;
      U2<=2*BASE_S+BASE_L+BASE_R+4*T_YEL;
      U3<=2*BASE_S+BASE_L+BASE_R+4*T_YEL;
      U4<=2*BASE_S+2*BASE_L+BASE_R+4*T_YEL;
      U5<=2*BASE_S+2*BASE_L+BASE_R+5*T_YEL;
      U6<=2*BASE_S+2*BASE_L+BASE_R+5*T_YEL;
      U7<=2*BASE_S+2*BASE_L+2*BASE_R+5*T_YEL;
      U8<=2*(BASE_S+BASE_L+BASE_R+3*T_YEL);
      FULL_CYCLE<=2*(BASE_S+BASE_L+BASE_R+3*T_YEL);

      A0<=0;
      A1<=BASE_S;
      A2<=BASE_S+T_YEL;
      A3<=BASE_S+T_YEL;
      A4<=BASE_S+T_YEL+BASE_L;
      A5<=BASE_S+T_YEL+BASE_L+T_YEL;
      A6<=BASE_S+T_YEL+BASE_L+T_YEL;
      A7<=BASE_S+T_YEL+BASE_L+T_YEL+BASE_R;
      A8<=BASE_S+T_YEL+BASE_L+T_YEL+BASE_R+T_YEL;

      B0<=BASE_S+BASE_L+BASE_R+3*T_YEL;
      B1<=2*BASE_S+BASE_L+BASE_R+3*T_YEL;
      B2<=2*BASE_S+BASE_L+BASE_R+4*T_YEL;
      B3<=2*BASE_S+BASE_L+BASE_R+4*T_YEL;
      B4<=2*BASE_S+2*BASE_L+BASE_R+4*T_YEL;
      B5<=2*BASE_S+2*BASE_L+BASE_R+5*T_YEL;
      B6<=2*BASE_S+2*BASE_L+BASE_R+5*T_YEL;
      B7<=2*BASE_S+2*BASE_L+2*BASE_R+5*T_YEL;
      B8<=2*(BASE_S+BASE_L+BASE_R+3*T_YEL);
      FULL_CYCLE_ADAPT<=2*(BASE_S+BASE_L+BASE_R+3*T_YEL);
    end
    else if (sec_tick) begin
      // ���ڼ���
      if (t_cnt >= ((use_any_AB ? FULL_CYCLE_ADAPT : FULL_CYCLE) - 1)) t_cnt <= 0;
      else t_cnt <= t_cnt + 11'd1;

      // 1) ����ƫ�� + 2) ����Ӱ�죺������Ӧģʽ��Ч���̶�ģʽȫ���� 0
      if (mode_adapt_sw) begin
        // ����ƫ��
        n_add_S_LR = (car_bias==2'b01) ? EXT_BIG   : (car_bias==2'b10 ? 8'd0 : EXT_SMALL);
        n_add_L_LR = (car_bias==2'b01) ? EXT_SMALL : 8'd0;
        n_add_R_LR = (car_bias==2'b01) ? EXT_SMALL : 8'd0;

        n_add_S_TB = (car_bias==2'b10) ? EXT_BIG   : (car_bias==2'b01 ? 8'd0 : EXT_SMALL);
        n_add_L_TB = (car_bias==2'b10) ? EXT_SMALL : 8'd0;
        n_add_R_TB = (car_bias==2'b10) ? EXT_SMALL : 8'd0;

        // ����Ӱ��
        if (ped_has_lr) begin
          n_add_S_TB = n_add_S_TB + PED_EXT_S;
          n_add_R_LR = (n_add_R_LR >= PED_RT_CUT) ? (n_add_R_LR - PED_RT_CUT) : 8'd0;
        end
        if (ped_has_tb) begin
          n_add_S_LR = n_add_S_LR + PED_EXT_S;
          n_add_R_TB = (n_add_R_TB >= PED_RT_CUT) ? (n_add_R_TB - PED_RT_CUT) : 8'd0;
        end

        if (ped_n_lr >= PED_RT_TH) n_add_R_LR = 8'd0;
        if (ped_n_tb >= PED_RT_TH) n_add_R_TB = 8'd0;
      end else begin
        n_add_S_LR = 8'd0; n_add_L_LR = 8'd0; n_add_R_LR = 8'd0;
        n_add_S_TB = 8'd0; n_add_L_TB = 8'd0; n_add_R_TB = 8'd0;
      end

      // 3) ���� -- ��ڶ���һ�£���Ȼ����õ��� g_add_*��
      add_S_LR <= n_add_S_LR; add_L_LR <= n_add_L_LR; add_R_LR <= n_add_R_LR;
      add_S_TB <= n_add_S_TB; add_L_TB <= n_add_L_TB; add_R_TB <= n_add_R_TB;

      // 4) �̶����� T/U��ʹ�� base_* + g_add_*��
      T0 <= 11'd0;
      T1 <= 11'd0 + ({3'd0,base_LRS} + {3'd0,g_add_S_LR});
      T2 <= T1 + T_YEL;

      T3 <= T2;
      T4 <= T3 + ({3'd0,base_LRL} + {3'd0,g_add_L_LR});
      T5 <= T4 + T_YEL;

      if (rt_phase_enable_LR) begin
        T6 <= T5;
        T7 <= T6 + (lr_small ? 11'd0 : {3'd0,clamp_right(base_LRR + g_add_R_LR)});
        T8 <= T7 + (lr_small ? 11'd0 : T_YEL);
      end else begin
        T6 <= T5; T7 <= T6; T8 <= T7;
      end

      U0 <= T8;
      U1 <= U0 + ({3'd0,base_TBS} + {3'd0,g_add_S_TB});
      U2 <= U1 + T_YEL;

      U3 <= U2;
      U4 <= U3 + ({3'd0,base_TBL} + {3'd0,g_add_L_TB});
      U5 <= U4 + T_YEL;

      if (rt_phase_enable_TB) begin
        U6 <= U5;
        U7 <= U6 + (tb_small ? 11'd0 : {3'd0,clamp_right(base_TBR + g_add_R_TB)});
        U8 <= U7 + (tb_small ? 11'd0 : T_YEL);
      end else begin
        U6 <= U5; U7 <= U6; U8 <= U7;
      end

      FULL_CYCLE <= U8;

      // 5) ����Ӧ���� A/B��ͬ���� base_* + g_add_*��
      A0 <= 11'd0;
      A1 <= 11'd0 + ({3'd0,base_LRS} + {3'd0,g_add_S_LR});
      A2 <= A1 + T_YEL;

      A3 <= A2;
      A4 <= A3 + ({3'd0,base_LRL} + {3'd0,g_add_L_LR});
      A5 <= A4 + T_YEL;

      if (lr_small) begin
        A6 <= A5; A7 <= A6; A8 <= A7;
      end else begin
        A6 <= A5; A7 <= A6 + {3'd0,clamp_right(base_LRR + g_add_R_LR)}; A8 <= A7 + T_YEL;
      end

      B0 <= A8;
      B1 <= B0 + ({3'd0,base_TBS} + {3'd0,g_add_S_TB});
      B2 <= B1 + T_YEL;

      B3 <= B2;
      B4 <= B3 + ({3'd0,base_TBL} + {3'd0,g_add_L_TB});
      B5 <= B4 + T_YEL;

      if (tb_small) begin
        B6 <= B5; B7 <= B6; B8 <= B7;
      end else begin
        B6 <= B5; B7 <= B6 + {3'd0,clamp_right(base_TBR + g_add_R_TB)}; B8 <= B7 + T_YEL;
      end

      FULL_CYCLE_ADAPT <= B8;
    end
  end

  // ====== ��ת mini-FSM���¼�ʱ�ӣ�sec_tick �� �����뿪�½��أ� ======
  localparam [1:0] RT_G=2'd0, RT_Y=2'd1, RT_R=2'd2;

  // LR
  reg [1:0] rtLR_state; reg [7:0] rtLR_sec, rtLR_g_sec;
  reg       ped_has_lr_d, ped_active_lr_d;
  reg [3:0] ped_on_cnt_lr;

  // TB
  reg [1:0] rtTB_state; reg [7:0] rtTB_sec, rtTB_g_sec;
  reg       ped_has_tb_d, ped_active_tb_d;
  reg [3:0] ped_on_cnt_tb;

  // �� small �������� S/L ����ʱ���� mini-FSM����ڶ���ͬ����?
  wire lr_fsm_enable = (mode_adapt_sw && lr_small && (lr_in_S || lr_in_L));
  wire tb_fsm_enable = (mode_adapt_sw && tb_small && (tb_in_S || tb_in_L));

  // ȥ��/��С����
  wire ped_on_ok_lr  = (ped_on_cnt_lr >= PED_ON_DB_S);
  wire min_g_ok_lr   = (rtLR_g_sec    >= MIN_RIGHT_FREE);
  wire ped_on_ok_tb  = (ped_on_cnt_tb >= PED_ON_DB_S);
  wire min_g_ok_tb   = (rtTB_g_sec    >= MIN_RIGHT_FREE);

  // �½��أ���ʵʱռ�ã�
  wire lr_fall_edge = (ped_active_lr_d==1'b1) && (ped_active_lr==1'b0);
  wire tb_fall_edge = (ped_active_tb_d==1'b1) && (ped_active_tb==1'b0);

  // �¼�ʱ��
  wire lr_event_tick = sec_tick | lr_fall_edge;
  wire tb_event_tick = sec_tick | tb_fall_edge;

  // ������ֻ�� sec_tick��ת�ƣ��� event_tick��������Ӧ��
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      rtLR_state<=RT_G; rtLR_sec<=0; rtLR_g_sec<=0; ped_on_cnt_lr<=0;
      rtTB_state<=RT_G; rtTB_sec<=0; rtTB_g_sec<=0; ped_on_cnt_tb<=0;
      ped_has_lr_d<=0; ped_active_lr_d<=0;
      ped_has_tb_d<=0; ped_active_tb_d<=0;
    end else begin
      // ���������ؼ��?
      ped_has_lr_d    <= ped_has_lr;
      ped_active_lr_d <= ped_active_lr;
      ped_has_tb_d    <= ped_has_tb;
      ped_active_tb_d <= ped_active_tb;

      // ����ֻ�� sec_tick
      if (sec_tick) begin
        // LR
        rtLR_sec   <= (rtLR_sec==8'hFF) ? rtLR_sec : (rtLR_sec + 1'b1);
        rtLR_g_sec <= (rtLR_state==RT_G) ? ((rtLR_g_sec==8'hFF)?rtLR_g_sec:(rtLR_g_sec+1'b1)) : 0;
        if (lr_fsm_enable)
          ped_on_cnt_lr <= ped_active_lr ? ((ped_on_cnt_lr < PED_ON_DB_S)?(ped_on_cnt_lr+1'b1):ped_on_cnt_lr) : 0;
        else ped_on_cnt_lr <= 0;

        // TB
        rtTB_sec   <= (rtTB_sec==8'hFF) ? rtTB_sec : (rtTB_sec + 1'b1);
        rtTB_g_sec <= (rtTB_state==RT_G) ? ((rtTB_g_sec==8'hFF)?rtTB_g_sec:(rtTB_g_sec+1'b1)) : 0;
        if (tb_fsm_enable)
          ped_on_cnt_tb <= ped_active_tb ? ((ped_on_cnt_tb < PED_ON_DB_S)?(ped_on_cnt_tb+1'b1):ped_on_cnt_tb) : 0;
        else ped_on_cnt_tb <= 0;
      end

      // ===== LR ״̬�����¼�ʱ������ =====
      if (lr_event_tick) begin
        if (lr_fsm_enable) begin
          case (rtLR_state)
            RT_G: begin
              if (lr_in_S && ped_on_ok_lr && min_g_ok_lr) begin
                rtLR_state <= RT_Y;
                rtLR_sec   <= 0; // ������ƵƼ���?
              end
            end
            RT_Y: begin
              if (sec_tick && (rtLR_sec >= RTY_S)) begin
                rtLR_state <= RT_R;
                rtLR_sec   <= 0;
              end
            end
            RT_R: begin
              // �ؼ�������һ�뿪����ֱ�д����ˣ�����ת�̣����� sec_tick
              if (lr_in_L || !ped_has_lr || !ped_active_lr || (lr_in_S && !ped_active_lr)) begin
                rtLR_state <= RT_G;
                rtLR_sec   <= 0;   // �������㣬�������?
                rtLR_g_sec <= 0;   // �������㣬MIN ���¼�
              end
            end
          endcase
        end else begin
          rtLR_state <= RT_G;
          rtLR_sec   <= 0;
        end
      end

      // ===== TB ״̬�����¼�ʱ������ =====
      if (tb_event_tick) begin
        if (tb_fsm_enable) begin
          case (rtTB_state)
            RT_G: begin
              if (tb_in_S && ped_on_ok_tb && min_g_ok_tb) begin
                rtTB_state <= RT_Y;
                rtTB_sec   <= 0;
              end
            end
            RT_Y: begin
              if (sec_tick && (rtTB_sec >= RTY_S)) begin
                rtTB_state <= RT_R;
                rtTB_sec   <= 0;
              end
            end
            RT_R: begin
              if (tb_in_L || !ped_has_tb || !ped_active_tb || (tb_in_S && !ped_active_tb)) begin
                rtTB_state <= RT_G;
                rtTB_sec   <= 0;
                rtTB_g_sec <= 0;
              end
            end
          endcase
        end else begin
          rtTB_state <= RT_G;
          rtTB_sec   <= 0;
        end
      end
    end
  end

  wire [1:0] rtLR_col = (rtLR_state==RT_G)?C_GRN : (rtLR_state==RT_Y)?C_YEL : C_RED;
  wire [1:0] rtTB_col = (rtTB_state==RT_G)?C_GRN : (rtTB_state==RT_Y)?C_YEL : C_RED;

  // ====== ��ɫ��ϣ���ڶ���һ�£� ======
  always @(*) begin
    // ȱʡȫ��
    col_LR_S = C_RED;  col_LR_L = C_RED;  col_LR_R = C_RED;
    col_TB_S = C_RED;  col_TB_L = C_RED;  col_TB_R = C_RED;

    // ֱ/��
    if (mode_adapt_sw && lr_small) begin
      if      (in_range(A0, A1, t_cnt)) col_LR_S = C_GRN;
      else if (in_range(A1, A2, t_cnt)) col_LR_S = C_YEL;
      if      (in_range(A3, A4, t_cnt)) col_LR_L = C_GRN;
      else if (in_range(A4, A5, t_cnt)) col_LR_L = C_YEL;
    end else begin
      if      (in_range(T0, T1, t_cnt)) col_LR_S = C_GRN;
      else if (in_range(T1, T2, t_cnt)) col_LR_S = C_YEL;
      if      (in_range(T3, T4, t_cnt)) col_LR_L = C_GRN;
      else if (in_range(T4, T5, t_cnt)) col_LR_L = C_YEL;
    end

    if (mode_adapt_sw && tb_small) begin
      if      (in_range(B0, B1, t_cnt)) col_TB_S = C_GRN;
      else if (in_range(B1, B2, t_cnt)) col_TB_S = C_YEL;
      if      (in_range(B3, B4, t_cnt)) col_TB_L = C_GRN;
      else if (in_range(B4, B5, t_cnt)) col_TB_L = C_YEL;
    end else begin
      if      (in_range(U0, U1, t_cnt)) col_TB_S = C_GRN;
      else if (in_range(U1, U2, t_cnt)) col_TB_S = C_YEL;
      if      (in_range(U3, U4, t_cnt)) col_TB_L = C_GRN;
      else if (in_range(U4, U5, t_cnt)) col_TB_L = C_YEL;
    end

    // ��ת��many ����ת��small ��ֱ�д��� mini-FSM
    if (!mode_adapt_sw) begin
      if      (in_range(T6, T7, t_cnt)) col_LR_R = C_GRN;
      else if (in_range(T7, T8, t_cnt)) col_LR_R = C_YEL;

      if      (in_range(U6, U7, t_cnt)) col_TB_R = C_GRN;
      else if (in_range(U7, U8, t_cnt)) col_TB_R = C_YEL;
    end else begin
      if (lr_many) begin
        if      (in_range(T3, T4, t_cnt)) col_LR_R = C_GRN;
        else if (in_range(T4, T5, t_cnt)) col_LR_R = C_YEL;
        else                              col_LR_R = C_RED;
      end else begin
        if      (lr_in_L) col_LR_R = C_GRN;
        else if (lr_in_S) col_LR_R = rtLR_col;
        else              col_LR_R = C_RED;
      end

      if (tb_many) begin
        if      (in_range(U3, U4, t_cnt)) col_TB_R = C_GRN;
        else if (in_range(U4, U5, t_cnt)) col_TB_R = C_YEL;
        else                              col_TB_R = C_RED;
      end else begin
        if      (tb_in_L) col_TB_R = C_GRN;
        else if (tb_in_S) col_TB_R = rtTB_col;
        else              col_TB_R = C_RED;
      end
    end

    // ========== ��ȫ���� ==========
    if ((col_LR_S==C_RED) && (col_LR_L==C_RED) && (col_LR_R==C_RED)
     && (col_TB_S==C_RED) && (col_TB_L==C_RED) && (col_TB_R==C_RED)) begin
      col_LR_S = C_GRN;
    end

    // ========== ˫��СС���������ˣ�˫����תһ���? ==========
    if (mode_adapt_sw && lr_small && tb_small && !ped_has_lr && !ped_has_tb) begin
      col_LR_R = C_GRN; col_TB_R = C_GRN;
    end
  end

  // ====== �̵�ʱ�����? ======
  // ע���̶�ģʽ�� g_add_* = 0����˴˴���ʾ�ľ���? base_*��
  //     ����Ӧ����ʾ base_* + �Ѽ���ļӳɣ�S/L����R �ڹ̶�ģʽ�²���Ч����
  assign green_sec_LR_S = base_LRS + g_add_S_LR;
  assign green_sec_LR_L = base_LRL + g_add_L_LR;
  assign green_sec_LR_R = (!mode_adapt_sw) ? (base_LRR + g_add_R_LR) : 8'd0;

  assign green_sec_TB_S = base_TBS + g_add_S_TB;
  assign green_sec_TB_L = base_TBL + g_add_L_TB;
  assign green_sec_TB_R = (!mode_adapt_sw) ? (base_TBR + g_add_R_TB) : 8'd0;

endmodule
