// mode_label.v - 左下角显示 "mode: adaptive" 或 "mode: fixed"
module mode_label #(
    parameter CHAR_W   = 8,
    parameter CHAR_H   = 8,
    parameter SPACE_W  = 1,      // 字间距（列）
    parameter SCREEN_W = 640,
    parameter SCREEN_H = 480,
    parameter PAD_X    = 8,      // 左边距
    parameter PAD_Y    = 8       // 下边距
)(
    input            pix_clk,
    input      [9:0] x,              // 当前像素 x
    input      [9:0] y,              // 当前像素 y
    input            adaptive_mode,  // 1=自适应，0=固定配时
    output           mode_on         // 该像素是否属于模式文字
);
    localparam BASE_X = PAD_X;
    localparam BASE_Y = SCREEN_H - CHAR_H - PAD_Y;

    // 统一最大长度 14（"mode: adaptive" 恰好 14）
    localparam integer LEN_MAX = 14;

    // 直接用打包字符串（注意：Verilog 字符串是高位在前）
    localparam [8*LEN_MAX-1:0] STR_AD_PACK = "mode: adaptive"; // 14
    localparam [8*LEN_MAX-1:0] STR_FX_PACK = "mode: fixed   "; // 11 + 3空格 = 14

    // 判定是否落在文字包围盒
    wire in_box = (x >= BASE_X) && (y >= BASE_Y) &&
                  (x <  BASE_X + LEN_MAX*(CHAR_W+SPACE_W)) &&
                  (y <  BASE_Y + CHAR_H);

    // 算出当前像素对应的字符/行/列
    wire [9:0] col_in_word = x - BASE_X;
    wire [9:0] dy          = y - BASE_Y;
    wire [2:0] row_in_char = dy[2:0];

    wire [3:0] ch_idx   = col_in_word / (CHAR_W + SPACE_W);            // 0..13
    wire [3:0] col_mod  = col_in_word % (CHAR_W + SPACE_W);            // 0..(W+SPACE-1)
    wire       in_space = (col_mod >= CHAR_W);                         // 第 8 列是空列
    wire [2:0] col_in_char = CHAR_W - 1 - col_mod[2:0];                // 仅在非空列有意义

    // 取第 idx 个字符（打包字符串是高位在前）
    function [7:0] get_char_from_pack;
        input [8*LEN_MAX-1:0] pack_str;
        input [3:0]            idx;   // 0..LEN_MAX-1
        integer                i;
        begin
            // 第 idx 个字符在位段：8*(LEN_MAX-1-idx)+:8
            get_char_from_pack = pack_str[8*(LEN_MAX-1-idx) +: 8];
        end
    endfunction

    // 选择当前字符 ASCII
    wire [7:0] ch_ascii = adaptive_mode
                        ? get_char_from_pack(STR_AD_PACK, ch_idx)
                        : get_char_from_pack(STR_FX_PACK, ch_idx);

    // 查字库得到该行 8bit 点阵
    wire [7:0] row_bits;
    font u_font(
        .ascii(ch_ascii),
        .row  (row_in_char),
        .bits (row_bits)
    );


    // 空列强制灭；其余按点阵取像素
    assign mode_on = in_box && !in_space ? row_bits[col_in_char] : 1'b0;

endmodule
