// vga_pic.v - ����λ��ɫ������λ��+ �������� + �೵������ + ��ƿ�ֹͣ��ͣ��? + ״̬ɫ�� + ģʽɫ�� + ������(people_count)
`timescale 1ns/1ps
module vga_pic(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    // �����ĵ� = ��·��
    input  wire        main_R,
    input  wire        main_Y,
    input  wire        main_G,
    // ���˿��ĵ� = ��·��
    input  wire        side_R,
    input  wire        side_Y,
    input  wire        side_G,
    // ������λ/����
    input  wire [9:0]  car_x,
    input  wire [9:0]  ped_y,
    // �ƿ�״̬�����Ͻ�16x16Сɫ�飩
    input  wire [2:0]  tl_state,

    // --- �������ƣ����Զ���/ģʽӳ�䣩 ---
    input  wire [7:0]  car_count_up,      // ���г����� (0..N_UP)
    input  wire [7:0]  car_count_down,    // ���г����� (0..N_DN)
    input  wire [7:0]  people_count,      // ������ (0..MAX_PED)
    input  wire [7:0]  walk_time_sec,     // ��ǰ过街计时（秒�?
    input  wire [3:0]  eff_tens,          // Ч��ʮλ (0~9)
    input  wire [3:0]  eff_ones,          // Ч����λ (0~9)
    input  wire [3:0]  eff_frac,          // Ч��Сλ (0~9)

    // ģʽ�ţ��������Ͻ�16x16ɫ����ʾ��0=LOW 1=NORMAL 2=MANY��
    input  wire [1:0]  modenum,

    // ��ѡ����������"ʱ����λ"����������Ҳ���ڱ��ļ�����? localparam��
    input  wire [9:0]  ped_phase_step,

    output reg  [15:0] pix_data
);
    // Compatibility placeholders for the reverted display experiment.
    wire [1:0] tidal_dir = 2'd0;
    wire [1:0] congestion_level = 2'd0;
    wire [7:0] speed_limit = 8'd0;
    // ����ɫ
    localparam BLACK = 16'h0000, WHITE=16'hFFFF, YELLOW=16'hFFE0, RED=16'hF800, GREEN=16'h07E0;

    // �ֱ���
    localparam H_VALID=10'd640, V_VALID=10'd480;

    // ��·������
    localparam Y_TOP=10'd190, Y_BOTTOM=10'd310;
    localparam SIDE_H=10'd3, MID_H=10'd2;
    localparam Y_MID=(Y_TOP+Y_BOTTOM)>>1;
    localparam H_DASH_PERIOD=10'd64, H_DASH_ON=10'd24;

    // ��·����ֱ��
    localparam X_LEFT = 10'd300, X_RIGHT=10'd340;
    localparam V_SIDE_W = 10'd3;
    localparam X_MID  = (X_LEFT + X_RIGHT) >> 1;
    localparam V_DASH_PERIOD = 10'd64, V_DASH_ON = 10'd24;

    // �೵�����������룩
    localparam integer N_UP = 15, N_DN = 15;
    localparam integer SP_BASE = 96;
    localparam [9:0]  CAR_W=10'd20, CAR_H=10'd12;
    localparam [9:0]  UP_Y_MIN = Y_TOP + 10'd6, UP_Y_MAX = Y_MID - 10'd10;
    localparam [9:0]  DN_Y_MIN = Y_MID + 10'd4, DN_Y_MAX = Y_BOTTOM - 10'd8;

    // ֹͣ�ߣ����ͣ����?
    localparam [9:0] STOP_X_L = 10'd280; // �³���������ֹͣ�ߣ������е����?
    localparam [9:0] STOP_X_R = 10'd360; // �ϳ���������ֹͣ�ߣ������е��Ҳࣩ
    localparam [9:0] NEAR_WIN = 10'd28;

    // �����ж�
    wire in_area   = (pix_x < H_VALID) && (pix_y < V_VALID);
    wire top_side  = (pix_y >= (Y_TOP    - SIDE_H)) && (pix_y <= (Y_TOP    + SIDE_H));
    wire bot_side  = (pix_y >= (Y_BOTTOM - SIDE_H)) && (pix_y <= (Y_BOTTOM + SIDE_H));
    wire left_side = (pix_x >= (X_LEFT   - V_SIDE_W)) && (pix_x <= (X_LEFT   + V_SIDE_W));
    wire right_side= (pix_x >= (X_RIGHT  - V_SIDE_W)) && (pix_x <= (X_RIGHT  + V_SIDE_W));
    wire h_mid_band= (pix_y >= (Y_MID    - MID_H)) && (pix_y <= (Y_MID    + MID_H));
    // H_DASH_PERIOD=64, so the low six bits are the exact remainder.
    wire h_dash_on = (pix_x[5:0] < H_DASH_ON);
    wire v_mid_band= 1'b0;
    wire v_dash_on = 1'b0; 

    // ���ˣ�СԲ��
    localparam PED_R = 10'd5;

    // ��ֱ��·�ڲ��ĺ��������������?+2���ذ�ȫ�ߣ�
    localparam [9:0] PED_MARGIN = PED_R + 10'd2;
    localparam [9:0] INNER_L = X_LEFT  + PED_MARGIN;
    localparam [9:0] INNER_R = X_RIGHT - PED_MARGIN;
    localparam [9:0] INNER_W = INNER_R - INNER_L;
    // ����"���Ұڶ�"�ĺ������ǲ��������Ը��ã�
    wire [5:0] s      = ped_y[5:0];                 // 0..63
    wire [4:0] tri_v  = s[5] ? (5'd31 - s[4:0])     // 0..31..0
                             :  s[4:0];
    wire [10:0] mult  = tri_v * INNER_W;            // �� 31 * (INNER_W)
    wire [9:0]  offset= (mult + 5'd15) >> 5;        // Լ���� /32
    wire [9:0]  PED_X_dyn = INNER_L + offset;       // Բ��X�����˲ο���

    // ����Բ�ж����ο��棩
    wire signed [11:0] dx_ref = $signed({1'b0,pix_x}) - $signed({1'b0,PED_X_dyn});
    wire signed [11:0] dy_ref = $signed({1'b0,pix_y})  - $signed({1'b0,ped_y});
   // wire [23:0] dx2_ref = $signed(dx_ref) * $signed(dx_ref);
    //wire [23:0] dy2_ref = $signed(dy_ref) * $signed(dy_ref);
    //wire [24:0] sum2_ref = {1'b0,dx2_ref} + {1'b0,dy2_ref};
    //wire [19:0] r2_20 = PED_R * PED_R;
    //wire [24:0] r2_25 = {5'b0, r2_20};
    //wire inPedCircle_ref = (sum2_ref <= r2_25); // �����ο�������ֱ��ʹ��

    // ===== ����λ����Ųλ�ã�=====
    localparam LAMP_W = 10'd14, LAMP_H = 10'd14;

    // �����ĵƣ����ƣ���·�м������?
    localparam CAR_LAMP_X0 = (H_VALID>>1) - (LAMP_W>>1);  // ˮƽ����
    localparam CAR_LAMP_X1 = CAR_LAMP_X0 + LAMP_W;
    localparam CAR_LAMP_Y0 = Y_MID - (LAMP_H>>1);  // ��·�м�?
    localparam CAR_LAMP_Y1 = CAR_LAMP_Y0 + LAMP_H;

    // ���˿��ĵƣ���ƣ��������е��Ҳ࣬λ�ù̶�?
    localparam PED_LAMP_X0 = X_RIGHT + 10'd6;
    localparam PED_LAMP_X1 = PED_LAMP_X0 + LAMP_W;
    localparam PED_LAMP_Y0 = Y_TOP - 10'd20;
    localparam PED_LAMP_Y1 = PED_LAMP_Y0 + LAMP_H;

    wire inLampCar = (pix_x>=CAR_LAMP_X0 && pix_x<CAR_LAMP_X1) && (pix_y>=CAR_LAMP_Y0 && pix_y<CAR_LAMP_Y1);
    wire inLampPed = (pix_x>=PED_LAMP_X0 && pix_x<PED_LAMP_X1) && (pix_y>=PED_LAMP_Y0 && pix_y<PED_LAMP_Y1);

    // ��ɫ���������ȼ� G>Y>R��
    function [15:0] color_from_main; input mr,my,mg;
        begin
            if(mg)      color_from_main = GREEN;
            else if(my) color_from_main = YELLOW;
            else        color_from_main = RED;
        end
    endfunction
    function [15:0] color_from_side; input sr,sy,sg;
        begin
            if(sg)      color_from_side = GREEN;
            else if(sy) color_from_side = YELLOW;
            else        color_from_side = RED;
        end
    endfunction

    // �೵λ�ã������� + ��ƿ�ֹͣ��ͣ����?
    function [9:0] wrap640; input [10:0] v; begin wrap640 = (v>=11'd640)? (v-11'd640) : v[9:0]; end endfunction
    function [9:0] wrap480; input [10:0] v; begin wrap480 = (v>=11'd480)? (v-11'd480) : v[9:0]; end endfunction

    reg [9:0] car_up_x [0:N_UP-1], car_up_y [0:N_UP-1];
    reg [9:0] car_dn_x [0:N_DN-1], car_dn_y [0:N_DN-1];
    reg [10:0] acc_dn, acc_up;
    integer i, k;
    function [10:0] dn_spacing; input integer idx; begin dn_spacing = (SP_BASE + ((idx*37 + 11) % 29)); end endfunction
    function [10:0] up_spacing; input integer idx; begin up_spacing = (SP_BASE + ((idx*31 +  7) % 27)); end endfunction
    function [9:0]  dn_yoff;    input integer idx; integer r; begin r=(DN_Y_MAX>DN_Y_MIN)?(DN_Y_MAX-DN_Y_MIN):1; dn_yoff = DN_Y_MIN + ((idx*17 + 23)%r); end endfunction
    function [9:0]  up_yoff;    input integer idx; integer r; begin r=(UP_Y_MAX>UP_Y_MIN)?(UP_Y_MAX-UP_Y_MIN):1; up_yoff = UP_Y_MIN + ((idx*19 + 13)%r); end endfunction

    always @* begin
        // �³���������
        acc_dn = 11'd0;
        for(i=0;i<N_DN;i=i+1) begin
            car_dn_x[i] = wrap640({1'b0,car_x} + acc_dn);
            car_dn_y[i] = dn_yoff(i);
            if (main_R) begin
                if ( (car_dn_x[i] + CAR_W > STOP_X_L) && (car_dn_x[i] + CAR_W <= STOP_X_L + NEAR_WIN) )
                    car_dn_x[i] = (STOP_X_L - CAR_W);
            end
            acc_dn = acc_dn + dn_spacing(i);
        end
        // �ϳ���������
        acc_up = 11'd40;
        for(i=0;i<N_UP;i=i+1) begin
            car_up_x[i] = 10'd639 - wrap640({1'b0,car_x} + acc_up);
            car_up_y[i] = up_yoff(i);
            if (main_R) begin
                if ( (car_up_x[i] < STOP_X_R) && (car_up_x[i] + NEAR_WIN >= STOP_X_R) )
                    car_up_x[i] = STOP_X_R;
            end
            acc_up = acc_up + up_spacing(i);
        end
    end

    // -- ���Ͻǣ���ͨ��״̬Сɫ�飨16x16�� --
    // 调试小方块已移除

    // ================= м�? =================
function [0:0] diamond_hit_xy;
  input [9:0] cx, cy; reg [10:0] dx, dy, md;
  begin
    dx = (pix_x > cx) ? (pix_x - cx) : (cx - pix_x);
    dy = (pix_y > cy) ? (pix_y - cy) : (cy - pix_y);
    md = dx + dy;
    // PED_R �� 10 λ������md 11 λ������Ƚ�? OK���ۺ�Ϊ����չ��
    diamond_hit_xy = (md <= PED_R);
  end
endfunction
    // -- �����ˣ���"�����߷�"��ɺ���? + for �ۺ� --
    localparam integer MAX_PED = 32; // ��Դ���ޣ��ɰ������?

// === �����ˣ����������У��滻ԭ is_ped_circle_for_phase��===
function [0:0] is_ped_circle_for_phase;   // ���ֿɱ������Ķ����ô�
    input [9:0] phase;               // ����˵�ʱ����λƫ��?
    reg  [9:0] ped_y_i;
    reg  [5:0] s_i;
    reg  [4:0] tri_i;
    reg  [10:0] mult_i;
    reg  [9:0]  off_i;
    reg  [9:0]  ped_x_i;
begin
    // 1) y = ԭʼ ped_y + ��λ������ 0..479��
    ped_y_i = wrap480({1'b0,ped_y} + phase);

    // 2) x = ���ǲ����? �� [INNER_L..INNER_R]
    s_i     = ped_y_i[5:0];
    tri_i   = s_i[5] ? (5'd31 - s_i[4:0]) : s_i[4:0];
    mult_i  = tri_i * INNER_W;
    off_i   = (mult_i + 5'd15) >> 5;
    ped_x_i = INNER_L + off_i;

    // 3) �������У�|dx|+|dy| <= PED_R
    is_ped_circle_for_phase = diamond_hit_xy(ped_x_i, ped_y_i);
end
endfunction

    reg inPedAny;
    integer pi;
    always @* begin
        inPedAny = 1'b0;
        for (pi = 0; pi < MAX_PED; pi = pi + 1) begin
            if (pi < people_count) begin
                if (is_ped_circle_for_phase(pi * ped_phase_step))
                    inPedAny = 1'b1;
            end
        end
    end

    // ===================== 字符显示：行人数和车辆数 =====================
    // 显示位置（左上角�?
    localparam CHAR_W = 8, CHAR_H = 8, SPACE_W = 1;
    localparam TEXT_X = 10'd8;
    localparam TEXT_PEOPLE_Y = 10'd32;  // 在模式色块下�?
    localparam TEXT_CAR_Y = TEXT_PEOPLE_Y + CHAR_H + 2;
    localparam TEXT_WALK_Y = TEXT_CAR_Y + CHAR_H + 2;
    localparam TEXT_EFF_Y  = TEXT_WALK_Y + CHAR_H + 2;
    
    // 计算车辆总数
    wire [7:0] car_total = car_count_up + car_count_down;
    
    // "people:" 标签显示
    localparam TEXT_PEOPLE_LEN = 7;
    wire in_people_label = (pix_x >= TEXT_X) && (pix_x < TEXT_X + TEXT_PEOPLE_LEN*(CHAR_W+SPACE_W)) &&
                           (pix_y >= TEXT_PEOPLE_Y) && (pix_y < TEXT_PEOPLE_Y + CHAR_H);
    wire [9:0] people_label_col = pix_x - TEXT_X;
    wire [9:0] people_label_dy = pix_y - TEXT_PEOPLE_Y;
    wire [2:0] people_label_row = people_label_dy[2:0];
    wire [2:0] people_label_ch_idx = people_label_col / (CHAR_W + SPACE_W);
    wire [3:0] people_label_col_mod = people_label_col % (CHAR_W + SPACE_W);
    wire people_label_in_space = (people_label_col_mod >= CHAR_W);
    wire [2:0] people_label_col_in_char = CHAR_W - 1 - people_label_col_mod[2:0];
    
    wire [7:0] people_label_ch_ascii;
    wire [8*7-1:0] str_people_pack = "people:";
    assign people_label_ch_ascii = str_people_pack[8*(6-people_label_ch_idx) +: 8];
    
    wire [7:0] people_label_row_bits;
    font u_font_people_label(.ascii(people_label_ch_ascii), .row(people_label_row), .bits(people_label_row_bits));
    wire people_label_on = in_people_label && !people_label_in_space ? people_label_row_bits[people_label_col_in_char] : 1'b0;
    
    // 行人数数字显示（支持两位数）
    localparam PEOPLE_NUM_X = TEXT_X + TEXT_PEOPLE_LEN*(CHAR_W+SPACE_W);
    wire [3:0] people_tens = people_count / 10;
    wire [3:0] people_ones = people_count % 10;
    wire in_people_num = (pix_x >= PEOPLE_NUM_X) && (pix_x < PEOPLE_NUM_X + 2*(CHAR_W+SPACE_W)) &&
                         (pix_y >= TEXT_PEOPLE_Y) && (pix_y < TEXT_PEOPLE_Y + CHAR_H);
    wire [9:0] people_num_col = pix_x - PEOPLE_NUM_X;
    wire [9:0] people_num_dy = pix_y - TEXT_PEOPLE_Y;
    wire [2:0] people_num_row = people_num_dy[2:0];
    wire [1:0] people_num_ch_idx = people_num_col / (CHAR_W + SPACE_W);
    wire [3:0] people_num_col_mod = people_num_col % (CHAR_W + SPACE_W);
    wire people_num_in_space = (people_num_col_mod >= CHAR_W);
    wire [2:0] people_num_col_in_char = CHAR_W - 1 - people_num_col_mod[2:0];
    
    wire [7:0] people_num_ch_ascii;
    assign people_num_ch_ascii = (people_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, people_tens}) : (8'h30 + {1'b0, people_ones});
    
    wire [7:0] people_num_row_bits;
    font u_font_people_num(.ascii(people_num_ch_ascii), .row(people_num_row), .bits(people_num_row_bits));
    wire people_num_on = in_people_num && !people_num_in_space ? people_num_row_bits[people_num_col_in_char] : 1'b0;
    
    // "car:" 标签显示
    localparam TEXT_CAR_LEN = 4;
    wire in_car_label = (pix_x >= TEXT_X) && (pix_x < TEXT_X + TEXT_CAR_LEN*(CHAR_W+SPACE_W)) &&
                        (pix_y >= TEXT_CAR_Y) && (pix_y < TEXT_CAR_Y + CHAR_H);
    wire [9:0] car_label_col = pix_x - TEXT_X;
    wire [9:0] car_label_dy = pix_y - TEXT_CAR_Y;
    wire [2:0] car_label_row = car_label_dy[2:0];
    wire [2:0] car_label_ch_idx = car_label_col / (CHAR_W + SPACE_W);
    wire [3:0] car_label_col_mod = car_label_col % (CHAR_W + SPACE_W);
    wire car_label_in_space = (car_label_col_mod >= CHAR_W);
    wire [2:0] car_label_col_in_char = CHAR_W - 1 - car_label_col_mod[2:0];
    
    wire [7:0] car_label_ch_ascii;
    wire [8*4-1:0] str_car_pack = "car:";
    assign car_label_ch_ascii = str_car_pack[8*(3-car_label_ch_idx) +: 8];
    
    wire [7:0] car_label_row_bits;
    font u_font_car_label(.ascii(car_label_ch_ascii), .row(car_label_row), .bits(car_label_row_bits));
    wire car_label_on = in_car_label && !car_label_in_space ? car_label_row_bits[car_label_col_in_char] : 1'b0;
    
    // 车辆数数字显示（支持两位数）
    localparam CAR_NUM_X = TEXT_X + TEXT_CAR_LEN*(CHAR_W+SPACE_W);
    wire [3:0] car_tens = car_total / 10;
    wire [3:0] car_ones = car_total % 10;
    wire in_car_num = (pix_x >= CAR_NUM_X) && (pix_x < CAR_NUM_X + 2*(CHAR_W+SPACE_W)) &&
                      (pix_y >= TEXT_CAR_Y) && (pix_y < TEXT_CAR_Y + CHAR_H);
    wire [9:0] car_num_col = pix_x - CAR_NUM_X;
    wire [9:0] car_num_dy = pix_y - TEXT_CAR_Y;
    wire [2:0] car_num_row = car_num_dy[2:0];
    wire [1:0] car_num_ch_idx = car_num_col / (CHAR_W + SPACE_W);
    wire [3:0] car_num_col_mod = car_num_col % (CHAR_W + SPACE_W);
    wire car_num_in_space = (car_num_col_mod >= CHAR_W);
    wire [2:0] car_num_col_in_char = CHAR_W - 1 - car_num_col_mod[2:0];
    
    wire [7:0] car_num_ch_ascii;
    assign car_num_ch_ascii = (car_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, car_tens}) : (8'h30 + {1'b0, car_ones});
    
    wire [7:0] car_num_row_bits;
    font u_font_car_num(.ascii(car_num_ch_ascii), .row(car_num_row), .bits(car_num_row_bits));
    wire car_num_on = in_car_num && !car_num_in_space ? car_num_row_bits[car_num_col_in_char] : 1'b0;

    // "walktime:" 标签显示
    localparam TEXT_WALK_LEN = 9;
    localparam WALK_NUM_CHARS = 3;
    localparam WALK_NUM_X = TEXT_X + TEXT_WALK_LEN*(CHAR_W+SPACE_W);
    wire in_walk_label = (pix_x >= TEXT_X) && (pix_x < TEXT_X + TEXT_WALK_LEN*(CHAR_W+SPACE_W)) &&
                         (pix_y >= TEXT_WALK_Y) && (pix_y < TEXT_WALK_Y + CHAR_H);
    wire [9:0] walk_label_col = pix_x - TEXT_X;
    wire [9:0] walk_label_dy  = pix_y - TEXT_WALK_Y;
    wire [2:0] walk_label_row = walk_label_dy[2:0];
    wire [3:0] walk_label_ch_idx = walk_label_col / (CHAR_W + SPACE_W);
    wire [3:0] walk_label_col_mod = walk_label_col % (CHAR_W + SPACE_W);
    wire walk_label_in_space = (walk_label_col_mod >= CHAR_W);
    wire [2:0] walk_label_col_in_char = CHAR_W - 1 - walk_label_col_mod[2:0];
    wire [8*9-1:0] str_walk_pack = "walktime:";
    wire [7:0] walk_label_ch_ascii = str_walk_pack[8*(8-walk_label_ch_idx) +: 8];
    wire [7:0] walk_label_row_bits;
    font u_font_walk_label(.ascii(walk_label_ch_ascii), .row(walk_label_row), .bits(walk_label_row_bits));
    wire walk_label_on = in_walk_label && !walk_label_in_space ? walk_label_row_bits[walk_label_col_in_char] : 1'b0;
    
    // walktime 数字显示（简化为 0~99 秒，节省 LUT）
    wire [7:0] walk_time_clamped = (walk_time_sec > 99) ? 8'd99 : walk_time_sec;
    wire [7:0] walk_tens_val = walk_time_clamped / 8'd10;
    wire [7:0] walk_ones_val = walk_time_clamped % 8'd10;
    wire [3:0] walk_tens_digit = walk_tens_val[3:0];
    wire [3:0] walk_ones_digit = walk_ones_val[3:0];
    
    wire in_walk_num = (pix_x >= WALK_NUM_X) && (pix_x < WALK_NUM_X + WALK_NUM_CHARS*(CHAR_W+SPACE_W)) &&
                       (pix_y >= TEXT_WALK_Y) && (pix_y < TEXT_WALK_Y + CHAR_H);
    wire [9:0] walk_num_col = pix_x - WALK_NUM_X;
    wire [9:0] walk_num_dy  = pix_y - TEXT_WALK_Y;
    wire [2:0] walk_num_row = walk_num_dy[2:0];
    wire [1:0] walk_num_ch_idx = walk_num_col / (CHAR_W + SPACE_W);
    wire [3:0] walk_num_col_mod = walk_num_col % (CHAR_W + SPACE_W);
    wire walk_num_in_space = (walk_num_col_mod >= CHAR_W);
    wire [2:0] walk_num_col_in_char = CHAR_W - 1 - walk_num_col_mod[2:0];
    wire [7:0] walk_num_ch_ascii =
        (walk_num_ch_idx == 2'd0) ? ((walk_tens_digit == 4'd0) ? 8'h20 : (8'h30 + {4'b0000, walk_tens_digit})) :
        (walk_num_ch_idx == 2'd1) ? (8'h30 + {4'b0000, walk_ones_digit}) :
                                     8'h73;  // 's'
    wire [7:0] walk_num_row_bits;
    font u_font_walk_num(.ascii(walk_num_ch_ascii), .row(walk_num_row), .bits(walk_num_row_bits));
    wire walk_num_on = in_walk_num && !walk_num_in_space ? walk_num_row_bits[walk_num_col_in_char] : 1'b0;
    
    // "efficiency:" 标签显示
    localparam TEXT_EFF_LEN = 11;
    localparam EFF_NUM_CHARS = 4;
    localparam EFF_NUM_X = TEXT_X + TEXT_EFF_LEN*(CHAR_W+SPACE_W);
    wire in_eff_label = (pix_x >= TEXT_X) && (pix_x < TEXT_X + TEXT_EFF_LEN*(CHAR_W+SPACE_W)) &&
                        (pix_y >= TEXT_EFF_Y) && (pix_y < TEXT_EFF_Y + CHAR_H);
    wire [9:0] eff_label_col = pix_x - TEXT_X;
    wire [9:0] eff_label_dy  = pix_y - TEXT_EFF_Y;
    wire [2:0] eff_label_row = eff_label_dy[2:0];
    wire [3:0] eff_label_ch_idx = eff_label_col / (CHAR_W + SPACE_W);
    wire [3:0] eff_label_col_mod = eff_label_col % (CHAR_W + SPACE_W);
    wire eff_label_in_space = (eff_label_col_mod >= CHAR_W);
    wire [2:0] eff_label_col_in_char = CHAR_W - 1 - eff_label_col_mod[2:0];
    wire [8*11-1:0] str_eff_pack = "efficiency:";
    wire [7:0] eff_label_ch_ascii = str_eff_pack[8*(10-eff_label_ch_idx) +: 8];
    wire [7:0] eff_label_row_bits;
    font u_font_eff_label(.ascii(eff_label_ch_ascii), .row(eff_label_row), .bits(eff_label_row_bits));
    wire eff_label_on = in_eff_label && !eff_label_in_space ? eff_label_row_bits[eff_label_col_in_char] : 1'b0;
    
    // efficiency 数字显示（直接使用传入的拆分数字，vga_colorbar已完成计算）
    wire [3:0] eff_int_tens = eff_tens;
    wire [3:0] eff_int_ones = eff_ones;
    wire [3:0] eff_frac_digit = eff_frac;
    
    wire in_eff_num = (pix_x >= EFF_NUM_X) && (pix_x < EFF_NUM_X + EFF_NUM_CHARS*(CHAR_W+SPACE_W)) &&
                      (pix_y >= TEXT_EFF_Y) && (pix_y < TEXT_EFF_Y + CHAR_H);
    wire [9:0] eff_num_col = pix_x - EFF_NUM_X;
    wire [9:0] eff_num_dy  = pix_y - TEXT_EFF_Y;
    wire [2:0] eff_num_row = eff_num_dy[2:0];
    wire [1:0] eff_num_ch_idx = eff_num_col / (CHAR_W + SPACE_W);
    wire [3:0] eff_num_col_mod = eff_num_col % (CHAR_W + SPACE_W);
    wire eff_num_in_space = (eff_num_col_mod >= CHAR_W);
    wire [2:0] eff_num_col_in_char = CHAR_W - 1 - eff_num_col_mod[2:0];
    wire [7:0] eff_num_ch_ascii =
        (eff_num_ch_idx == 2'd0) ? ((eff_int_tens == 4'd0) ? 8'h20 : (8'h30 + {4'b0000, eff_int_tens})) :
        (eff_num_ch_idx == 2'd1) ? (8'h30 + {4'b0000, eff_int_ones}) :
        (eff_num_ch_idx == 2'd2) ? 8'h2E :
                                   (8'h30 + {4'b0000, eff_frac_digit});
    wire [7:0] eff_num_row_bits;
    font u_font_eff_num(.ascii(eff_num_ch_ascii), .row(eff_num_row), .bits(eff_num_row_bits));
    wire eff_num_on = in_eff_num && !eff_num_in_space ? eff_num_row_bits[eff_num_col_in_char] : 1'b0;

    // First-stage display-only status overlay.
    localparam STATUS_Y0 = TEXT_EFF_Y + CHAR_H + 4;
    localparam STATUS_Y1 = STATUS_Y0 + CHAR_H + 2;
    localparam STATUS_Y2 = STATUS_Y1 + CHAR_H + 2;
    localparam STATUS_X = TEXT_X;
    localparam STATUS_LEVEL_NUM_X = STATUS_X + 6*(CHAR_W+SPACE_W);
    localparam STATUS_SPEED_NUM_X = STATUS_X + 6*(CHAR_W+SPACE_W);
    localparam STATUS_DIR_NUM_X = STATUS_X + 4*(CHAR_W+SPACE_W);

    function [7:0] status_char;
        input [8*14-1:0] pack_str;
        input [3:0] idx;
        begin status_char = pack_str[8*(13-idx) +: 8]; end
    endfunction
    localparam [8*14-1:0] STR_LEVEL = "level:        ";
    localparam [8*14-1:0] STR_SPEED = "speed:        ";
    localparam [8*14-1:0] STR_DIR   = "dir:          ";

    wire [9:0] status_col = pix_x - STATUS_X;
    wire [3:0] status_idx = status_col / (CHAR_W+SPACE_W);
    wire [3:0] status_mod = status_col % (CHAR_W+SPACE_W);
    wire [2:0] status_row0 = pix_y - STATUS_Y0;
    wire [2:0] status_row1 = pix_y - STATUS_Y1;
    wire [2:0] status_row2 = pix_y - STATUS_Y2;

    wire [7:0] level_label_ascii = status_char(STR_LEVEL, status_idx);
    wire [7:0] level_label_bits;
    font u_font_level_label(.ascii(level_label_ascii), .row(status_row0), .bits(level_label_bits));
    wire level_label_on = (pix_x >= STATUS_X) && (pix_x < STATUS_LEVEL_NUM_X) &&
                          (pix_y >= STATUS_Y0) && (pix_y < STATUS_Y0 + CHAR_H) &&
                          (status_mod < CHAR_W) && level_label_bits[CHAR_W-1-status_mod[2:0]];
    wire [7:0] level_num_bits;
    font u_font_level_num(.ascii(8'h30 + congestion_level), .row(status_row0), .bits(level_num_bits));
    wire level_num_on = (pix_x >= STATUS_LEVEL_NUM_X) &&
                        (pix_x < STATUS_LEVEL_NUM_X + CHAR_W) &&
                        (pix_y >= STATUS_Y0) && (pix_y < STATUS_Y0 + CHAR_H) &&
                        level_num_bits[CHAR_W-1-(pix_x-STATUS_LEVEL_NUM_X)];

    wire [7:0] speed_label_ascii = status_char(STR_SPEED, status_idx);
    wire [7:0] speed_label_bits;
    font u_font_speed_label(.ascii(speed_label_ascii), .row(status_row1), .bits(speed_label_bits));
    wire speed_label_on = (pix_x >= STATUS_X) && (pix_x < STATUS_SPEED_NUM_X) &&
                          (pix_y >= STATUS_Y1) && (pix_y < STATUS_Y1 + CHAR_H) &&
                          (status_mod < CHAR_W) && speed_label_bits[CHAR_W-1-status_mod[2:0]];
    wire [7:0] speed_tens_ascii = 8'h30 + ((speed_limit / 10) % 10);
    wire [7:0] speed_ones_ascii = 8'h30 + (speed_limit % 10);
    wire [3:0] speed_num_idx = (pix_x - STATUS_SPEED_NUM_X) / (CHAR_W+SPACE_W);
    wire [3:0] speed_num_mod = (pix_x - STATUS_SPEED_NUM_X) % (CHAR_W+SPACE_W);
    wire [7:0] speed_num_bits;
    font u_font_speed_num(.ascii((speed_num_idx == 0) ? speed_tens_ascii : speed_ones_ascii),
                          .row(status_row1), .bits(speed_num_bits));
    wire speed_num_on = (pix_x >= STATUS_SPEED_NUM_X) &&
                        (pix_x < STATUS_SPEED_NUM_X + 2*(CHAR_W+SPACE_W)) &&
                        (pix_y >= STATUS_Y1) && (pix_y < STATUS_Y1 + CHAR_H) &&
                        (speed_num_mod < CHAR_W) && speed_num_bits[CHAR_W-1-speed_num_mod[2:0]];

    wire [7:0] dir_label_ascii = status_char(STR_DIR, status_idx);
    wire [7:0] dir_label_bits;
    font u_font_dir_label(.ascii(dir_label_ascii), .row(status_row2), .bits(dir_label_bits));
    wire dir_label_on = (pix_x >= STATUS_X) && (pix_x < STATUS_DIR_NUM_X) &&
                        (pix_y >= STATUS_Y2) && (pix_y < STATUS_Y2 + CHAR_H) &&
                        (status_mod < CHAR_W) && dir_label_bits[CHAR_W-1-status_mod[2:0]];
    wire [7:0] dir_value_ascii = (tidal_dir == 2'd1) ? "L" :
                                 (tidal_dir == 2'd2) ? "R" : "-";
    wire [7:0] dir_value_bits;
    font u_font_dir_value(.ascii(dir_value_ascii), .row(status_row2), .bits(dir_value_bits));
    wire dir_value_on = (pix_x >= STATUS_DIR_NUM_X) &&
                        (pix_x < STATUS_DIR_NUM_X + CHAR_W) &&
                        (pix_y >= STATUS_Y2) && (pix_y < STATUS_Y2 + CHAR_H) &&
                        dir_value_bits[CHAR_W-1-(pix_x-STATUS_DIR_NUM_X)];
    
    // 绘制

    // 
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            pix_data <= BLACK;
        end else if(!in_area) begin
            pix_data <= BLACK;
        end else begin
            // ����
            pix_data <= BLACK;

            // ��·�ױߣ�������λ������ʮ�ֵ��ߣ�
            if ( (top_side || bot_side) && !(pix_x >= X_LEFT && pix_x <= X_RIGHT) )
                pix_data <= WHITE;
            if ( (left_side || right_side) && !(pix_y >= Y_TOP && pix_y <= Y_BOTTOM) )
                pix_data <= WHITE;

            // ���߻ƣ��ױ���λ��
            if(h_mid_band && h_dash_on && !(top_side||bot_side))
                pix_data <= YELLOW;

            // ����λ�������ĵƣ�main_* ��ɫ��
            if(inLampCar) pix_data <= color_from_main(main_R, main_Y, main_G);
            // ����λ�����˿��ĵƣ�side_* ��ɫ��
            if(inLampPed) pix_data <= color_from_side(side_R, side_Y, side_G);

            // �೵���ϣ�����- �����ſ�
            for(k=0;k<N_UP;k=k+1) begin
                if (k < car_count_up) begin
                    if ( (pix_x>=car_up_x[k]) && (pix_x<car_up_x[k]+CAR_W) &&
                         (pix_y>=car_up_y[k]) && (pix_y<car_up_y[k]+CAR_H) )
                        pix_data <= WHITE;
                end
            end

            // �೵���£�����- �����ſأ����룩
            for(k=0;k<N_DN;k=k+1) begin
                if (k < car_count_down) begin
                    if ( (pix_x>=car_dn_x[k]) && (pix_x<car_dn_x[k]+CAR_W) &&
                         (pix_y>=car_dn_y[k]) && (pix_y<car_dn_y[k]+CAR_H) )
                        pix_data <= WHITE;
                end
            end

            // �����ˣ����� people_count����λ���? ped_phase_step��
            if(inPedAny) begin
               pix_data <= WHITE;
            end

            // 字符显示：行人数、车辆数以及效率信息（白色）
            if(people_label_on || people_num_on || car_label_on || car_num_on ||
               walk_label_on || walk_num_on || eff_label_on || eff_num_on) begin
                pix_data <= WHITE;
            end
        end
    end
endmodule
