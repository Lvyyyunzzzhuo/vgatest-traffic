// word_renderer.v - �? VGA 坐标系显示标签和数字（people / carM / carS / people: 总人数）
`ifdef LEGACY_WORD_RENDERER_UNUSED
module word_renderer_legacy #(
    parameter CHAR_W  = 8,
    parameter CHAR_H  = 8,
    parameter SPACE_W = 1  // 字符间距（像素）
)(
    input            pix_clk,   // 未使用，为兼容接�?
    input      [9:0] x,         // 当前像素 x
    input      [9:0] y,         // 当前像素 y
    output           people_on,
    output           carM_on,
    output           carS_on,
    // 人数输入�?0-31�?
    input      [4:0] ped_num_lr, // LR方向人数
    input      [4:0] ped_num_tb, // TB方向人数
    // 车辆数量输入�?0-31�?
    input      [4:0] car_num_lr, // LR方向车辆�?
    input      [4:0] car_num_tb, // TB方向车辆�?
    // 新增输出：people: 总人�?
    output           people_label_on,  // "people:" 标签
    output           people_num_on,    // 总人数数字（LR + TB�?
    // 新增输出：LRCar: �? TBCar: 车辆�?
    output           lrcar_label_on,   // "LRCar:" 标签
    output           lrcar_num_on,     // LR车辆�?
    output           tbcar_label_on,   // "TBCar:" 标签
    output           tbcar_num_on,     // TB车辆�?
    // 绿灯时长输入（秒�?
    input      [7:0] green_sec_LR_S,   // LR直行绿灯时长
    input      [7:0] green_sec_LR_L,   // LR左转绿灯时长
    input      [7:0] green_sec_LR_R,   // LR右转绿灯时长（固定模式）
    input      [7:0] green_sec_TB_S,   // TB直行绿灯时长
    input      [7:0] green_sec_TB_L,   // TB左转绿灯时长
    input      [7:0] green_sec_TB_R,   // TB右转绿灯时长（固定模式）
    input            mode_adapt_sw,    // 1=自�?�应模式�?0=固定模式
    // 绿灯时长显示输出
    output           tb_green_label_on,   // "TB:" 标签
    output           tb_s_label_on,       // "S:" 标签
    output           tb_s_num_on,        // TB直行绿灯时长数字
    output           tb_l_label_on,       // "L:" 标签
    output           tb_l_num_on,        // TB左转绿灯时长数字
    output           tb_r_label_on,       // "R:" 标签
    output           tb_r_num_on,         // TB右转绿灯时长数字（固定模式）
    output           lr_green_label_on,   // "LR:" 标签
    output           lr_s_label_on,       // "S:" 标签
    output           lr_s_num_on,        // LR直行绿灯时长数字
    output           lr_l_label_on,       // "L:" 标签
    output           lr_l_num_on,         // LR左转绿灯时长数字
    output           lr_r_label_on,       // "R:" 标签
    output           lr_r_num_on,         // LR右转绿灯时长数字（固定模式）
    // 建议限速显示
    input      [7:0] speed_sugg,          // 建议速度（km/h），仅显示两位数
    output           speed_label_on,      // "SPEED:" 标签
    output           speed_num_on,        // 建议速度数字
    // 倒计时输入
    input      [7:0] countdown_LR_S,      // LR直行倒计时
    input      [7:0] countdown_LR_L,      // LR左转倒计时
    input      [7:0] countdown_LR_R,      // LR右转倒计时
    input      [7:0] countdown_TB_S,      // TB直行倒计时
    input      [7:0] countdown_TB_L,      // TB左转倒计时
    input      [7:0] countdown_TB_R,      // TB右转倒计时
    // 倒计时显示输出
    output           cd_tb_s_num_on,      // TB直行倒计时数字
    output           cd_tb_l_num_on,      // TB左转倒计时数字
    output           cd_tb_r_num_on,      // TB右转倒计时数字
    output           cd_lr_s_num_on,      // LR直行倒计时数字
    output           cd_lr_l_num_on,      // LR左转倒计时数字
    output           cd_lr_r_num_on       // LR右转倒计时数字
);
    // 位置
    localparam PEO_X  = 16,  PEO_Y  = 16;  // people 标签
    localparam CARM_X = 16,  CARM_Y = 40;  // carM
    localparam CARS_X = 16,  CARS_Y = 64;  // carS

    // ---------------- 字符位图查询�?8x8字体�? ----------------
    function [7:0] get_bits;
        input [7:0] ch;
        input [2:0] row;
        reg [7:0] outb;
        begin
            case (ch)
                8'h61: case(row)  // a
                    0: outb=8'b00000000; 1: outb=8'b00011100; 2: outb=8'b00000010; 3: outb=8'b00111110;
                    4: outb=8'b01000010; 5: outb=8'b00111110; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h63: case(row)  // c
                    0: outb=8'b00000000; 1: outb=8'b00111100; 2: outb=8'b01000010; 3: outb=8'b01000000;
                    4: outb=8'b01000000; 5: outb=8'b00111100; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h65: case(row)  // e
                    0: outb=8'b00000000; 1: outb=8'b00111100; 2: outb=8'b01000010; 3: outb=8'b01111110;
                    4: outb=8'b01000000; 5: outb=8'b00111100; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h6C: case(row)  // l
                    0: outb=8'b00000000; 1: outb=8'b00011000; 2: outb=8'b00011000; 3: outb=8'b00011000;
                    4: outb=8'b00011000; 5: outb=8'b00011000; 6: outb=8'b00011000; 7: outb=8'b00000000;
                endcase
                8'h6F: case(row)  // o
                    0: outb=8'b00000000; 1: outb=8'b00111100; 2: outb=8'b01000010; 3: outb=8'b01000010;
                    4: outb=8'b01000010; 5: outb=8'b00111100; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h70: case(row)  // p
                    0: outb=8'b00000000; 1: outb=8'b01111100; 2: outb=8'b01000010; 3: outb=8'b01111100;
                    4: outb=8'b01000000; 5: outb=8'b01000000; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h72: case(row)  // r
                    0: outb=8'b00000000; 1: outb=8'b00111000; 2: outb=8'b00000100; 3: outb=8'b00000100;
                    4: outb=8'b00000100; 5: outb=8'b00000100; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h4D: case(row)  // M
                    0: outb=8'b00000000; 1: outb=8'b01000010; 2: outb=8'b01100110; 3: outb=8'b01011010;
                    4: outb=8'b01000010; 5: outb=8'b01000010; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                8'h53: case(row)  // S
                    0: outb=8'b00000000; 1: outb=8'b00111110; 2: outb=8'b01000000; 3: outb=8'b00111100;
                    4: outb=8'b00000010; 5: outb=8'b01111100; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
                default: case(row) // Space
                    0: outb=8'b00000000; 1: outb=8'b00000000; 2: outb=8'b00000000; 3: outb=8'b00000000;
                    4: outb=8'b00000000; 5: outb=8'b00000000; 6: outb=8'b00000000; 7: outb=8'b00000000;
                endcase
            endcase
            get_bits = outb;
        end
    endfunction

    // -------- 文字范围判断 --------
    function in_word;
        input [9:0] x0, y0;     // 左上角坐�?
        input [9:0] wlen;       // 字符长度
        input [9:0] px, py;     // 当前像素
        begin
            in_word = (px >= x0) && (py >= y0) &&
                      (px <  x0 + wlen*(CHAR_W+SPACE_W)) &&
                      (py <  y0 + CHAR_H);
        end
    endfunction

    // -------- 从字符串获取"当前像素是否点亮" --------
    function pixel_from_word;
        input [9:0] x0, y0;
        input [9:0] wlen;
        input [9:0] px, py;
        input [7:0] ch0, ch1, ch2, ch3, ch4, ch5;  // �?�? 6 个字�?
        reg   [9:0] dx, dy;
        reg   [9:0] col_in_word;
        reg   [2:0] row_in_char;
        reg   [2:0] col_in_char;
        reg   [9:0] idx;         // 第几个字�?
        reg   [9:0] off;         // 当前字符内的偏移（字符间距不算）
        reg   [7:0] bits;
        reg   [7:0] ch;
        begin
            dx = px - x0;
            dy = py - y0;

            col_in_word = dx;
            row_in_char = dy[2:0];              // 等同�? (py - y0)[2:0]，字符行索引

            idx = col_in_word / (CHAR_W + SPACE_W);
            off = col_in_word % (CHAR_W + SPACE_W);

            // 根据索引直接选字�?
            case (idx)
                0: ch = ch0;
                1: ch = ch1;
                2: ch = ch2;
                3: ch = ch3;
                4: ch = ch4;
                5: ch = ch5;
                default: ch = 8'h20;
            endcase

            // 超出字符间距（SPACE_W）时不点�?
            if (off >= CHAR_W) begin
                pixel_from_word = 1'b0;
            end else begin
                col_in_char = CHAR_W - 1 - off; // 列反�?
                bits = get_bits(ch, row_in_char);
                pixel_from_word = bits[col_in_char];
            end
        end
    endfunction

    // -------- 各个单词的字符数组（使用 SV 数组�? --------
    localparam integer PEO_LEN = 6;
    localparam [7:0] PEO0="p", PEO1="e", PEO2="o", PEO3="p", PEO4="l", PEO5="e";

    localparam integer CARM_LEN = 4;
    localparam [7:0] CARM0="c", CARM1="a", CARM2="r", CARM3="M";

    localparam integer CARS_LEN = 4;
    localparam [7:0] CARS0="c", CARS1="a", CARS2="r", CARS3="S";

    // -------- 输出逻辑 --------
    wire in_people = in_word(PEO_X,  PEO_Y,  PEO_LEN,  x, y);
    wire in_carM   = in_word(CARM_X, CARM_Y, CARM_LEN, x, y);
    wire in_carS   = in_word(CARS_X, CARS_Y, CARS_LEN, x, y);

    assign people_on = in_people ?
        pixel_from_word(PEO_X,  PEO_Y,  PEO_LEN,  x, y,
                        PEO0, PEO1, PEO2, PEO3, PEO4, PEO5) : 1'b0;

    assign carM_on = in_carM ?
        pixel_from_word(CARM_X, CARM_Y, CARM_LEN, x, y,
                        CARM0, CARM1, CARM2, CARM3, 8'h20, 8'h20) : 1'b0;

    assign carS_on = in_carS ?
        pixel_from_word(CARS_X, CARS_Y, CARS_LEN, x, y,
                        CARS0, CARS1, CARS2, CARS3, 8'h20, 8'h20) : 1'b0;

    // ===================== people: 总人数显示（使用 font 模块�? =====================
    // 显示位置（左上角�?
    localparam LABEL_X = 8;
    localparam LABEL_Y = 16;
    localparam LABEL_LEN = 7;  // "people:" �?7个字�?
    localparam NUM_X = LABEL_X + LABEL_LEN*(CHAR_W+SPACE_W);  // "people:" 后面显示数字

    // 计算总人数：LR + TB（扩展到6位以支持更大的数，最�?62�?
    wire [5:0] ped_total = ped_num_lr + ped_num_tb;

    // "people:" 标签显示
    wire [8*7-1:0] str_people_pack = "people:";
    wire in_label_box = (x >= LABEL_X) && (y >= LABEL_Y) &&
                        (x < LABEL_X + LABEL_LEN*(CHAR_W+SPACE_W)) && (y < LABEL_Y + CHAR_H);
    wire [9:0] label_col = x - LABEL_X;
    wire [9:0] label_dy = y - LABEL_Y;
    wire [2:0] label_row = label_dy[2:0];
    wire [2:0] label_ch_idx = label_col / (CHAR_W + SPACE_W);
    wire [3:0] label_col_mod = label_col % (CHAR_W + SPACE_W);
    wire label_in_space = (label_col_mod >= CHAR_W);
    wire [2:0] label_col_in_char = CHAR_W - 1 - label_col_mod[2:0];
    
    wire [7:0] label_ch_ascii;
    assign label_ch_ascii = str_people_pack[8*(6-label_ch_idx) +: 8];
    
    wire [7:0] label_row_bits;
    font u_font_label(.ascii(label_ch_ascii), .row(label_row), .bits(label_row_bits));
    assign people_label_on = in_label_box && !label_in_space ? label_row_bits[label_col_in_char] : 1'b0;

    // 总人数数字（支持两位数，�?�?99�?
    // 注意：Verilog中整数除法需要确保类型正�?
    wire [3:0] total_tens = ped_total[5:0] / 10;  // 十位
    wire [3:0] total_ones = ped_total[5:0] % 10;  // 个位
    
    wire in_num_box = (x >= NUM_X) && (y >= LABEL_Y) &&
                      (x < NUM_X + 2*(CHAR_W+SPACE_W)) && (y < LABEL_Y + CHAR_H);
    wire [9:0] num_col = x - NUM_X;
    wire [9:0] num_dy = y - LABEL_Y;
    wire [2:0] num_row = num_dy[2:0];
    wire [1:0] num_ch_idx = num_col / (CHAR_W + SPACE_W);
    wire [3:0] num_col_mod = num_col % (CHAR_W + SPACE_W);
    wire num_in_space = (num_col_mod >= CHAR_W);
    wire [2:0] num_col_in_char = CHAR_W - 1 - num_col_mod[2:0];
    
    // 根据字符索引选择十位或个位数�?
    wire [7:0] num_ch_ascii;
    assign num_ch_ascii = (num_ch_idx == 2'd0) ? (8'h30 + {1'b0, total_tens}) : (8'h30 + {1'b0, total_ones});
    
    wire [7:0] num_row_bits;
    font u_font_num(.ascii(num_ch_ascii), .row(num_row), .bits(num_row_bits));
    assign people_num_on = in_num_box && !num_in_space ? num_row_bits[num_col_in_char] : 1'b0;

    // ===================== LRCar: �? TBCar: 车辆数显示（使用 font 模块�? =====================
    // 显示位置（在 people: 下方�?
    localparam LRCAR_LABEL_Y = LABEL_Y + CHAR_H + 2;  // people: 下面�?�?
    localparam TBCAR_LABEL_Y = LRCAR_LABEL_Y + CHAR_H + 2;  // LRCar: 下面�?�?
    localparam LRCAR_LABEL_LEN = 6;  // "LRCar:" �?6个字�?
    localparam TBCAR_LABEL_LEN = 6;  // "TBCar:" �?6个字�?
    localparam LRCAR_NUM_X = LABEL_X + LRCAR_LABEL_LEN*(CHAR_W+SPACE_W);
    localparam TBCAR_NUM_X = LABEL_X + TBCAR_LABEL_LEN*(CHAR_W+SPACE_W);
    localparam SPEED_LABEL_Y   = TBCAR_LABEL_Y + CHAR_H + 2;
    localparam SPEED_LABEL_LEN = 6;
    localparam SPEED_NUM_X     = LABEL_X + SPEED_LABEL_LEN*(CHAR_W+SPACE_W);

    // LRCar: 标签显示
    wire [8*6-1:0] str_lrcar_pack = "LRCar:";
    wire in_lrcar_label_box = (x >= LABEL_X) && (y >= LRCAR_LABEL_Y) &&
                               (x < LABEL_X + LRCAR_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < LRCAR_LABEL_Y + CHAR_H);
    wire [9:0] lrcar_label_col = x - LABEL_X;
    wire [9:0] lrcar_label_dy = y - LRCAR_LABEL_Y;
    wire [2:0] lrcar_label_row = lrcar_label_dy[2:0];
    wire [2:0] lrcar_label_ch_idx = lrcar_label_col / (CHAR_W + SPACE_W);
    wire [3:0] lrcar_label_col_mod = lrcar_label_col % (CHAR_W + SPACE_W);
    wire lrcar_label_in_space = (lrcar_label_col_mod >= CHAR_W);
    wire [2:0] lrcar_label_col_in_char = CHAR_W - 1 - lrcar_label_col_mod[2:0];
    
    wire [7:0] lrcar_label_ch_ascii;
    assign lrcar_label_ch_ascii = str_lrcar_pack[8*(5-lrcar_label_ch_idx) +: 8];
    
    wire [7:0] lrcar_label_row_bits;
    font u_font_lrcar_label(.ascii(lrcar_label_ch_ascii), .row(lrcar_label_row), .bits(lrcar_label_row_bits));
    assign lrcar_label_on = in_lrcar_label_box && !lrcar_label_in_space ? lrcar_label_row_bits[lrcar_label_col_in_char] : 1'b0;

    // LRCar 车辆数数字（支持两位数）
    wire [3:0] lrcar_tens = car_num_lr / 10;
    wire [3:0] lrcar_ones = car_num_lr % 10;
    
    wire in_lrcar_num_box = (x >= LRCAR_NUM_X) && (y >= LRCAR_LABEL_Y) &&
                            (x < LRCAR_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < LRCAR_LABEL_Y + CHAR_H);
    wire [9:0] lrcar_num_col = x - LRCAR_NUM_X;
    wire [9:0] lrcar_num_dy = y - LRCAR_LABEL_Y;
    wire [2:0] lrcar_num_row = lrcar_num_dy[2:0];
    wire [1:0] lrcar_num_ch_idx = lrcar_num_col / (CHAR_W + SPACE_W);
    wire [3:0] lrcar_num_col_mod = lrcar_num_col % (CHAR_W + SPACE_W);
    wire lrcar_num_in_space = (lrcar_num_col_mod >= CHAR_W);
    wire [2:0] lrcar_num_col_in_char = CHAR_W - 1 - lrcar_num_col_mod[2:0];
    
    wire [7:0] lrcar_num_ch_ascii;
    assign lrcar_num_ch_ascii = (lrcar_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, lrcar_tens}) : (8'h30 + {1'b0, lrcar_ones});
    
    wire [7:0] lrcar_num_row_bits;
    font u_font_lrcar_num(.ascii(lrcar_num_ch_ascii), .row(lrcar_num_row), .bits(lrcar_num_row_bits));
    assign lrcar_num_on = in_lrcar_num_box && !lrcar_num_in_space ? lrcar_num_row_bits[lrcar_num_col_in_char] : 1'b0;

    // TBCar: 标签显示
    wire [8*6-1:0] str_tbcar_pack = "TBCar:";
    wire in_tbcar_label_box = (x >= LABEL_X) && (y >= TBCAR_LABEL_Y) &&
                               (x < LABEL_X + TBCAR_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < TBCAR_LABEL_Y + CHAR_H);
    wire [9:0] tbcar_label_col = x - LABEL_X;
    wire [9:0] tbcar_label_dy = y - TBCAR_LABEL_Y;
    wire [2:0] tbcar_label_row = tbcar_label_dy[2:0];
    wire [2:0] tbcar_label_ch_idx = tbcar_label_col / (CHAR_W + SPACE_W);
    wire [3:0] tbcar_label_col_mod = tbcar_label_col % (CHAR_W + SPACE_W);
    wire tbcar_label_in_space = (tbcar_label_col_mod >= CHAR_W);
    wire [2:0] tbcar_label_col_in_char = CHAR_W - 1 - tbcar_label_col_mod[2:0];
    
    wire [7:0] tbcar_label_ch_ascii;
    assign tbcar_label_ch_ascii = str_tbcar_pack[8*(5-tbcar_label_ch_idx) +: 8];
    
    wire [7:0] tbcar_label_row_bits;
    font u_font_tbcar_label(.ascii(tbcar_label_ch_ascii), .row(tbcar_label_row), .bits(tbcar_label_row_bits));
    assign tbcar_label_on = in_tbcar_label_box && !tbcar_label_in_space ? tbcar_label_row_bits[tbcar_label_col_in_char] : 1'b0;

    // TBCar 车辆数数字（支持两位数）
    wire [3:0] tbcar_tens = car_num_tb / 10;
    wire [3:0] tbcar_ones = car_num_tb % 10;
    
    wire in_tbcar_num_box = (x >= TBCAR_NUM_X) && (y >= TBCAR_LABEL_Y) &&
                             (x < TBCAR_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < TBCAR_LABEL_Y + CHAR_H);
    wire [9:0] tbcar_num_col = x - TBCAR_NUM_X;
    wire [9:0] tbcar_num_dy = y - TBCAR_LABEL_Y;
    wire [2:0] tbcar_num_row = tbcar_num_dy[2:0];
    wire [1:0] tbcar_num_ch_idx = tbcar_num_col / (CHAR_W + SPACE_W);
    wire [3:0] tbcar_num_col_mod = tbcar_num_col % (CHAR_W + SPACE_W);
    wire tbcar_num_in_space = (tbcar_num_col_mod >= CHAR_W);
    wire [2:0] tbcar_num_col_in_char = CHAR_W - 1 - tbcar_num_col_mod[2:0];
    
    wire [7:0] tbcar_num_ch_ascii;
    assign tbcar_num_ch_ascii = (tbcar_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, tbcar_tens}) : (8'h30 + {1'b0, tbcar_ones});
    
    wire [7:0] tbcar_num_row_bits;
    font u_font_tbcar_num(.ascii(tbcar_num_ch_ascii), .row(tbcar_num_row), .bits(tbcar_num_row_bits));
    assign tbcar_num_on = in_tbcar_num_box && !tbcar_num_in_space ? tbcar_num_row_bits[tbcar_num_col_in_char] : 1'b0;

    // SPEED: 建议限速
    wire [8*6-1:0] str_speed_pack = "SPEED:";
    wire in_speed_label_box = (x >= LABEL_X) && (y >= SPEED_LABEL_Y) &&
                              (x < LABEL_X + SPEED_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < SPEED_LABEL_Y + CHAR_H);
    wire [9:0] speed_label_col = x - LABEL_X;
    wire [9:0] speed_label_dy  = y - SPEED_LABEL_Y;
    wire [2:0] speed_label_row = speed_label_dy[2:0];
    wire [2:0] speed_label_ch_idx = speed_label_col / (CHAR_W + SPACE_W);
    wire [3:0] speed_label_col_mod = speed_label_col % (CHAR_W + SPACE_W);
    wire       speed_label_in_space = (speed_label_col_mod >= CHAR_W);
    wire [2:0] speed_label_col_in_char = CHAR_W - 1 - speed_label_col_mod[2:0];

    wire [7:0] speed_label_ch_ascii;
    assign speed_label_ch_ascii = str_speed_pack[8*(5-speed_label_ch_idx) +: 8];

    wire [7:0] speed_label_row_bits;
    font u_font_speed_label(.ascii(speed_label_ch_ascii), .row(speed_label_row), .bits(speed_label_row_bits));
    assign speed_label_on = in_speed_label_box && !speed_label_in_space ? speed_label_row_bits[speed_label_col_in_char] : 1'b0;

    wire [3:0] speed_tens = speed_sugg / 10;
    wire [3:0] speed_ones = speed_sugg % 10;
    wire in_speed_num_box = (x >= SPEED_NUM_X) && (y >= SPEED_LABEL_Y) &&
                            (x < SPEED_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < SPEED_LABEL_Y + CHAR_H);
    wire [9:0] speed_num_col = x - SPEED_NUM_X;
    wire [9:0] speed_num_dy  = y - SPEED_LABEL_Y;
    wire [2:0] speed_num_row = speed_num_dy[2:0];
    wire [1:0] speed_num_ch_idx = speed_num_col / (CHAR_W + SPACE_W);
    wire [3:0] speed_num_col_mod = speed_num_col % (CHAR_W + SPACE_W);
    wire       speed_num_in_space = (speed_num_col_mod >= CHAR_W);
    wire [2:0] speed_num_col_in_char = CHAR_W - 1 - speed_num_col_mod[2:0];
    wire [7:0] speed_num_ch_ascii = (speed_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, speed_tens}) : (8'h30 + {1'b0, speed_ones});
    wire [7:0] speed_num_row_bits;
    font u_font_speed_num(.ascii(speed_num_ch_ascii), .row(speed_num_row), .bits(speed_num_row_bits));
    assign speed_num_on = in_speed_num_box && !speed_num_in_space ? speed_num_row_bits[speed_num_col_in_char] : 1'b0;

    // ===================== 绿灯时长显示 =====================
    // 显示位置（在左下角，mode标签上方�?
    // mode标签位置：Y = 480 - 8 - 8 = 464
    // �?多显�?8行（包含R时），每行高�? = 10，�?�高�? = 80，间�? = 2
    localparam SCREEN_H = 480;
    localparam MODE_PAD_Y = 8;
    localparam MODE_LABEL_Y = SCREEN_H - CHAR_H - MODE_PAD_Y;  // 464
    localparam GREEN_MAX_LINES = 8;  // �?�?8行（TB/LR�?4行）
    localparam GREEN_LINE_HEIGHT = CHAR_H + 2;  // 每行高度 = 10
    localparam GREEN_TOTAL_HEIGHT = GREEN_MAX_LINES * GREEN_LINE_HEIGHT;  // 总高�? = 80
    localparam GREEN_SPACING = 2;  // 与mode标签的间�?
    localparam GREEN_BASE_Y = MODE_LABEL_Y - GREEN_TOTAL_HEIGHT - GREEN_SPACING;  // 464 - 80 - 2 = 382
    
    // TB方向标签 "TB:"
    localparam TB_GREEN_LABEL_Y = GREEN_BASE_Y;
    localparam TB_GREEN_LABEL_LEN = 3;  // "TB:"
    localparam TB_GREEN_LABEL_WIDTH = TB_GREEN_LABEL_LEN*(CHAR_W+SPACE_W);  // "TB:" 占据的宽�?
    localparam TB_INDENT_X = LABEL_X + TB_GREEN_LABEL_WIDTH + 2;  // "TB:" 后面的缩进位置（+2像素间距�?
    wire [8*3-1:0] str_tb_green_pack = "TB:";
    wire in_tb_green_label_box = (x >= LABEL_X) && (y >= TB_GREEN_LABEL_Y) &&
                                  (x < LABEL_X + TB_GREEN_LABEL_WIDTH) && (y < TB_GREEN_LABEL_Y + CHAR_H);
    wire [9:0] tb_green_label_col = x - LABEL_X;
    wire [9:0] tb_green_label_dy = y - TB_GREEN_LABEL_Y;
    wire [2:0] tb_green_label_row = tb_green_label_dy[2:0];
    wire [1:0] tb_green_label_ch_idx = tb_green_label_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_green_label_col_mod = tb_green_label_col % (CHAR_W + SPACE_W);
    wire tb_green_label_in_space = (tb_green_label_col_mod >= CHAR_W);
    wire [2:0] tb_green_label_col_in_char = CHAR_W - 1 - tb_green_label_col_mod[2:0];
    
    wire [7:0] tb_green_label_ch_ascii;
    assign tb_green_label_ch_ascii = str_tb_green_pack[8*(2-tb_green_label_ch_idx) +: 8];
    
    wire [7:0] tb_green_label_row_bits;
    font u_font_tb_green_label(.ascii(tb_green_label_ch_ascii), .row(tb_green_label_row), .bits(tb_green_label_row_bits));
    assign tb_green_label_on = in_tb_green_label_box && !tb_green_label_in_space ? tb_green_label_row_bits[tb_green_label_col_in_char] : 1'b0;

    // TB S: 标签和数�?
    localparam TB_S_LABEL_Y = TB_GREEN_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam TB_S_LABEL_X = TB_INDENT_X;  // �?"TB:"后面
    localparam TB_S_LABEL_LEN = 2;  // "S:"
    localparam TB_S_NUM_X = TB_S_LABEL_X + TB_S_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_tb_s_pack = "S:";
    wire in_tb_s_label_box = (x >= TB_S_LABEL_X) && (y >= TB_S_LABEL_Y) &&
                              (x < TB_S_LABEL_X + TB_S_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < TB_S_LABEL_Y + CHAR_H);
    wire [9:0] tb_s_label_col = x - TB_S_LABEL_X;
    wire [9:0] tb_s_label_dy = y - TB_S_LABEL_Y;
    wire [2:0] tb_s_label_row = tb_s_label_dy[2:0];
    wire [1:0] tb_s_label_ch_idx = tb_s_label_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_s_label_col_mod = tb_s_label_col % (CHAR_W + SPACE_W);
    wire tb_s_label_in_space = (tb_s_label_col_mod >= CHAR_W);
    wire [2:0] tb_s_label_col_in_char = CHAR_W - 1 - tb_s_label_col_mod[2:0];
    
    wire [7:0] tb_s_label_ch_ascii;
    assign tb_s_label_ch_ascii = str_tb_s_pack[8*(1-tb_s_label_ch_idx) +: 8];
    
    wire [7:0] tb_s_label_row_bits;
    font u_font_tb_s_label(.ascii(tb_s_label_ch_ascii), .row(tb_s_label_row), .bits(tb_s_label_row_bits));
    assign tb_s_label_on = in_tb_s_label_box && !tb_s_label_in_space ? tb_s_label_row_bits[tb_s_label_col_in_char] : 1'b0;

    // TB S 数字
    wire [3:0] tb_s_tens = green_sec_TB_S / 10;
    wire [3:0] tb_s_ones = green_sec_TB_S % 10;
    wire in_tb_s_num_box = (x >= TB_S_NUM_X) && (y >= TB_S_LABEL_Y) &&
                           (x < TB_S_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < TB_S_LABEL_Y + CHAR_H);
    wire [9:0] tb_s_num_col = x - TB_S_NUM_X;
    wire [9:0] tb_s_num_dy = y - TB_S_LABEL_Y;
    wire [2:0] tb_s_num_row = tb_s_num_dy[2:0];
    wire [1:0] tb_s_num_ch_idx = tb_s_num_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_s_num_col_mod = tb_s_num_col % (CHAR_W + SPACE_W);
    wire tb_s_num_in_space = (tb_s_num_col_mod >= CHAR_W);
    wire [2:0] tb_s_num_col_in_char = CHAR_W - 1 - tb_s_num_col_mod[2:0];
    
    wire [7:0] tb_s_num_ch_ascii;
    assign tb_s_num_ch_ascii = (tb_s_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, tb_s_tens}) : (8'h30 + {1'b0, tb_s_ones});
    
    wire [7:0] tb_s_num_row_bits;
    font u_font_tb_s_num(.ascii(tb_s_num_ch_ascii), .row(tb_s_num_row), .bits(tb_s_num_row_bits));
    assign tb_s_num_on = in_tb_s_num_box && !tb_s_num_in_space ? tb_s_num_row_bits[tb_s_num_col_in_char] : 1'b0;

    // TB L: 标签和数�?
    localparam TB_L_LABEL_Y = TB_S_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam TB_L_LABEL_X = TB_INDENT_X;  // �?"TB:"后面
    localparam TB_L_LABEL_LEN = 2;
    localparam TB_L_NUM_X = TB_L_LABEL_X + TB_L_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_tb_l_pack = "L:";
    wire in_tb_l_label_box = (x >= TB_L_LABEL_X) && (y >= TB_L_LABEL_Y) &&
                             (x < TB_L_LABEL_X + TB_L_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < TB_L_LABEL_Y + CHAR_H);
    wire [9:0] tb_l_label_col = x - TB_L_LABEL_X;
    wire [9:0] tb_l_label_dy = y - TB_L_LABEL_Y;
    wire [2:0] tb_l_label_row = tb_l_label_dy[2:0];
    wire [1:0] tb_l_label_ch_idx = tb_l_label_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_l_label_col_mod = tb_l_label_col % (CHAR_W + SPACE_W);
    wire tb_l_label_in_space = (tb_l_label_col_mod >= CHAR_W);
    wire [2:0] tb_l_label_col_in_char = CHAR_W - 1 - tb_l_label_col_mod[2:0];
    
    wire [7:0] tb_l_label_ch_ascii;
    assign tb_l_label_ch_ascii = str_tb_l_pack[8*(1-tb_l_label_ch_idx) +: 8];
    
    wire [7:0] tb_l_label_row_bits;
    font u_font_tb_l_label(.ascii(tb_l_label_ch_ascii), .row(tb_l_label_row), .bits(tb_l_label_row_bits));
    assign tb_l_label_on = in_tb_l_label_box && !tb_l_label_in_space ? tb_l_label_row_bits[tb_l_label_col_in_char] : 1'b0;

    // TB L 数字
    wire [3:0] tb_l_tens = green_sec_TB_L / 10;
    wire [3:0] tb_l_ones = green_sec_TB_L % 10;
    wire in_tb_l_num_box = (x >= TB_L_NUM_X) && (y >= TB_L_LABEL_Y) &&
                           (x < TB_L_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < TB_L_LABEL_Y + CHAR_H);
    wire [9:0] tb_l_num_col = x - TB_L_NUM_X;
    wire [9:0] tb_l_num_dy = y - TB_L_LABEL_Y;
    wire [2:0] tb_l_num_row = tb_l_num_dy[2:0];
    wire [1:0] tb_l_num_ch_idx = tb_l_num_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_l_num_col_mod = tb_l_num_col % (CHAR_W + SPACE_W);
    wire tb_l_num_in_space = (tb_l_num_col_mod >= CHAR_W);
    wire [2:0] tb_l_num_col_in_char = CHAR_W - 1 - tb_l_num_col_mod[2:0];
    
    wire [7:0] tb_l_num_ch_ascii;
    assign tb_l_num_ch_ascii = (tb_l_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, tb_l_tens}) : (8'h30 + {1'b0, tb_l_ones});
    
    wire [7:0] tb_l_num_row_bits;
    font u_font_tb_l_num(.ascii(tb_l_num_ch_ascii), .row(tb_l_num_row), .bits(tb_l_num_row_bits));
    assign tb_l_num_on = in_tb_l_num_box && !tb_l_num_in_space ? tb_l_num_row_bits[tb_l_num_col_in_char] : 1'b0;

    // TB R: 标签和数字（仅在固定模式显示�?
    localparam TB_R_LABEL_Y = TB_L_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam TB_R_LABEL_X = TB_INDENT_X;  // �?"TB:"后面
    localparam TB_R_LABEL_LEN = 2;
    localparam TB_R_NUM_X = TB_R_LABEL_X + TB_R_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_tb_r_pack = "R:";
    wire in_tb_r_label_box = (x >= TB_R_LABEL_X) && (y >= TB_R_LABEL_Y) &&
                             (x < TB_R_LABEL_X + TB_R_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < TB_R_LABEL_Y + CHAR_H) &&
                             (!mode_adapt_sw);  // 固定模式才显�?
    wire [9:0] tb_r_label_col = x - TB_R_LABEL_X;
    wire [9:0] tb_r_label_dy = y - TB_R_LABEL_Y;
    wire [2:0] tb_r_label_row = tb_r_label_dy[2:0];
    wire [1:0] tb_r_label_ch_idx = tb_r_label_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_r_label_col_mod = tb_r_label_col % (CHAR_W + SPACE_W);
    wire tb_r_label_in_space = (tb_r_label_col_mod >= CHAR_W);
    wire [2:0] tb_r_label_col_in_char = CHAR_W - 1 - tb_r_label_col_mod[2:0];
    
    wire [7:0] tb_r_label_ch_ascii;
    assign tb_r_label_ch_ascii = str_tb_r_pack[8*(1-tb_r_label_ch_idx) +: 8];
    
    wire [7:0] tb_r_label_row_bits;
    font u_font_tb_r_label(.ascii(tb_r_label_ch_ascii), .row(tb_r_label_row), .bits(tb_r_label_row_bits));
    assign tb_r_label_on = in_tb_r_label_box && !tb_r_label_in_space ? tb_r_label_row_bits[tb_r_label_col_in_char] : 1'b0;

    // TB R 数字（仅在固定模式显示）
    wire [3:0] tb_r_tens = green_sec_TB_R / 10;
    wire [3:0] tb_r_ones = green_sec_TB_R % 10;
    wire in_tb_r_num_box = (x >= TB_R_NUM_X) && (y >= TB_R_LABEL_Y) &&
                           (x < TB_R_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < TB_R_LABEL_Y + CHAR_H) &&
                           (!mode_adapt_sw);  // 固定模式才显�?
    wire [9:0] tb_r_num_col = x - TB_R_NUM_X;
    wire [9:0] tb_r_num_dy = y - TB_R_LABEL_Y;
    wire [2:0] tb_r_num_row = tb_r_num_dy[2:0];
    wire [1:0] tb_r_num_ch_idx = tb_r_num_col / (CHAR_W + SPACE_W);
    wire [3:0] tb_r_num_col_mod = tb_r_num_col % (CHAR_W + SPACE_W);
    wire tb_r_num_in_space = (tb_r_num_col_mod >= CHAR_W);
    wire [2:0] tb_r_num_col_in_char = CHAR_W - 1 - tb_r_num_col_mod[2:0];
    
    wire [7:0] tb_r_num_ch_ascii;
    assign tb_r_num_ch_ascii = (tb_r_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, tb_r_tens}) : (8'h30 + {1'b0, tb_r_ones});
    
    wire [7:0] tb_r_num_row_bits;
    font u_font_tb_r_num(.ascii(tb_r_num_ch_ascii), .row(tb_r_num_row), .bits(tb_r_num_row_bits));
    assign tb_r_num_on = in_tb_r_num_box && !tb_r_num_in_space ? tb_r_num_row_bits[tb_r_num_col_in_char] : 1'b0;

    // LR方向标签 "LR:"（紧接在TB下方，确保也在左下角�?
    // TB�?多有4行（TB:, S:, L:, R:），每行高度GREEN_LINE_HEIGHT
    // 自�?�应模式：TB显示3行（TB:, S:, L:），LR从TB_L之后�?�? = GREEN_BASE_Y + 3*GREEN_LINE_HEIGHT
    // 固定模式：TB显示4行（TB:, S:, L:, R:），LR从TB_R之后�?�? = GREEN_BASE_Y + 4*GREEN_LINE_HEIGHT
    // 注意：使用wire而不是localparam，因为需要依赖运行时信号mode_adapt_sw
    wire [9:0] LR_GREEN_LABEL_Y;
    assign LR_GREEN_LABEL_Y = (!mode_adapt_sw) ? 
                              (GREEN_BASE_Y + 4*GREEN_LINE_HEIGHT) :  // 固定模式：TB�?4�?
                              (GREEN_BASE_Y + 3*GREEN_LINE_HEIGHT);   // 自�?�应模式：TB�?3�?
    localparam LR_GREEN_LABEL_LEN = 3;
    localparam LR_GREEN_LABEL_WIDTH = LR_GREEN_LABEL_LEN*(CHAR_W+SPACE_W);  // "LR:" 占据的宽�?
    localparam LR_INDENT_X = LABEL_X + LR_GREEN_LABEL_WIDTH + 2;  // "LR:" 后面的缩进位置（+2像素间距�?
    wire [8*3-1:0] str_lr_green_pack = "LR:";
    wire in_lr_green_label_box = (x >= LABEL_X) && (y >= LR_GREEN_LABEL_Y) &&
                                  (x < LABEL_X + LR_GREEN_LABEL_WIDTH) && (y < LR_GREEN_LABEL_Y + CHAR_H);
    wire [9:0] lr_green_label_col = x - LABEL_X;
    wire [9:0] lr_green_label_dy = y - LR_GREEN_LABEL_Y;
    wire [2:0] lr_green_label_row = lr_green_label_dy[2:0];
    wire [1:0] lr_green_label_ch_idx = lr_green_label_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_green_label_col_mod = lr_green_label_col % (CHAR_W + SPACE_W);
    wire lr_green_label_in_space = (lr_green_label_col_mod >= CHAR_W);
    wire [2:0] lr_green_label_col_in_char = CHAR_W - 1 - lr_green_label_col_mod[2:0];
    
    wire [7:0] lr_green_label_ch_ascii;
    assign lr_green_label_ch_ascii = str_lr_green_pack[8*(2-lr_green_label_ch_idx) +: 8];
    
    wire [7:0] lr_green_label_row_bits;
    font u_font_lr_green_label(.ascii(lr_green_label_ch_ascii), .row(lr_green_label_row), .bits(lr_green_label_row_bits));
    assign lr_green_label_on = in_lr_green_label_box && !lr_green_label_in_space ? lr_green_label_row_bits[lr_green_label_col_in_char] : 1'b0;

    // LR S: 标签和数�?
    wire [9:0] LR_S_LABEL_Y;
    assign LR_S_LABEL_Y = LR_GREEN_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam LR_S_LABEL_X = LR_INDENT_X;  // �?"LR:"后面
    localparam LR_S_LABEL_LEN = 2;
    localparam LR_S_NUM_X = LR_S_LABEL_X + LR_S_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_lr_s_pack = "S:";
    wire in_lr_s_label_box = (x >= LR_S_LABEL_X) && (y >= LR_S_LABEL_Y) &&
                              (x < LR_S_LABEL_X + LR_S_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < LR_S_LABEL_Y + CHAR_H);
    wire [9:0] lr_s_label_col = x - LR_S_LABEL_X;
    wire [9:0] lr_s_label_dy = y - LR_S_LABEL_Y;
    wire [2:0] lr_s_label_row = lr_s_label_dy[2:0];
    wire [1:0] lr_s_label_ch_idx = lr_s_label_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_s_label_col_mod = lr_s_label_col % (CHAR_W + SPACE_W);
    wire lr_s_label_in_space = (lr_s_label_col_mod >= CHAR_W);
    wire [2:0] lr_s_label_col_in_char = CHAR_W - 1 - lr_s_label_col_mod[2:0];
    
    wire [7:0] lr_s_label_ch_ascii;
    assign lr_s_label_ch_ascii = str_lr_s_pack[8*(1-lr_s_label_ch_idx) +: 8];
    
    wire [7:0] lr_s_label_row_bits;
    font u_font_lr_s_label(.ascii(lr_s_label_ch_ascii), .row(lr_s_label_row), .bits(lr_s_label_row_bits));
    assign lr_s_label_on = in_lr_s_label_box && !lr_s_label_in_space ? lr_s_label_row_bits[lr_s_label_col_in_char] : 1'b0;

    // LR S 数字
    wire [3:0] lr_s_tens = green_sec_LR_S / 10;
    wire [3:0] lr_s_ones = green_sec_LR_S % 10;
    wire in_lr_s_num_box = (x >= LR_S_NUM_X) && (y >= LR_S_LABEL_Y) &&
                           (x < LR_S_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < LR_S_LABEL_Y + CHAR_H);
    wire [9:0] lr_s_num_col = x - LR_S_NUM_X;
    wire [9:0] lr_s_num_dy = y - LR_S_LABEL_Y;
    wire [2:0] lr_s_num_row = lr_s_num_dy[2:0];
    wire [1:0] lr_s_num_ch_idx = lr_s_num_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_s_num_col_mod = lr_s_num_col % (CHAR_W + SPACE_W);
    wire lr_s_num_in_space = (lr_s_num_col_mod >= CHAR_W);
    wire [2:0] lr_s_num_col_in_char = CHAR_W - 1 - lr_s_num_col_mod[2:0];
    
    wire [7:0] lr_s_num_ch_ascii;
    assign lr_s_num_ch_ascii = (lr_s_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, lr_s_tens}) : (8'h30 + {1'b0, lr_s_ones});
    
    wire [7:0] lr_s_num_row_bits;
    font u_font_lr_s_num(.ascii(lr_s_num_ch_ascii), .row(lr_s_num_row), .bits(lr_s_num_row_bits));
    assign lr_s_num_on = in_lr_s_num_box && !lr_s_num_in_space ? lr_s_num_row_bits[lr_s_num_col_in_char] : 1'b0;

    // LR L: 标签和数�?
    wire [9:0] LR_L_LABEL_Y;
    assign LR_L_LABEL_Y = LR_S_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam LR_L_LABEL_X = LR_INDENT_X;  // �?"LR:"后面
    localparam LR_L_LABEL_LEN = 2;
    localparam LR_L_NUM_X = LR_L_LABEL_X + LR_L_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_lr_l_pack = "L:";
    wire in_lr_l_label_box = (x >= LR_L_LABEL_X) && (y >= LR_L_LABEL_Y) &&
                             (x < LR_L_LABEL_X + LR_L_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < LR_L_LABEL_Y + CHAR_H);
    wire [9:0] lr_l_label_col = x - LR_L_LABEL_X;
    wire [9:0] lr_l_label_dy = y - LR_L_LABEL_Y;
    wire [2:0] lr_l_label_row = lr_l_label_dy[2:0];
    wire [1:0] lr_l_label_ch_idx = lr_l_label_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_l_label_col_mod = lr_l_label_col % (CHAR_W + SPACE_W);
    wire lr_l_label_in_space = (lr_l_label_col_mod >= CHAR_W);
    wire [2:0] lr_l_label_col_in_char = CHAR_W - 1 - lr_l_label_col_mod[2:0];
    
    wire [7:0] lr_l_label_ch_ascii;
    assign lr_l_label_ch_ascii = str_lr_l_pack[8*(1-lr_l_label_ch_idx) +: 8];
    
    wire [7:0] lr_l_label_row_bits;
    font u_font_lr_l_label(.ascii(lr_l_label_ch_ascii), .row(lr_l_label_row), .bits(lr_l_label_row_bits));
    assign lr_l_label_on = in_lr_l_label_box && !lr_l_label_in_space ? lr_l_label_row_bits[lr_l_label_col_in_char] : 1'b0;

    // LR L 数字
    wire [3:0] lr_l_tens = green_sec_LR_L / 10;
    wire [3:0] lr_l_ones = green_sec_LR_L % 10;
    wire in_lr_l_num_box = (x >= LR_L_NUM_X) && (y >= LR_L_LABEL_Y) &&
                           (x < LR_L_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < LR_L_LABEL_Y + CHAR_H);
    wire [9:0] lr_l_num_col = x - LR_L_NUM_X;
    wire [9:0] lr_l_num_dy = y - LR_L_LABEL_Y;
    wire [2:0] lr_l_num_row = lr_l_num_dy[2:0];
    wire [1:0] lr_l_num_ch_idx = lr_l_num_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_l_num_col_mod = lr_l_num_col % (CHAR_W + SPACE_W);
    wire lr_l_num_in_space = (lr_l_num_col_mod >= CHAR_W);
    wire [2:0] lr_l_num_col_in_char = CHAR_W - 1 - lr_l_num_col_mod[2:0];
    
    wire [7:0] lr_l_num_ch_ascii;
    assign lr_l_num_ch_ascii = (lr_l_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, lr_l_tens}) : (8'h30 + {1'b0, lr_l_ones});
    
    wire [7:0] lr_l_num_row_bits;
    font u_font_lr_l_num(.ascii(lr_l_num_ch_ascii), .row(lr_l_num_row), .bits(lr_l_num_row_bits));
    assign lr_l_num_on = in_lr_l_num_box && !lr_l_num_in_space ? lr_l_num_row_bits[lr_l_num_col_in_char] : 1'b0;

    // LR R: 标签和数字（仅在固定模式显示�?
    wire [9:0] LR_R_LABEL_Y;
    assign LR_R_LABEL_Y = LR_L_LABEL_Y + GREEN_LINE_HEIGHT;
    localparam LR_R_LABEL_X = LR_INDENT_X;  // �?"LR:"后面
    localparam LR_R_LABEL_LEN = 2;
    localparam LR_R_NUM_X = LR_R_LABEL_X + LR_R_LABEL_LEN*(CHAR_W+SPACE_W);
    
    wire [8*2-1:0] str_lr_r_pack = "R:";
    wire in_lr_r_label_box = (x >= LR_R_LABEL_X) && (y >= LR_R_LABEL_Y) &&
                             (x < LR_R_LABEL_X + LR_R_LABEL_LEN*(CHAR_W+SPACE_W)) && (y < LR_R_LABEL_Y + CHAR_H) &&
                             (!mode_adapt_sw);  // 固定模式才显�?
    wire [9:0] lr_r_label_col = x - LR_R_LABEL_X;
    wire [9:0] lr_r_label_dy = y - LR_R_LABEL_Y;
    wire [2:0] lr_r_label_row = lr_r_label_dy[2:0];
    wire [1:0] lr_r_label_ch_idx = lr_r_label_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_r_label_col_mod = lr_r_label_col % (CHAR_W + SPACE_W);
    wire lr_r_label_in_space = (lr_r_label_col_mod >= CHAR_W);
    wire [2:0] lr_r_label_col_in_char = CHAR_W - 1 - lr_r_label_col_mod[2:0];
    
    wire [7:0] lr_r_label_ch_ascii;
    assign lr_r_label_ch_ascii = str_lr_r_pack[8*(1-lr_r_label_ch_idx) +: 8];
    
    wire [7:0] lr_r_label_row_bits;
    font u_font_lr_r_label(.ascii(lr_r_label_ch_ascii), .row(lr_r_label_row), .bits(lr_r_label_row_bits));
    assign lr_r_label_on = in_lr_r_label_box && !lr_r_label_in_space ? lr_r_label_row_bits[lr_r_label_col_in_char] : 1'b0;

    // LR R 数字（仅在固定模式显示）
    wire [3:0] lr_r_tens = green_sec_LR_R / 10;
    wire [3:0] lr_r_ones = green_sec_LR_R % 10;
    wire in_lr_r_num_box = (x >= LR_R_NUM_X) && (y >= LR_R_LABEL_Y) &&
                           (x < LR_R_NUM_X + 2*(CHAR_W+SPACE_W)) && (y < LR_R_LABEL_Y + CHAR_H) &&
                           (!mode_adapt_sw);  // 固定模式才显�?
    wire [9:0] lr_r_num_col = x - LR_R_NUM_X;
    wire [9:0] lr_r_num_dy = y - LR_R_LABEL_Y;
    wire [2:0] lr_r_num_row = lr_r_num_dy[2:0];
    wire [1:0] lr_r_num_ch_idx = lr_r_num_col / (CHAR_W + SPACE_W);
    wire [3:0] lr_r_num_col_mod = lr_r_num_col % (CHAR_W + SPACE_W);
    wire lr_r_num_in_space = (lr_r_num_col_mod >= CHAR_W);
    wire [2:0] lr_r_num_col_in_char = CHAR_W - 1 - lr_r_num_col_mod[2:0];
    
    wire [7:0] lr_r_num_ch_ascii;
    assign lr_r_num_ch_ascii = (lr_r_num_ch_idx == 2'd0) ? (8'h30 + {1'b0, lr_r_tens}) : (8'h30 + {1'b0, lr_r_ones});
    
    wire [7:0] lr_r_num_row_bits;
    font u_font_lr_r_num(.ascii(lr_r_num_ch_ascii), .row(lr_r_num_row), .bits(lr_r_num_row_bits));
    assign lr_r_num_on = in_lr_r_num_box && !lr_r_num_in_space ? lr_r_num_row_bits[lr_r_num_col_in_char] : 1'b0;

    // ===================== 倒计时已完全删除以节省LUT =====================
    // 删除了所有倒计时显示逻辑（6个除法器、6个取模器、6个字体渲染）
    // 节省约 240 LUT

endmodule
`endif

// Shared text rasterizer. One coordinate decoder and one font lookup serve all
// labels and values; this preserves the display while avoiding duplicated logic.
module word_renderer #(
    parameter CHAR_W = 8,
    parameter CHAR_H = 8,
    parameter SPACE_W = 1
)(
    input pix_clk,
    input [9:0] x,
    input [9:0] y,
    output people_on,
    output carM_on,
    output carS_on,
    input [4:0] ped_num_lr,
    input [4:0] ped_num_tb,
    input [4:0] car_num_lr,
    input [4:0] car_num_tb,
    output people_label_on,
    output people_num_on,
    output lrcar_label_on,
    output lrcar_num_on,
    output tbcar_label_on,
    output tbcar_num_on,
    input [7:0] green_sec_LR_S,
    input [7:0] green_sec_LR_L,
    input [7:0] green_sec_LR_R,
    input [7:0] green_sec_TB_S,
    input [7:0] green_sec_TB_L,
    input [7:0] green_sec_TB_R,
    input mode_adapt_sw,
    output tb_green_label_on,
    output tb_s_label_on,
    output tb_s_num_on,
    output tb_l_label_on,
    output tb_l_num_on,
    output tb_r_label_on,
    output tb_r_num_on,
    output lr_green_label_on,
    output lr_s_label_on,
    output lr_s_num_on,
    output lr_l_label_on,
    output lr_l_num_on,
    output lr_r_label_on,
    output lr_r_num_on,
    input [7:0] speed_sugg,
    output speed_label_on,
    output speed_num_on,
    input [7:0] countdown_LR_S,
    input [7:0] countdown_LR_L,
    input [7:0] countdown_LR_R,
    input [7:0] countdown_TB_S,
    input [7:0] countdown_TB_L,
    input [7:0] countdown_TB_R,
    output cd_tb_s_num_on,
    output cd_tb_l_num_on,
    output cd_tb_r_num_on,
    output cd_lr_s_num_on,
    output cd_lr_l_num_on,
    output cd_lr_r_num_on
);
    localparam [4:0] ID_NONE=0, ID_PEOPLE_L=1, ID_PEOPLE_N=2,
                     ID_LRCAR_L=3, ID_LRCAR_N=4, ID_TBCAR_L=5,
                     ID_TBCAR_N=6, ID_SPEED_L=7, ID_SPEED_N=8,
                     ID_TB_HEAD=9, ID_TB_S_L=10, ID_TB_S_N=11,
                     ID_TB_L_L=12, ID_TB_L_N=13, ID_TB_R_L=14,
                     ID_TB_R_N=15, ID_LR_HEAD=16, ID_LR_S_L=17,
                     ID_LR_S_N=18, ID_LR_L_L=19, ID_LR_L_N=20,
                     ID_LR_R_L=21, ID_LR_R_N=22;

    reg [4:0] sel;
    reg [9:0] x0;
    reg [3:0] nch;
    reg [7:0] number;
    wire [9:0] lr_y = mode_adapt_sw ? 10'd412 : 10'd422;
    wire [5:0] ped_total = {1'b0,ped_num_lr} + {1'b0,ped_num_tb};

    always @* begin
        sel=ID_NONE; x0=0; nch=0; number=0;
        if (y>=16 && y<24) begin
            if (x>=8 && x<71) begin sel=ID_PEOPLE_L; x0=8; nch=7; end
            else if (x>=71 && x<89) begin sel=ID_PEOPLE_N; x0=71; nch=2; number={2'b0,ped_total}; end
        end else if (y>=26 && y<34) begin
            if (x>=8 && x<62) begin sel=ID_LRCAR_L; x0=8; nch=6; end
            else if (x>=62 && x<80) begin sel=ID_LRCAR_N; x0=62; nch=2; number={3'b0,car_num_lr}; end
        end else if (y>=36 && y<44) begin
            if (x>=8 && x<62) begin sel=ID_TBCAR_L; x0=8; nch=6; end
            else if (x>=62 && x<80) begin sel=ID_TBCAR_N; x0=62; nch=2; number={3'b0,car_num_tb}; end
        end else if (y>=46 && y<54) begin
            if (x>=8 && x<62) begin sel=ID_SPEED_L; x0=8; nch=6; end
            else if (x>=62 && x<80) begin sel=ID_SPEED_N; x0=62; nch=2; number=speed_sugg; end
        end else if (y>=382 && y<390 && x>=8 && x<35) begin
            sel=ID_TB_HEAD; x0=8; nch=3;
        end else if (y>=392 && y<400) begin
            if (x>=37 && x<55) begin sel=ID_TB_S_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_TB_S_N; x0=55; nch=2; number=green_sec_TB_S; end
        end else if (y>=402 && y<410) begin
            if (x>=37 && x<55) begin sel=ID_TB_L_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_TB_L_N; x0=55; nch=2; number=green_sec_TB_L; end
        end else if (!mode_adapt_sw && y>=412 && y<420) begin
            if (x>=37 && x<55) begin sel=ID_TB_R_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_TB_R_N; x0=55; nch=2; number=green_sec_TB_R; end
        end else if (y>=lr_y && y<lr_y+8 && x>=8 && x<35) begin
            sel=ID_LR_HEAD; x0=8; nch=3;
        end else if (y>=lr_y+10 && y<lr_y+18) begin
            if (x>=37 && x<55) begin sel=ID_LR_S_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_LR_S_N; x0=55; nch=2; number=green_sec_LR_S; end
        end else if (y>=lr_y+20 && y<lr_y+28) begin
            if (x>=37 && x<55) begin sel=ID_LR_L_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_LR_L_N; x0=55; nch=2; number=green_sec_LR_L; end
        end else if (!mode_adapt_sw && y>=lr_y+30 && y<lr_y+38) begin
            if (x>=37 && x<55) begin sel=ID_LR_R_L; x0=37; nch=2; end
            else if (x>=55 && x<73) begin sel=ID_LR_R_N; x0=55; nch=2; number=green_sec_LR_R; end
        end
    end

    wire [9:0] dx = x-x0;
    wire [3:0] ch_idx = dx/9;
    wire [3:0] ch_col = dx%9;
    wire [3:0] tens = number/10;
    wire [3:0] ones = number%10;
    reg [7:0] ascii;
    always @* begin
        ascii=8'h20;
        case (sel)
          ID_PEOPLE_L: case(ch_idx) 0:ascii="p";1:ascii="e";2:ascii="o";3:ascii="p";4:ascii="l";5:ascii="e";6:ascii=":";default:ascii=" ";endcase
          ID_LRCAR_L:  case(ch_idx) 0:ascii="L";1:ascii="R";2:ascii="C";3:ascii="a";4:ascii="r";5:ascii=":";default:ascii=" ";endcase
          ID_TBCAR_L:  case(ch_idx) 0:ascii="T";1:ascii="B";2:ascii="C";3:ascii="a";4:ascii="r";5:ascii=":";default:ascii=" ";endcase
          ID_SPEED_L:  case(ch_idx) 0:ascii="S";1:ascii="P";2:ascii="E";3:ascii="E";4:ascii="D";5:ascii=":";default:ascii=" ";endcase
          ID_TB_HEAD:  case(ch_idx) 0:ascii="T";1:ascii="B";2:ascii=":";default:ascii=" ";endcase
          ID_LR_HEAD:  case(ch_idx) 0:ascii="L";1:ascii="R";2:ascii=":";default:ascii=" ";endcase
          ID_TB_S_L,ID_LR_S_L: ascii=(ch_idx==0)?"S":":";
          ID_TB_L_L,ID_LR_L_L: ascii=(ch_idx==0)?"L":":";
          ID_TB_R_L,ID_LR_R_L: ascii=(ch_idx==0)?"R":":";
          ID_PEOPLE_N,ID_LRCAR_N,ID_TBCAR_N,ID_SPEED_N,
          ID_TB_S_N,ID_TB_L_N,ID_TB_R_N,ID_LR_S_N,ID_LR_L_N,ID_LR_R_N:
              ascii=8'h30+((ch_idx==0)?tens:ones);
          default: ascii=8'h20;
        endcase
    end
    wire [7:0] row_bits;
    font u_shared_font(.ascii(ascii),.row(y[2:0]),.bits(row_bits));
    wire pixel_on = (sel!=ID_NONE) && (ch_idx<nch) && (ch_col<8) && row_bits[7-ch_col[2:0]];

    assign people_on=0; assign carM_on=0; assign carS_on=0;
    assign people_label_on=pixel_on&&(sel==ID_PEOPLE_L); assign people_num_on=pixel_on&&(sel==ID_PEOPLE_N);
    assign lrcar_label_on=pixel_on&&(sel==ID_LRCAR_L); assign lrcar_num_on=pixel_on&&(sel==ID_LRCAR_N);
    assign tbcar_label_on=pixel_on&&(sel==ID_TBCAR_L); assign tbcar_num_on=pixel_on&&(sel==ID_TBCAR_N);
    assign speed_label_on=pixel_on&&(sel==ID_SPEED_L); assign speed_num_on=pixel_on&&(sel==ID_SPEED_N);
    assign tb_green_label_on=pixel_on&&(sel==ID_TB_HEAD);
    assign tb_s_label_on=pixel_on&&(sel==ID_TB_S_L); assign tb_s_num_on=pixel_on&&(sel==ID_TB_S_N);
    assign tb_l_label_on=pixel_on&&(sel==ID_TB_L_L); assign tb_l_num_on=pixel_on&&(sel==ID_TB_L_N);
    assign tb_r_label_on=pixel_on&&(sel==ID_TB_R_L); assign tb_r_num_on=pixel_on&&(sel==ID_TB_R_N);
    assign lr_green_label_on=pixel_on&&(sel==ID_LR_HEAD);
    assign lr_s_label_on=pixel_on&&(sel==ID_LR_S_L); assign lr_s_num_on=pixel_on&&(sel==ID_LR_S_N);
    assign lr_l_label_on=pixel_on&&(sel==ID_LR_L_L); assign lr_l_num_on=pixel_on&&(sel==ID_LR_L_N);
    assign lr_r_label_on=pixel_on&&(sel==ID_LR_R_L); assign lr_r_num_on=pixel_on&&(sel==ID_LR_R_N);
    assign cd_tb_s_num_on=0; assign cd_tb_l_num_on=0; assign cd_tb_r_num_on=0;
    assign cd_lr_s_num_on=0; assign cd_lr_l_num_on=0; assign cd_lr_r_num_on=0;
endmodule
