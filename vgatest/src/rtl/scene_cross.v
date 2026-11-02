// scene_cross_right_turn_lanecontrol.v

`timescale 1ns/1ps
module scene_cross #(
    // 閿熸枻鎷峰箷閿熻鎲嬫嫹閿熸枻锟??/閿熸枻鎷烽敓鏂ゆ嫹
    parameter H_VALID = 640,
    parameter V_VALID = 480,
    parameter XC = 320,
    parameter YC = 240,
    parameter MAIN_W = 120,   // 閿熸枻鎷烽敓缂寸鎷烽敓鏂ゆ嫹閿熸枻锟??
    parameter SIDE_W = 120,   // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽緥閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷峰偦閿熸枻鎷烽敓閰殿剨鎷烽敓鏂ゆ嫹绾敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熼摪鍑ゆ嫹鍐㈤敓?
    // 閿熺鏂ゆ嫹/璺紭/閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??/閿熸枻鎷烽敓鏂ゆ嫹
    parameter EDGE_W = 3,
    parameter CURB_R = 40,
    parameter XW = 40,
    parameter STRIPE_W = 6,
    parameter STRIPE_G = 6,
    parameter ZB_OFF   = 35,
    parameter DASH_PERIOD = 32,
    parameter DASH_ON     = 12,
    parameter LANE_T        = 1,
    parameter LANE_DASH_PER = 16,
    parameter LANE_DASH_ON  = 8,
    // 閿熸枻鎷烽敓鏂ゆ嫹閿熺杈炬嫹/閿熷姭璁规嫹
    parameter CAR_W    = 10,
    parameter CAR_L    = 18,
    parameter CAR_SPD  = 3,
    parameter GAP_L2R  = 180,
    parameter GAP_R2L  = 180,
    parameter MOVE_DIV_W   = 19,
    // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷?
    parameter TURN_N   = 3,   // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??(2~4)
    parameter TURN_DY  = 3,   // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏂ゆ嫹閿熸磥锛堥敓鏂ゆ嫹閿熸枻鎷稢AR_SPD 閿熸枻锟?? CAR_SPD>>1)
    // 鐩撮敓鍙鎷烽敓鏂ゆ嫹閿熺嫛鍖℃嫹閿熸埅锝忔嫹1=閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??0=閿熸埅闂綇鎷烽敓鏂ゆ嫹閿熻妭璇ф嫹閿熺殕锝忔嫹
    parameter PAUSE_R2L     = 0,  // 閿熸枻鎷烽敓鏂ゆ嫹(閿熸枻锟??->閿熸枻锟??)閿熻鍑ゆ嫹閿熸枻鎷峰仠
    parameter PAUSE_L2R_TOP = 1,  // 閿熸枻鎷疯壊閿熸枻锟??(閿熸枻锟??->閿熸枻锟??)閿熻緝绛规嫹閿熸枻锟??(YD2C)
    parameter PAUSE_L2R_MID = 0,  // 閿熸枻鎷疯壊閿熸枻锟??(閿熸枻锟??->閿熸枻锟??)閿熷彨绛规嫹閿熸枻锟??(YD1C)
    // ==== 閿熸枻鎷烽敓鏁欑伅纰夋嫹閿熸枻锟??(閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹)閿熸枻鎷烽敓鏂ゆ嫹 ====
    parameter TL_BOX_W   = 20, // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽緥閿熸枻鎷烽敓琛楁唻鎷烽敓鏂ゆ嫹锟???
    parameter TL_BOX_H   = 48, // 閿熸枻鎷烽敓鏂ゆ嫹鍙ㄩ緥锟???3閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鑴氬嚖鎷烽敓鏂ゆ嫹+閿熸枻鎷烽敓?
    parameter TL_BOX_PAD = 8,  // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓閾板嚖鎷烽敓?/璺紭閿熶茎纭锋嫹锟???
    parameter TL_RING_T  = 2,  // 閿熸枻鎷烽敓鏂ゆ嫹鍛栭敓鏂ゆ嫹閿熸枻锟??
    parameter TL_LIGHT_SIZE = 12,  // 閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛鐨勫昂杈炬嫹12x12閿熸枻鎷烽敓鏂ゆ嫹
    parameter TL_LIGHT_GAP  = 3,   // 閿熸枻鎷烽敓鏂ゆ嫹閿熻顕嗘嫹閿熸枻鎷烽敓?3閿熸枻鎷烽敓鏂ゆ嫹
    // 閿熸枻鎷烽敓鏁欑鎷锋椂閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熺即鐗堟湰閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熻妭纰夋嫹閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛锝忔嫹閿熸枻鎷烽敓鏂ゆ嫹缁熶竴閿熸枻锟??
    parameter TL_T_RED     = 40,   // 閿熸枻鎷烽敓缁炴唻鎷烽敓?
    parameter TL_T_YEL     = 12,   // 閿熺嫛纰夋嫹鏃堕敓鏂ゆ嫹
    parameter TL_T_GRN_S   = 40,   // 鐩撮敓鏂ゆ嫹閿熸暀纰夋嫹鏃堕敓鏂ゆ嫹
    parameter TL_T_GRN_L   = 30,   // 閿熸枻鎷疯浆閿熸暀纰夋嫹鏃堕敓鏂ゆ嫹
    parameter TL_T_GRN_R   = 20,
    parameter USE_BG      = 1    // 閿熸枻鎷疯浆閿熸暀纰夋嫹鏃堕敓鏂ゆ嫹
)(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [15:0] l2r_head_ext, // 澶栭儴杈撳叆棰勭暀
    input  wire [15:0] r2l_head_ext, // 澶栭儴杈撳叆棰勭暀
    input  wire        rst_key,     // 鎸夐敭澶嶄綅锛氫綆鏈夋晥=0
    // 琛屼汉鎺у埗鍙傛暟锛堢被浼紇ga_pic.v锟??
    input  wire [7:0]  people_count, // 鏄剧ず鐨勮浜烘暟锟?? (0..MAX_PED)
    input wire ped_sw_1,    // 1=4浜猴紝0=10锟??
    input wire car_sw,
    input wire car_sw2,
    input  wire mode_adapt_sw,
    output reg  [15:0] pix_cross,
    
      // 琛屼汉鏁伴噺
  input wire [4:0] PED_N_LR, // 琛屼汉鏁伴噺鍦↙R鏂瑰悜
  input wire [4:0] PED_N_TB, // 琛屼汉鏁伴噺鍦═B鏂瑰悜
  input  wire        uart_rx_valid,
input  wire [7:0]  uart_rx_byte,
input  wire [7:0]  cfg_LRS_in, cfg_LRL_in, cfg_LRR_in,
input  wire [7:0]  cfg_TBS_in, cfg_TBL_in, cfg_TBR_in,

  
  // 浼狅拷?锟界粰 traffic_adapt2 鐨勪俊锟??
  output wire [4:0] ped_n_lr_out, 
  output wire [4:0] ped_n_tb_out, 
  output reg ped_has_lr_out, 
  output reg ped_has_tb_out,
  
    //  鏂板锛氳繃琛楀崰鐢ㄤ俊鍙凤紙鐢ㄤ簬鍒ゆ柇琛屼汉鏄惁姝ｅ湪杩囬┈璺級
  output reg  ped_cross_lr_out,
  output reg  ped_cross_tb_out,
  output wire [4:0] car_n_lr_status,
  output wire [4:0] car_n_tb_status,
  output wire [7:0] green_LRS_status, green_LRL_status, green_LRR_status,
  output wire [7:0] green_TBS_status, green_TBL_status, green_TBR_status,
  output wire [11:0] light_status
);
    // 棰滆壊
    localparam [15:0] BLACK  = 16'h0000;
    localparam [15:0] WHITE  = 16'hFFFF;
    localparam [15:0] ROAD   = 16'h4208;
    localparam [15:0] YEL    = 16'hFFE0;
    localparam [15:0] RED    = 16'h4A49;  // 娣辩伆鑹? (鍘熸潵鏄孩鑹? F800)
    localparam [15:0] GRN    = 16'h07E0;
    localparam [15:0] BLUE = 16'h001F;

localparam integer MAX_PED = 10;

reg ped_sw_s0, ped_sw_s1;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin ped_sw_s0 <= 1'b0; ped_sw_s1 <= 1'b0; end
  else begin ped_sw_s0 <= ped_sw_1; ped_sw_s1 <= ped_sw_s0; end
end
wire [4:0] PED_N = ped_sw_s1 ? 5'd4 : 5'd10;

reg car_sw_s0, car_sw_s1;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin car_sw_s0 <= 1'b0; car_sw_s1 <= 1'b0; end
  else begin car_sw_s0 <= car_sw; car_sw_s1 <= car_sw_s0; end
end

reg car_sw2_s0, car_sw2_s1;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin
    car_sw2_s0 <= 1'b0;
    car_sw2_s1 <= 1'b0;
  end else begin
    car_sw2_s0 <= car_sw2;
    car_sw2_s1 <= car_sw2_s0;
  end
end

// ===== 鍚屾 mode_adapt_sw 锟??鍏充俊锟?? =====
reg mode_adapt_sw_s0, mode_adapt_sw_s1;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin
    mode_adapt_sw_s0 <= 1'b0;
    mode_adapt_sw_s1 <= 1'b0;
  end else begin
    mode_adapt_sw_s0 <= mode_adapt_sw;
    mode_adapt_sw_s1 <= mode_adapt_sw_s0;
  end
end

// ===== ????????????1=??? ROM ??????0=??????????????????/????/???????=====

// ===== ??????????? bg_layer_ip ????? ROM ????=====
reg [9:0] pix_x_d, pix_y_d;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin pix_x_d <= 10'd0; pix_y_d <= 10'd0; end
  else begin pix_x_d <= pix_x; pix_y_d <= pix_y; end
end

// ***** 缁熶竴鐢ㄥ綋鍓嶆媿鍧愭爣锛岄伩鍏嶈锟??/杞﹂亾/鍥惧舰鍛戒腑閿欎綅 *****
wire [9:0] PX = pix_x;
wire [9:0] PY = pix_y;

// ===== ???? IP??????????? pix_x/pix_y ?????????? bg_idx ???????? =====
wire [2:0] bg_idx;
generate
  if (USE_BG) begin : G_BG
    bg_layer_ip #(
      .H(640), .V(480), .BITS(3)
    ) u_bg (
      .clk(vga_clk),
      .pix_x(pix_x),
      .pix_y(pix_y),
      .bg_idx(bg_idx)
    );
  end else begin : G_NO_BG
    assign bg_idx = 3'd0;
  end
endgenerate

// ===== 3bit ????? ?? RGB565?????????????????=====
function [15:0] pal3_to_rgb565;
  input [2:0] i;
  begin
    case(i)
      3'd0: pal3_to_rgb565 = 16'h0000; // ????/????????/???
      3'd1: pal3_to_rgb565 = 16'hFFFF; // ???????/????/?????
      3'd2: pal3_to_rgb565 = 16'hFFE0; // ?????????????
      3'd3: pal3_to_rgb565 = 16'h7BEF; // ?????????
      3'd4: pal3_to_rgb565 = 16'h39E7; // ????????
      3'd5: pal3_to_rgb565 = 16'h001F; // ???????
      3'd6: pal3_to_rgb565 = 16'hF800; // ???????
      3'd7: pal3_to_rgb565 = 16'h07E0; // ???????
      default: pal3_to_rgb565 = 16'h0000;
    endcase
  end
endfunction
wire [15:0] BG_RGB = pal3_to_rgb565(bg_idx);


// ========= ???????????? PX/PY??=========
function is_rect;
  input integer x0,x1,y0,y1; begin
    is_rect = (PX>=x0 && PX<x1 && PY>=y0 && PY<y1);
  end
endfunction

// ??????????????????????????????
function ring_band_exact;
  input integer cx, cy, r, thk; integer dx,dy,d2,r_in,r_in2,r_out2; begin
    dx=PX-cx; dy=PY-cy; d2=dx*dx+dy*dy;
    r_in=(r>thk)?(r-thk):0; r_in2=r_in*r_in; r_out2=(r+thk)*(r+thk);
    ring_band_exact=(d2>=r_in2)&&(d2<=r_out2);
  end
endfunction

// ???????????????????????????????
function in_circle;
  input integer cx, cy, r; integer dx, dy;
  begin
    dx = PX - cx; dy = PY - cy;
    in_circle = (dx*dx + dy*dy) <= (r*r);
  end
endfunction

function car_rect_xy;
  input integer px,py;
  begin
    car_rect_xy = is_rect(px-(CAR_L>>1), px+(CAR_L>>1), py-(CAR_W>>1), py+(CAR_W>>1));
  end
endfunction

function car_rect_h; input integer px,py; begin
  car_rect_h = is_rect(px-(CAR_L>>1), px+(CAR_L>>1),
                       py-(CAR_W>>1), py+(CAR_W>>1));
end endfunction

function car_rect_v; input integer px,py; begin
  car_rect_v = is_rect(px-(CAR_W>>1), px+(CAR_W>>1),
                       py-(CAR_L>>1), py+(CAR_L>>1));
end endfunction


// ------------ ??????????????????=6 ????? ------------
function in_circle_fast_r6;
  input integer cx, cy;
  integer dx, dy, adx, ady, halfw;
  begin
    dx  = pix_x - cx;
    dy  = pix_y - cy;
    adx = (dx<0)?-dx:dx;
    ady = (dy<0)?-dy:dy;

    // ----------- ??????????????????????? false -----------
    if (adx>6 || ady>6) begin
      in_circle_fast_r6 = 1'b0;
    end else begin
      // ???
      case(ady)
        0: halfw = 6;
        1,2: halfw = 5;
        3,4: halfw = 4;
        5:   halfw = 3;
        default: halfw = 0;
      endcase
      in_circle_fast_r6 = (adx <= halfw);
    end
  end
endfunction


// 閿熻剼浼欐嫹閿熸枻鎷峰渾閿熻娇纭锋嫹鐚擃煉鎷峰垨? 6 鏃朵娇閿熺煫鍖℃嫹閿熷姭鐗堟湰閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹甯介敓闃剁》鎷峰Ч鎾呮嫹锟???
function in_circle_fast;
  input integer cx, cy, r;
  begin
    if (r==6) in_circle_fast = in_circle_fast_r6(cx,cy);
    else      in_circle_fast = in_circle(cx,cy,r); // 閿熸枻鎷烽敓鏂ゆ嫹閿熻锟??
  end
endfunction


// =================== 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鍙綇鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鍔拝鎷烽敓璇級 ===================
// 閿熸枻鎷烽敓鏂ゆ嫹 1 閿熸枻鎷风ず閿熸枻鎷烽敓鏂ゆ嫹 (PX,PY) 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟?? (cx,cy) 涓洪敓鏂ゆ嫹閿熶茎鈽呮嫹閿熻锟?? r 閿熸枻锟??"閿熸枻鎷烽敓鏂ゆ嫹"
// 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷穦PX-cx| + |PY-cy| <= r
function is_diamond_hit;
  input integer cx, cy, r;
  integer dx, dy, adx, ady, sum;
  begin
    dx  = PX - cx;
    dy  = PY - cy;
    adx = (dx < 0) ? -dx : dx;
    ady = (dy < 0) ? -dy : dy;
    sum = adx + ady;
    is_diamond_hit = (sum <= r);
  end
endfunction

    // ========= 璺敓鑺傝竟鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹 =========
    localparam integer XL = XC - SIDE_W/2;
    localparam integer XR = XC + SIDE_W/2;
    localparam integer YT = YC - MAIN_W/2;
    localparam integer YB = YC + MAIN_W/2;

    wire in_center_box = (PX >= XL) && (PX < XR) &&
                         (PY >= YT) && (PY < YB);
    wire in_h_road     = (PX < H_VALID) && (PY >= YT) && (PY < YB);
    wire in_v_road     = (PX >= XL) && (PX < XR) && (PY < V_VALID);

    // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹
    localparam integer HW_HALF = MAIN_W/2;   // 閿熸枻鎷烽敓閾板嚖鎷烽敓?
    localparam integer HW_LW   = HW_HALF/3;  // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹
    localparam integer VW_HALF = SIDE_W/2;   // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??
    localparam integer VH_LW   = VW_HALF/3;  // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹锟???

    // 閿熸枻鎷烽敓缂寸鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷穀
    localparam integer YU0C = YT + (HW_LW/2);
    localparam integer YU1C = YT + (HW_LW + HW_LW/2);
    localparam integer YU2C = YC - (HW_LW/2);
    localparam integer YD0C = YB - (HW_LW/2);          // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹鐩撮敓鍙鎷烽敓鏂ゆ嫹閿熻妭绛规嫹閿熸枻锟??
    localparam integer YD1C = YB - (HW_LW + HW_LW/2);  // 閿熷彨闂磋溅閿熸枻锟??
    localparam integer YD2C = YC + (HW_LW/2);          // 閿熻緝鍑ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹

    // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓绲忛敓鏂ゆ嫹閿熸枻鎷风洿閿熸枻鎷烽敓鏂ゆ嫹3閿熸枻锟?? + 姘村钩3閿熸枻鎷烽敓鏂ゆ嫹
    localparam integer XL_1 = XL + (VH_LW>>1);         // 閿熸枻鎷疯浆 閿熸枻锟??1閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??
    localparam integer XL_2 = XL + VH_LW + (VH_LW>>1);
    localparam integer XL_3 = XC - (VH_LW>>1);
    localparam integer XR_1 = XC + (VH_LW>>1);
    localparam integer XR_2 = XC + VH_LW + (VH_LW>>1);
    localparam integer XR_3 = XR - (VH_LW>>1);

    // ?????????
    wire h_dash_on_core = (pix_x[4:0] < DASH_ON) && (pix_y >= (YC-1)) && (pix_y <= (YC+1)) && !in_center_box;
    wire v_dash_on_core = (pix_y[4:0] < DASH_ON) && (pix_x >= (XC-1)) && (pix_x <= (XC+1)) && !in_center_box;

    // ???????
    localparam integer YU1 = YT + HW_LW;
    localparam integer YU2 = YT + 2*HW_LW;
    localparam integer YD1 = YC + HW_LW;
    localparam integer YD2 = YC + 2*HW_LW;

    wire lane_h_u1 = (pix_y >= (YU1-LANE_T) && pix_y <= (YU1+LANE_T)) && in_h_road && (pix_x[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_h_u2 = (pix_y >= (YU2-LANE_T) && pix_y <= (YU2+LANE_T)) && in_h_road && (pix_x[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_h_d1 = (pix_y >= (YD1-LANE_T) && pix_y <= (YD1+LANE_T)) && in_h_road && (pix_x[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_h_d2 = (pix_y >= (YD2-LANE_T) && pix_y <= (YD2+LANE_T)) && in_h_road && (pix_x[3:0] < LANE_DASH_ON) && !in_center_box;

    // ????????????
    wire lane_v_lsep1 = (pix_x >= (XL + VH_LW - LANE_T)     && pix_x <= (XL + VH_LW + LANE_T))
                      && in_v_road && (pix_y[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_v_lsep2 = (pix_x >= (XL + (2*VH_LW) - LANE_T) && pix_x <= (XL + (2*VH_LW) + LANE_T))
                      && in_v_road && (pix_y[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_v_rsep1 = (pix_x >= (XC + VH_LW - LANE_T)     && pix_x <= (XC + VH_LW + LANE_T))
                      && in_v_road && (pix_y[3:0] < LANE_DASH_ON) && !in_center_box;
    wire lane_v_rsep2 = (pix_x >= (XC + (2*VH_LW) - LANE_T) && pix_x <= (XC + (2*VH_LW) + LANE_T))
                      && in_v_road && (pix_y[3:0] < LANE_DASH_ON) && !in_center_box;

    // ????????????
    wire zb_top_band   = is_rect(XL, XR, YT - ZB_OFF - XW, YT - ZB_OFF);
    wire zb_bot_band   = is_rect(XL, XR, YB + ZB_OFF,      YB + ZB_OFF + XW);
    wire zb_left_band  = is_rect(XL - ZB_OFF - XW, XL - ZB_OFF, YT, YB);
    wire zb_right_band = is_rect(XR + ZB_OFF,      XR + ZB_OFF + XW, YT, YB);

    wire zb_top   = zb_top_band   && (~pix_x[3]);
    wire zb_bot   = zb_bot_band   && (~pix_x[3]);
    wire zb_left  = zb_left_band  && (~pix_y[3]);
    wire zb_right = zb_right_band && (~pix_y[3]);

    // ????????????????
    wire edge_top_L_raw = is_rect(0,  XL, YT-EDGE_W, YT);
    wire edge_top_R_raw = is_rect(XR, H_VALID, YT-EDGE_W, YT);
    wire edge_bot_L_raw = is_rect(0,  XL, YB,        YB+EDGE_W);
    wire edge_bot_R_raw = is_rect(XR, H_VALID, YB,  YB+EDGE_W);

    wire edge_left_T_raw  = is_rect(XL-EDGE_W, XL, 0,   YT);
    wire edge_left_B_raw  = is_rect(XL-EDGE_W, XL, YB,  V_VALID);
    wire edge_right_T_raw = is_rect(XR, XR+EDGE_W, 0,   YT);
    wire edge_right_B_raw = is_rect(XR, XR+EDGE_W, YB,  V_VALID);

    // ????????
    localparam integer C_TL_X = XL - CURB_R, C_TL_Y = YT - CURB_R;
    localparam integer C_TR_X = XR + CURB_R, C_TR_Y = YT - CURB_R;
    localparam integer C_BL_X = XL - CURB_R, C_BL_Y = YB + CURB_R;
    localparam integer C_BR_X = XR + CURB_R, C_BR_Y = YB + CURB_R;

    wire cut_top_tl   = is_rect(XL-CURB_R, XL,         YT-EDGE_W, YT);
    wire cut_top_tr   = is_rect(XR,         XR+CURB_R, YT-EDGE_W, YT);
    wire cut_bot_bl   = is_rect(XL-CURB_R, XL,         YB,        YB+EDGE_W);
    wire cut_bot_br   = is_rect(XR,         XR+CURB_R, YB,        YB+EDGE_W);
    wire cut_left_tl  = is_rect(XL-EDGE_W,  XL,        YT-CURB_R, YT);
    wire cut_left_bl  = is_rect(XL-EDGE_W,  XL,        YB,        YB+CURB_R);
    wire cut_right_tr = is_rect(XR,         XR+EDGE_W, YT-CURB_R, YT);
    wire cut_right_br = is_rect(XR,         XR+EDGE_W, YB,        YB+CURB_R);

    wire edge_top_L   = edge_top_L_raw   && !cut_top_tl;
    wire edge_top_R   = edge_top_R_raw   && !cut_top_tr;
    wire edge_bot_L   = edge_bot_L_raw   && !cut_bot_bl;
    wire edge_bot_R   = edge_bot_R_raw   && !cut_bot_br;
    wire edge_left_T  = edge_left_T_raw  && !cut_left_tl;
    wire edge_left_B  = edge_left_B_raw  && !cut_left_bl;
    wire edge_right_T = edge_right_T_raw && !cut_right_tr;
    wire edge_right_B = edge_right_B_raw && !cut_right_br;

    wire box_tl = (pix_x >= XL-CURB_R && pix_x <  XL && pix_y >= YT-CURB_R && pix_y <  YT);
    wire box_tr = (pix_x >  XR        && pix_x <= XR+CURB_R && pix_y >= YT-CURB_R && pix_y <  YT);
    wire box_bl = (pix_x >= XL-CURB_R && pix_x <  XL && pix_y >  YB        && pix_y <= YB+CURB_R);
    wire box_br = (pix_x >  XR        && pix_x <= XR+CURB_R && pix_y >  YB        && pix_y <= YB+CURB_R);

    wire c_tl_arc = box_tl && ring_band_exact(C_TL_X, C_TL_Y, CURB_R, EDGE_W);
    wire c_tr_arc = box_tr && ring_band_exact(C_TR_X, C_TR_Y, CURB_R, EDGE_W);
    wire c_bl_arc = box_bl && ring_band_exact(C_BL_X, C_BL_Y, CURB_R, EDGE_W);
    wire c_br_arc = box_br && ring_band_exact(C_BR_X, C_BR_Y, CURB_R, EDGE_W);
    
    // ================== Zebra Traffic Lights Final Positions ==================
// TOP (X+40 done)
localparam integer ZT_CX = 400;
localparam integer ZT_G_CY = 55;
localparam integer ZT_Y_CY = 73;
localparam integer ZT_R_CY = 91;

// BOTTOM (X+40 done)
localparam integer ZB_CX = 400;
localparam integer ZB_G_CY = 389;
localparam integer ZB_Y_CY = 407;
localparam integer ZB_R_CY = 425;

// LEFT  (Y-40 done)
localparam integer ZL_CY = 160;
localparam integer ZL_G_CX = 135;
localparam integer ZL_Y_CX = 153;
localparam integer ZL_R_CX = 171;

// RIGHT (Y-40 done)
localparam integer ZR_CY = 160;
localparam integer ZR_G_CX = 469;
localparam integer ZR_Y_CX = 487;
localparam integer ZR_R_CX = 505;

// 閿熸枻鎷烽敓鎴尨鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓璇溅閿熺煫纰夋嫹锟??閿熼摪锝忔嫹--閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熺獤璁规嫹閿熻棄锛岄敓鏂ゆ嫹閿熸枻鎷烽敓鎴潻鎷烽敓鏂ゆ嫹閿熸枻锟??
function [9:0] wrap480; input [10:0] v;
begin
  wrap480 = (v>=11'd480) ? (v-11'd480) : v[9:0];
end
endfunction

localparam [1:0] C_RED = 2'd0, C_YEL = 2'd1, C_GRN = 2'd2;
 // 璁＄畻涓昏矾LR鐨勭伅鑹诧紙鐩磋/宸﹁浆/鍙宠浆锟??
wire [1:0] col_LR_S, col_LR_L, col_LR_R;
// 璁＄畻娆¤矾TB鐨勭伅鑹诧紙鐩磋/宸﹁浆/鍙宠浆锛夛紝涓嶭R鐩镐綅锟??90锟??
wire [1:0] col_TB_S, col_TB_L, col_TB_R;
wire [1:0] car_bias;
// 缁跨伅鏃堕暱淇″彿锛堝湪 traffic_adapt2 瀹炰緥鍖栦箣鍓嶅０鏄庯級
wire [7:0] green_sec_LR_S, green_sec_LR_L, green_sec_LR_R;
wire [7:0] green_sec_TB_S, green_sec_TB_L, green_sec_TB_R;
// 鍒犻櫎鍊掕鏃朵互鑺傜渷LUT璧勬簮
// 浼樺厛绾э細涓や釜閮芥嫧=骞宠　锛涘彧锟?? LR=01锛涘彧锟?? TB=10锛涢兘涓嶆嫧=00
assign car_bias =
    (car_sw_s1 & car_sw2_s1) ? 2'b00 :   // 涓や釜鍚屾椂锟?? 锟?? EQ
    (car_sw_s1)              ? 2'b01 :   // LR more
    (car_sw2_s1)             ? 2'b10 :   // TB more
                               2'b00 ;   // 榛樿 EQ


    // ========= ??????? =========
    reg [MOVE_DIV_W-1:0] div;  wire move_tick = (div=={MOVE_DIV_W{1'b0}});
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) div <= {MOVE_DIV_W{1'b0}};
        else            div <= div + 1'b1;
    end
    
    // ???????move_tick ???????1Hz
    // move_tick ?? 47.7Hz??????VGA???25MHz??MOVE_DIV_W=19??
    // ?????????1Hz ?? ?48??move_tick = 1??
    localparam integer SEC_DIV = 12;  // ?????48??move_tick ?? 1??
    
    reg [7:0] sec_div_cnt;
    wire sec_tick = move_tick && (sec_div_cnt == 0);
    
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sec_div_cnt <= 8'd0;
        end
        else if (move_tick) begin
            if (sec_div_cnt < SEC_DIV-1)
                sec_div_cnt <= sec_div_cnt + 1'b1;
            else
                sec_div_cnt <= 8'd0;
        end
    end

    // 鍊掕鏃跺姛鑳藉凡鍒犻櫎浠ヨ妭鐪丩UT
// ===================== 琛屼汉锛堥潬璺鎺掗槦锛屽垎鎵硅繃琛楋紝鏁磋矾锟??3锟??/鎵癸級 =====================
// 渚濊禆锛歑L,XR,YT,YB,XW,ZB_OFF, col_LR_S/col_TB_S/C_GRN, vga_clk, sys_rst_n, pix_x,pix_y, sec_tick
// 绾﹀畾锛氬閮ㄦ彁锟?? MAX_PED銆丳ED_N锛堢粯鍒朵笂锟?? <= MAX_PED锛夛拷?锟絇ED_N_LR銆丳ED_N_TB
// 绔彛绫诲瀷鍔″繀锟?? output wire [4:0] ped_n_lr_out, ped_n_tb_out;  output reg ped_has_lr_out, ped_has_tb_out;

// ---------- 鍙傛暟 ----------
localparam integer PED_D        = 7;
localparam integer PED_R        = PED_D;
localparam integer PED_SPD      = 1;            // 1 px / tick
localparam integer PED_TICK_DIV = 624_999;      // 25MHz -> 40Hz
localparam [9:0]  PED_STEP      = 10'd26;       // 闃熶紞闂磋窛
localparam integer MARGIN       = PED_D;        // 绛夊緟绾垮锟??
localparam [9:0]  WRAP_GAP      = 10'd12;       // 灞忓寰亸绉伙紙灏佸瓨鏃剁敤锟??

// ---------- 鏂戦┈锟??/绛夊緟锟?? ----------
localparam integer PED_TOP_Y = YT - ZB_OFF - (XW>>1);
localparam integer PED_BOT_Y = YB + ZB_OFF + (XW>>1);
localparam integer PED_L_X   = XL - ZB_OFF - (XW>>1);
localparam integer PED_R_X   = XR + ZB_OFF + (XW>>1);

localparam [9:0] WAIT_L_X = (XL > (PED_D + MARGIN))            ? (XL - (PED_D + MARGIN))          : 10'd0;
localparam [9:0] WAIT_R_X = (XR + (PED_D + MARGIN) < 10'd639)  ? (XR + (PED_D + MARGIN))          : 10'd639;
localparam [9:0] WAIT_T_Y = (YT > (PED_D + MARGIN))            ? (YT - (PED_D + MARGIN))          : 10'd0;
localparam [9:0] WAIT_B_Y = (YB + (PED_D + MARGIN) < 10'd479)  ? (YB + (PED_D + MARGIN))          : 10'd479;

// ---------- 淇″彿涓庤竟锟?? ----------
wire lr_green = (col_LR_S == C_GRN);
wire tb_green = (col_TB_S == C_GRN);

reg lr_green_q, tb_green_q;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin lr_green_q<=1'b0; tb_green_q<=1'b0; end
  else begin        lr_green_q<=lr_green; tb_green_q<=tb_green; end
end
wire lr_green_rise =  lr_green & ~lr_green_q;
wire tb_green_rise =  tb_green & ~tb_green_q;
wire lr_green_fall = ~lr_green &  lr_green_q;   // 鐢ㄤ簬"澶嶆椿"
wire tb_green_fall = ~tb_green &  tb_green_q;

// ---------- 锟??娆＄豢鐏彧鏀捐锟??鎵癸細浠ょ墝 ----------
reg lr_token, tb_token;
reg lr_batch_started, tb_batch_started;

// ---------- 鏂瑰悜/杩涘叆閿佸瓨 ----------
reg signed [1:0] dir_top, dir_bot;    // +1锛氬悜鍙筹紱-1锛氬悜锟??
reg signed [1:0] dir_left, dir_right; // +1锛氬悜涓嬶紱-1锛氬悜锟??
reg entered_top, entered_bot, entered_left, entered_right;

initial begin
  dir_top   =  1;  // 椤堕儴锛氬乏->锟??
  dir_bot   = -1;  // 搴曢儴锛氬彸->锟??
  dir_left  =  1;  // 宸︿晶锛氫笂->锟??
  dir_right = -1;  // 鍙充晶锛氫笅->锟??
end


// ---------- 40Hz 琛屼汉姝ヨ繘鏃堕挓 ----------
reg [31:0] ped_div;  wire ped_tick = (ped_div == PED_TICK_DIV);
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) ped_div <= 0;
  else           ped_div <= ped_tick ? 0 : ped_div + 1'b1;
end

// ---------- "灏佸瓨/澶嶆椿" 绠＄悊 ----------
reg top_wrapped,  bot_wrapped;
reg left_wrapped, right_wrapped;
reg respawn_arm_lr, respawn_arm_tb;   // 鏈変晶灏佸瓨鍚庝妇鎵嬶紝绛夊緟鍏佽澶嶆椿

// 鍏佽杩涘叆锛堝皝瀛樻湡闂寸姝級
wire ALLOW_ENTER_LR = lr_green && !top_wrapped && !bot_wrapped
                    && (lr_token || entered_top || entered_bot);
wire ALLOW_ENTER_TB = tb_green && !left_wrapped && !right_wrapped
                    && (tb_token || entered_left || entered_right);
// ---------- 鍏抽敭浣嶇疆 ----------
reg [9:0] ped_x_top, ped_x_bot;
reg [9:0] ped_y_left, ped_y_right;

localparam integer ENTER_GUARD = PED_D;
localparam integer EXIT_GUARD  = PED_D;

// ===== TB direction now uses direct entry logic like LR (no will_enter signals) =====
// ===== 统一锟斤拷 LR/TB 锟斤拷锟狡癸拷锟斤拷 =====
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin
    lr_token         <= 1'b0;
    tb_token         <= 1'b0;
    lr_batch_started <= 1'b0;
    tb_batch_started <= 1'b0;
  end else begin
    // -- LR锟斤拷锟教碉拷锟斤拷锟截凤拷锟斤拷锟狡ｏ拷锟斤拷一锟斤拷锟斤拷锟剿斤拷锟斤拷锟斤拷锟斤拷眩锟斤拷锟斤拷锟斤拷锟斤拷
    if (lr_green_rise) begin
      lr_token         <= 1'b1;
      lr_batch_started <= 1'b0;
    end
    if (!lr_green)
      lr_token <= 1'b0;
    if (lr_token && (entered_top || entered_bot)) begin
      lr_token         <= 1'b0;   // 锟斤拷锟斤拷
      lr_batch_started <= 1'b1;
    end

    // -- TB direction token control, identical to LR
    if (tb_green_rise) begin
      tb_token         <= 1'b1;
      tb_batch_started <= 1'b0;
    end
    if (!tb_green)
      tb_token <= 1'b0;
    if (tb_token && (entered_left || entered_right)) begin
      tb_token         <= 1'b0;
      tb_batch_started <= 1'b1;
    end
  end
end


// =====================================================
// 缁熶竴锟?? respawn_req_* 鐢熸垚锛堝敮锟??椹卞姩鑰咃級
// =====================================================
reg [7:0] wrap_secs_lr, wrap_secs_tb;
always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin wrap_secs_lr<=8'd0; wrap_secs_tb<=8'd0; end
  else if (sec_tick) begin
    wrap_secs_lr <= (top_wrapped  || bot_wrapped ) ? (wrap_secs_lr + 1'b1) : 8'd0;
    wrap_secs_tb <= (left_wrapped || right_wrapped) ? (wrap_secs_tb + 1'b1) : 8'd0;
  end
end
localparam integer WRAP_FORCE_RESPAWN_S = 0; // 0=鍏抽棴缁库啈寮哄埗澶嶆椿

// 浠呮澶勫啓 respawn_req_*
reg respawn_req_lr, respawn_req_tb;

// 锟??"鎵ц锟??"浼犲洖鐨勪竴鎷嶅畬鎴愯剦鍐诧紙鍦ㄦ墽琛屽潡閲屼骇鐢熸垚瀵勫瓨鍣紝鐒跺悗杩欓噷鍙锟??
wire respawn_done_lr_p, respawn_done_tb_p;

always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    respawn_req_lr <= 1'b0;
    respawn_req_tb <= 1'b0;
  end else begin
if (respawn_done_lr_p) begin
  respawn_req_lr <= 1'b0;
end else if (respawn_arm_lr) begin
  if (lr_green_fall ||
      (lr_green_rise && (wrap_secs_lr >= WRAP_FORCE_RESPAWN_S)) ||
      (lr_green      && (wrap_secs_lr >= WRAP_FORCE_RESPAWN_S))) begin
    respawn_req_lr <= 1'b1;
  end
end


if (respawn_done_tb_p) begin
  respawn_req_tb <= 1'b0;
end else if (respawn_arm_tb) begin
  if (tb_green_fall) begin
    respawn_req_tb <= 1'b1;  // 锟斤拷锟斤拷锟斤拷->锟斤拷锟截伙拷锟斤拷
  end
end


  end
end

// ====================== 姘村钩锛圠R锛夎繍鍔ㄤ笌澶嶆椿鎵ц ======================
reg respawn_done_lr_z;  assign respawn_done_lr_p = respawn_done_lr_z; // 鍙湪鏈潡閲屽啓 _z
always @(posedge vga_clk or negedge sys_rst_n) begin
  if(!sys_rst_n) begin
    ped_x_top<=WAIT_L_X; ped_x_bot<=WAIT_R_X;
    entered_top<=1'b0; entered_bot<=1'b0;
    top_wrapped<=1'b0; bot_wrapped<=1'b0;
    respawn_arm_lr<=1'b0;
    respawn_done_lr_z<=1'b0;
  end else if (ped_tick) begin
    respawn_done_lr_z <= 1'b0; // 榛樿鎷変綆

    // 杩涘叆锟??锟?? - 鍙湪缁跨伅鏃跺厑璁歌繘锟??
    if(!entered_top && !top_wrapped && lr_green) begin
      if (dir_top==1) begin
        if((ped_x_top < (XL - ENTER_GUARD)) && (ped_x_top + PED_SPD >= (XL - ENTER_GUARD))) entered_top <= 1'b1;
      end else begin
        if((ped_x_top > (XR + ENTER_GUARD)) && (ped_x_top - PED_SPD <= (XR + ENTER_GUARD))) entered_top <= 1'b1;
      end
    end
    if(!entered_bot && !bot_wrapped && lr_green) begin
      if (dir_bot==-1) begin
        if((ped_x_bot > (XR + ENTER_GUARD)) && (ped_x_bot - PED_SPD <= (XR + ENTER_GUARD))) entered_bot <= 1'b1;
      end else begin
        if((ped_x_bot < (XL - ENTER_GUARD)) && (ped_x_bot + PED_SPD >= (XL - ENTER_GUARD))) entered_bot <= 1'b1;
      end
    end

    // 绉诲姩锛堟湭灏佸瓨渚э級
    if (!top_wrapped) begin
      if (lr_green) begin
        if (ALLOW_ENTER_LR || entered_top) ped_x_top <= ped_x_top + (dir_top==1 ? PED_SPD : -PED_SPD);
      end else begin
        if (entered_top) ped_x_top <= ped_x_top + (dir_top==1 ? PED_SPD : -PED_SPD);
        else begin
          if (dir_top==1) begin
            if(ped_x_top < WAIT_L_X) ped_x_top <= (ped_x_top + PED_SPD <= WAIT_L_X)?(ped_x_top + PED_SPD):WAIT_L_X;
          end else begin
            if(ped_x_top > WAIT_R_X) ped_x_top <= (ped_x_top > WAIT_R_X + PED_SPD)?(ped_x_top - PED_SPD):WAIT_R_X;
          end
        end
      end
    end else begin
      ped_x_top <= (dir_top==1) ? (10'd639 - WRAP_GAP) : (10'd0 + WRAP_GAP); // 灏佸瓨锛氬睆澶栧浐锟??
    end

    if (!bot_wrapped) begin
      if (lr_green) begin
        if (ALLOW_ENTER_LR || entered_bot) ped_x_bot <= ped_x_bot + (dir_bot==1 ? PED_SPD : -PED_SPD);
      end else begin
        if (entered_bot) ped_x_bot <= ped_x_bot + (dir_bot==1 ? PED_SPD : -PED_SPD);
        else begin
          if (dir_bot==-1) begin
            if(ped_x_bot > WAIT_R_X) ped_x_bot <= (ped_x_bot > WAIT_R_X + PED_SPD)?(ped_x_bot - PED_SPD):WAIT_R_X;
          end else begin
            if(ped_x_bot < WAIT_L_X) ped_x_bot <= (ped_x_bot + PED_SPD <= WAIT_L_X)?(ped_x_bot + PED_SPD):WAIT_L_X;
          end
        end
      end
    end else begin
      ped_x_bot <= (dir_bot==1) ? (10'd639 - WRAP_GAP) : (10'd0 + WRAP_GAP);
    end

    // 闃熷熬瓒婄晫 锟?? 灏佸瓨 + 涓炬墜
    if (entered_top) begin
      if (dir_top==1) begin
        if (($signed({1'b0,ped_x_top}) - $signed((PED_N-1)*PED_STEP)) >= $signed(XR + EXIT_GUARD)) begin
          entered_top<=1'b0; top_wrapped<=1'b1; respawn_arm_lr<=1'b1;
        end
      end else begin
        if (($signed({1'b0,ped_x_top}) + $signed((PED_N-1)*PED_STEP)) <= $signed(XL - EXIT_GUARD)) begin
          entered_top<=1'b0; top_wrapped<=1'b1; respawn_arm_lr<=1'b1;
        end
      end
    end
    if (entered_bot) begin
      if (dir_bot==-1) begin
        if (($signed({1'b0,ped_x_bot}) + $signed((PED_N-1)*PED_STEP)) <= $signed(XL - EXIT_GUARD)) begin
          entered_bot<=1'b0; bot_wrapped<=1'b1; respawn_arm_lr<=1'b1;
        end
      end else begin
        if (($signed({1'b0,ped_x_bot}) - $signed((PED_N-1)*PED_STEP)) >= $signed(XR + EXIT_GUARD)) begin
          entered_bot<=1'b0; bot_wrapped<=1'b1; respawn_arm_lr<=1'b1;
        end
      end
    end

    // 澶嶆椿鎵ц锛堝彧锟?? respawn_req_lr锛涜繖閲屼笉淇敼 req 鏈綋锟??
    if (respawn_req_lr) begin
      // 鍥炲埌"璧峰渚х瓑寰呯嚎"
      if (top_wrapped) ped_x_top <= (dir_top==1) ? WAIT_L_X : WAIT_R_X;
      if (bot_wrapped) ped_x_bot <= (dir_bot==1) ? WAIT_L_X : WAIT_R_X;
      top_wrapped<=1'b0; bot_wrapped<=1'b0; respawn_arm_lr<=1'b0;
      respawn_done_lr_z <= 1'b1;  // 鍗曟媿瀹屾垚鑴夊啿
    end
  end
end



// ====================== TB 锟斤拷锟斤拷锟剿讹拷/锟斤拷锟斤拷/锟斤拷锟界（锟街革拷锟芥，锟斤拷锟斤拷锟斤拷锟斤拷 tb_token锟斤拷 ======================
localparam integer CLEARANCE_Y = EXIT_GUARD + PED_R;

reg respawn_done_tb_z;
assign respawn_done_tb_p = respawn_done_tb_z;

always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    // 锟斤拷值锟截碉拷锟饺达拷锟斤拷
    ped_y_left     <= WAIT_T_Y;
    ped_y_right    <= WAIT_B_Y;
    entered_left   <= 1'b0;
    entered_right  <= 1'b0;
    left_wrapped   <= 1'b0;
    right_wrapped  <= 1'b0;
    respawn_arm_tb <= 1'b0;
    respawn_done_tb_z <= 1'b0;
  end else if (ped_tick) begin
    respawn_done_tb_z <= 1'b0; // 默锟斤拷锟斤拷锟斤拷

    // -- 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷位锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟窖斤拷锟筋；tb_token 只锟斤拷"锟斤拷锟狡癸拷锟斤拷锟斤拷"锟斤拷模锟?
    // 锟斤拷锟?
    if(!entered_left && !left_wrapped && tb_green) begin
      if (dir_left== 1) begin
        if((ped_y_left < (YT - ENTER_GUARD)) && (ped_y_left + PED_SPD >= (YT - ENTER_GUARD))) entered_left <= 1'b1;
      end else begin
        if((ped_y_left > (YB + ENTER_GUARD)) && (ped_y_left - PED_SPD <= (YB + ENTER_GUARD))) entered_left <= 1'b1;
      end
    end
    // 锟揭诧拷
    if(!entered_right && !right_wrapped && tb_green) begin
      if (dir_right==-1) begin
        if((ped_y_right > (YB + ENTER_GUARD)) && (ped_y_right - PED_SPD <= (YB + ENTER_GUARD))) entered_right <= 1'b1;
      end else begin
        if((ped_y_right < (YT - ENTER_GUARD)) && (ped_y_right + PED_SPD >= (YT - ENTER_GUARD))) entered_right <= 1'b1;
      end
    end

    // ================= 锟斤拷锟斤拷锟叫讹拷锟斤拷锟斤拷锟斤拷圆锟?+锟斤拷全锟斤拷锟斤拷 -> wrap锟斤拷 =================
    // 锟斤拷啵篸ir_left=+1 锟斤拷->锟铰ｏ拷dir_left=-1 锟斤拷->锟斤拷
    if (entered_left) begin
      if (dir_left ==  1) begin
        // 头锟斤拷越锟斤拷 YB + 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷 PED_N/PED_STEP/PED_R锟斤拷
        if (($signed({1'b0,ped_y_left}) - $signed((PED_N-1)*PED_STEP) - $signed(PED_R))
              >= $signed(YB + EXIT_GUARD)) begin
          entered_left   <= 1'b0;
          left_wrapped   <= 1'b1;
          respawn_arm_tb <= 1'b1;
        end
      end else begin
        // 头锟斤拷越锟斤拷 YT - 锟斤拷锟斤拷
        if (($signed({1'b0,ped_y_left}) + $signed((PED_N-1)*PED_STEP) + $signed(PED_R))
              <= $signed(YT - EXIT_GUARD)) begin
          entered_left   <= 1'b0;
          left_wrapped   <= 1'b1;
          respawn_arm_tb <= 1'b1;
        end
      end
    end

    // 锟揭侧：dir_right=-1 锟斤拷->锟较ｏ拷dir_right=+1 锟斤拷->锟斤拷
    if (entered_right) begin
      if (dir_right == -1) begin
        if (($signed({1'b0,ped_y_right}) + $signed((PED_N-1)*PED_STEP) + $signed(PED_R))
              <= $signed(YT - EXIT_GUARD)) begin
          entered_right  <= 1'b0;
          right_wrapped  <= 1'b1;
          respawn_arm_tb <= 1'b1;
        end
      end else begin
        if (($signed({1'b0,ped_y_right}) - $signed((PED_N-1)*PED_STEP) - $signed(PED_R))
              >= $signed(YB + EXIT_GUARD)) begin
          entered_right  <= 1'b0;
          right_wrapped  <= 1'b1;
          respawn_arm_tb <= 1'b1;
        end
      end
    end

    // ================= 位锟斤拷 =================
    // 锟斤拷锟?
    if (!left_wrapped) begin
      if (tb_green) begin
        // 锟教碉拷锟节ｏ拷未锟诫场时锟斤拷锟斤拷锟斤拷 ALLOW_ENTER_TB锟斤拷锟斤拷锟诫场锟斤拷锟斤拷锟角帮拷锟?
        if (ALLOW_ENTER_TB || entered_left)
          ped_y_left <= ped_y_left + (dir_left==1 ? PED_SPD : -PED_SPD);
      end else begin
        // 锟斤拷锟斤拷冢锟斤拷氤★拷募锟斤拷锟斤拷撸锟轿达拷氤★拷目锟斤拷锟斤拷却锟斤拷锟?
        if (entered_left) begin
          ped_y_left <= ped_y_left + (dir_left==1 ? PED_SPD : -PED_SPD);
        end else begin
          if (dir_left==1) begin
            // 锟斤拷->锟铰ｏ拷锟斤拷 WAIT_T_Y
            if (ped_y_left < WAIT_T_Y)
              ped_y_left <= (ped_y_left + PED_SPD <= WAIT_T_Y) ? (ped_y_left + PED_SPD) : WAIT_T_Y;
          end else begin
            // 锟斤拷->锟较ｏ拷锟斤拷 WAIT_B_Y
            if (ped_y_left > WAIT_B_Y)
              ped_y_left <= (ped_y_left > WAIT_B_Y + PED_SPD) ? (ped_y_left - PED_SPD) : WAIT_B_Y;
          end
        end
      end
    end else begin
      // wrapped锟斤拷锟脚碉拷锟斤拷锟解缓锟斤拷位
      ped_y_left <= (dir_left==1) ? (10'd479 - WRAP_GAP) : (10'd0 + WRAP_GAP);
    end

    // 锟揭诧拷
    if (!right_wrapped) begin
      if (tb_green) begin
        if (ALLOW_ENTER_TB || entered_right)
          ped_y_right <= ped_y_right + (dir_right==1 ? PED_SPD : -PED_SPD);
      end else begin
        if (entered_right) begin
          ped_y_right <= ped_y_right + (dir_right==1 ? PED_SPD : -PED_SPD);
        end else begin
          if (dir_right==-1) begin
            // 锟斤拷->锟较ｏ拷锟斤拷 WAIT_B_Y
            if (ped_y_right > WAIT_B_Y)
              ped_y_right <= (ped_y_right > WAIT_B_Y + PED_SPD) ? (ped_y_right - PED_SPD) : WAIT_B_Y;
          end else begin
            // 锟斤拷->锟铰ｏ拷锟斤拷 WAIT_T_Y
            if (ped_y_right < WAIT_T_Y)
              ped_y_right <= (ped_y_right + PED_SPD <= WAIT_T_Y) ? (ped_y_right + PED_SPD) : WAIT_T_Y;
          end
        end
      end
    end else begin
      ped_y_right <= (dir_right==1) ? (10'd479 - WRAP_GAP) : (10'd0 + WRAP_GAP);
    end

    // ================= 锟斤拷锟轿伙拷锟铰ｏ拷锟斤拷锟斤拷应 respawn_req_tb锟斤拷 =================
    if (respawn_req_tb) begin
      // 锟截碉拷"锟斤拷始锟饺达拷锟斤拷"
      if (left_wrapped)  ped_y_left  <= (dir_left==1)  ? WAIT_T_Y : WAIT_B_Y;
      if (right_wrapped) ped_y_right <= (dir_right==1) ? WAIT_T_Y : WAIT_B_Y;

      left_wrapped      <= 1'b0;
      right_wrapped     <= 1'b0;
      respawn_arm_tb    <= 1'b0;
      respawn_done_tb_z <= 1'b1; // 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟?
    end
  end
end

// ================= 鍛戒腑锟??娴嬶細鑿卞舰 =================
function [0:0] diamond_hit_xy;
  input [9:0] cx, cy;
  begin
    diamond_hit_xy = (pix_x[9:3] == cx[9:3]) &&
                     (pix_y[9:3] == cy[9:3]);
  end
endfunction

function hit_top_idx; input integer idx; reg [11:0] xt;
  begin
    if (top_wrapped) hit_top_idx = 1'b0;
    else begin
      xt = {2'b00,ped_x_top} - (idx * PED_STEP);
      hit_top_idx = (xt[11]==1'b0 && xt<12'd640) ? diamond_hit_xy(xt[9:0], PED_TOP_Y[9:0]) : 1'b0;
    end
  end
endfunction

function hit_bot_idx; input integer idx; reg [11:0] xt;
  begin
    if (bot_wrapped) hit_bot_idx = 1'b0;
    else begin
      xt = {2'b00,ped_x_bot} + (idx * PED_STEP);
      hit_bot_idx = (xt<12'd640) ? diamond_hit_xy(xt[9:0], PED_BOT_Y[9:0]) : 1'b0;
    end
  end
endfunction

function hit_left_idx;  input integer idx; reg [11:0] yt;
  begin
    if (left_wrapped) hit_left_idx = 1'b0;
    else begin
      yt = {2'b00,ped_y_left} - (idx * PED_STEP);
      hit_left_idx = (yt[11]==1'b0 && yt<12'd480) ? diamond_hit_xy(PED_L_X[9:0], yt[9:0]) : 1'b0;
    end
  end
endfunction

function hit_right_idx; input integer idx; reg [11:0] yt;
  begin
    if (right_wrapped) hit_right_idx = 1'b0;
    else begin
      yt = {2'b00,ped_y_right} + (idx * PED_STEP);
      hit_right_idx = (yt<12'd480) ? diamond_hit_xy(PED_R_X[9:0], yt[9:0]) : 1'b0;
    end
  end
endfunction

// ---------- 鑱氬悎 ----------
reg ped_hit_r_h, ped_hit_r_v; integer i;
always @* begin
  ped_hit_r_h = 1'b0;
  for(i=0;i<MAX_PED;i=i+1) begin
    if (i < PED_N) begin
      if(hit_top_idx(i)) ped_hit_r_h = 1'b1;
      if(hit_bot_idx(i)) ped_hit_r_h = 1'b1;
    end
  end
  ped_hit_r_v = 1'b0;
  for(i=0;i<MAX_PED;i=i+1) begin
    if (i < PED_N) begin
      if(hit_left_idx(i))  ped_hit_r_v = 1'b1;
      if(hit_right_idx(i)) ped_hit_r_v = 1'b1;
    end
  end
end

wire ped_hit = ped_hit_r_h | ped_hit_r_v;  // 鑻ヤ綘澶栭潰鏈夛拷?锟藉儚绱犳贩鑹诧紝杩欓噷鎺ュ叆

// ===================== 鍗犵敤杈撳嚭锛堝彧绠楁枒椹嚎鍐咃紝绛夊緟绾夸笉绠楋級 =====================
// 只统锟狡帮拷锟斤拷锟斤拷锟节诧拷锟角凤拷锟斤拷锟剿ｏ拷锟饺达拷锟竭诧拷锟姐）
wire ped_active_lr = (entered_top  || entered_bot );
wire ped_active_tb = (entered_left || entered_right);

// 锟斤拷锟斤拷锟斤拷锟秸硷拷茫锟斤拷锟斤拷倬锟? sec_tick 锟斤拷锟斤拷/锟斤拷锟街ｏ拷锟斤拷锟斤拷 1~2 锟斤拷锟接筹拷
// 注锟斤拷: 只统锟斤拷锟斤拷锟窖斤拷锟诫爱锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷却锟斤拷锟斤拷锟斤拷氤∈憋拷锟阶拷锟斤拷苑锟斤拷锟斤拷锟斤拷锟?
always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    ped_has_lr_out <= 1'b0;
    ped_has_tb_out <= 1'b0;
  end else begin
    ped_has_lr_out <= ped_active_lr;
    ped_has_tb_out <= ped_active_tb;
  end
end

// --- 杩囪鍗犵敤淇″彿杈撳嚭锛堣〃绀鸿浜烘槸鍚︽鍦ㄨ繃椹矾锟?? ---
always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    ped_cross_lr_out <= 1'b0;
    ped_cross_tb_out <= 1'b0;
  end else begin
    ped_cross_lr_out <= ped_active_lr;
    ped_cross_tb_out <= ped_active_tb;
  end
end

// --- 浜烘暟杈撳嚭锛堜繚鎸佷笌鍘熸帴鍙ｄ竴鑷达紱绔彛锟?? output wire锟?? ---
// 浣跨敤鍐呴儴 PED_N锛堢敱 ped_sw_1 鎺у埗锛夋潵鏄剧ず锛岀‘淇濇嫧鐮佸紑鍏宠兘鎺у埗鏄剧ず鐨勪汉锟??
// LR鏂瑰悜鏈塼op鍜宐ot涓ゆ潯璺紝姣忔潯璺疨ED_N浜猴紝锟??浠R鏂瑰悜鎬诲叡 = PED_N * 2
// TB鏂瑰悜鏈塴eft鍜宺ight涓ゆ潯璺紝姣忔潯璺疨ED_N浜猴紝锟??浠B鏂瑰悜鎬诲叡 = PED_N * 2
// 鎬讳汉锟?? = (PED_N * 2) + (PED_N * 2) = PED_N * 4 = 16 锟?? 40
assign ped_n_lr_out = PED_N * 2;  // LR鏂瑰悜鎬讳汉鏁帮細1=8锟??(4*2)锟??0=20锟??(10*2)
assign ped_n_tb_out = PED_N * 2;  // TB鏂瑰悜鎬讳汉鏁帮細1=8锟??(4*2)锟??0=20锟??(10*2)

// --- 杞﹁締鍙傛暟瀹氫箟锛堝繀椤诲湪wire鍜屾暟缁勫０鏄庝箣鍓嶏級 ---
// LR鏂瑰悜杞﹁締鍙傛暟
localparam integer N_ST = 8;
localparam integer N_RT = 6; 
localparam integer N_LT = 4;
localparam integer N_ST_R = 8;
localparam integer N_RT_R = 6;
localparam integer N_LT_R = 4;

// TB鏂瑰悜杞﹁締鍙傛暟
localparam integer N_TSD = 10;
localparam integer N_TL = 4;
localparam integer N_TR_ALWAYS   = 6;
localparam integer N_BS_ST = 10;
localparam integer N_BR = 6;
localparam integer N_BL = 4;

// --- 杞﹁締鍙傛暟鍜屾暟缁勫畾涔夛紙蹇呴』鍦ㄧ粺璁′唬鐮佷箣鍓嶏級 ---
// 0=淇濇寔鐜扮姸锟??1=锟??鏈夋祦閲忓己鍒朵负2锛堢敤鍚屾鍚庣殑 car_sw_s1锟??
wire [4:0] NUM_ST    = car_sw_s1 ? N_ST : 5'd2;     // L鈫扲 鐩磋
wire [2:0] NUM_RT    = car_sw_s1 ? N_RT : 3'd2;     // L鈫扲 鍙宠浆
wire [2:0] NUM_LT    = car_sw_s1 ? N_LT : 3'd2;     // L鈫扲 宸﹁浆
wire [4:0] NUM_ST_R  = car_sw_s1 ? N_ST_R : 5'd2;   // R鈫扡 鐩磋
wire [2:0] NUM_RT_R  = car_sw_s1 ? N_RT_R : 3'd2;   // R鈫扡 鍙宠浆
wire [2:0] NUM_LT_R  = car_sw_s1 ? N_LT_R : 3'd2;   // R鈫扡 宸﹁浆

// 绔栫洿鏂瑰悜 - 浣跨敤 car_sw2_s1 寮哄埗 =2
wire [4:0] NUM_TSD    = car_sw2_s1 ? N_TSD : 5'd2;
wire [2:0] NUM_TL     = car_sw2_s1 ? N_TL : 3'd2;
wire [2:0] NUM_TR     = car_sw2_s1 ? N_TR_ALWAYS : 3'd2;
wire [4:0] NUM_BS_ST  = car_sw2_s1 ? N_BS_ST : 5'd2;
wire [2:0] NUM_BR     = car_sw2_s1 ? N_BR : 3'd2;
wire [2:0] NUM_BL     = car_sw2_s1 ? N_BL : 3'd2;

// 杞﹁締鐘讹拷?锟芥暟缁勫０鏄庯紙鐢ㄤ簬缁熻锟??
reg        st_active [0:N_ST-1];
reg        rt_active [0:N_RT-1];
reg        lt_active [0:N_LT-1];
reg        stR_active [0:N_ST_R-1];
reg        rt2_active [0:N_RT_R-1];
reg        lt2_active [0:N_LT_R-1];
reg        tsd_active [0:N_TSD-1];
reg        tl_active [0:N_TL-1];
reg        tr_active [0:N_TR_ALWAYS-1];
reg        bs_st_active [0:N_BS_ST-1];
reg        br_active [0:N_BR-1];
reg        bl_active [0:N_BL-1];

// --- 杞﹁締鏁伴噺缁熻锛圠R鍜孴B鏂瑰悜锟?? ---
// LR鏂瑰悜锛歴t_active, rt_active, lt_active, stR_active, rt2_active, lt2_active
// TB鏂瑰悜锛歵sd_active, tl_active, tr_active, bs_st_active, br_active, bl_active
integer car_lr_count, car_tb_count;
integer car_i;
always @(*) begin
    car_lr_count = 0;
    car_tb_count = 0;
    
    // LR鏂瑰悜杞﹁締缁熻
    for (car_i = 0; car_i < N_ST; car_i = car_i + 1)
        if (car_i < NUM_ST && st_active[car_i]) car_lr_count = car_lr_count + 1;
    for (car_i = 0; car_i < N_RT; car_i = car_i + 1)
        if (car_i < NUM_RT && rt_active[car_i]) car_lr_count = car_lr_count + 1;
    for (car_i = 0; car_i < N_LT; car_i = car_i + 1)
        if (car_i < NUM_LT && lt_active[car_i]) car_lr_count = car_lr_count + 1;
    for (car_i = 0; car_i < N_ST_R; car_i = car_i + 1)
        if (car_i < NUM_ST_R && stR_active[car_i]) car_lr_count = car_lr_count + 1;
    for (car_i = 0; car_i < N_RT_R; car_i = car_i + 1)
        if (car_i < NUM_RT_R && rt2_active[car_i]) car_lr_count = car_lr_count + 1;
    for (car_i = 0; car_i < N_LT_R; car_i = car_i + 1)
        if (car_i < NUM_LT_R && lt2_active[car_i]) car_lr_count = car_lr_count + 1;
    
    // TB鏂瑰悜杞﹁締缁熻锛堥渶瑕佹锟?? NUM_* 闄愬埗锟??
    for (car_i = 0; car_i < N_TSD; car_i = car_i + 1)
        if (car_i < NUM_TSD && tsd_active[car_i]) car_tb_count = car_tb_count + 1;
    for (car_i = 0; car_i < N_TL; car_i = car_i + 1)
        if (car_i < NUM_TL && tl_active[car_i]) car_tb_count = car_tb_count + 1;
    for (car_i = 0; car_i < N_TR_ALWAYS; car_i = car_i + 1)
        if (car_i < NUM_TR && tr_active[car_i]) car_tb_count = car_tb_count + 1;
    for (car_i = 0; car_i < N_BS_ST; car_i = car_i + 1)
        if (car_i < NUM_BS_ST && bs_st_active[car_i]) car_tb_count = car_tb_count + 1;
    for (car_i = 0; car_i < N_BR; car_i = car_i + 1)
        if (car_i < NUM_BR && br_active[car_i]) car_tb_count = car_tb_count + 1;
    for (car_i = 0; car_i < N_BL; car_i = car_i + 1)
        if (car_i < NUM_BL && bl_active[car_i]) car_tb_count = car_tb_count + 1;
end

// 杞﹁締鏁伴噺杈撳嚭锛堥檺鍒跺湪5浣嶏紝锟??锟??31锟??
wire [4:0] car_n_lr_out = (car_lr_count > 31) ? 5'd31 : car_lr_count[4:0];
wire [4:0] car_n_tb_out = (car_tb_count > 31) ? 5'd31 : car_tb_count[4:0];
assign car_n_lr_status = car_n_lr_out;
assign car_n_tb_status = car_n_tb_out;
// 閫熷害寤鸿锛氭牴鎹甃R鍜孴B涓ゆ潯杞﹂亾鐨勮溅娴佸瘑搴?
localparam [4:0] CAR_HIGH_TH = 5'd15;  // 鍗曟潯杞﹂亾杞﹀鐨勯槇鍊?
localparam [7:0] SPEED_BOTH_LOW  = 8'd60;  // 涓ゆ潯杞﹂亾閮藉皯锛?60 km/h
localparam [7:0] SPEED_ONE_HIGH  = 8'd40;  // 涓?鏉¤溅閬撳锛?40 km/h
localparam [7:0] SPEED_BOTH_HIGH = 8'd30;  // 涓ゆ潯杞﹂亾閮藉锛?30 km/h

wire lr_busy = (car_n_lr_out >= CAR_HIGH_TH);  // LR杞﹂亾鎷ュ牭鏍囧織
wire tb_busy = (car_n_tb_out >= CAR_HIGH_TH);  // TB杞﹂亾鎷ュ牭鏍囧織
reg  [7:0] speed_sugg;

always @(posedge vga_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    speed_sugg <= SPEED_BOTH_LOW;
  end else if (sec_tick) begin
    case ({lr_busy, tb_busy})
      2'b00: speed_sugg <= SPEED_BOTH_LOW;   // 涓ゆ潯閮藉皯锛?60
      2'b01,
      2'b10: speed_sugg <= SPEED_ONE_HIGH;   // 涓?鏉″锛?40
      2'b11: speed_sugg <= SPEED_BOTH_HIGH;  // 涓ゆ潯閮藉锛?30
      default: speed_sugg <= SPEED_BOTH_LOW;
    endcase
  end
end
wire [7:0] cfg_LRS_uart, cfg_LRL_uart, cfg_LRR_uart;
wire [7:0] cfg_TBS_uart, cfg_TBL_uart, cfg_TBR_uart;
wire [7:0] cfg_LRS=cfg_LRS_in, cfg_LRL=cfg_LRL_in, cfg_LRR=cfg_LRR_in;
wire [7:0] cfg_TBS=cfg_TBS_in, cfg_TBL=cfg_TBL_in, cfg_TBR=cfg_TBR_in;
wire       pLRS, pLRL, pLRR, pTBS, pTBL, pTBR;

// 2) 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷募锟斤拷锟斤拷 cfg_uart_simple
cfg_uart_simple #(
  .DEF_LRS(8'd40), .DEF_LRL(8'd30), .DEF_LRR(8'd20),
  .DEF_TBS(8'd40), .DEF_TBL(8'd30), .DEF_TBR(8'd20)
) u_cfg (
  .clk     (vga_clk),
  .rst_n   (sys_rst_n),
  .rx_valid(uart_rx_valid),   // 锟斤拷锟姐传锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷
  .rx_data (uart_rx_byte),

  .LRS(cfg_LRS_uart), .LRL(cfg_LRL_uart), .LRR(cfg_LRR_uart),
  .TBS(cfg_TBS_uart), .TBL(cfg_TBL_uart), .TBR(cfg_TBR_uart),

  .LRS_up(pLRS), .LRL_up(pLRL), .LRR_up(pLRR),
  .TBS_up(pTBS), .TBL_up(pTBL), .TBR_up(pTBR)
);

traffic_adapt2 #(
  .BASE_S (40), .BASE_L (30), .BASE_R (20), .T_YEL (12),
  .EXT_BIG(10), .EXT_SMALL(5), .PED_RT_TH(9)
) u_adapt (
  .clk          (vga_clk),
  .rst_n        (sys_rst_n),
  .sec_tick     (sec_tick),
  .car_bias     (car_bias),

  // 鏉ヨ嚜 scene_cross 鐨勮浜虹粺锟??/绛夊緟锟??
  .ped_n_lr     (ped_n_lr_out),   // [4:0]
  .ped_n_tb     (ped_n_tb_out),   // [4:0]
  .ped_has_lr   (ped_has_lr_out), // 1bit锛堝姞鍏ョ浉浣嶄繚鎸侊級
  .ped_has_tb   (ped_has_tb_out), // 1bit锟斤拷锟斤拷锟斤拷锟斤拷位锟斤拷锟街ｏ拷
  // 实时锟斤拷锟斤拷锟脚号ｏ拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟教硷拷猓?
  .ped_active_lr(ped_active_lr),  // 实时锟脚号ｏ拷锟斤拷前锟角凤拷锟斤拷锟斤拷锟斤拷锟斤拷LR锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟?
  .ped_active_tb(ped_active_tb),  // 实时锟脚号ｏ拷锟斤拷前锟角凤拷锟斤拷锟斤拷锟斤拷锟斤拷TB锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟?

  // 鑷拷?锟藉簲锟??锟??
  .mode_adapt_sw(mode_adapt_sw_s1),  // 浣跨敤鍚屾鍚庣殑淇″彿

  // 鐏緭锟??
  .col_LR_S     (col_LR_S),
  .col_LR_L     (col_LR_L),
  .col_LR_R     (col_LR_R),
  .col_TB_S     (col_TB_S),
  .col_TB_L     (col_TB_L),
  .col_TB_R     (col_TB_R),
  // 缁跨伅鏃堕暱杈撳嚭
  .green_sec_LR_S (green_sec_LR_S),
  .green_sec_LR_L (green_sec_LR_L),
  .green_sec_LR_R (green_sec_LR_R),
  .green_sec_TB_S (green_sec_TB_S),
  .green_sec_TB_L (green_sec_TB_L),
  .green_sec_TB_R (green_sec_TB_R),
  // 只锟斤拷锟斤拷锟斤拷6锟斤拷锟斤拷锟斤拷
  .cfg_LRS(cfg_LRS), .cfg_LRL(cfg_LRL), .cfg_LRR(cfg_LRR),
  .cfg_TBS(cfg_TBS), .cfg_TBL(cfg_TBL), .cfg_TBR(cfg_TBR)
);
// Human-facing simulated timings. Fixed mode keeps the configured values;
// adaptive mode makes the selected traffic and pedestrian demand visible.
reg [7:0] shown_LRS, shown_LRL, shown_LRR;
reg [7:0] shown_TBS, shown_TBL, shown_TBR;
always @* begin
  shown_LRS=cfg_LRS; shown_LRL=cfg_LRL; shown_LRR=cfg_LRR;
  shown_TBS=cfg_TBS; shown_TBL=cfg_TBL; shown_TBR=cfg_TBR;
  if (mode_adapt_sw_s1) begin
    if (car_sw_s1) begin
      shown_LRS=8'd50; shown_LRL=8'd35; shown_LRR=8'd25;
    end
    if (car_sw2_s1) begin
      shown_TBS=8'd50; shown_TBL=8'd35; shown_TBR=8'd25;
    end
    if (ped_n_lr_out >= 5) begin
      shown_TBS=shown_TBS+8'd8;
      shown_LRR=(shown_LRR>8'd5) ? shown_LRR-8'd5 : 8'd0;
    end
    if (ped_n_tb_out >= 5) begin
      shown_LRS=shown_LRS+8'd8;
      shown_TBR=(shown_TBR>8'd5) ? shown_TBR-8'd5 : 8'd0;
    end
  end
end
assign green_LRS_status=shown_LRS; assign green_LRL_status=shown_LRL;
assign green_LRR_status=shown_LRR; assign green_TBS_status=shown_TBS;
assign green_TBL_status=shown_TBL; assign green_TBR_status=shown_TBR;
assign light_status={col_TB_R,col_TB_L,col_TB_S,col_LR_R,col_LR_L,col_LR_S};

// ===================== 妯″紡鏍囩鏄剧ず妯″潡 =====================
wire mode_label_on;
mode_label #(
  .CHAR_W   (8),
  .CHAR_H   (8),
  .SPACE_W  (1),
  .SCREEN_W (640),
  .SCREEN_H (480),
  .PAD_X    (8),
  .PAD_Y    (8)
) u_mode_label (
  .pix_clk      (vga_clk),
  .x             (pix_x),
  .y             (pix_y),
  .adaptive_mode (mode_adapt_sw_s1),  // 浣跨敤鍚屾鍚庣殑淇″彿
  .mode_on      (mode_label_on)
);

// ===================== 宸︿笂瑙掓樉绀猴細people: 鎬讳汉鏁帮拷?锟絃RCar: 锟?? TBCar: 杞﹁締鏁帮紙浣跨敤 word_renderer锟?? =====================
wire people_label_on, people_num_on;
wire lrcar_label_on, lrcar_num_on;
wire tbcar_label_on, tbcar_num_on;
wire speed_label_on, speed_num_on;
// 缁跨伅鏃堕暱鏄剧ず杈撳嚭淇″彿锛堝湪 word_renderer 瀹炰緥鍖栦箣鍓嶅０鏄庯級
wire tb_green_label_on, tb_s_label_on, tb_s_num_on;
wire tb_l_label_on, tb_l_num_on;
wire tb_r_label_on, tb_r_num_on;
wire lr_green_label_on, lr_s_label_on, lr_s_num_on;
wire lr_l_label_on, lr_l_num_on;
wire lr_r_label_on, lr_r_num_on;
// 鍊掕鏃跺凡鍒犻櫎

`ifdef CROSS_TEXT_ENABLE
word_renderer #(
  .CHAR_W  (8),
  .CHAR_H  (8),
  .SPACE_W (1)
) u_word_renderer (
  .pix_clk    (vga_clk),
  .x          (pix_x),
  .y          (pix_y),
  .people_on  (),  // 鏈娇锟??
  .carM_on    (),  // 鏈娇锟??
  .carS_on    (),  // 鏈娇锟??
  .ped_num_lr (ped_n_lr_out),
  .ped_num_tb (ped_n_tb_out),
  .car_num_lr (car_n_lr_out),
  .car_num_tb (car_n_tb_out),
  .people_label_on(people_label_on),
  .people_num_on  (people_num_on),
  .lrcar_label_on (lrcar_label_on),
  .lrcar_num_on   (lrcar_num_on),
  .tbcar_label_on (tbcar_label_on),
  .tbcar_num_on   (tbcar_num_on),
  // 缁跨伅鏃堕暱杈撳叆
  .green_sec_LR_S (green_sec_LR_S),
  .green_sec_LR_L (green_sec_LR_L),
  .green_sec_LR_R (green_sec_LR_R),
  .green_sec_TB_S (green_sec_TB_S),
  .green_sec_TB_L (green_sec_TB_L),
  .green_sec_TB_R (green_sec_TB_R),
  .mode_adapt_sw  (mode_adapt_sw_s1),
  .speed_sugg     (speed_sugg),
  // 缁跨伅鏃堕暱鏄剧ず杈撳嚭
  .tb_green_label_on(tb_green_label_on),
  .tb_s_label_on    (tb_s_label_on),
  .tb_s_num_on      (tb_s_num_on),
  .tb_l_label_on    (tb_l_label_on),
  .tb_l_num_on      (tb_l_num_on),
  .tb_r_label_on    (tb_r_label_on),
  .tb_r_num_on      (tb_r_num_on),
  .lr_green_label_on(lr_green_label_on),
  .lr_s_label_on    (lr_s_label_on),
  .lr_s_num_on      (lr_s_num_on),
  .lr_l_label_on    (lr_l_label_on),
  .lr_l_num_on      (lr_l_num_on),
  .lr_r_label_on    (lr_r_label_on),
  .lr_r_num_on      (lr_r_num_on),
  .speed_label_on   (speed_label_on),
  .speed_num_on     (speed_num_on),
  // 鍊掕鏃跺凡鍒犻櫎浠ヨ妭鐪丩UT
  .countdown_LR_S   (8'd0),
  .countdown_LR_L   (8'd0),
  .countdown_LR_R   (8'd0),
  .countdown_TB_S   (8'd0),
  .countdown_TB_L   (8'd0),
  .countdown_TB_R   (8'd0),
  .cd_tb_s_num_on   (),
  .cd_tb_l_num_on   (),
  .cd_tb_r_num_on   (),
  .cd_lr_s_num_on   (),
  .cd_lr_l_num_on   (),
  .cd_lr_r_num_on   ()
);
`else
assign people_label_on=1'b0, people_num_on=1'b0;
assign lrcar_label_on=1'b0, lrcar_num_on=1'b0;
assign tbcar_label_on=1'b0, tbcar_num_on=1'b0;
assign speed_label_on=1'b0, speed_num_on=1'b0;
assign tb_green_label_on=1'b0, tb_s_label_on=1'b0, tb_s_num_on=1'b0;
assign tb_l_label_on=1'b0, tb_l_num_on=1'b0, tb_r_label_on=1'b0, tb_r_num_on=1'b0;
assign lr_green_label_on=1'b0, lr_s_label_on=1'b0, lr_s_num_on=1'b0;
assign lr_l_label_on=1'b0, lr_l_num_on=1'b0, lr_r_label_on=1'b0, lr_r_num_on=1'b0;
`endif

    // ========= 6?????????????????? + ?????? =========
    // ??????LR?????????40s?? -> ?????30s?? -> ?????20s??
    // ??????TB?????????40s?? -> ?????30s?? -> ?????20s??????????90??
    
    // ?????????????????????????????????
    localparam integer LR_S_GREEN  = 4;   // ?????? 4???
    localparam integer LR_S_YELLOW = 1;   // ?????? 1???
    
    localparam integer LR_L_GREEN  = 3;   // ?????? 3???
    localparam integer LR_L_YELLOW = 1;   // ?????? 1???
    
    localparam integer LR_R_GREEN  = 2;   // ?????? 2???
    localparam integer LR_R_YELLOW = 1;   // ?????? 1???
    
    // LR??????????????
    localparam integer LR_T0  = 0;
    localparam integer LR_T1  = LR_T0  + LR_S_GREEN;
    localparam integer LR_T2  = LR_T1  + LR_S_YELLOW;
    localparam integer LR_T3  = LR_T2;
    localparam integer LR_T4  = LR_T3  + LR_L_GREEN;
    localparam integer LR_T5  = LR_T4  + LR_L_YELLOW;
    localparam integer LR_T6  = LR_T5;
    localparam integer LR_T7  = LR_T6  + LR_R_GREEN;
    localparam integer LR_T8  = LR_T7  + LR_R_YELLOW;
    localparam integer LR_END = LR_T8;
    
    // TB???????????????LR???
    localparam integer TB_T0  = LR_END;
    localparam integer TB_T1  = TB_T0  + LR_S_GREEN;
    localparam integer TB_T2  = TB_T1  + LR_S_YELLOW;
    localparam integer TB_T3  = TB_T2;
    localparam integer TB_T4  = TB_T3  + LR_L_GREEN;
    localparam integer TB_T5  = TB_T4  + LR_L_YELLOW;
    localparam integer TB_T6  = TB_T5;
    localparam integer TB_T7  = TB_T6  + LR_R_GREEN;
    localparam integer TB_T8  = TB_T7  + LR_R_YELLOW;
    localparam integer TB_END = TB_T8;
    
    localparam integer FULL_CYCLE = TB_END;  // ???????? = LR + TB

    // 鑼冨洿鍒ゆ柇鍑芥暟
    function in_range;
        input integer s0, s1;
        input [15:0] cnt;
        begin
            in_range = (cnt >= s0) && (cnt < s1);
        end
    endfunction
    
    // ========= 杞﹁締浣嶇疆锛堣溅澶达級=========
    reg   signed [15:0] l2r_mid_head_int, l2r_top_head_int; // 宸﹀埌鍙充腑/锟??
    reg   signed [15:0] r2l_head_int;                       // 鍙冲埌宸﹁溅锟??
  
// === LightL 绾㈢豢鐏乏渚х伅绠变綅缃紙LS鐩磋鐏拷?锟絃L宸﹁浆鐏拷?锟絃R鍙宠浆鐏級===
localparam integer L_x0 = XL + TL_BOX_PAD;
localparam integer L_x1 = XL + TL_BOX_PAD + TL_BOX_W;
localparam integer L_y0 = YB - TL_BOX_PAD - TL_BOX_H;
localparam integer L_y1 = YB - TL_BOX_PAD;

// 鐏杈规
wire lightL_border =
    is_rect(L_x0, L_x1, L_y0,              L_y0 + TL_RING_T) |
    is_rect(L_x0, L_x1, L_y1 - TL_RING_T,  L_y1) |
    is_rect(L_x0, L_x0 + TL_RING_T, L_y0,  L_y1) |
    is_rect(L_x1 - TL_RING_T, L_x1, L_y0,  L_y1);

// 鐏鍐呴儴鍦嗗舰鐏綅缃紙妯悜灞呬腑锛岀旱鍚戜粠涓婂埌涓嬫帓鍒楋級
localparam integer L_light_x0 = L_x0 + 2;  // 鐏殑宸﹁竟锟??+2鍍忕礌杈硅窛
localparam integer L_light_x1 = L_light_x0 + TL_LIGHT_SIZE;

// 宸︿晶鐏 L锛屼粠涓婂埌涓嬩緷娆′负 锟?? 锟?? 锟?? 涓変釜锟??
// 绗竴涓伅锛歀L (Left) - 宸﹁浆
localparam integer L_L_y0 = L_y0 + TL_LIGHT_GAP;
localparam integer L_L_y1 = L_L_y0 + TL_LIGHT_SIZE;
wire L_L_rect = is_rect(L_light_x0, L_light_x1, L_L_y0, L_L_y1);

// 绗簩涓伅锛歀S (Straight) - 鐩磋锟??
localparam integer L_S_y0 = L_L_y1 + TL_LIGHT_GAP;
localparam integer L_S_y1 = L_S_y0 + TL_LIGHT_SIZE;
wire L_S_rect = is_rect(L_light_x0, L_light_x1, L_S_y0, L_S_y1);

// 绗笁涓伅锛歀R (Right) - 鍙宠浆锟??
localparam integer L_R_y0 = L_S_y1 + TL_LIGHT_GAP;
localparam integer L_R_y1 = L_R_y0 + TL_LIGHT_SIZE;
wire L_R_rect = is_rect(L_light_x0, L_light_x1, L_R_y0, L_R_y1);
    
// === LightR 绾㈢豢鐏彸渚х伅绠变綅缃紙RR鍙宠浆鐏拷?锟絉L宸﹁浆鐏拷?锟絉S鐩磋鐏級===    
localparam integer R_x0 = XR - TL_BOX_PAD - TL_BOX_W;
localparam integer R_x1 = XR - TL_BOX_PAD;
localparam integer R_y0 = YT + TL_BOX_PAD;
localparam integer R_y1 = YT + TL_BOX_PAD + TL_BOX_H;

// 鐏杈规
wire lightR_border =
    is_rect(R_x0, R_x1, R_y0,              R_y0 + TL_RING_T) |
    is_rect(R_x0, R_x1, R_y1 - TL_RING_T,  R_y1) |
    is_rect(R_x0, R_x0 + TL_RING_T, R_y0,  R_y1) |
    is_rect(R_x1 - TL_RING_T, R_x1, R_y0,  R_y1);

// 鐏鍐呴儴鍦嗗舰鐏綅缃紙妯悜灞呬腑锛岀旱鍚戜粠涓婂埌涓嬫帓鍒楋級
localparam integer R_light_x0 = R_x0 + 2;
localparam integer R_light_x1 = R_light_x0 + TL_LIGHT_SIZE;

// 绗竴涓伅锛歊R (Right)
localparam integer R_R_y0 = R_y0 + TL_LIGHT_GAP;
localparam integer R_R_y1 = R_R_y0 + TL_LIGHT_SIZE;
wire R_R_rect = is_rect(R_light_x0, R_light_x1, R_R_y0, R_R_y1);

// 绗簩涓伅锛歊L (Left)
localparam integer R_L_y0 = R_R_y1 + TL_LIGHT_GAP;
localparam integer R_L_y1 = R_L_y0 + TL_LIGHT_SIZE;
wire R_L_rect = is_rect(R_light_x0, R_light_x1, R_L_y0, R_L_y1);

// 绗笁涓伅锛歊S (Straight)
localparam integer R_S_y0 = R_L_y1 + TL_LIGHT_GAP;
localparam integer R_S_y1 = R_S_y0 + TL_LIGHT_SIZE;
wire R_S_rect = is_rect(R_light_x0, R_light_x1, R_S_y0, R_S_y1);
// ============== LightT ?????????????????TR???????TL???????TS?????==============
// ???????????=TL_BOX_H(48)??????=TL_BOX_W(16)
localparam integer T_x1 = XC - TL_BOX_PAD;
localparam integer T_x0 = T_x1 - TL_BOX_H;  // ???????????
localparam integer T_y1 = YT - TL_BOX_PAD;
localparam integer T_y0 = T_y1 - TL_BOX_W;  // ???????????

// ??????
wire lightT_border =
    is_rect(T_x0,T_x1,           T_y0,           T_y0+TL_RING_T) |
    is_rect(T_x0,T_x1,           T_y1-TL_RING_T, T_y1) |
    is_rect(T_x0,T_x0+TL_RING_T, T_y0,           T_y1)           |
    is_rect(T_x1-TL_RING_T,T_x1, T_y0,           T_y1);

// ???????????????????????????????????????
localparam integer T_light_y0 = T_y0 + 2;
localparam integer T_light_y1 = T_light_y0 + TL_LIGHT_SIZE;

// ???????? TR (Right)
localparam integer T_R_x0 = T_x0 + TL_LIGHT_GAP;
localparam integer T_R_x1 = T_R_x0 + TL_LIGHT_SIZE;
wire T_R_rect = is_rect(T_R_x0, T_R_x1, T_light_y0, T_light_y1);

// ????????? TL (Left)
localparam integer T_L_x0 = T_R_x1 + TL_LIGHT_GAP;
localparam integer T_L_x1 = T_L_x0 + TL_LIGHT_SIZE;
wire T_L_rect = is_rect(T_L_x0, T_L_x1, T_light_y0, T_light_y1);

// ???????? TS (Straight)
localparam integer T_S_x0 = T_L_x1 + TL_LIGHT_GAP;
localparam integer T_S_x1 = T_S_x0 + TL_LIGHT_SIZE;
wire T_S_rect = is_rect(T_S_x0, T_S_x1, T_light_y0, T_light_y1);



// ============== LightB ??????????????????BS???????BL???????BR?????==============
// ???????????=TL_BOX_H(48)??????=TL_BOX_W(16)
localparam integer B_x1 = XR - TL_BOX_PAD;
localparam integer B_x0 = B_x1 - TL_BOX_H;  // ???????????
localparam integer B_y0 = YB + TL_BOX_PAD;
localparam integer B_y1 = B_y0 + TL_BOX_W;  // ???????????

// ??????
wire lightB_border =
    is_rect(B_x0,B_x1,           B_y0,           B_y0+TL_RING_T) |
    is_rect(B_x0,B_x1,           B_y1-TL_RING_T, B_y1)           |
    is_rect(B_x0,B_x0+TL_RING_T, B_y0,           B_y1)           |
    is_rect(B_x1-TL_RING_T,B_x1, B_y0,           B_y1);

// ???????????????????????????????????????
localparam integer B_light_y0 = B_y0 + 2;
localparam integer B_light_y1 = B_light_y0 + TL_LIGHT_SIZE;

// ???????? BS (Straight)
localparam integer B_S_x0 = B_x0 + TL_LIGHT_GAP;
localparam integer B_S_x1 = B_S_x0 + TL_LIGHT_SIZE;
wire B_S_rect = is_rect(B_S_x0, B_S_x1, B_light_y0, B_light_y1);

// ????????? BL (Left)
localparam integer B_L_x0 = B_S_x1 + TL_LIGHT_GAP;
localparam integer B_L_x1 = B_L_x0 + TL_LIGHT_SIZE;
wire B_L_rect = is_rect(B_L_x0, B_L_x1, B_light_y0, B_light_y1);

// ???????? BR (Right)
localparam integer B_R_x0 = B_L_x1 + TL_LIGHT_GAP;
localparam integer B_R_x1 = B_R_x0 + TL_LIGHT_SIZE;
wire B_R_rect = is_rect(B_R_x0, B_R_x1, B_light_y0, B_light_y1);

// ================= ???????????????????????? =================
// ????????????????????????????????
localparam integer ZTL_R = 6;  // ???????????????????????

// =========== ????????????????????????===========
// ????????????????????????????????????????????
// ??????????
localparam integer L_CX  = (L_x0 + L_x1) >> 1;
localparam integer L_CY0 = (L_L_y0 + L_L_y1) >> 1;  // ?????????
localparam integer L_CY1 = (L_S_y0 + L_S_y1) >> 1;  // ?????????

localparam integer L_L_X = L_CX;
localparam integer L_L_Y = L_CY0;
localparam integer L_S_X = L_CX;
localparam integer L_S_Y = L_CY1;

// ??????????
localparam integer R_CX  = (R_x0 + R_x1) >> 1;
localparam integer R_CY0 = (R_R_y0 + R_R_y1) >> 1;  // ?????????
localparam integer R_CY1 = (R_L_y0 + R_L_y1) >> 1;  // ?????????

localparam integer R_L_X = R_CX;
localparam integer R_L_Y = R_CY1;
localparam integer R_S_X = R_CX;
localparam integer R_S_Y = R_CY0;

// ????????????
localparam integer B_CXc = (B_x0 + B_x1) >> 1;
localparam integer B_CY  = (B_y0 + B_y1) >> 1;
localparam integer B_CX0 = (B_L_x0 + B_L_x1) >> 1;  // ?????????
localparam integer B_CX1 = (B_S_x0 + B_S_x1) >> 1;  // ?????????

localparam integer B_L_X = B_CX0;
localparam integer B_L_Y = B_CY;
localparam integer B_S_X = B_CX1;
localparam integer B_S_Y = B_CY;

// ???????????
localparam integer T_CYc = (T_y0 + T_y1) >> 1;
localparam integer T_CY  = T_CYc;
localparam integer T_CX0 = (T_S_x0 + T_S_x1) >> 1;  // ?????????
localparam integer T_CX1 = (T_L_x0 + T_L_x1) >> 1;  // ?????????

localparam integer T_L_X = T_CX1;
localparam integer T_L_Y = T_CY;
localparam integer T_S_X = T_CX0;
localparam integer T_S_Y = T_CY;


// ===== ?????????????? =====
localparam integer ZBOX_PAD_X = 6;         // ?????????????????????
localparam integer ZBOX_PAD_Y = 6;         // ??????????????????????
localparam integer ZBOX_BORDER_T = 2;      // ???????????

// ===== Precompute TL box rectangles =====
// --- TOP (vertical)
localparam integer ZT_x0 = ZT_CX - (ZTL_R + ZBOX_PAD_X);
localparam integer ZT_x1 = ZT_CX + (ZTL_R + ZBOX_PAD_X);
localparam integer ZT_y0 = ZT_G_CY - (ZTL_R + ZBOX_PAD_Y);
localparam integer ZT_y1 = ZT_R_CY + (ZTL_R + ZBOX_PAD_Y);

// --- BOTTOM (vertical)
localparam integer ZB_x0 = ZB_CX - (ZTL_R + ZBOX_PAD_X);
localparam integer ZB_x1 = ZB_CX + (ZTL_R + ZBOX_PAD_X);
localparam integer ZB_y0 = ZB_G_CY - (ZTL_R + ZBOX_PAD_Y);
localparam integer ZB_y1 = ZB_R_CY + (ZTL_R + ZBOX_PAD_Y);

// --- LEFT (horizontal)
localparam integer ZL_x0 = ZL_G_CX - (ZTL_R + ZBOX_PAD_X);
localparam integer ZL_x1 = ZL_R_CX + (ZTL_R + ZBOX_PAD_X);
localparam integer ZL_y0 = ZL_CY   - (ZTL_R + ZBOX_PAD_Y);
localparam integer ZL_y1 = ZL_CY   + (ZTL_R + ZBOX_PAD_Y);

// --- RIGHT (horizontal)
localparam integer ZR_x0 = ZR_G_CX - (ZTL_R + ZBOX_PAD_X);
localparam integer ZR_x1 = ZR_R_CX + (ZTL_R + ZBOX_PAD_X);
localparam integer ZR_y0 = ZR_CY   - (ZTL_R + ZBOX_PAD_Y);
localparam integer ZR_y1 = ZR_CY   + (ZTL_R + ZBOX_PAD_Y);

// ===== ???????????????????????? =====
localparam integer ZTL_SIZE = 10;  // ????????10x10

// ZT - ????????????????????????????
localparam integer ZT_G_x0 = ZT_CX - (ZTL_SIZE>>1);
localparam integer ZT_G_x1 = ZT_CX + (ZTL_SIZE>>1);
localparam integer ZT_G_y0 = ZT_G_CY - (ZTL_SIZE>>1);
localparam integer ZT_G_y1 = ZT_G_CY + (ZTL_SIZE>>1);

localparam integer ZT_Y_x0 = ZT_CX - (ZTL_SIZE>>1);
localparam integer ZT_Y_x1 = ZT_CX + (ZTL_SIZE>>1);
localparam integer ZT_Y_y0 = ZT_Y_CY - (ZTL_SIZE>>1);
localparam integer ZT_Y_y1 = ZT_Y_CY + (ZTL_SIZE>>1);

localparam integer ZT_R_x0 = ZT_CX - (ZTL_SIZE>>1);
localparam integer ZT_R_x1 = ZT_CX + (ZTL_SIZE>>1);
localparam integer ZT_R_y0 = ZT_R_CY - (ZTL_SIZE>>1);
localparam integer ZT_R_y1 = ZT_R_CY + (ZTL_SIZE>>1);

// ZB - ?????????????????????????????
localparam integer ZB_G_x0 = ZB_CX - (ZTL_SIZE>>1);
localparam integer ZB_G_x1 = ZB_CX + (ZTL_SIZE>>1);
localparam integer ZB_G_y0 = ZB_G_CY - (ZTL_SIZE>>1);
localparam integer ZB_G_y1 = ZB_G_CY + (ZTL_SIZE>>1);

localparam integer ZB_Y_x0 = ZB_CX - (ZTL_SIZE>>1);
localparam integer ZB_Y_x1 = ZB_CX + (ZTL_SIZE>>1);
localparam integer ZB_Y_y0 = ZB_Y_CY - (ZTL_SIZE>>1);
localparam integer ZB_Y_y1 = ZB_Y_CY + (ZTL_SIZE>>1);

localparam integer ZB_R_x0 = ZB_CX - (ZTL_SIZE>>1);
localparam integer ZB_R_x1 = ZB_CX + (ZTL_SIZE>>1);
localparam integer ZB_R_y0 = ZB_R_CY - (ZTL_SIZE>>1);
localparam integer ZB_R_y1 = ZB_R_CY + (ZTL_SIZE>>1);

// ZL - ??????????????????????????
localparam integer ZL_G_x0 = ZL_G_CX - (ZTL_SIZE>>1);
localparam integer ZL_G_x1 = ZL_G_CX + (ZTL_SIZE>>1);
localparam integer ZL_G_y0 = ZL_CY - (ZTL_SIZE>>1);
localparam integer ZL_G_y1 = ZL_CY + (ZTL_SIZE>>1);

localparam integer ZL_Y_x0 = ZL_Y_CX - (ZTL_SIZE>>1);
localparam integer ZL_Y_x1 = ZL_Y_CX + (ZTL_SIZE>>1);
localparam integer ZL_Y_y0 = ZL_CY - (ZTL_SIZE>>1);
localparam integer ZL_Y_y1 = ZL_CY + (ZTL_SIZE>>1);

localparam integer ZL_R_x0 = ZL_R_CX - (ZTL_SIZE>>1);
localparam integer ZL_R_x1 = ZL_R_CX + (ZTL_SIZE>>1);
localparam integer ZL_R_y0 = ZL_CY - (ZTL_SIZE>>1);
localparam integer ZL_R_y1 = ZL_CY + (ZTL_SIZE>>1);

// ZR - ???????????????????????????
localparam integer ZR_G_x0 = ZR_G_CX - (ZTL_SIZE>>1);
localparam integer ZR_G_x1 = ZR_G_CX + (ZTL_SIZE>>1);
localparam integer ZR_G_y0 = ZR_CY - (ZTL_SIZE>>1);
localparam integer ZR_G_y1 = ZR_CY + (ZTL_SIZE>>1);

localparam integer ZR_Y_x0 = ZR_Y_CX - (ZTL_SIZE>>1);
localparam integer ZR_Y_x1 = ZR_Y_CX + (ZTL_SIZE>>1);
localparam integer ZR_Y_y0 = ZR_CY - (ZTL_SIZE>>1);
localparam integer ZR_Y_y1 = ZR_CY + (ZTL_SIZE>>1);

localparam integer ZR_R_x0 = ZR_R_CX - (ZTL_SIZE>>1);
localparam integer ZR_R_x1 = ZR_R_CX + (ZTL_SIZE>>1);
localparam integer ZR_R_y0 = ZR_CY - (ZTL_SIZE>>1);
localparam integer ZR_R_y1 = ZR_CY + (ZTL_SIZE>>1);


/// ============= 閿熸枻鎷烽敓鏁欑鎷风姸鎬侀敓鏂ゆ嫹2=閿熸暀锝忔嫹1=閿熺嫛锝忔嫹0=閿熸枻锟?? =============


// 閿熸枻鎷烽敓鏁欑鎷烽敓鏂ゆ嫹鑹查敓鏂ゆ嫹閿熻棄锛圧GB565閿熸枻鎷峰紡閿熸枻锟??
localparam [15:0] COL_RED = 16'hF800;
localparam [15:0] COL_YEL = 16'hFFE0;
localparam [15:0] COL_GRN = 16'h07E0;
localparam integer RAD    = 6; // 閿熸枻鎷烽敓鏁欑鎷峰渾閿熻娇鍗婂緞閿熸枻鎷烽敓鏂ゆ嫹閿熻妭鍖℃嫹閿熷姭浼欐嫹閿熺嫛锝忔嫹

//======================================================================
// 鐩撮敓鍙鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹锟??/閿熸枻鎷疯壊閿熸枻鎷烽敓鏂ゆ嫹 + 90閿熸枻鎷烽敓鏂ゆ嫹浣嶉敓绛嬶紝閿熻鎲嬫嫹閿熸枻鎷烽敓鏂ゆ嫹鍖婚敓鏂ゆ嫹鑰勵儱鐧告嫹閿熺祶erilog-2001閿熸枻锟??
// 閫氶敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹PAUSE_*閿熺即鍖℃嫹閿熸枻鎷烽敓瑙掑嚖鎷烽敓鏂ゆ嫹閿熺煫闈╂嫹閿熸枻鎷烽敓鏂ゆ嫹
//======================================================================

/************ 閿熺嫛璁规嫹鏃堕敓鎺ュ嚖鎷烽閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛绛规嫹閿熸枻鎷烽敓鍔害锝忔嫹 ************/
initial begin
  div = {MOVE_DIV_W{1'b0}};  // 閿熸枻鎷峰閿熸枻鎷烽敓鏂ゆ嫹棰戦敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷?
end
// 浣块敓鏂ゆ嫹initial閿熸枻鎷烽敓鏂ゆ嫹閿熺禈lways閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷峰閿熸枻鎷烽敓鏂ゆ嫹棰戦敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷穒nitial閿熸枻鎷烽敓鑺傝鎷烽敓鏂ゆ嫹閿熸枻鎷稾锟??

/************ 鍋滄閿熸枻鎷蜂綅閿熺煫璁规嫹閿熸枻锟?? ************/
localparam integer STOP_L2R_X = XL - ZB_OFF - XW;   // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鎻鎷烽敓鏂ゆ嫹鍋滄閿熸枻鎷稾閿熸枻鎷烽敓鏂ゆ嫹
localparam integer STOP_R2L_X = XR + ZB_OFF + XW;

localparam integer GAP_SPAWN  = CAR_L + 60;    // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓缂寸》鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹锟???+60閿熸枻鎷烽敓鎴綇锟??
localparam integer GAP_QUEUE  = CAR_L + 20; // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷峰暤顭掓嫹閿熸枻鎷烽敓?+20閿熸枻鎷烽敓鎴綇锟??

function is_out_right_x; input integer x; begin
  is_out_right_x = (x - (CAR_L>>1)) > H_VALID; // 閿熸枻鎷烽敓鏂ゆ嫹閿熻鍚﹁秴绛规嫹閿熸彮杈规枻锟??
end endfunction
function is_out_top_y; input integer y; begin
  is_out_top_y = (y + (CAR_L>>1)) < 0;         // 閿熸枻鎷烽敓鏂ゆ嫹閿熻鍚﹁秴绛规嫹閿熻緝杈规枻锟??
end endfunction

// ================= 閿熸枻鎷疯浆閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷锋挒閿熸枻鎷风寭銊婄櫢鎷烽敓锟??8.8閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹 =================
function car_rect_rot_q;
  input integer cx, cy, halfL, halfW;      // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹 & 閿熻闀块敓鏂ゆ嫹锟???
  input signed [15:0] cos_q, sin_q;        // cos/sin鍊奸敓鏂ゆ嫹Q8.8閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹
  reg   signed [17:0] dx, dy;
  reg   signed [31:0] lx, ly;              // Q8.8
  begin
    dx = $signed(pix_x) - $signed(cx);
    dy = $signed(pix_y) - $signed(cy);
    // x' =  dx*cos + dy*sin
    // y' = -dx*sin + dy*cos
    lx = $signed(dx)*$signed(cos_q) + $signed(dy)*$signed(sin_q);
    ly = -$signed(dx)*$signed(sin_q) + $signed(dy)*$signed(cos_q);
    car_rect_rot_q =
      ( ($signed(lx>>>8) >= -halfL) && ($signed(lx>>>8) < halfL) &&
        ($signed(ly>>>8) >= -halfW) && ($signed(ly>>>8) < halfW) );
  end
endfunction

// ============ 0..90?? ?? cos/sin ?????Q8.8?????? 95/01?? ============
localparam integer ANG_STEPS = 8;  // ????????0..16 (?????????LUT??12??8)

// 娉ㄦ剰锛歂_ST, N_RT, N_LT, N_ST_R, N_RT_R, N_LT_R, N_TSD, N_TL, N_TR_ALWAYS, N_BS_ST, N_BR, N_BL
// 宸茬Щ鑷崇934琛屼箣鍓嶅畾涔夛紝浠ヤ究鍦╳ire澹版槑鍜屾暟缁勫０鏄庝腑浣跨敤

// -- ??????????????????????????????????????????????????--
integer st_minx, st_t;   // ????????????

// ========================= ????????????YD1C?? =========================
  // ?????????????10??6
reg signed [15:0] st_x     [0:N_ST-1];
reg signed [15:0] st_y     [0:N_ST-1];

wire ST_GREEN = (col_LR_S==C_GRN);

integer st_i;
// L鈫扲 鐩磋锛氭棤鏉′欢鍒濆锟??
initial begin
  for (st_i=0; st_i<N_ST; st_i=st_i+1) begin
    st_active[st_i] = 1'b1;
    st_x[st_i]      = -CAR_L - st_i*GAP_SPAWN;
    st_y[st_i]      = YD1C;
  end
end


integer st_prev_allow_x, st_nx;
always @(posedge vga_clk) begin
  if (move_tick) begin
    st_prev_allow_x = 32'sh7fffffff;
    for (st_i=0; st_i<N_ST; st_i=st_i+1) 
    if (st_active[st_i]&& (st_i < NUM_ST)) begin
      if (!ST_GREEN && (st_x[st_i] + (CAR_L>>1) >= STOP_L2R_X))
        st_nx = STOP_L2R_X - (CAR_L>>1);
      else
        st_nx = st_x[st_i] + $signed(CAR_SPD);

      if (st_prev_allow_x != 32'sh7fffffff && st_nx > st_prev_allow_x)
        st_nx = st_prev_allow_x;

      st_x[st_i] <= st_nx;
      st_y[st_i] <= YD1C;

      st_prev_allow_x = st_nx - GAP_QUEUE;

      if (is_out_right_x(st_nx)) begin
        st_minx = st_nx;
        for (st_t=0; st_t<N_ST; st_t=st_t+1)
          if (st_active[st_t] && st_x[st_t] < st_minx) st_minx = st_x[st_t];
        st_x[st_i] <= st_minx - GAP_SPAWN;
        st_y[st_i] <= YD1C;
      end
    end
  end
end

// ?????????????????????
wire car_hit_straight_any;
// L鈫扲 鐩磋鍛戒腑
reg [N_ST-1:0] st_hit_array;
integer st_hit_i;

always @(*) begin
  st_hit_array = {N_ST{1'b0}};  // 鑷拷?锟藉簲娓呴浂锛岄伩锟?? N_ST锟??10 鐨勫搴﹂棶锟??
  for (st_hit_i = 0; st_hit_i < N_ST; st_hit_i = st_hit_i + 1) begin
    st_hit_array[st_hit_i] =
      (st_hit_i < NUM_ST) && st_active[st_hit_i] && car_rect_xy(st_x[st_hit_i], st_y[st_hit_i]);
  end
end

assign car_hit_straight_any = |st_hit_array;


// ====================== ?????YD0C ?? XL_1???? FSM?? ======================
// ====================== ?????YD0C ?? XL_1???? FSM??????? ======================

// ????????? / ?????
localparam [1:0] RT_STRAIGHT=2'd0, RT_VERT=2'd1;

// ???????
localparam integer RT_TURN_X0 = XL - (CAR_L>>1);  // ???? XL ???????
localparam integer RT_X_TGT   = XL_1;             // ????????1???????

// ??????? FSM ?????
// reg        rt_active [0:N_RT-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] rt_state  [0:N_RT-1];
reg signed [15:0] rt_x [0:N_RT-1], rt_y [0:N_RT-1];

// ?????????????? GAP_SPAWN ???
integer k_rt;
initial begin
  for (k_rt=0; k_rt<N_RT; k_rt=k_rt+1) begin
    rt_active[k_rt] = 1'b1;
    rt_state[k_rt]  = RT_STRAIGHT;
    rt_x[k_rt]      = -CAR_L - k_rt*GAP_SPAWN;
    rt_y[k_rt]      = YD0C;
  end
end

// rt绯婚敓鏂ゆ嫹閿熺嫛璁规嫹閿熺纭锋嫹
integer i_rt, prev_allow_x_rt, nx_rt, minx_rt, t_rt;

always @(posedge vga_clk) begin
  if (move_tick) begin
    // -- rt绯婚敓鍙綇鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹閿熸枻鎷锋按骞抽敓杞匡綇锟??
    prev_allow_x_rt = 32'sh7fffffff; // 閿熸枻鎷峰閿熸枻鎷蜂负閿熸枻鎷烽敓锟???
    for (i_rt=0; i_rt<N_RT; i_rt=i_rt+1) 
      if (rt_active[i_rt] && (i_rt < NUM_RT)) begin
      if (rt_state[i_rt]==RT_STRAIGHT) begin
        // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏁欑伅鍖℃嫹閿熺嫛锝忔嫹閿熸枻鎷烽敓缁炶摉锝忔嫹閿熼叺锛剁櫢鎷烽敓?
        if (col_LR_R == 2'd0 && (rt_x[i_rt] + (CAR_L>>1) >= STOP_L2R_X)) begin
          // 鍋滈敓鏂ゆ嫹鍋滄閿熺锝忔嫹閿熸枻鎷峰ご閿熸枻鎷烽敓鏂ゆ嫹鍋滄閿熺锝忔嫹
          nx_rt = STOP_L2R_X - (CAR_L>>1);  // 鍋滄
        end else if (rt_x[i_rt] < RT_TURN_X0) begin
          nx_rt = rt_x[i_rt] + $signed(CAR_SPD);   // 閿熸枻鎷烽敓鏂ゆ嫹鍓嶉敓鏂ゆ嫹
        end else begin
          nx_rt          = RT_X_TGT;               // 閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹鎮栴剨鎷烽敓鏂ゆ嫹閿熶茎鍖℃嫹閿熺祻
          rt_state[i_rt] <= RT_VERT;               // 閿熸枻鎷烽敓璇瀭鐩撮敓鏂ゆ嫹
        end

        // 閿熸枻鎷烽敓鏂ゆ嫹閿熺纭锋嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸澃绛规嫹閿熸枻鎷峰墠閿熸枻锟??
        if (prev_allow_x_rt != 32'sh7fffffff && nx_rt > prev_allow_x_rt)
          nx_rt = prev_allow_x_rt;

        rt_x[i_rt] <= nx_rt;
        rt_y[i_rt] <= YD0C;                        // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷穣閿熸枻鎷烽敓鐤ワ紙閿熼摪鍑ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻锟??
        prev_allow_x_rt = nx_rt - GAP_QUEUE;
      end
    end

    // -- rt绯婚敓鍙揪鎷风洿閿熻娇锝忔嫹閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛璁规嫹閿熸枻锟??--
    for (i_rt=0; i_rt<N_RT; i_rt=i_rt+1) 
      if (rt_active[i_rt] && (i_rt < NUM_RT) && rt_state[i_rt]==RT_VERT) begin
      rt_x[i_rt] <= RT_X_TGT;                      // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷稾杞敓鏂ゆ嫹锟???
      rt_y[i_rt] <= rt_y[i_rt] + $signed(CAR_SPD); // 閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛璁规嫹
      if (rt_y[i_rt] >= $signed(V_VALID + (CAR_L>>1))) begin
        // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷峰箷閿熼樁璇ф嫹閿熸枻鎷峰惊閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷锋倴鐟囬敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹涓洪敓鏂ゆ嫹灏弜閿熸枻鎷稧AP_SPAWN
        minx_rt = rt_x[i_rt];
        for (t_rt=0; t_rt<N_RT; t_rt=t_rt+1)
          if (rt_active[t_rt] && rt_x[t_rt] < minx_rt) minx_rt = rt_x[t_rt];
        rt_x[i_rt]     <= minx_rt - GAP_SPAWN;
        rt_y[i_rt]     <= YD0C;
        rt_state[i_rt] <= RT_STRAIGHT;
      end
    end
  end
end

wire [5:0] rt_idx_en = { (NUM_RT>5), (NUM_RT>4), (NUM_RT>3), (NUM_RT>2), (NUM_RT>1), (NUM_RT>0) };

wire car_hit_rturn_arr =
  (rt_idx_en[0] & rt_active[0] && ((rt_state[0]==RT_STRAIGHT && car_rect_h(rt_x[0], rt_y[0])) ||
                                   (rt_state[0]==RT_VERT     && car_rect_v(rt_x[0], rt_y[0])))) |
  (rt_idx_en[1] & rt_active[1] && ((rt_state[1]==RT_STRAIGHT && car_rect_h(rt_x[1], rt_y[1])) ||
                                   (rt_state[1]==RT_VERT     && car_rect_v(rt_x[1], rt_y[1])))) |
  (rt_idx_en[2] & rt_active[2] && ((rt_state[2]==RT_STRAIGHT && car_rect_h(rt_x[2], rt_y[2])) ||
                                   (rt_state[2]==RT_VERT     && car_rect_v(rt_x[2], rt_y[2])))) |
  (rt_idx_en[3] & rt_active[3] && ((rt_state[3]==RT_STRAIGHT && car_rect_h(rt_x[3], rt_y[3])) ||
                                   (rt_state[3]==RT_VERT     && car_rect_v(rt_x[3], rt_y[3])))) |
  (rt_idx_en[4] & rt_active[4] && ((rt_state[4]==RT_STRAIGHT && car_rect_h(rt_x[4], rt_y[4])) ||
                                   (rt_state[4]==RT_VERT     && car_rect_v(rt_x[4], rt_y[4])))) |
  (rt_idx_en[5] & rt_active[5] && ((rt_state[5]==RT_STRAIGHT && car_rect_h(rt_x[5], rt_y[5])) ||
                                   (rt_state[5]==RT_VERT     && car_rect_v(rt_x[5], rt_y[5]))));

                    
//======================================================================
// LEFT TURN ARC (EAST -> NORTH, CCW)  ????????????????????????????
// ???????? 1/4 ?????? (X_TURN, YD2C) ????? (XR_1, YT)
localparam [1:0]   LT_STRAIGHT=2'd0, LT_ARC=2'd1, LT_VERT=2'd2;
wire [N_LT-1:0] lt_hit_rot;
wire [N_LT-1:0] lt_hit_valid;

// ---------- ?????????????????? XR_1 & YT?? ----------
// ????R = YD2C - YT?????LT_X_TURN = XR_1 - R??????C = (LT_X_TURN, YD2C - R)
localparam integer ARC_MGN     = 0;
localparam integer LT_R_BASE   = (YD2C - YT) - ARC_MGN;
localparam integer LT_R        = (LT_R_BASE>8) ? LT_R_BASE : 8;

localparam integer LT_X_TURN   = XR_1 - LT_R;
localparam integer LT_CX       = LT_X_TURN;
localparam integer LT_CY       = YD2C - LT_R;

// ---------- ??/???? ----------
// reg        lt_active [0:N_LT-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] lt_state  [0:N_LT-1];
reg signed [15:0] lt_x [0:N_LT-1], lt_y [0:N_LT-1];

// ---------- ?????????0..ANG_STEPS ??? 0??..90?? ????? ----------
reg [7:0]  lt_ang_idx   [0:N_LT-1];
reg [15:0] lt_tick_ps   [0:N_LT-1];
reg [15:0] lt_tick_cnt  [0:N_LT-1];
reg [7:0]  lt_ang_idx_d [0:N_LT-1];  // ???????????????????????

// ---------- ?????????????? ----------
integer idx_lt;
initial begin
  for (idx_lt=0; idx_lt<N_LT; idx_lt=idx_lt+1) begin
    lt_active[idx_lt]   = 1'b1;
    lt_state[idx_lt]    = LT_STRAIGHT;
    lt_x[idx_lt]        = -CAR_L - idx_lt*(CAR_L + 60);
    lt_y[idx_lt]        = YD2C;
    lt_ang_idx[idx_lt]  = 0;
    lt_tick_ps[idx_lt]  = 1;
    lt_tick_cnt[idx_lt] = 0;
    lt_ang_idx_d[idx_lt]= 0;
  end
end

// ---------- ??????????? ROM ?????????????? move_tick ??? ----------
integer ii_d_lt;
always @(posedge vga_clk) begin : LT_SHADOW_ANG
  integer j;
  for (j=0; j<N_LT; j=j+1) lt_ang_idx_d[j] <= lt_ang_idx[j];
end

// ---------- ??"???????"???? sin/cos??????=????? ----------
wire signed [15:0] lt_cos_pos_q [0:N_LT-1];
wire signed [15:0] lt_sin_pos_q [0:N_LT-1];

genvar g_lt_pos;
generate
for (g_lt_pos=0; g_lt_pos<N_LT; g_lt_pos=g_lt_pos+1) begin: G_LT_POS_TRIG
  wire signed [15:0] COS_Q_POS, SIN_Q_POS;
  sincos90_q88 #(.ANG_STEPS(ANG_STEPS)) u_sc_pos (
    .clk  (vga_clk),
    .idx  (lt_ang_idx_d[g_lt_pos]),   // ???? ?? ???? ROM ???
    .cos_q(COS_Q_POS),
    .sin_q(SIN_Q_POS)
  );
  // EAST??NORTH ???????????x = Cx + R*sin(a), y = Cy + R*cos(a)
  assign lt_cos_pos_q[g_lt_pos] = COS_Q_POS;   // +cos(a)
  assign lt_sin_pos_q[g_lt_pos] = SIN_Q_POS;   // +sin(a)
end
endgenerate

// ---------- ?????? ----------
integer lt_i, lt_prev_allow_x, lt_nx, lt_minx, lt_t;
integer lt_steps_on_arc;
integer tmp_ps;   // ???? lt_tick_ps ??
wire L_L_GREEN = (col_LR_L == C_GRN);

always @(posedge vga_clk) begin
  if (move_tick) begin
    // ===== ????????? + ???? + ???? + ?? =====
    lt_prev_allow_x = 32'sh7fffffff; // ??????????
    for (lt_i=0; lt_i<N_LT; lt_i=lt_i+1) 
      if (lt_active[lt_i] && (lt_i < NUM_LT)) begin
      if (lt_state[lt_i]==LT_STRAIGHT) begin
        // ??/????????????????????
        if (!L_L_GREEN && (lt_x[lt_i] + (CAR_L>>1) >= STOP_L2R_X))
          lt_nx = STOP_L2R_X - (CAR_L>>1);
        else if (lt_x[lt_i] < LT_X_TURN)
          lt_nx = lt_x[lt_i] + $signed(CAR_SPD);   // ???????
        else begin
          // ?????? a=0????????????????? ROM ?????
          lt_ang_idx[lt_i] <= 0;
          tmp_ps = ((LT_R + (CAR_SPD-1)) / CAR_SPD) / ANG_STEPS;
          if (tmp_ps <= 0) tmp_ps = 1;
          lt_tick_ps[lt_i] <= tmp_ps;
          lt_tick_cnt[lt_i]<= 0;

          lt_nx            = LT_X_TURN;   // ?????
          lt_state[lt_i]   <= LT_ARC;
        end

        // ?????????????????????????????????????? - GAP_QUEUE??
        if (lt_prev_allow_x != 32'sh7fffffff && lt_nx > lt_prev_allow_x)
          lt_nx = lt_prev_allow_x;

        lt_x[lt_i] <= lt_nx;
        lt_y[lt_i] <= YD2C;
        lt_prev_allow_x = lt_nx - (CAR_L + 20);
      end
    end

    // ===== ?????????????????? + ????????????=???? =====
    for (lt_i=0; lt_i<N_LT; lt_i=lt_i+1) 
    if (lt_active[lt_i] && (lt_i < NUM_LT) && lt_state[lt_i]==LT_ARC)  begin
      // ???????????????????"???????"???? lt_ang_idx??????
      if (lt_ang_idx[lt_i] < ANG_STEPS) begin
        lt_tick_cnt[lt_i] <= lt_tick_cnt[lt_i] + 1'b1;
        if (lt_tick_cnt[lt_i] >= lt_tick_ps[lt_i]) begin
          lt_tick_cnt[lt_i] <= 0;
          lt_ang_idx[lt_i]  <= lt_ang_idx[lt_i] + 1'b1; // ?????????????? ROM ????
        end
      end

      // ????????x = Cx + R*sin(a) ; y = Cy + R*cos(a)??Q8.8 ?? >>8??
      for (lt_steps_on_arc=0; lt_steps_on_arc<CAR_SPD; lt_steps_on_arc=lt_steps_on_arc+1) begin
        lt_x[lt_i] <= LT_CX + ( ($signed(LT_R) * $signed(lt_sin_pos_q[lt_i])) >>> 8 );
        lt_y[lt_i] <= LT_CY + ( ($signed(LT_R) * $signed(lt_cos_pos_q[lt_i])) >>> 8 );
      end

      // ???????? 90?? ??
      if (lt_ang_idx[lt_i] >= ANG_STEPS) lt_state[lt_i] <= LT_VERT;
    end

    // ===== ????????????????????? =====
    for (lt_i=0; lt_i<N_LT; lt_i=lt_i+1) 
    if (lt_active[lt_i] && (lt_i < NUM_LT) && lt_state[lt_i]==LT_VERT) begin
      lt_x[lt_i] <= XR_1;                         // ????? x ???
      lt_y[lt_i] <= lt_y[lt_i] - $signed(CAR_SPD);
      if ( (lt_y[lt_i] + $signed(CAR_L>>1)) < 0 ) begin
        // ???????????????????? x??
        lt_minx = lt_x[lt_i];
        for (lt_t=0; lt_t<N_LT; lt_t=lt_t+1)
          if (lt_active[lt_t] && lt_x[lt_t] < lt_minx) lt_minx = lt_x[lt_t];
        lt_x[lt_i]     <= lt_minx - (CAR_L + 60);
        lt_y[lt_i]     <= YD2C;
        lt_state[lt_i] <= LT_STRAIGHT;
        lt_ang_idx[lt_i]   <= 0;
        lt_tick_cnt[lt_i]  <= 0;
      end
    end
  end // move_tick
end

genvar g_lt;
generate
for (g_lt=0; g_lt<N_LT; g_lt=g_lt+1) begin: G_LT_ROT_HIT
  // ???????? trig??lt_cos_pos_q / lt_sin_pos_q
  wire signed [15:0] COS_Q = lt_cos_pos_q[g_lt]; // cos(a_d)
  wire signed [15:0] SIN_Q = lt_sin_pos_q[g_lt]; // sin(a_d)

  // EAST->NORTH?????????cos' = +cos(a)??sin' = -sin(a)
  wire signed [15:0] COS2_Q =  COS_Q;
  wire signed [15:0] SIN2_Q = -SIN_Q;

  car_rect_rot_ip #(.Q(8)) u_rot (
    .clk      (vga_clk),
    .valid_in (1'b1),
    .pix_x    (pix_x),
    .pix_y    (pix_y),
    .cx       (lt_x[g_lt]),
    .cy       (lt_y[g_lt]),
    .halfL    ({ {8{1'b0}}, (CAR_L>>1) }),
    .halfW    ({ {8{1'b0}}, (CAR_W>>1) }),
    .cos_q    (COS2_Q),
    .sin_q    (SIN2_Q),
    .hit      (lt_hit_rot[g_lt]),
    .valid_out(lt_hit_valid[g_lt])
  );
end
endgenerate

// 绱㈠紩浣胯兘锛氫笌 NUM_LT 缁戝畾锛沜ar_sw_2=1 鏃跺彧锟?? 0锟??1
wire [3:0] lt_idx_en = { (NUM_LT>3), (NUM_LT>2), (NUM_LT>1), (NUM_LT>0) };

wire car_hit_lturn_arr =
  (lt_idx_en[0] & lt_active[0] && ((lt_state[0]==LT_STRAIGHT && car_rect_h(lt_x[0], lt_y[0])) ||
                                   (lt_state[0]==LT_ARC      && lt_hit_valid[0] && lt_hit_rot[0]) ||
                                   (lt_state[0]==LT_VERT     && car_rect_v(lt_x[0], lt_y[0])))) |
  (lt_idx_en[1] & lt_active[1] && ((lt_state[1]==LT_STRAIGHT && car_rect_h(lt_x[1], lt_y[1])) ||
                                   (lt_state[1]==LT_ARC      && lt_hit_valid[1] && lt_hit_rot[1]) ||
                                   (lt_state[1]==LT_VERT     && car_rect_v(lt_x[1], lt_y[1])))) |
  (lt_idx_en[2] & lt_active[2] && ((lt_state[2]==LT_STRAIGHT && car_rect_h(lt_x[2], lt_y[2])) ||
                                   (lt_state[2]==LT_ARC      && lt_hit_valid[2] && lt_hit_rot[2]) ||
                                   (lt_state[2]==LT_VERT     && car_rect_v(lt_x[2], lt_y[2])))) |
  (lt_idx_en[3] & lt_active[3] && ((lt_state[3]==LT_STRAIGHT && car_rect_h(lt_x[3], lt_y[3])) ||
                                   (lt_state[3]==LT_ARC      && lt_hit_valid[3] && lt_hit_rot[3]) ||
                                   (lt_state[3]==LT_VERT     && car_rect_v(lt_x[3], lt_y[3]))));

wire car_hit_r2l = 1'b0;
// ????????R_S / R_L ??????????????/?????????????????
wire RS_GREEN = (col_LR_S==C_GRN);  // ?????
wire RL_GREEN = (col_LR_L==C_GRN);  // ?????

// reg        stR_active [0:N_ST_R-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg signed [15:0] stR_x [0:N_ST_R-1];
reg signed [15:0] stR_y [0:N_ST_R-1];

integer i_stR, stR_prev_allow_x, stR_nx, stR_minx, stR_t;

// ???????????????????????
initial begin
  for (i_stR=0; i_stR<N_ST_R; i_stR=i_stR+1) begin
    stR_active[i_stR] = 1'b1;
    stR_x[i_stR]      = H_VALID + CAR_L + i_stR*GAP_SPAWN;  // ???????
    stR_y[i_stR]      = YU1C;
  end
end

always @(posedge vga_clk) begin
  if (move_tick) begin
    stR_prev_allow_x = -32'sh7fffffff; // ???????????????????????????????+???
    for (i_stR=0; i_stR<N_ST_R; i_stR=i_stR+1) 
    if (stR_active[i_stR] && (i_stR < NUM_ST_R)) begin
      // ??/?????????????????????????????? x-(L/2) ???? <= STOP_R2L_X??
      if (!RS_GREEN && (stR_x[i_stR] - (CAR_L>>1) <= STOP_R2L_X))
        stR_nx = STOP_R2L_X + (CAR_L>>1);
      else
        stR_nx = stR_x[i_stR] - $signed(CAR_SPD);

      // ??????????????????????? < ????????? + GAP_QUEUE??
      if (stR_prev_allow_x != -32'sh7fffffff && stR_nx < stR_prev_allow_x)
        stR_nx = stR_prev_allow_x;

      stR_x[i_stR] <= stR_nx;
      stR_y[i_stR] <= YU1C;

      stR_prev_allow_x = stR_nx + GAP_QUEUE;

      // ??????????????????
      if ((stR_nx + (CAR_L>>1)) < 0) begin
        stR_minx = stR_nx;
        for (stR_t=0; stR_t<N_ST_R; stR_t=stR_t+1)
          if (stR_active[stR_t] && stR_x[stR_t] > stR_minx) stR_minx = stR_x[stR_t]; // ??????
        stR_x[i_stR] <= stR_minx + GAP_SPAWN;
        stR_y[i_stR] <= YU1C;
      end
    end
  end
end

// ?????????????????????
wire car_hit_r2l_straight_arr;
// R鈫扡 鐩磋鍛戒腑
reg [N_ST_R-1:0] stR_hit_array;
integer stR_hit_i;

always @(*) begin
  stR_hit_array = {N_ST_R{1'b0}};  // ? 鑷拷?锟藉簲瀹藉害娓呴浂
  for (stR_hit_i = 0; stR_hit_i < N_ST_R; stR_hit_i = stR_hit_i + 1) begin
    stR_hit_array[stR_hit_i] =
      (stR_hit_i < NUM_ST_R) &&
      stR_active[stR_hit_i] &&
      car_rect_h(stR_x[stR_hit_i], stR_y[stR_hit_i]);
  end
end

assign car_hit_r2l_straight_arr = |stR_hit_array;

  
localparam [1:0]   RT2_STRAIGHT=2'd0, RT2_VERT=2'd1;
localparam integer RT2_TURN_X0 = XR + (CAR_L>>1);  // ??????????
localparam integer RT2_X_TGT   = XR_3;             // ????????3???????

// reg        rt2_active [0:N_RT_R-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] rt2_state  [0:N_RT_R-1];
reg signed [15:0] rt2_x [0:N_RT_R-1], rt2_y [0:N_RT_R-1];

integer i_rt2, prev_allow_x_rt2, nx_rt2, maxx_rt2, t_rt2;

// ????????????????? YU0C ????
initial begin
  for (i_rt2=0; i_rt2<N_RT_R; i_rt2=i_rt2+1) begin
    rt2_active[i_rt2] = 1'b1;
    rt2_state[i_rt2]  = RT2_STRAIGHT;
    rt2_x[i_rt2]      = H_VALID + CAR_L + i_rt2*GAP_SPAWN;
    rt2_y[i_rt2]      = YU0C;
  end
end

always @(posedge vga_clk) begin
  if (move_tick) begin
    // rt2绯婚敓鍙綇鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹閿熸枻鎷锋按骞抽敓杞匡綇锟??
    prev_allow_x_rt2 = -32'sh7fffffff;
    for (i_rt2=0; i_rt2<N_RT_R; i_rt2=i_rt2+1) 
    if (rt2_active[i_rt2] && (i_rt2 < NUM_RT_R)) begin
      if (rt2_state[i_rt2]==RT2_STRAIGHT) begin
        // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏁欑伅鍖℃嫹閿熺嫛锝忔嫹閿熸枻鎷烽敓缁炶摉锝忔嫹閿熼叺锛剁櫢鎷烽敓?
        if (col_LR_R == 2'd0 && (rt2_x[i_rt2] - (CAR_L>>1) <= STOP_R2L_X)) begin
          // 鍋滈敓鏂ゆ嫹鍋滄閿熺锝忔嫹閿熸枻鎷峰ご閿熸枻鎷烽敓鏂ゆ嫹鍋滄閿熺锝忔嫹
          nx_rt2 = STOP_R2L_X + (CAR_L>>1);  // 鍋滄
        end else if (rt2_x[i_rt2] > RT2_TURN_X0) begin
          nx_rt2 = rt2_x[i_rt2] - $signed(CAR_SPD);
        end else begin
          nx_rt2           = RT2_X_TGT;    // 閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹鎮栴剨鎷烽敓鏂ゆ嫹閿熶茎鍖℃嫹閿熺祻
          rt2_state[i_rt2] <= RT2_VERT;
        end
        if (prev_allow_x_rt2 != -32'sh7fffffff && nx_rt2 < prev_allow_x_rt2)
          nx_rt2 = prev_allow_x_rt2;

        rt2_x[i_rt2] <= nx_rt2;  rt2_y[i_rt2] <= YU0C;
        prev_allow_x_rt2 = nx_rt2 + GAP_QUEUE;
      end
    end

// rt2绯婚敓鍙揪鎷风洿閿熻娇锝忔嫹閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛璁规嫹閿熸枻锟??
for (i_rt2=0; i_rt2<N_RT_R; i_rt2=i_rt2+1) 
if (rt2_active[i_rt2] && (i_rt2 < NUM_RT_R) && rt2_state[i_rt2]==RT2_VERT) begin
  rt2_x[i_rt2] <= RT2_X_TGT;
  rt2_y[i_rt2] <= rt2_y[i_rt2] - $signed(CAR_SPD);  // 閿熸枻鎷烽敓鏂ゆ嫹閿熺嫛璁规嫹
  if ( (rt2_y[i_rt2] + $signed(CAR_L>>1)) < 0 ) begin  // 閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷峰箷閿熸枻鎷烽敓鏂ゆ嫹
    // 寰敓鏂ゆ嫹閿熸枻锟??"閿熸枻鎷烽敓?"閿熸枻鎷穢閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷蜂负閿熸枻鎷烽敓绲伴敓鏂ゆ嫹GAP_SPAWN
    maxx_rt2 = rt2_x[i_rt2];
    for (t_rt2=0; t_rt2<N_RT_R; t_rt2=t_rt2+1)
      if (rt2_active[t_rt2] && rt2_x[t_rt2] > maxx_rt2) maxx_rt2 = rt2_x[t_rt2];
    rt2_x[i_rt2]     <= maxx_rt2 + GAP_SPAWN;
    rt2_y[i_rt2]     <= YU0C;
    rt2_state[i_rt2] <= RT2_STRAIGHT;
  end
end

  end
end
wire [5:0] rt2_idx_en = { (NUM_RT_R>5), (NUM_RT_R>4), (NUM_RT_R>3), (NUM_RT_R>2), (NUM_RT_R>1), (NUM_RT_R>0) };
wire car_hit_rturn_R_arr =
  (rt2_idx_en[0] & rt2_active[0] && ((rt2_state[0]==RT2_STRAIGHT && car_rect_h(rt2_x[0], rt2_y[0])) ||
                                     (rt2_state[0]==RT2_VERT     && car_rect_v(rt2_x[0], rt2_y[0])))) |
  (rt2_idx_en[1] & rt2_active[1] && ((rt2_state[1]==RT2_STRAIGHT && car_rect_h(rt2_x[1], rt2_y[1])) ||
                                     (rt2_state[1]==RT2_VERT     && car_rect_v(rt2_x[1], rt2_y[1])))) |
  (rt2_idx_en[2] & rt2_active[2] && ((rt2_state[2]==RT2_STRAIGHT && car_rect_h(rt2_x[2], rt2_y[2])) ||
                                     (rt2_state[2]==RT2_VERT     && car_rect_v(rt2_x[2], rt2_y[2])))) |
  (rt2_idx_en[3] & rt2_active[3] && ((rt2_state[3]==RT2_STRAIGHT && car_rect_h(rt2_x[3], rt2_y[3])) ||
                                     (rt2_state[3]==RT2_VERT     && car_rect_v(rt2_x[3], rt2_y[3])))) |
  (rt2_idx_en[4] & rt2_active[4] && ((rt2_state[4]==RT2_STRAIGHT && car_rect_h(rt2_x[4], rt2_y[4])) ||
                                     (rt2_state[4]==RT2_VERT     && car_rect_v(rt2_x[4], rt2_y[4])))) |
  (rt2_idx_en[5] & rt2_active[5] && ((rt2_state[5]==RT2_STRAIGHT && car_rect_h(rt2_x[5], rt2_y[5])) ||
                                     (rt2_state[5]==RT2_VERT     && car_rect_v(rt2_x[5], rt2_y[5]))));


//======================================================================
// RIGHT-TOP LEFT TURN (WEST -> SOUTH, CCW 90??)
// ????????????????????????? 1/4 ???????????
// ?????????? (XL_3, YB)
//======================================================================
localparam [1:0]   LT2_STRAIGHT=2'd0, LT2_ARC=2'd1, LT2_VERT=2'd2;

// ---------- ???????????"???????????"???? ----------
localparam integer ARC_MGN2   = 0;
localparam integer LT2_R_BASE = (YB - YU2C) - ARC_MGN2;
localparam integer LT2_R      = (LT2_R_BASE>8) ? LT2_R_BASE : 8;

localparam integer LT2_CX     = XL_3 + LT2_R;
localparam integer LT2_CY     = YB;
localparam integer LT2_X_TURN = LT2_CX;  // ????? x ????

// ---------- ??/???? ----------
// reg        lt2_active [0:N_LT_R-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] lt2_state  [0:N_LT_R-1];
reg signed [15:0] lt2_x [0:N_LT_R-1], lt2_y [0:N_LT_R-1];

// ---------- ?????????0..ANG_STEPS ??? 0??..90?? ----------
reg [7:0]  lt2_ang_idx   [0:N_LT_R-1];
reg [15:0] lt2_tick_ps   [0:N_LT_R-1];
reg [15:0] lt2_tick_cnt  [0:N_LT_R-1];

// ---------- ?????????????"???????"?? ROM ??????? ----------
reg [7:0]  lt2_ang_idx_d [0:N_LT_R-1];
always @(posedge vga_clk) begin : LT2_SHADOW_ANG
  integer j;
  for (j=0; j<N_LT_R; j=j+1)
    lt2_ang_idx_d[j] <= lt2_ang_idx[j];
end

// ---------- ????????? trig???????????=???????????? ----------
wire signed [15:0] lt2_cos_pos_q [0:N_LT_R-1];
wire signed [15:0] lt2_sin_pos_q [0:N_LT_R-1];

genvar g_lt2_pos;
generate
for (g_lt2_pos=0; g_lt2_pos<N_LT_R; g_lt2_pos=g_lt2_pos+1) begin: G_LT2_POS_TRIG
  wire signed [15:0] COS_Q_POS, SIN_Q_POS;
  sincos90_q88 #(.ANG_STEPS(ANG_STEPS)) u_sc2_pos (
    .clk  (vga_clk),
    .idx  (lt2_ang_idx_d[g_lt2_pos]),   // ???? ?? ???? ROM ???
    .cos_q(COS_Q_POS),
    .sin_q(SIN_Q_POS)
  );
  // ????"???????????"??????????? sin(a), cos(a)
  assign lt2_cos_pos_q[g_lt2_pos] = COS_Q_POS;
  assign lt2_sin_pos_q[g_lt2_pos] = SIN_Q_POS;
end
endgenerate

// ---------- ??????? ----------
integer idx_lt2;
initial begin
  for (idx_lt2=0; idx_lt2<N_LT_R; idx_lt2=idx_lt2+1) begin
    lt2_active[idx_lt2]   = 1'b1;
    lt2_state[idx_lt2]    = LT2_STRAIGHT;
    lt2_x[idx_lt2]        = H_VALID + CAR_L + idx_lt2*(CAR_L + 60);
    lt2_y[idx_lt2]        = YU2C;
    lt2_ang_idx[idx_lt2]  = 0;
    lt2_tick_ps[idx_lt2]  = 1;
    lt2_tick_cnt[idx_lt2] = 0;
  end
end

// ---------- ?????? ----------
integer i_lt2, prev_allow_x_lt2, nx_lt2, maxx_lt2, t_lt2;
integer steps_on_arc_lt2;
integer tmp_ps2;

always @(posedge vga_clk) begin
  if (move_tick) begin
    // ===== ????????? + ????????????=====
    prev_allow_x_lt2 = -32'sh7fffffff;
    for (i_lt2=0; i_lt2<N_LT_R; i_lt2=i_lt2+1) 
    if (lt2_active[i_lt2] && (i_lt2 < NUM_LT_R)) begin
      if (lt2_state[i_lt2]==LT2_STRAIGHT) begin
        if (!RL_GREEN && (lt2_x[i_lt2] - (CAR_L>>1) <= STOP_R2L_X))
          nx_lt2 = STOP_R2L_X + (CAR_L>>1);
        else if (lt2_x[i_lt2] > LT2_X_TURN)
          nx_lt2 = lt2_x[i_lt2] - $signed(CAR_SPD);
        else begin
          // ?????? a=0???????????????? ROM ?? trig??
          lt2_ang_idx[i_lt2] <= 0;
          tmp_ps2 = ((LT2_R + (CAR_SPD-1)) / CAR_SPD) / ANG_STEPS;
          if (tmp_ps2 <= 0) tmp_ps2 = 1;
          lt2_tick_ps[i_lt2]  <= tmp_ps2;
          lt2_tick_cnt[i_lt2] <= 0;

          nx_lt2              = LT2_X_TURN;
          lt2_state[i_lt2]    <= LT2_ARC;
        end

        // ????????????
        if (prev_allow_x_lt2 != -32'sh7fffffff && nx_lt2 < prev_allow_x_lt2)
          nx_lt2 = prev_allow_x_lt2;

        lt2_x[i_lt2] <= nx_lt2;
        lt2_y[i_lt2] <= YU2C;
        prev_allow_x_lt2 = nx_lt2 + (CAR_L + 20);
      end
    end

    // ===== ??????WEST ?? SOUTH??????? 0..90??=====
    for (i_lt2=0; i_lt2<N_LT_R; i_lt2=i_lt2+1) 
    if (lt2_active[i_lt2] && (i_lt2 < NUM_LT_R) && lt2_state[i_lt2]==LT2_ARC)  begin
      // ???????????
      if (lt2_ang_idx[i_lt2] < ANG_STEPS) begin
        lt2_tick_cnt[i_lt2] <= lt2_tick_cnt[i_lt2] + 1'b1;
        if (lt2_tick_cnt[i_lt2] >= lt2_tick_ps[i_lt2]) begin
          lt2_tick_cnt[i_lt2] <= 0;
          lt2_ang_idx[i_lt2]  <= lt2_ang_idx[i_lt2] + 1'b1; // ?????????????? ROM ????
        end
      end

      // ??????????"???????????"????
      // x = Cx - R*sin(a) ; y = Cy - R*cos(a)  ??Q8.8 ?? >>8??
      for (steps_on_arc_lt2=0; steps_on_arc_lt2<CAR_SPD; steps_on_arc_lt2=steps_on_arc_lt2+1) begin
        lt2_x[i_lt2] <= LT2_CX - ( ($signed(LT2_R) * $signed(lt2_sin_pos_q[i_lt2])) >>> 8 );
        lt2_y[i_lt2] <= LT2_CY - ( ($signed(LT2_R) * $signed(lt2_cos_pos_q[i_lt2])) >>> 8 );
      end

      // ???????????????????????
      if (lt2_ang_idx_d[i_lt2] >= ANG_STEPS) begin
        lt2_state[i_lt2] <= LT2_VERT;
      end
    end

    // ===== ????????x ??? XL_3??=====
    for (i_lt2=0; i_lt2<N_LT_R; i_lt2=i_lt2+1) 
    if (lt2_active[i_lt2] && (i_lt2 < NUM_LT_R) && lt2_state[i_lt2]==LT2_VERT) begin
      lt2_x[i_lt2] <= XL_3;
      lt2_y[i_lt2] <= lt2_y[i_lt2] + $signed(CAR_SPD);
      if (lt2_y[i_lt2] >= $signed(V_VALID + (CAR_L>>1))) begin
        // ???????????"????"?? x??
        maxx_lt2 = lt2_x[i_lt2];
        for (t_lt2=0; t_lt2<N_LT_R; t_lt2=t_lt2+1)
          if (lt2_active[t_lt2] && lt2_x[t_lt2] > maxx_lt2) maxx_lt2 = lt2_x[t_lt2];
        lt2_x[i_lt2]     <= maxx_lt2 + (CAR_L + 60);
        lt2_y[i_lt2]     <= YU2C;
        lt2_state[i_lt2] <= LT2_STRAIGHT;
        lt2_ang_idx[i_lt2]<= 0;
        lt2_tick_cnt[i_lt2]<= 0;
      end
    end
  end
end
// ================= ??????????WEST -> SOUTH?? =================
wire [N_LT_R-1:0] lt2_hit_rot;
wire [N_LT_R-1:0] lt2_hit_valid;

genvar g_lt2;
generate
for (g_lt2=0; g_lt2<N_LT_R; g_lt2=g_lt2+1) begin: G_LT2_ROT_HIT
  // ???????? trig??lt2_cos_pos_q / lt2_sin_pos_q
  wire signed [15:0] COS_Q = lt2_cos_pos_q[g_lt2]; // cos(a_d)
  wire signed [15:0] SIN_Q = lt2_sin_pos_q[g_lt2]; // sin(a_d)

  // WEST -> SOUTH????????cos' = -cos(a)??sin' = +sin(a)
  wire signed [15:0] COS2_Q = -COS_Q;
  wire signed [15:0] SIN2_Q =  SIN_Q;

  car_rect_rot_ip #(.Q(8)) u_rot2 (
    .clk      (vga_clk),
    .valid_in (1'b1),
    .pix_x    (pix_x),
    .pix_y    (pix_y),
    .cx       (lt2_x[g_lt2]),
    .cy       (lt2_y[g_lt2]),
    .halfL    ({ {8{1'b0}}, (CAR_L>>1) }),
    .halfW    ({ {8{1'b0}}, (CAR_W>>1) }),
    .cos_q    (COS2_Q),
    .sin_q    (SIN2_Q),
    .hit      (lt2_hit_rot[g_lt2]),
    .valid_out(lt2_hit_valid[g_lt2])
  );
end
endgenerate

// 绱㈠紩浣胯兘锛氬綋 car_sw_2=1 锟?? NUM_LT_R=2锛屽彧鏀捐涓嬫爣 0锟??1
wire [3:0] lt2_idx_en = { (NUM_LT_R>3), (NUM_LT_R>2), (NUM_LT_R>1), (NUM_LT_R>0) };

wire car_hit_lturn_R_arr =
  (lt2_idx_en[0] & lt2_active[0] && ((lt2_state[0]==LT2_STRAIGHT && car_rect_h(lt2_x[0], lt2_y[0])) ||
                                     (lt2_state[0]==LT2_ARC      && lt2_hit_valid[0] && lt2_hit_rot[0]) ||
                                     (lt2_state[0]==LT2_VERT     && car_rect_v(lt2_x[0], lt2_y[0])))) |
  (lt2_idx_en[1] & lt2_active[1] && ((lt2_state[1]==LT2_STRAIGHT && car_rect_h(lt2_x[1], lt2_y[1])) ||
                                     (lt2_state[1]==LT2_ARC      && lt2_hit_valid[1] && lt2_hit_rot[1]) ||
                                     (lt2_state[1]==LT2_VERT     && car_rect_v(lt2_x[1], lt2_y[1])))) |
  (lt2_idx_en[2] & lt2_active[2] && ((lt2_state[2]==LT2_STRAIGHT && car_rect_h(lt2_x[2], lt2_y[2])) ||
                                     (lt2_state[2]==LT2_ARC      && lt2_hit_valid[2] && lt2_hit_rot[2]) ||
                                     (lt2_state[2]==LT2_VERT     && car_rect_v(lt2_x[2], lt2_y[2])))) |
  (lt2_idx_en[3] & lt2_active[3] && ((lt2_state[3]==LT2_STRAIGHT && car_rect_h(lt2_x[3], lt2_y[3])) ||
                                     (lt2_state[3]==LT2_ARC      && lt2_hit_valid[3] && lt2_hit_rot[3]) ||
                                     (lt2_state[3]==LT2_VERT     && car_rect_v(lt2_x[3], lt2_y[3]))));


//======================================================================
// ????????????XL_3 / XL_2 / XL_1???????????????????
// 1) XL_3 ?????NORTH -> EAST??CW 90???? ???? YD2C
// 2) XL_2 ????????NORTH -> SOUTH??
// 3) XL_1 ???????NORTH -> WEST??CCW 90?? ??"?????"??????????????? ???? YU0C
//   - TL: ??????????????? col_TB_L??"???????"??
//   - TS: ??????????????? col_TB_S??"???????+???"??
//======================================================================

// ---------- ??????????????? ----------
localparam integer STOP_T2B_Y = YT - ZB_OFF -XW ;      // ????????????

// ---------- ?????? ----------
wire TL_GREEN = (col_TB_L==C_GRN);
wire TS_GREEN = (col_TB_S==C_GRN);

//======================================================================
// A) XL_2 ?????????? TS ?????????????? + ???? + ??????
//======================================================================
// ===== A) XL_2 ?????????? TS ????? =====
// reg        tsd_active [0:N_TSD-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg signed [15:0] tsd_x [0:N_TSD-1];
reg signed [15:0] tsd_y [0:N_TSD-1];

integer i_tsd, tsd_prev_allow_y, ny_tsd, topy_tsd, t_tsd;

initial begin
  for (i_tsd=0; i_tsd<N_TSD; i_tsd=i_tsd+1) begin
    tsd_active[i_tsd] = 1'b1;
    tsd_x[i_tsd]      = XL_2;
    tsd_y[i_tsd]      = -CAR_L - i_tsd*GAP_SPAWN; // ???????????????
  end
end

always @(posedge vga_clk) begin
  if (move_tick) begin
    // ????????????"?????? GAP"--??? +?? / ?????
    tsd_prev_allow_y = 32'sh7fffffff;
    for (i_tsd=0; i_tsd<N_TSD; i_tsd=i_tsd+1) 
    if (tsd_active[i_tsd]&& (i_tsd < NUM_TSD)) begin
      // ??/?????????? STOP_T2B_Y
      if (!TS_GREEN && (tsd_y[i_tsd] + (CAR_L>>1) >= STOP_T2B_Y))
        ny_tsd = STOP_T2B_Y - (CAR_L>>1);
      else
        ny_tsd = tsd_y[i_tsd] + $signed(CAR_SPD);

      // ?????????????ny ??????????????
      if (ny_tsd > tsd_prev_allow_y) ny_tsd = tsd_prev_allow_y;

      tsd_x[i_tsd] <= XL_2;
      tsd_y[i_tsd] <= ny_tsd;

      // ?????????????? y - GAP_QUEUE
      tsd_prev_allow_y = ny_tsd - GAP_QUEUE;

      // ????????????????????
      if (ny_tsd - (CAR_L>>1) > V_VALID) begin
        topy_tsd = tsd_y[i_tsd];
        for (t_tsd=0; t_tsd<N_TSD; t_tsd=t_tsd+1)
          if (tsd_active[t_tsd] && tsd_y[t_tsd] < topy_tsd && (t_tsd < NUM_TSD)) topy_tsd = tsd_y[t_tsd];
        tsd_x[i_tsd] <= XL_2;
        tsd_y[i_tsd] <= topy_tsd - GAP_SPAWN;
      end
    end
  end
end


// ?????????????????????
wire car_hit_TS_down_arr;
reg [N_TSD-1:0] tsd_hit_array;  // 涓嶅啓锟?? 10
integer tsd_hit_i;
always @(*) begin
  tsd_hit_array = {N_TSD{1'b0}};
  for (tsd_hit_i = 0; tsd_hit_i < N_TSD; tsd_hit_i = tsd_hit_i + 1) begin
    if ((tsd_hit_i < NUM_TSD) && tsd_active[tsd_hit_i] &&
        car_rect_v(tsd_x[tsd_hit_i], tsd_y[tsd_hit_i])) begin
      tsd_hit_array[tsd_hit_i] = 1'b1;
    end
  end
end
assign car_hit_TS_down_arr = |tsd_hit_array;

//======================================================================
// TOP-LEFT TURN @ XL_3  (SOUTH -> EAST, CCW ~90?? in 180??..270?? quadrant)
// ???? XL_3 ???????????? TL_GREEN=col_TB_L ?????????????? YT ????
// ?????????????? 180???270?????????? y??YD2C????????????
// ?????CCW???? x = Cx - R*cos(a_d) ; y = Cy + R*sin(a_d)
// ????o??????????????cos' = +sin(a_d) ; sin' = +cos(a_d)
//======================================================================


localparam [1:0]   TL_STRAIGHT=2'd0, TL_ARC=2'd1, TL_HORZ=2'd2;

// ---- ???????????"?????????"? a=0 ?????????????????????? ----
localparam integer ARC_MGN_TL = 2;                           // ??????????(??0..3)
localparam integer TL_R_BASE  = (YD2C - YT) - ARC_MGN_TL;    // ??????YD2C-YT
localparam integer TL_R       = (TL_R_BASE > 8) ? TL_R_BASE : 8;
localparam integer TL_CX      = XL_3 + TL_R;                 // ??? x
localparam integer TL_CY      = YT;                          // ??? y?????????
localparam integer TL_Y_TURN  = YT;                          // ?????????????
localparam integer TL_Y_END   = YD2C;                        // ??? y ???

// ---------- ??/???? ----------
// reg        tl_active [0:N_TL-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] tl_state  [0:N_TL-1];
reg signed [15:0] tl_x [0:N_TL-1], tl_y [0:N_TL-1];

// ---------- ???????0..ANG_STEPS ?? 0??..90??????? ----------
reg  [7:0] tl_ang_idx   [0:N_TL-1];   // ??????????????????
reg  [7:0] tl_ang_idx_d [0:N_TL-1];   // ???????????/????????
reg [15:0] tl_tick_ps   [0:N_TL-1];
reg [15:0] tl_tick_cnt  [0:N_TL-1];

// ---------- ??????? ----------
integer k_tl_init;
initial begin
  for (k_tl_init=0; k_tl_init<N_TL; k_tl_init=k_tl_init+1) begin
    tl_active[k_tl_init]   = 1'b1;
    tl_state[k_tl_init]    = TL_STRAIGHT;
    tl_x[k_tl_init]        = XL_3;
    tl_y[k_tl_init]        = -CAR_L - k_tl_init*(CAR_L + 60);  // ???????????????
    tl_ang_idx[k_tl_init]  = 0;
    tl_ang_idx_d[k_tl_init]= 0;
    tl_tick_ps[k_tl_init]  = 1;
    tl_tick_cnt[k_tl_init] = 0;
  end
end

// ---------- ??????????? ROM ?????????????? move_tick ??? ----------
always @(posedge vga_clk) begin : TL_SHADOW_ANG
  integer j;
  for (j=0; j<N_TL; j=j+1) tl_ang_idx_d[j] <= tl_ang_idx[j];
end

// ---------- ?????? trig??????=???? ?? ??????????CCW ????????? ----------
// x = Cx - R*cos(a_d) ; y = Cy + R*sin(a_d)
wire signed [15:0] tl_pos_cos_q [0:N_TL-1];
wire signed [15:0] tl_pos_sin_q [0:N_TL-1];
genvar g_tl_pos;
generate
for (g_tl_pos=0; g_tl_pos<N_TL; g_tl_pos=g_tl_pos+1) begin: G_TL_POS_TRIG
  wire signed [15:0] COS_Q_POS, SIN_Q_POS;
  sincos90_q88 #(.ANG_STEPS(ANG_STEPS)) u_sc_pos (
    .clk  (vga_clk),
    .idx  (tl_ang_idx_d[g_tl_pos]),
    .cos_q(COS_Q_POS),
    .sin_q(SIN_Q_POS)
  );
  assign tl_pos_cos_q[g_tl_pos] = COS_Q_POS; // cos(a_d)
  assign tl_pos_sin_q[g_tl_pos] = SIN_Q_POS; // sin(a_d)
end
endgenerate

// ---------- ?????? ----------
integer i_tl, prev_allow_y_tl, ny_tl, steps_on_arc_tl, tmp_ps_tl;

always @(posedge vga_clk) begin
  if (move_tick) begin
    // === ???????? + ???? + ?????????????????????? ===
    prev_allow_y_tl = 32'sh7fffffff; // ??????? ny ????????????????
    for (i_tl=0; i_tl<N_TL; i_tl=i_tl+1) 
    if (tl_active[i_tl]&& (i_tl < NUM_TL)) begin
      if (tl_state[i_tl]==TL_STRAIGHT) begin
        if (!TL_GREEN && (tl_y[i_tl] + (CAR_L>>1) >= STOP_T2B_Y))
          ny_tl = STOP_T2B_Y - (CAR_L>>1);
        else if ( (tl_y[i_tl] + (CAR_L>>1)) < TL_Y_TURN )
          ny_tl = tl_y[i_tl] + $signed(CAR_SPD);              // ???????????
        else begin
          ny_tl             = TL_Y_TURN - (CAR_L>>1);         // ?????????(?????????)
          tl_ang_idx[i_tl]  <= 0;                             // ?? a=0
          tmp_ps_tl         = ((TL_R + (CAR_SPD-1)) / CAR_SPD) / ANG_STEPS;
          if (tmp_ps_tl <= 0) tmp_ps_tl = 1;
          tl_tick_ps[i_tl]  <= tmp_ps_tl;
          tl_tick_cnt[i_tl] <= 0;
          tl_state[i_tl]    <= TL_ARC;
        end
        if (ny_tl > prev_allow_y_tl) ny_tl = prev_allow_y_tl; // ???????
        tl_x[i_tl] <= XL_3;
        tl_y[i_tl] <= ny_tl;
        prev_allow_y_tl = ny_tl - (CAR_L + 20);
      end
    end

    // === ????????????????? + ????????????????????? CCW?? ===
    for (i_tl=0; i_tl<N_TL; i_tl=i_tl+1) 
    if (tl_active[i_tl] && tl_state[i_tl]==TL_ARC && (i_tl < NUM_TL)) begin
      if (tl_ang_idx[i_tl] < ANG_STEPS) begin
        tl_tick_cnt[i_tl] <= tl_tick_cnt[i_tl] + 1'b1;
        if (tl_tick_cnt[i_tl] >= tl_tick_ps[i_tl]) begin
          tl_tick_cnt[i_tl] <= 0;
          tl_ang_idx[i_tl]  <= tl_ang_idx[i_tl] + 1'b1;       // ?????????????
        end
      end
      // ???????????????
      // x = Cx - R*cos(a_d) ; y = Cy + R*sin(a_d)
      for (steps_on_arc_tl=0; steps_on_arc_tl<CAR_SPD; steps_on_arc_tl=steps_on_arc_tl+1) begin
        tl_x[i_tl] <= TL_CX - ( ($signed(TL_R) * $signed(tl_pos_cos_q[i_tl])) >>> 8 );
        tl_y[i_tl] <= TL_CY + ( ($signed(TL_R) * $signed(tl_pos_sin_q[i_tl])) >>> 8 );
      end

      // ??????????? 90????270??????????? ??????y ???? YD2C
      if (tl_ang_idx_d[i_tl] >= ANG_STEPS) begin
        tl_state[i_tl] <= TL_HORZ;
        tl_y[i_tl]     <= TL_Y_END;
      end
    end

    // === ???????????????????? ===
    for (i_tl=0; i_tl<N_TL; i_tl=i_tl+1) 
    if (tl_active[i_tl] && (i_tl < NUM_TL) && tl_state[i_tl]==TL_HORZ) begin
      tl_x[i_tl] <= tl_x[i_tl] + $signed(CAR_SPD);
      tl_y[i_tl] <= TL_Y_END;
      if ( (tl_x[i_tl] - $signed(CAR_L>>1)) > $signed(H_VALID) ) begin
        tl_x[i_tl]     <= XL_3;
        tl_y[i_tl]     <= -CAR_L - (i_tl*(CAR_L + 60));
        tl_state[i_tl] <= TL_STRAIGHT;
        tl_ang_idx[i_tl]  <= 0;
        tl_tick_cnt[i_tl] <= 0;
      end
    end
  end
end

// ---------- ???????????? TL_ARC ??? rot_ip???????????????(????) ----------
// ???????CCW??S->E????cos' = +sin(a_d)??sin' = +cos(a_d)  ?? ??"?????"
wire [N_TL-1:0] tl_hit_rot, tl_hit_valid;
genvar g_tl_hit;
generate
for (g_tl_hit=0; g_tl_hit<N_TL; g_tl_hit=g_tl_hit+1) begin: G_TL_ROT_HIT
  // ?????????????????????tl_pos_cos_q / tl_pos_sin_q
  wire signed [15:0] COS_Q_HIT = tl_pos_cos_q[g_tl_hit]; // cos(a_d)
  wire signed [15:0] SIN_Q_HIT = tl_pos_sin_q[g_tl_hit]; // sin(a_d)

  // S->E??????????????????????????cos' = +sin(a_d), sin' = +cos(a_d)
  wire signed [15:0] COS2_Q =  SIN_Q_HIT;
  wire signed [15:0] SIN2_Q =  COS_Q_HIT;

  car_rect_rot_ip #(.Q(8)) u_rot (
    .clk      (vga_clk),
    .valid_in (1'b1),
    .pix_x    (pix_x),
    .pix_y    (pix_y),
    .cx       (tl_x[g_tl_hit]),
    .cy       (tl_y[g_tl_hit]),
    .halfL    ({ {8{1'b0}}, (CAR_L>>1) }),
    .halfW    ({ {8{1'b0}}, (CAR_W>>1) }),
    .cos_q    (COS2_Q),
    .sin_q    (SIN2_Q),
    .hit      (tl_hit_rot[g_tl_hit]),
    .valid_out(tl_hit_valid[g_tl_hit])
  );
end
endgenerate

// 鏇挎崲浣犵幇鍦ㄧ殑 car_hit_TL_leftturn_arr 鎵嬪啓 0..5 鐗堟湰锟??
reg [N_TL-1:0] tl_hit_array;
integer tl_k;
always @(*) begin
  tl_hit_array = {N_TL{1'b0}};
  for (tl_k = 0; tl_k < N_TL; tl_k = tl_k + 1) begin
    if (tl_k < NUM_TL && tl_active[tl_k]) begin
      tl_hit_array[tl_k] =
          (tl_state[tl_k]==TL_STRAIGHT && car_rect_v(tl_x[tl_k], tl_y[tl_k])) ||
          (tl_state[tl_k]==TL_HORZ     && car_rect_h(tl_x[tl_k], tl_y[tl_k])) ||
          (tl_state[tl_k]==TL_ARC      && tl_hit_valid[tl_k] && tl_hit_rot[tl_k]);
    end
  end
end
wire car_hit_TL_leftturn_arr = |tl_hit_array;

// ========================== TR锛氶《閮ㄢ啋宸︿晶锛圢ORTH -> WEST锛夊彸杞溅锟?? ==========================
// 渚濇嵁浜鸿妯亾锛圸ebra锛夊缂樻潵纭畾鐪熸鐨勫仠姝㈢嚎锛岄伩鍏嶈鍋滃湪 YT 鏈綋绾夸笂

// 鏂戦┈绾匡紙椤惰竟锛夊唴澶栫紭锛堝凡瀛樺湪鍏ㄥ眬鍙傛暟锛歒T / ZB_OFF / XW锟??
localparam integer ZEBRA_TOP_OUT = YT - ZB_OFF - XW; // 杩滅璺彛锟??渚э紙澶栫紭锟??
localparam integer ZEBRA_TOP_IN  = YT - ZB_OFF;      // 闈犺矾鍙ｄ竴渚э紙鍐呯紭锟??

// 鍋滄绾垮井璋冿細鎶婂仠姝㈢嚎鏀惧湪鏂戦┈绾垮缂樺啀鍚戝鍋忕Щ鑻ュ共鍍忕礌锛堣瑙変綑閲忥紝0~4 閮藉彲锟??
localparam integer STOP_TR_PAD   = 2;

// TR 锟??"鐪熸鍋滄锟??"锛氶潬璺彛澶栦晶銆佺暐澶栫Щ
localparam integer STOP_TR_Y     = ZEBRA_TOP_OUT - STOP_TR_PAD;

// 鐩磋娈靛埌杈炬 y 瑙﹀彂杩涘叆姘村钩鍙宠浆锛涘彸杞悗淇濇寔鐨勭洰锟?? y
localparam integer TR_TURN_Y0    = YT + (CAR_L>>1);
localparam integer TR_Y_TGT      = YU0C;

// 杞︽祦瑙勬ā涓庣姸鎬佺紪锟??
localparam [1:0]   TR_STRAIGHT   = 2'd0,   // 鐩磋鍚戜笅锛堣嚜灞忓杩涘叆锟??
                   TR_HORZ       = 2'd1;   // 鍙宠浆鍚戝乏锛堟按骞冲嚭灞忥級

// 杞﹂槦鏁扮粍
// reg        tr_active [0:N_TR_ALWAYS-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] tr_state  [0:N_TR_ALWAYS-1];
reg signed [15:0] tr_x [0:N_TR_ALWAYS-1], tr_y [0:N_TR_ALWAYS-1];

// 杈呭姪鍙橀噺
integer i_tr, prev_allow_y_tr, ny_tr, miny_tr, t_tr;
integer head_y_now, head_y_next;

// 鍒濆鍖栵細杞﹁締锟?? XL_1 绔栫洿杞﹂亾涓婃柟渚濇杩涘叆
initial begin : INIT_TR_CARS
  integer k;
  for (k=0; k<N_TR_ALWAYS; k=k+1) begin
    tr_active[k] = 1'b1;
    tr_state[k]  = TR_STRAIGHT;
    tr_x[k]      = XL_1;
    tr_y[k]      = -CAR_L - k*GAP_SPAWN;
  end
end

// 杩愬姩涓庣伅鎺э細涓庡叾瀹冨彸杞锛堝 rt2锛変竴鑷寸殑"涓嬩竴鎷嶈溅澶磋法绾块锟??"
always @(posedge vga_clk) begin
  if (move_tick) begin
    // ---------------- 绔栫洿鐩磋闃舵锛堝悜涓嬶級 ----------------
    // ---------------- 绔栫洿鐩磋闃舵锛堝悜涓嬶級 ----------------
prev_allow_y_tr = 32'sh7fffffff;  // 鍏佽锟??"锟??锟?? y"鍏堣寰堝ぇ
for (i_tr=0; i_tr<N_TR_ALWAYS; i_tr=i_tr+1) 
if (tr_active[i_tr]&& (i_tr < NUM_TR)) begin
  if (tr_state[i_tr]==TR_STRAIGHT) begin
    head_y_now  = tr_y[i_tr] + (CAR_L>>1);
    head_y_next = tr_y[i_tr] + $signed(CAR_SPD) + (CAR_L>>1);

    // 锟??/榛勶細涓嬩竴鎷嶈溅澶磋法绾垮氨鍒瑰仠锟?? STOP_TR_Y 澶栦晶
    if ((col_TB_R==C_RED || col_TB_R==C_YEL) && head_y_next >= STOP_TR_Y) begin
      ny_tr = STOP_TR_Y - (CAR_L>>1);
    end
    // 鏈埌杞集瑙﹀彂锟?? 锟?? 缁х画鍚戜笅
    else if (tr_y[i_tr] < TR_TURN_Y0) begin
      ny_tr = tr_y[i_tr] + $signed(CAR_SPD);
    end
    // 鍒拌揪杞集瑙﹀彂锟?? 锟?? 鍒囨按骞冲彸锟??
    else begin
      ny_tr          = TR_Y_TGT;
      tr_state[i_tr] <= TR_HORZ;
    end

    // 闃熷垪闃茶拷灏撅細涓嶅緱瓒呰繃"鍏佽鐨勬渶锟?? y"
    if (ny_tr > prev_allow_y_tr)
      ny_tr = prev_allow_y_tr;

    tr_x[i_tr] <= XL_1;
    tr_y[i_tr] <= ny_tr;

    // 缁欎笅锟??杈嗚溅鐨勬渶锟?? y锛氬綋鍓嶈溅锟?? - 闂磋窛锛堝悜涓婄暀绌猴級
    prev_allow_y_tr = ny_tr - GAP_QUEUE;
  end
end


    // ---------------- 姘村钩鍙宠浆闃舵锛堝悜宸︼級 ----------------
    for (i_tr=0; i_tr<N_TR_ALWAYS; i_tr=i_tr+1) 
    if (tr_active[i_tr] && (i_tr < NUM_TR) && tr_state[i_tr]==TR_HORZ) begin
      tr_x[i_tr] <= tr_x[i_tr] - $signed(CAR_SPD);
      tr_y[i_tr] <= TR_Y_TGT;

      // 鍑哄睆宸︿晶鍚庨噸缃埌绔栫洿娈佃捣鐐癸紙涓庡叾瀹冩锟??鑷寸殑鍥炴敹閫昏緫锟??
      if ( (tr_x[i_tr] + $signed(CAR_L>>1)) < 0 ) begin
        // 鍙栧綋鍓嶉槦鍒椾腑锟??灏忕殑 y锛堟渶闈犱笂鐨勮溅锛夛紝鍦ㄥ叾涓婃柟鎸夊浐瀹氶棿闅旂敓锟??
        miny_tr = tr_y[i_tr];
        for (t_tr=0; t_tr<N_TR_ALWAYS; t_tr=t_tr+1)
          if (tr_active[t_tr] && (t_tr < NUM_TR)&& tr_y[t_tr] < miny_tr) miny_tr = tr_y[t_tr];
        tr_x[i_tr]     <= XL_1;
        tr_y[i_tr]     <= -CAR_L - (i_tr*(CAR_L + 60));
        tr_state[i_tr] <= TR_STRAIGHT;
      end
    end
  end
end

// 锛堝彲閫夎皟璇曪細鐢荤嚎渚夸簬鑲夌溂鏍″噯鍋滄锟??/鏂戦┈绾夸綅缃拷?锟戒笂绾垮墠娉ㄩ噴鎺夛級
// if (PY>=ZEBRA_TOP_OUT-1 && PY<=ZEBRA_TOP_OUT+1) pix_cross <= 16'hFFFF; // 鏂戦┈澶栫紭锛堢櫧锟??
// if (PY>=ZEBRA_TOP_IN-1  && PY<=ZEBRA_TOP_IN+1 ) pix_cross <= 16'hFFFF; // 鏂戦┈鍐呯紭锛堢櫧锟??
// if (PY>=STOP_TR_Y-1     && PY<=STOP_TR_Y+1    ) pix_cross <= 16'h07FF; // TR 鍋滄绾匡紙闈掞級

reg [N_TR_ALWAYS-1:0] tr_hit_array;
integer tr_k;
always @(*) begin
  tr_hit_array = {N_TR_ALWAYS{1'b0}};
  for (tr_k=0; tr_k<N_TR_ALWAYS; tr_k=tr_k+1) begin
    if (tr_k < NUM_TR && tr_active[tr_k]) begin
      tr_hit_array[tr_k] =
        (tr_state[tr_k]==TR_STRAIGHT && car_rect_v(tr_x[tr_k], tr_y[tr_k])) ||
        (tr_state[tr_k]==TR_HORZ     && car_rect_h(tr_x[tr_k], tr_y[tr_k]));
    end
  end
end
wire car_hit_TR_always_arr = |tr_hit_array;

                    
                    //======================================================================
// BOTTOM -> TOP three flows (XR_2 / XR_3 / XR_1)
// 1) XR_2 ????????BS=????? STOP_B2T_Y??
// 2) XR_3 ??? ?? ???? YD0C??BS=?????????????
// 3) XR_1 ?????BL=?????? 0..90??SOUTH->WEST?????? YU2C ????????
//======================================================================

localparam integer STOP_B2T_Y = YB + ZB_OFF + XW;  // ????????????????????
wire BS_GREEN = (col_TB_S==C_GRN); // ???????+?????Bottom Straight ??? TB_S??
wire BL_GREEN = (col_TB_L==C_GRN); // ?????????Bottom Left ??? TB_L)

//========================= 1) XR_2 ??????? =========================
// reg        bs_st_active [0:N_BS_ST-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg signed [15:0] bs_st_x [0:N_BS_ST-1];
reg signed [15:0] bs_st_y [0:N_BS_ST-1];

integer i_bs_st, bs_prev_allow_y, bs_ny, bs_maxy, t_bs_st;

initial begin
  for (i_bs_st=0; i_bs_st<N_BS_ST; i_bs_st=i_bs_st+1) begin
    bs_st_active[i_bs_st] = 1'b1;
    bs_st_x[i_bs_st]      = XR_2;
    bs_st_y[i_bs_st]      = V_VALID + CAR_L + i_bs_st*GAP_SPAWN; // ??????????????
  end
end

always @(posedge vga_clk) begin
  if (move_tick) begin
    // ?????y ??????????? y ????????"???????? y"???????????
    bs_prev_allow_y = -32'sh7fffffff; // ???? = -???????????????
    for (i_bs_st=0; i_bs_st<N_BS_ST; i_bs_st=i_bs_st+1) 
    if (bs_st_active[i_bs_st] && (i_bs_st < NUM_BS_ST)) begin
      // ??/????????????? STOP_B2T_Y???????y-(L/2) <= STOP_B2T_Y??
      if (!BS_GREEN && (bs_st_y[i_bs_st] - (CAR_L>>1) <= STOP_B2T_Y))
        bs_ny = STOP_B2T_Y + (CAR_L>>1);
      else
        bs_ny = bs_st_y[i_bs_st] - $signed(CAR_SPD);

      // ?????????????ny ???? < ???????? y??
      if (bs_prev_allow_y != -32'sh7fffffff && bs_ny < bs_prev_allow_y)
        bs_ny = bs_prev_allow_y;

      bs_st_x[i_bs_st] <= XR_2;
      bs_st_y[i_bs_st] <= bs_ny;

      // ??????????????? y = ???? y + GAP_QUEUE
      bs_prev_allow_y = bs_ny + GAP_QUEUE;

      // ????????????????????????"????"?? y??
      if ( (bs_ny + (CAR_L>>1)) < 0 ) begin
        bs_maxy = bs_st_y[i_bs_st];
        for (t_bs_st=0; t_bs_st<N_BS_ST; t_bs_st=t_bs_st+1)
          if (bs_st_active[t_bs_st]&& (t_bs_st < NUM_BS_ST) && bs_st_y[t_bs_st] > bs_maxy) bs_maxy = bs_st_y[t_bs_st];
        bs_st_x[i_bs_st] <= XR_2;
        bs_st_y[i_bs_st] <= bs_maxy + GAP_SPAWN;
      end
    end
  end
end

reg [N_BS_ST-1:0] bs_hit_array;
integer bs_hit_i;
always @(*) begin
  bs_hit_array = {N_BS_ST{1'b0}};
  for (bs_hit_i = 0; bs_hit_i < N_BS_ST; bs_hit_i = bs_hit_i + 1) begin
    if (bs_st_active[bs_hit_i] && (bs_hit_i < NUM_BS_ST) &&
        car_rect_v(bs_st_x[bs_hit_i], bs_st_y[bs_hit_i]))
      bs_hit_array[bs_hit_i] = 1'b1;
  end
end
wire car_hit_BS_up_arr = |bs_hit_array;

//========================= 2) XR_3 ??????????????? =========================
localparam [1:0]   BR_VERT=2'd0, BR_HORZ=2'd1;

// reg        br_active [0:N_BR-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] br_state  [0:N_BR-1];
reg signed [15:0] br_x [0:N_BR-1], br_y [0:N_BR-1];

integer i_br, br_prev_allow_y, br_ny, br_maxy, t_br;

localparam integer BR_TURN_Y0 = YB - (CAR_L>>1); // ????????????
localparam integer BR_Y_TGT   = YD0C;            // ??????????????????

initial begin
  for (i_br=0; i_br<N_BR; i_br=i_br+1) begin
    br_active[i_br] = 1'b1;
    br_state[i_br]  = BR_VERT;
    br_x[i_br]      = XR_3;
    br_y[i_br]      = V_VALID + CAR_L + i_br*GAP_SPAWN; // ???????
  end
end

always @(posedge vga_clk) begin
  if (move_tick) begin
    // br绯婚敓鍙綇鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹閿熸枻鎷烽敓鏂ゆ嫹鐩撮敓杞匡綇锟??
    br_prev_allow_y = -32'sh7fffffff;
    for (i_br=0; i_br<N_BR; i_br=i_br+1) 
    if (br_active[i_br]&& (i_br < NUM_BR)) begin
      if (br_state[i_br]==BR_VERT) begin
        // 閿熸枻鎷疯浆閿熸枻鎷烽敓鏁欑伅鍖℃嫹閿熺嫛锝忔嫹閿熸枻鎷烽敓缁炶摉锝忔嫹閿熼叺锛剁櫢鎷烽敓?
        if (col_TB_R == 2'd0 && (br_y[i_br] - (CAR_L>>1) <= STOP_B2T_Y)) begin
          // 鍋滈敓鏂ゆ嫹鍋滄閿熺锝忔嫹閿熸枻鎷峰ご閿熸枻鎷烽敓鏂ゆ嫹鍋滄閿熺锝忔嫹
          br_ny = STOP_B2T_Y + (CAR_L>>1);  // 鍋滄
        end else if (br_y[i_br] > BR_TURN_Y0) begin
          br_ny = br_y[i_br] - $signed(CAR_SPD);
        end else begin
          br_ny          = BR_Y_TGT;   // 閿熸枻鎷烽敓鏂ゆ嫹杞敓鏂ゆ嫹鎮栴剨鎷烽敓鏂ゆ嫹閿熶茎鍖℃嫹閿熺祼
          br_state[i_br] <= BR_HORZ;
        end
        if (br_prev_allow_y != -32'sh7fffffff && br_ny < br_prev_allow_y)
          br_ny = br_prev_allow_y;

        br_x[i_br] <= XR_3;
        br_y[i_br] <= br_ny;
        br_prev_allow_y = br_ny + GAP_QUEUE;
      end
    end

    // ????????????????
    for (i_br=0; i_br<N_BR; i_br=i_br+1) 
    if (br_active[i_br] && (i_br < NUM_BR)&& br_state[i_br]==BR_HORZ) begin
      br_x[i_br] <= br_x[i_br] + $signed(CAR_SPD);
      br_y[i_br] <= BR_Y_TGT;
      if ( (br_x[i_br] - $signed(CAR_L>>1)) > $signed(H_VALID) ) begin
        // ???????????
        br_maxy = br_y[i_br];
        for (t_br=0; t_br<N_BR; t_br=t_br+1)
          if (br_active[t_br]&& (t_br < NUM_BR) && br_y[t_br] > br_maxy) br_maxy = br_y[t_br];
        br_x[i_br]     <= XR_3;
        br_y[i_br]     <= br_maxy + GAP_SPAWN;
        br_state[i_br] <= BR_VERT;
      end
    end
  end
end

reg [N_BR-1:0] br_hit_array;
integer br_k;
always @(*) begin
  br_hit_array = {N_BR{1'b0}};
  for (br_k=0; br_k<N_BR; br_k=br_k+1) begin
    if (br_k < NUM_BR && br_active[br_k]) begin
      br_hit_array[br_k] =
        (br_state[br_k]==BR_VERT && car_rect_v(br_x[br_k], br_y[br_k])) ||
        (br_state[br_k]==BR_HORZ && car_rect_h(br_x[br_k], br_y[br_k]));
    end
  end
end
wire car_hit_BR_turn_arr = |br_hit_array;


//========================= 3) XR_1 ???????? 0..90?? =========================
localparam [1:0]   BL_VERT=2'd0, BL_ARC=2'd1, BL_HORZ=2'd2;

// ?????????a=0..90??: ????? y=YB????? y=YU2C??SOUTH->WEST??CCW??
// ???????????????????
localparam integer BL_R_BASE = (YB - YU2C);
localparam integer BL_R      = (BL_R_BASE>8) ? BL_R_BASE : 8;
localparam integer BL_CX     = XR_1 - BL_R;       // ???X????????  
localparam integer BL_CY     = YB;                // ???Y = ???????????????
localparam integer BL_Y_TURN = YB;                // ???????????
localparam integer BL_Y_END  = YU2C;              // ??? y

// reg        bl_active [0:N_BL-1];  // 宸插湪缁熻浠ｇ爜涔嬪墠澹版槑
reg  [1:0] bl_state  [0:N_BL-1];
reg signed [15:0] bl_x [0:N_BL-1], bl_y [0:N_BL-1];

// ???????0..ANG_STEPS ??? 0??..90??
reg  [7:0] bl_ang_idx   [0:N_BL-1];
reg  [7:0] bl_ang_idx_d [0:N_BL-1];
reg [15:0] bl_tick_ps   [0:N_BL-1];
reg [15:0] bl_tick_cnt  [0:N_BL-1];

integer k_bl;
initial begin
  for (k_bl=0; k_bl<N_BL; k_bl=k_bl+1) begin
    bl_active[k_bl]   = 1'b1;
    bl_state[k_bl]    = BL_VERT;
    bl_x[k_bl]        = XR_1;
    bl_y[k_bl]        = V_VALID + CAR_L + k_bl*(CAR_L + 60);
    bl_ang_idx[k_bl]  = 0;
    bl_ang_idx_d[k_bl]= 0;
    bl_tick_ps[k_bl]  = 1;
    bl_tick_cnt[k_bl] = 0;
  end
end

// ????????
always @(posedge vga_clk) begin : BL_SHADOW_ANG
  integer j;
  for (j=0; j<N_BL; j=j+1) bl_ang_idx_d[j] <= bl_ang_idx[j];
end

// ?????? trig??????=???? ?? ??????????
wire signed [15:0] bl_pos_cos_q [0:N_BL-1];
wire signed [15:0] bl_pos_sin_q [0:N_BL-1];
genvar g_bl_pos;
generate
for (g_bl_pos=0; g_bl_pos<N_BL; g_bl_pos=g_bl_pos+1) begin: G_BL_POS_TRIG
  wire signed [15:0] COS_Q_POS, SIN_Q_POS;
  sincos90_q88 #(.ANG_STEPS(ANG_STEPS)) u_sc_bl_pos (
    .clk  (vga_clk),
    .idx  (bl_ang_idx_d[g_bl_pos]),
    .cos_q(COS_Q_POS),
    .sin_q(SIN_Q_POS)
  );
  assign bl_pos_cos_q[g_bl_pos] = COS_Q_POS; // cos(a_d)
  assign bl_pos_sin_q[g_bl_pos] = SIN_Q_POS; // sin(a_d)
end
endgenerate

// ??????
integer i_bl, bl_prev_allow_y, bl_ny, steps_on_arc_bl, tmp_ps_bl;

always @(posedge vga_clk) begin
  if (move_tick) begin
    // === ??????????(BL) + ???? + ????????????????????===
    bl_prev_allow_y = -32'sh7fffffff;
    for (i_bl=0; i_bl<N_BL; i_bl=i_bl+1) 
    if (bl_active[i_bl]&& (i_bl < NUM_BL)) begin
      if (bl_state[i_bl]==BL_VERT) begin
        if (!BL_GREEN && (bl_y[i_bl] - (CAR_L>>1) <= STOP_B2T_Y))
          bl_ny = STOP_B2T_Y + (CAR_L>>1);
        else if ( (bl_y[i_bl] - (CAR_L>>1)) > BL_Y_TURN )
          bl_ny = bl_y[i_bl] - $signed(CAR_SPD);  // ????
        else begin
          bl_ny            = BL_Y_TURN + (CAR_L>>1); // ?????????????? YB??
          bl_ang_idx[i_bl] <= 0;                     // ?? a=0
          tmp_ps_bl        = ((BL_R + (CAR_SPD-1)) / CAR_SPD) / ANG_STEPS;
          if (tmp_ps_bl <= 0) tmp_ps_bl = 1;
          bl_tick_ps[i_bl] <= tmp_ps_bl;
          bl_tick_cnt[i_bl]<= 0;
          bl_state[i_bl]   <= BL_ARC;
        end
        if (bl_prev_allow_y != -32'sh7fffffff && bl_ny < bl_prev_allow_y)
          bl_ny = bl_prev_allow_y;

        bl_x[i_bl] <= XR_1;
        bl_y[i_bl] <= bl_ny;
        bl_prev_allow_y = bl_ny + (CAR_L + 20);
      end
    end

    // === ??????????? + ????????0..90??S->W??CCW??===
    for (i_bl=0; i_bl<N_BL; i_bl=i_bl+1) 
    if (bl_active[i_bl] && (i_bl < NUM_BL)&& bl_state[i_bl]==BL_ARC) begin
      if (bl_ang_idx[i_bl] < ANG_STEPS) begin
        bl_tick_cnt[i_bl] <= bl_tick_cnt[i_bl] + 1'b1;
        if (bl_tick_cnt[i_bl] >= bl_tick_ps[i_bl]) begin
          bl_tick_cnt[i_bl] <= 0;
          bl_ang_idx[i_bl]  <= bl_ang_idx[i_bl] + 1'b1;
        end
      end
      // x = Cx + R*cos(a) ; y = Cy - R*sin(a)
      for (steps_on_arc_bl=0; steps_on_arc_bl<CAR_SPD; steps_on_arc_bl=steps_on_arc_bl+1) begin
        bl_x[i_bl] <= BL_CX + ( ($signed(BL_R) * $signed(bl_pos_cos_q[i_bl])) >>> 8 );
        bl_y[i_bl] <= BL_CY - ( ($signed(BL_R) * $signed(bl_pos_sin_q[i_bl])) >>> 8 );
      end

      if (bl_ang_idx_d[i_bl] >= ANG_STEPS) begin
        bl_state[i_bl] <= BL_HORZ;
        bl_x[i_bl]     <= BL_CX;              // ???????x = XR_1 - BL_R
        bl_y[i_bl]     <= BL_Y_END;           // = YU2C
      end
    end

    // === ?????????????????? ===
    for (i_bl=0; i_bl<N_BL; i_bl=i_bl+1) 
    if (bl_active[i_bl] && (i_bl < NUM_BL)&& bl_state[i_bl]==BL_HORZ) begin
      bl_x[i_bl] <= bl_x[i_bl] - $signed(CAR_SPD);
      bl_y[i_bl] <= BL_Y_END;
      if ( (bl_x[i_bl] + $signed(CAR_L>>1)) < 0 ) begin
        // ???????? XR_1 ????
        bl_x[i_bl]     <= XR_1;
        bl_y[i_bl]     <= V_VALID + CAR_L + (i_bl*(CAR_L + 60));
        bl_state[i_bl] <= BL_VERT;
        bl_ang_idx[i_bl]  <= 0;
        bl_tick_cnt[i_bl] <= 0;
      end
    end
  end
end

// ????????????????????
// ????????????????????? bl_pos_cos_q/bl_pos_sin_q??
wire [N_BL-1:0] bl_hit_rot, bl_hit_valid;
genvar g_bl_hit;
generate
for (g_bl_hit=0; g_bl_hit<N_BL; g_bl_hit=g_bl_hit+1) begin: G_BL_ROT_HIT
  // SOUTH->WEST?????0????90????1/4???
  wire signed [15:0] COS_Q_HIT = bl_pos_cos_q[g_bl_hit];
  wire signed [15:0] SIN_Q_HIT = bl_pos_sin_q[g_bl_hit];

  // ????????????????????????(-sin(a), -cos(a))
  // cos(theta) = -sin(a), sin(theta) = -cos(a)
  wire signed [15:0] COS2_Q = -SIN_Q_HIT;
  wire signed [15:0] SIN2_Q = -COS_Q_HIT;

  car_rect_rot_ip #(.Q(8)) u_rot_bl (
    .clk      (vga_clk),
    .valid_in (1'b1),
    .pix_x    (pix_x),
    .pix_y    (pix_y),
    .cx       (bl_x[g_bl_hit]),
    .cy       (bl_y[g_bl_hit]),
    .halfL    ({ {8{1'b0}}, (CAR_L>>1) }),
    .halfW    ({ {8{1'b0}}, (CAR_W>>1) }),
    .cos_q    (COS2_Q),
    .sin_q    (SIN2_Q),
    .hit      (bl_hit_rot[g_bl_hit]),
    .valid_out(bl_hit_valid[g_bl_hit])
  );
end
endgenerate

reg [N_BL-1:0] bl_hit_array;
integer bl_k;
always @(*) begin
  bl_hit_array = {N_BL{1'b0}};
  for (bl_k=0; bl_k<N_BL; bl_k=bl_k+1) begin
    if (bl_k < NUM_BL && bl_active[bl_k]) begin
      bl_hit_array[bl_k] =
        (bl_state[bl_k]==BL_VERT && car_rect_v(bl_x[bl_k], bl_y[bl_k])) ||
        (bl_state[bl_k]==BL_HORZ && car_rect_h(bl_x[bl_k], bl_y[bl_k])) ||
        (bl_state[bl_k]==BL_ARC  && bl_hit_valid[bl_k] && bl_hit_rot[bl_k]);
    end
  end
end
wire car_hit_BL_left_arr = |bl_hit_array;


//======================================================================
// ??????????????????????????????????????????????????
// ?????????"?????/?????????????????????"?????
//======================================================================
// Resource-efficient vehicle renderer. Every active queue member is visible;
// color separates vehicles from the white pedestrian symbols.
function car_dot8;
  input signed [15:0] cx, cy;
  begin
    car_dot8 = (cx[15:10] == 6'd0) && (cy[15:10] == 6'd0) &&
               (pix_x[9:3] == cx[9:3]) && (pix_y[9:3] == cy[9:3]);
  end
endfunction

reg car_hit_orange_simple;
reg car_hit_blue_simple;
reg car_hit_purple_simple;
reg car_hit_grey_simple;
integer render_i;
always @* begin
  car_hit_orange_simple = 1'b0;
  car_hit_blue_simple   = 1'b0;
  car_hit_purple_simple = 1'b0;
  car_hit_grey_simple   = 1'b0;

  for (render_i=0; render_i<N_ST; render_i=render_i+1)
    if ((render_i < 4) && (render_i < NUM_ST) && st_active[render_i] && car_dot8(st_x[render_i], st_y[render_i])) car_hit_orange_simple = 1'b1;
  for (render_i=0; render_i<N_RT; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw_s1) && (render_i < NUM_RT) && rt_active[render_i] && car_dot8(rt_x[render_i], rt_y[render_i])) car_hit_orange_simple = 1'b1;
  for (render_i=0; render_i<N_LT; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw_s1) && (render_i < NUM_LT) && lt_active[render_i] && car_dot8(lt_x[render_i], lt_y[render_i])) car_hit_orange_simple = 1'b1;

  for (render_i=0; render_i<N_ST_R; render_i=render_i+1)
    if ((render_i < 4) && (render_i < NUM_ST_R) && stR_active[render_i] && car_dot8(stR_x[render_i], stR_y[render_i])) car_hit_blue_simple = 1'b1;
  for (render_i=0; render_i<N_RT_R; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw_s1) && (render_i < NUM_RT_R) && rt2_active[render_i] && car_dot8(rt2_x[render_i], rt2_y[render_i])) car_hit_blue_simple = 1'b1;
  for (render_i=0; render_i<N_LT_R; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw_s1) && (render_i < NUM_LT_R) && lt2_active[render_i] && car_dot8(lt2_x[render_i], lt2_y[render_i])) car_hit_blue_simple = 1'b1;

  for (render_i=0; render_i<N_TSD; render_i=render_i+1)
    if ((render_i < 4) && (render_i < NUM_TSD) && tsd_active[render_i] && car_dot8(tsd_x[render_i], tsd_y[render_i])) car_hit_purple_simple = 1'b1;
  for (render_i=0; render_i<N_TL; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw2_s1) && (render_i < NUM_TL) && tl_active[render_i] && car_dot8(tl_x[render_i], tl_y[render_i])) car_hit_purple_simple = 1'b1;
  for (render_i=0; render_i<N_TR_ALWAYS; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw2_s1) && (render_i < NUM_TR) && tr_active[render_i] && car_dot8(tr_x[render_i], tr_y[render_i])) car_hit_purple_simple = 1'b1;

  for (render_i=0; render_i<N_BS_ST; render_i=render_i+1)
    if ((render_i < 4) && (render_i < NUM_BS_ST) && bs_st_active[render_i] && car_dot8(bs_st_x[render_i], bs_st_y[render_i])) car_hit_grey_simple = 1'b1;
  for (render_i=0; render_i<N_BR; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw2_s1) && (render_i < NUM_BR) && br_active[render_i] && car_dot8(br_x[render_i], br_y[render_i])) car_hit_grey_simple = 1'b1;
  for (render_i=0; render_i<N_BL; render_i=render_i+1)
    if ((render_i < 2) && ((render_i < 1) || car_sw2_s1) && (render_i < NUM_BL) && bl_active[render_i] && car_dot8(bl_x[render_i], bl_y[render_i])) car_hit_grey_simple = 1'b1;
end
localparam [15:0] PURPLE = 16'hF81F; // ???
localparam [15:0] GREY  = 16'h07FF;  // cyan keeps vertical cars distinct from white pedestrians
localparam [15:0] ORANGE = 16'hFD80; // 娴呮鑹? (R=31, G=44, B=0)

// ======= 鑱氬悎锛氬悇鏂瑰悜鏂戦┈绾夸笂鏄惁"褰撳墠鏈変汉" =======
reg ped_on_top, ped_on_bottom, ped_on_left, ped_on_right;
integer p_i;

always @* begin
  ped_on_top    = 1'b0;
  ped_on_bottom = 1'b0;
  ped_on_left   = 1'b0;
  ped_on_right  = 1'b0;

  for (p_i=0; p_i<MAX_PED; p_i=p_i+1) begin
    if (p_i < PED_N) begin
      if (hit_top_idx(p_i))    ped_on_top    = 1'b1;
      if (hit_bot_idx(p_i))    ped_on_bottom = 1'b1;
      if (hit_left_idx(p_i))   ped_on_left   = 1'b1;
      if (hit_right_idx(p_i))  ped_on_right  = 1'b1;
    end
  end
end

// "琛屼汉鎬绘暟<5"鐨勬潯浠讹細浣犵幇锟?? PED_N=4 锟?? 10锛堜簩閫変竴锟??
wire ped_small_total = (PED_N < 5);

// Large page title and concise control guide.
wire cross_title_area = (pix_x >= 10'd248) && (pix_x < 10'd392) &&
                        (pix_y >= 10'd8) && (pix_y < 10'd24);
wire cross_info_area = (pix_x >= 10'd16) && (pix_x < 10'd280) &&
                       (((pix_y >= 10'd40) && (pix_y < 10'd48)) ||
                        ((pix_y >= 10'd56) && (pix_y < 10'd64)) ||
                        ((pix_y >= 10'd72) && (pix_y < 10'd80)));
wire [3:0] cross_title_slot = (pix_x - 10'd248) >> 4;
wire [5:0] cross_info_slot = (pix_x - 10'd16) >> 3;
wire [1:0] cross_info_line = (pix_y < 10'd48) ? 2'd0 :
                             (pix_y < 10'd64) ? 2'd1 : 2'd2;
reg [7:0] cross_overlay_ascii;
wire [2:0] cross_overlay_row = cross_title_area ? ((pix_y-10'd8)>>1) :
                               (cross_info_line==0) ? (pix_y-10'd40) :
                               (cross_info_line==1) ? (pix_y-10'd56) : (pix_y-10'd72);
wire [2:0] cross_overlay_col = cross_title_area ? ((pix_x-10'd248)>>1) : (pix_x-10'd16);
wire [7:0] cross_overlay_bits;
always @* begin
  cross_overlay_ascii = 8'h20;
  if (cross_title_area) begin
    case (cross_title_slot)
      0:cross_overlay_ascii="C"; 1:cross_overlay_ascii="R";
      2:cross_overlay_ascii="O"; 3:cross_overlay_ascii="S";
      4:cross_overlay_ascii="S"; 5:cross_overlay_ascii="R";
      6:cross_overlay_ascii="O"; 7:cross_overlay_ascii="A";
      8:cross_overlay_ascii="D"; default:cross_overlay_ascii=8'h20;
    endcase
  end else if (cross_info_area) begin
    case (cross_info_line)
      0: case (cross_info_slot)
        0:cross_overlay_ascii="K";1:cross_overlay_ascii="E";2:cross_overlay_ascii="Y";3:cross_overlay_ascii="1";4:cross_overlay_ascii=":";
        6:cross_overlay_ascii="H";7:cross_overlay_ascii="O";8:cross_overlay_ascii="R";9:cross_overlay_ascii="I";10:cross_overlay_ascii="Z";
        11:cross_overlay_ascii="O";12:cross_overlay_ascii="N";13:cross_overlay_ascii="T";14:cross_overlay_ascii="A";15:cross_overlay_ascii="L";
        17:cross_overlay_ascii="C";18:cross_overlay_ascii="A";19:cross_overlay_ascii="R";20:cross_overlay_ascii="S";21:cross_overlay_ascii=":";
        23:cross_overlay_ascii=car_sw_s1?"H":"L";24:cross_overlay_ascii=car_sw_s1?"I":"O";
        25:cross_overlay_ascii=car_sw_s1?"G":"W";26:cross_overlay_ascii=car_sw_s1?"H":" ";default:cross_overlay_ascii=8'h20; endcase
      1: case (cross_info_slot)
        0:cross_overlay_ascii="K";1:cross_overlay_ascii="E";2:cross_overlay_ascii="Y";3:cross_overlay_ascii="2";4:cross_overlay_ascii=":";
        6:cross_overlay_ascii="V";7:cross_overlay_ascii="E";8:cross_overlay_ascii="R";9:cross_overlay_ascii="T";10:cross_overlay_ascii="I";
        11:cross_overlay_ascii="C";12:cross_overlay_ascii="A";13:cross_overlay_ascii="L";
        15:cross_overlay_ascii="C";16:cross_overlay_ascii="A";17:cross_overlay_ascii="R";18:cross_overlay_ascii="S";19:cross_overlay_ascii=":";
        21:cross_overlay_ascii=car_sw2_s1?"H":"L";22:cross_overlay_ascii=car_sw2_s1?"I":"O";
        23:cross_overlay_ascii=car_sw2_s1?"G":"W";24:cross_overlay_ascii=car_sw2_s1?"H":" ";default:cross_overlay_ascii=8'h20; endcase
      default: case (cross_info_slot)
        0:cross_overlay_ascii="S";1:cross_overlay_ascii="W";2:cross_overlay_ascii="I";3:cross_overlay_ascii="T";
        4:cross_overlay_ascii="C";5:cross_overlay_ascii="H";6:cross_overlay_ascii=":";
        8:cross_overlay_ascii="P";9:cross_overlay_ascii="E";10:cross_overlay_ascii="D";11:cross_overlay_ascii="E";
        12:cross_overlay_ascii="S";13:cross_overlay_ascii="T";14:cross_overlay_ascii="R";15:cross_overlay_ascii="I";
        16:cross_overlay_ascii="A";17:cross_overlay_ascii="N";18:cross_overlay_ascii="S";19:cross_overlay_ascii=":";
        21:cross_overlay_ascii=ped_sw_s1?"4":"1";22:cross_overlay_ascii=ped_sw_s1?" ":"0";
        default:cross_overlay_ascii=8'h20; endcase
    endcase
  end
end
font u_cross_overlay_font(.ascii(cross_overlay_ascii), .row(cross_overlay_row),
                          .bits(cross_overlay_bits));
wire cross_overlay_on = (cross_title_area || cross_info_area) &&
                        cross_overlay_bits[7-cross_overlay_col];

// Internal crossroad green times, shown as six full labels at lower left.
wire uart_cfg_text_area = (pix_x >= 10'd8) && (pix_x < 10'd192) &&
                          (pix_y >= 10'd372) && (pix_y < 10'd456);
wire [2:0] uart_cfg_line = (pix_y<386)?0:(pix_y<400)?1:(pix_y<414)?2:
                           (pix_y<428)?3:(pix_y<442)?4:5;
wire [4:0] uart_cfg_slot = (pix_x - 10'd8) >> 3;
wire [3:0] uart_cfg_row4 = pix_y - (10'd372 + uart_cfg_line*14);
wire [2:0] uart_cfg_row = uart_cfg_row4[2:0];
wire [2:0] uart_cfg_col = pix_x - 10'd8;
reg [7:0] uart_cfg_ascii;
reg [7:0] uart_cfg_value;
wire [7:0] uart_cfg_bits;
always @* begin
  case (uart_cfg_line)
    0: uart_cfg_value=shown_LRS;
    1: uart_cfg_value=shown_LRL;
    2: uart_cfg_value=shown_LRR;
    3: uart_cfg_value=shown_TBS;
    4: uart_cfg_value=shown_TBL;
    default: uart_cfg_value=shown_TBR;
  endcase
  uart_cfg_ascii=" ";
  if (uart_cfg_line < 3) begin
    case (uart_cfg_slot)
      0:uart_cfg_ascii="H"; 1:uart_cfg_ascii="O"; 2:uart_cfg_ascii="R";
      3:uart_cfg_ascii="I"; 4:uart_cfg_ascii="Z"; 5:uart_cfg_ascii="O";
      6:uart_cfg_ascii="N"; 7:uart_cfg_ascii="T"; 8:uart_cfg_ascii="A";
      9:uart_cfg_ascii="L"; default:uart_cfg_ascii=" ";
    endcase
    if (uart_cfg_line==0) begin
      case (uart_cfg_slot)
        11:uart_cfg_ascii="S";12:uart_cfg_ascii="T";13:uart_cfg_ascii="R";
        14:uart_cfg_ascii="A";15:uart_cfg_ascii="I";16:uart_cfg_ascii="G";
        17:uart_cfg_ascii="H";18:uart_cfg_ascii="T";19:uart_cfg_ascii="=";
        20:uart_cfg_ascii="0"+(uart_cfg_value/10);21:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end else if (uart_cfg_line==1) begin
      case (uart_cfg_slot)
        11:uart_cfg_ascii="L";12:uart_cfg_ascii="E";13:uart_cfg_ascii="F";
        14:uart_cfg_ascii="T";15:uart_cfg_ascii="=";
        16:uart_cfg_ascii="0"+(uart_cfg_value/10);17:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end else begin
      case (uart_cfg_slot)
        11:uart_cfg_ascii="R";12:uart_cfg_ascii="I";13:uart_cfg_ascii="G";
        14:uart_cfg_ascii="H";15:uart_cfg_ascii="T";16:uart_cfg_ascii="=";
        17:uart_cfg_ascii="0"+(uart_cfg_value/10);18:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end
  end else begin
    case (uart_cfg_slot)
      0:uart_cfg_ascii="V";1:uart_cfg_ascii="E";2:uart_cfg_ascii="R";
      3:uart_cfg_ascii="T";4:uart_cfg_ascii="I";5:uart_cfg_ascii="C";
      6:uart_cfg_ascii="A";7:uart_cfg_ascii="L";default:uart_cfg_ascii=" ";
    endcase
    if (uart_cfg_line==3) begin
      case (uart_cfg_slot)
        9:uart_cfg_ascii="S";10:uart_cfg_ascii="T";11:uart_cfg_ascii="R";
        12:uart_cfg_ascii="A";13:uart_cfg_ascii="I";14:uart_cfg_ascii="G";
        15:uart_cfg_ascii="H";16:uart_cfg_ascii="T";17:uart_cfg_ascii="=";
        18:uart_cfg_ascii="0"+(uart_cfg_value/10);19:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end else if (uart_cfg_line==4) begin
      case (uart_cfg_slot)
        9:uart_cfg_ascii="L";10:uart_cfg_ascii="E";11:uart_cfg_ascii="F";
        12:uart_cfg_ascii="T";13:uart_cfg_ascii="=";
        14:uart_cfg_ascii="0"+(uart_cfg_value/10);15:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end else begin
      case (uart_cfg_slot)
        9:uart_cfg_ascii="R";10:uart_cfg_ascii="I";11:uart_cfg_ascii="G";
        12:uart_cfg_ascii="H";13:uart_cfg_ascii="T";14:uart_cfg_ascii="=";
        15:uart_cfg_ascii="0"+(uart_cfg_value/10);16:uart_cfg_ascii="0"+(uart_cfg_value%10);
        default:;
      endcase
    end
  end
end
font u_uart_cfg_font(.ascii(uart_cfg_ascii),.row(uart_cfg_row),.bits(uart_cfg_bits));
wire uart_cfg_text_on=uart_cfg_text_area&&(uart_cfg_row<8)&&uart_cfg_bits[7-uart_cfg_col];

// Two-aspect pedestrian signals placed next to the zebra crossings.
wire ped_lr_walk = (col_LR_S == C_GRN);
wire ped_tb_walk = (col_TB_S == C_GRN);
wire ped_zt_box = is_rect(390,410,48,100);
wire ped_zb_box = is_rect(390,410,380,432);
wire ped_zl_box = is_rect(128,180,150,170);
wire ped_zr_box = is_rect(460,512,150,170);
wire ped_signal_box = ped_zt_box || ped_zb_box || ped_zl_box || ped_zr_box;
wire ped_green_lamp = is_rect(395,405,54,64) || is_rect(395,405,386,396) ||
                      is_rect(134,144,155,165) || is_rect(466,476,155,165);
wire ped_red_lamp = is_rect(395,405,82,92) || is_rect(395,405,414,424) ||
                    is_rect(162,172,155,165) || is_rect(494,504,155,165);
wire ped_green_active = ((ped_zt_box || ped_zb_box) && ped_lr_walk) ||
                        ((ped_zl_box || ped_zr_box) && ped_tb_walk);

    // ?????????????????????
    always @(posedge vga_clk or negedge sys_rst_n) begin
      if(!sys_rst_n) begin
        pix_cross <= 16'h0000;
      end else begin
        // ???????????? ROM ???????????????????????????????
        pix_cross <= (USE_BG) ? BG_RGB :
                     ((in_h_road || in_v_road) ? ROAD : BLACK);
    // =====================================================
    // 2) ????????????/????/???/???/???????
    //    ?? USE_BG=1????ROM????????????????????????????
    // =====================================================
    if (!USE_BG) begin
    
      // -- ???????????????????????????--
      if (h_dash_on_core) pix_cross <= YEL;
      if (v_dash_on_core) pix_cross <= YEL;

      // -- ??????????????????????????????--
      if (lane_h_u1 | lane_h_u2 | lane_h_d1 | lane_h_d2
       |  lane_v_lsep1 | lane_v_lsep2 | lane_v_rsep1 | lane_v_rsep2)
        pix_cross <= WHITE;

      // -- ???????? -- 
      if (edge_top_L | edge_top_R | edge_bot_L | edge_bot_R
       |  edge_left_T | edge_left_B | edge_right_T | edge_right_B)
        pix_cross <= WHITE;

      // -- ??????? -- 

      // -- ???????????????????????/???????--
      if (zb_top | zb_bot | zb_left | zb_right)
        pix_cross <= WHITE;
    end

    // 杞﹁締缁樺埗锛堟棤璁烘槸鍚SE_BG閮界粯鍒讹級
    if (car_hit_purple_simple)
      pix_cross <= PURPLE;
    
    // ==== R鈫扡鏂瑰悜杞﹁締 ====
    if (car_hit_blue_simple)
      pix_cross <= BLUE;
      
    // ==== XR鏂瑰悜杞﹁締 ====
    if (car_hit_grey_simple)
      pix_cross <= GREY;
    
    // ==== 涓昏杞﹁締锛堢洿琛?/杞悜锛?====
    if (car_hit_orange_simple)
      pix_cross <= ORANGE;   // 姗欒壊杞﹁締

    // ==== 淇″彿鐏竟妗? ====
    
    // ==== 淇″彿鐏樉绀? ====
    // L鏂瑰悜淇″彿鐏?
    if (L_S_rect && col_LR_S==C_GRN) pix_cross <= COL_GRN;
    if (L_S_rect && col_LR_S==C_YEL) pix_cross <= COL_YEL;
    if (L_S_rect && col_LR_S==C_RED) pix_cross <= COL_RED;
    
    if (L_L_rect && col_LR_L==C_GRN) pix_cross <= COL_GRN;
    if (L_L_rect && col_LR_L==C_YEL) pix_cross <= COL_YEL;
    if (L_L_rect && col_LR_L==C_RED) pix_cross <= COL_RED;
    
    if (L_R_rect && col_LR_R==C_GRN) pix_cross <= COL_GRN;
    if (L_R_rect && col_LR_R==C_YEL) pix_cross <= COL_YEL;
    if (L_R_rect && col_LR_R==C_RED) pix_cross <= COL_RED;
    
    // R鏂瑰悜淇″彿鐏?
    if (R_R_rect && col_LR_R==C_GRN) pix_cross <= COL_GRN;
    if (R_R_rect && col_LR_R==C_YEL) pix_cross <= COL_YEL;
    if (R_R_rect && col_LR_R==C_RED) pix_cross <= COL_RED;
    
    if (R_L_rect && col_LR_S==C_GRN) pix_cross <= COL_GRN;
    if (R_L_rect && col_LR_S==C_YEL) pix_cross <= COL_YEL;
    if (R_L_rect && col_LR_S==C_RED) pix_cross <= COL_RED;
    
    if (R_S_rect && col_LR_L==C_GRN) pix_cross <= COL_GRN;
    if (R_S_rect && col_LR_L==C_YEL) pix_cross <= COL_YEL;
    if (R_S_rect && col_LR_L==C_RED) pix_cross <= COL_RED;
    
    // T鏂瑰悜淇″彿鐏?
    if (T_R_rect && col_TB_R==C_GRN) pix_cross <= COL_GRN;
    if (T_R_rect && col_TB_R==C_YEL) pix_cross <= COL_YEL;
    if (T_R_rect && col_TB_R==C_RED) pix_cross <= COL_RED;
    
    if (T_L_rect && col_TB_S==C_GRN) pix_cross <= COL_GRN;
    if (T_L_rect && col_TB_S==C_YEL) pix_cross <= COL_YEL;
    if (T_L_rect && col_TB_S==C_RED) pix_cross <= COL_RED;
    
    if (T_S_rect && col_TB_L==C_GRN) pix_cross <= COL_GRN;
    if (T_S_rect && col_TB_L==C_YEL) pix_cross <= COL_YEL;
    if (T_S_rect && col_TB_L==C_RED) pix_cross <= COL_RED;
    
    // B鏂瑰悜淇″彿鐏?
    if (B_S_rect && col_TB_L==C_GRN) pix_cross <= COL_GRN;
    if (B_S_rect && col_TB_L==C_YEL) pix_cross <= COL_YEL;
    if (B_S_rect && col_TB_L==C_RED) pix_cross <= COL_RED;
    
    if (B_L_rect && col_TB_S==C_GRN) pix_cross <= COL_GRN;
    if (B_L_rect && col_TB_S==C_YEL) pix_cross <= COL_YEL;
    if (B_L_rect && col_TB_S==C_RED) pix_cross <= COL_RED;
    
    if (B_R_rect && col_TB_R==C_GRN) pix_cross <= COL_GRN;
    if (B_R_rect && col_TB_R==C_YEL) pix_cross <= COL_YEL;
    if (B_R_rect && col_TB_R==C_RED) pix_cross <= COL_RED;
    
    // ==== 璺彛澶у瀷淇″彿鐏? ====
    // ZT
    if (col_LR_S==C_GRN && 1'b0 && is_rect(ZT_G_x0, ZT_G_x1, ZT_G_y0, ZT_G_y1)) pix_cross <= COL_GRN;
    if (col_LR_S==C_YEL && 1'b0 && is_rect(ZT_Y_x0, ZT_Y_x1, ZT_Y_y0, ZT_Y_y1)) pix_cross <= COL_YEL;
    if (col_LR_S==C_RED && 1'b0 && is_rect(ZT_R_x0, ZT_R_x1, ZT_R_y0, ZT_R_y1)) pix_cross <= COL_RED;
    
    // ZB
    if (col_LR_S==C_GRN && 1'b0 && is_rect(ZB_G_x0, ZB_G_x1, ZB_G_y0, ZB_G_y1)) pix_cross <= COL_GRN;
    if (col_LR_S==C_YEL && 1'b0 && is_rect(ZB_Y_x0, ZB_Y_x1, ZB_Y_y0, ZB_Y_y1)) pix_cross <= COL_YEL;
    if (col_LR_S==C_RED && 1'b0 && is_rect(ZB_R_x0, ZB_R_x1, ZB_R_y0, ZB_R_y1)) pix_cross <= COL_RED;
    
    // ZL
    if (col_TB_S==C_GRN && 1'b0 && is_rect(ZL_G_x0, ZL_G_x1, ZL_G_y0, ZL_G_y1)) pix_cross <= COL_GRN;
    if (col_TB_S==C_YEL && 1'b0 && is_rect(ZL_Y_x0, ZL_Y_x1, ZL_Y_y0, ZL_Y_y1)) pix_cross <= COL_YEL;
    if (col_TB_S==C_RED && 1'b0 && is_rect(ZL_R_x0, ZL_R_x1, ZL_R_y0, ZL_R_y1)) pix_cross <= COL_RED;
    
    // ZR
    if (col_TB_S==C_GRN && 1'b0 && is_rect(ZR_G_x0, ZR_G_x1, ZR_G_y0, ZR_G_y1)) pix_cross <= COL_GRN;
    if (col_TB_S==C_YEL && 1'b0 && is_rect(ZR_Y_x0, ZR_Y_x1, ZR_Y_y0, ZR_Y_y1)) pix_cross <= COL_YEL;
    if (col_TB_S==C_RED && 1'b0 && is_rect(ZR_R_x0, ZR_R_x1, ZR_R_y0, ZR_R_y1)) pix_cross <= COL_RED;
    
    // ==== 淇″彿鐏洅杈规 ====
    
    
    
    
    // ==== 鏂囧瓧淇℃伅鏄剧ず ====
    if (ped_signal_box) pix_cross <= 16'h2104;
    if (ped_green_lamp) pix_cross <= ped_green_active ? COL_GRN : 16'h0000;
    if (ped_red_lamp) pix_cross <= ped_green_active ? 16'h0000 : COL_RED;

    if (mode_label_on) pix_cross <= WHITE;
    if (people_label_on) pix_cross <= WHITE;
    if (people_num_on) pix_cross <= WHITE;
    if (lrcar_label_on) pix_cross <= WHITE;
    if (lrcar_num_on) pix_cross <= WHITE;
    if (tbcar_label_on) pix_cross <= WHITE;
    if (tbcar_num_on) pix_cross <= WHITE;
    if (speed_label_on) pix_cross <= WHITE;
    if (speed_num_on) pix_cross <= WHITE;
    
    // ==== 缁跨伅鏃堕暱鏄剧ず ====
    if (tb_green_label_on) pix_cross <= WHITE;
    if (tb_s_label_on) pix_cross <= WHITE;
    if (tb_s_num_on) pix_cross <= WHITE;
    if (tb_l_label_on) pix_cross <= WHITE;
    if (tb_l_num_on) pix_cross <= WHITE;
    if (tb_r_label_on) pix_cross <= WHITE;
    if (tb_r_num_on) pix_cross <= WHITE;
    if (lr_green_label_on) pix_cross <= WHITE;
    if (lr_s_label_on) pix_cross <= WHITE;
    if (lr_s_num_on) pix_cross <= WHITE;
    if (lr_l_label_on) pix_cross <= WHITE;
    if (lr_l_num_on) pix_cross <= WHITE;
    if (lr_r_label_on) pix_cross <= WHITE;
    if (lr_r_num_on) pix_cross <= WHITE;
    if (cross_overlay_on) pix_cross <= cross_title_area ? GRN : WHITE;
    
    // ==== 鍊掕鏃跺凡鍒犻櫎 ====
    
    // ==== 琛屼汉鏄剧ず ====
    if (ped_hit) pix_cross <= 16'hFFFF;
    if (uart_cfg_text_on) pix_cross <= 16'h07FF;
        end
    end
endmodule                                     
