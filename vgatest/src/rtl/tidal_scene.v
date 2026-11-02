`timescale 1ns/1ps

// Five-lane road: two left lanes, one reversible lane, and two right lanes.
module tidal_scene(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [9:0]  left_car_x,
    input  wire [9:0]  right_car_x,
    input  wire [9:0]  tidal_car_x,
    input  wire [1:0]  left_level,
    input  wire [1:0]  right_level,
    input  wire [1:0]  tidal_dir,
    input  wire [1:0]  target_dir,
    input  wire [1:0]  tidal_state,
    input  wire        move_tick,
    input  wire        manual_lock,
    input  wire [1:0]  work_mode,
    input  wire [1:0]  tidal_vehicle_level,
    input  wire [3:0]  tidal_spawn_count,
    input  wire [10:0] tidal_close_phase,
    input  wire [9:0]  tidal_travel,
    input  wire [10:0] tidal_entry_phase,
    output reg  [15:0] pix_data
);
    localparam [1:0] TIDAL_OPEN  = 2'd0;
    localparam [1:0] TIDAL_DRAIN = 2'd1;
    localparam [1:0] TIDAL_PREWARN = 2'd3;
    localparam [1:0] DIR_LEFT    = 2'd1;
    localparam [1:0] DIR_RIGHT   = 2'd2;

    localparam [15:0] BACK       = 16'h0000;
    localparam [15:0] ROAD       = 16'h2945;
    localparam [15:0] WHITE      = 16'hFFFF;
    localparam [15:0] RED        = 16'hF800;
    localparam [15:0] GREEN      = 16'h07E0;
    localparam [15:0] CAR_RED    = 16'hF945;
    localparam [15:0] CAR_BLUE   = 16'h04DF;
    localparam [15:0] CAR_YELLOW = 16'hFEC0;
    localparam [15:0] CAR_GREEN  = 16'h2E67;
    localparam [15:0] GLASS      = 16'hBDF7;
    localparam [15:0] TYRE       = 16'h0000;

    localparam [9:0] ROAD_TOP = 10'd100;
    localparam [9:0] ROAD_BOT = 10'd360;
    localparam [9:0] LANE0_CY = 10'd126;
    localparam [9:0] LANE1_CY = 10'd178;
    localparam [9:0] TIDAL_CY = 10'd230;
    localparam [9:0] LANE3_CY = 10'd282;
    localparam [9:0] LANE4_CY = 10'd334;
    localparam integer CAR_W = 30;

    // Registered pixel coordinates match the one-cycle scene pipeline.
    reg [9:0] draw_x_r, draw_y_r;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            draw_x_r <= 10'd0;
            draw_y_r <= 10'd0;
        end else begin
            draw_x_r <= pix_x;
            draw_y_r <= pix_y;
        end
    end
    wire [9:0] draw_x = draw_x_r;
    wire [9:0] draw_y = draw_y_r;


    function [9:0] wrap640;
        input [11:0] value;
        begin
            if (value >= 12'd1280)
                wrap640 = value - 12'd1280;
            else if (value >= 12'd640)
                wrap640 = value - 12'd640;
            else
                wrap640 = value[9:0];
        end
    endfunction

    function [9:0] car_rx;
        input [9:0] start_x;
        input [9:0] sample_x;
        reg [10:0] wrapped_x;
        begin
            if (sample_x >= start_x)
                car_rx = sample_x - start_x;
            else begin
                wrapped_x = {1'b0,sample_x} + 11'd640 - {1'b0,start_x};
                car_rx = wrapped_x[9:0];
            end
        end
    endfunction

    function car_body_hit;
        input [9:0] start_x;
        input [9:0] center_y;
        input [9:0] sample_x;
        input [9:0] sample_y;
        reg [9:0] rx;
        reg [9:0] dy;
        begin
            rx = car_rx(start_x, sample_x);
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            car_body_hit = (rx < CAR_W) && (dy <= 10'd8) &&
                           !((rx < 10'd3 || rx >= 10'd27) && dy > 10'd5);
        end
    endfunction

    function car_glass_hit;
        input [9:0] start_x;
        input [9:0] center_y;
        input       faces_right;
        input [9:0] sample_x;
        input [9:0] sample_y;
        reg [9:0] rx;
        reg [9:0] dy;
        begin
            rx = car_rx(start_x, sample_x);
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            if (faces_right)
                car_glass_hit = (rx >= 10'd19) && (rx < 10'd24) && (dy <= 10'd5);
            else
                car_glass_hit = (rx >= 10'd6) && (rx < 10'd11) && (dy <= 10'd5);
        end
    endfunction

    function car_tyre_hit;
        input [9:0] start_x;
        input [9:0] center_y;
        input [9:0] sample_x;
        input [9:0] sample_y;
        reg [9:0] rx;
        reg [9:0] dy;
        begin
            rx = car_rx(start_x, sample_x);
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            car_tyre_hit = (dy >= 10'd7) && (dy <= 10'd8) &&
                           (((rx >= 10'd5) && (rx < 10'd10)) ||
                            ((rx >= 10'd20) && (rx < 10'd25)));
        end
    endfunction

    // Non-wrapping variants are used while the reversible lane drains. Once a
    // vehicle leaves the screen, it cannot re-enter from the opposite edge.
    function linear_body_hit;
        input integer start_x;
        input [9:0] center_y;
        input [9:0] sample_x;
        input [9:0] sample_y;
        integer rx;
        integer dy;
        begin
            rx = sample_x - start_x;
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            linear_body_hit = (rx >= 0) && (rx < CAR_W) && (dy <= 8) &&
                              !(((rx < 3) || (rx >= 27)) && (dy > 5));
        end
    endfunction

    function linear_glass_hit;
        input integer start_x;
        input [9:0] center_y;
        input       faces_right;
        input [9:0] sample_x;
        input [9:0] sample_y;
        integer rx;
        integer dy;
        begin
            rx = sample_x - start_x;
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            if (faces_right)
                linear_glass_hit = (rx >= 19) && (rx < 24) && (dy <= 5);
            else
                linear_glass_hit = (rx >= 6) && (rx < 11) && (dy <= 5);
        end
    endfunction

    function linear_tyre_hit;
        input integer start_x;
        input [9:0] center_y;
        input [9:0] sample_x;
        input [9:0] sample_y;
        integer rx;
        integer dy;
        begin
            rx = sample_x - start_x;
            dy = (sample_y >= center_y) ? (sample_y-center_y) : (center_y-sample_y);
            linear_tyre_hit = (dy >= 7) && (dy <= 8) &&
                              (((rx >= 5) && (rx < 10)) ||
                               ((rx >= 20) && (rx < 25)));
        end
    endfunction

    wire in_road = (draw_y >= ROAD_TOP) && (draw_y < ROAD_BOT);
    wire road_edge = ((draw_y >= ROAD_TOP) && (draw_y < ROAD_TOP+10'd3)) ||
                     ((draw_y >= ROAD_BOT-10'd3) && (draw_y < ROAD_BOT));
    wire dash_on = (draw_x[5:0] < 6'd30);
    wire normal_separator = (((draw_y >= 10'd151) && (draw_y < 10'd154)) ||
                             ((draw_y >= 10'd307) && (draw_y < 10'd310))) && dash_on;
    wire tidal_separator = ((draw_y >= 10'd202) && (draw_y < 10'd205)) ||
                           ((draw_y >= 10'd255) && (draw_y < 10'd258));
    wire tidal_separator_left  = (draw_y >= 10'd202) && (draw_y < 10'd205);
    wire tidal_separator_right = (draw_y >= 10'd255) && (draw_y < 10'd258);
    wire emergency_mode = (work_mode == 2'd3);
    wire tidal_changing = (tidal_state != TIDAL_OPEN) || emergency_mode;
    // Stable traffic marks only the boundary beside opposing traffic red.
    // Reversal and emergency states mark both boundaries red.
    wire tidal_barrier = tidal_changing ? tidal_separator :
                         ((tidal_dir == DIR_LEFT) ? tidal_separator_right :
                                                     tidal_separator_left);

    // During reversal, target_dir identifies the next entrance. The left
    // entrance flashes an up arrow, the right entrance flashes a down arrow,
    // and the side that must remain closed shows an X.
    wire signals_open = (tidal_state == TIDAL_OPEN) && !emergency_mode;
    wire reversing = (tidal_state != TIDAL_OPEN) && !emergency_mode;
    reg [4:0] signal_blink_count;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            signal_blink_count <= 5'd0;
        else if (!reversing)
            signal_blink_count <= 5'd0;
        else if (move_tick)
            signal_blink_count <= signal_blink_count + 1'b1;
    end
    wire transition_arrow_on = ~signal_blink_count[3];
    wire left_allowed = (signals_open && (tidal_dir == DIR_RIGHT)) ||
                        (reversing && (target_dir == DIR_RIGHT));
    wire right_allowed = (signals_open && (tidal_dir == DIR_LEFT)) ||
                         (reversing && (target_dir == DIR_LEFT));
    wire left_box = (draw_x >= 10'd8) && (draw_x < 10'd25) &&
                    (draw_y >= 10'd208) && (draw_y < 10'd225);
    wire right_box = (draw_x >= 10'd615) && (draw_x < 10'd632) &&
                     (draw_y >= 10'd208) && (draw_y < 10'd225);
    wire signal_border = (left_box && ((draw_x==10'd8)||(draw_x==10'd24)||(draw_y==10'd208)||(draw_y==10'd224))) ||
                         (right_box && ((draw_x==10'd615)||(draw_x==10'd631)||(draw_y==10'd208)||(draw_y==10'd224)));
    wire [4:0] left_sx = draw_x - 10'd9;
    wire [4:0] right_sx = draw_x - 10'd616;
    wire [4:0] signal_sy = draw_y - 10'd209;
    wire left_red_x = left_box && !left_allowed &&
                      ((left_sx == signal_sy) || (left_sx + signal_sy == 5'd14));
    wire right_red_x = right_box && !right_allowed &&
                       ((right_sx == signal_sy) || (right_sx + signal_sy == 5'd14));
    wire left_flow_arrow = signals_open && left_allowed &&
        (((draw_x>=10'd11)&&(draw_x<=10'd19)&&(draw_y>=10'd215)&&(draw_y<=10'd217)) ||
         ((draw_x>=10'd18)&&(draw_x<=10'd22) &&
          (draw_y>=10'd216-(10'd22-draw_x)) && (draw_y<=10'd216+(10'd22-draw_x))));
    wire right_flow_arrow = signals_open && right_allowed &&
        (((draw_x>=10'd621)&&(draw_x<=10'd629)&&(draw_y>=10'd215)&&(draw_y<=10'd217)) ||
         ((draw_x>=10'd617)&&(draw_x<=10'd621) &&
          (draw_y>=10'd216-(draw_x-10'd617)) && (draw_y<=10'd216+(draw_x-10'd617))));
    wire left_up_arrow = reversing && transition_arrow_on && left_allowed && left_box &&
        (((left_sx>=5'd6)&&(left_sx<=5'd8)&&(signal_sy>=5'd6)&&(signal_sy<=5'd13)) ||
         ((signal_sy>=5'd1)&&(signal_sy<=5'd6) &&
          (left_sx>=5'd8-signal_sy)&&(left_sx<=5'd6+signal_sy)));
    wire right_down_arrow = reversing && transition_arrow_on && right_allowed && right_box &&
        (((right_sx>=5'd6)&&(right_sx<=5'd8)&&(signal_sy>=5'd2)&&(signal_sy<=5'd9)) ||
         ((signal_sy>=5'd8)&&(signal_sy<=5'd13) &&
          (right_sx>=signal_sy-5'd6)&&(right_sx<=5'd20-signal_sy)));
    wire left_green_arrow = left_flow_arrow || left_up_arrow;
    wire right_green_arrow = right_flow_arrow || right_down_arrow;

    integer i;
    integer active_left, active_right, active_tidal;
    integer spacing_left, spacing_right, spacing_tidal;
    integer tidal_start_linear;
    reg [11:0] phase_value;
    reg [9:0] start_x;
    reg hit_left_body, hit_left_glass, hit_left_tyre;
    reg hit_right_body, hit_right_glass, hit_right_tyre;
    reg hit_tidal_body, hit_tidal_glass, hit_tidal_tyre;

    // Live traffic status: L:3S:60 R:3S:60 T:3S:60.
    wire status_area = (draw_x >= 10'd16) && (draw_x < 10'd200) &&
                       (draw_y >= 10'd16) && (draw_y < 10'd24);
    wire [4:0] status_slot = (draw_x - 10'd16) >> 3;
    wire [2:0] status_row = draw_y - 10'd16;
    reg [7:0] status_ascii;
    wire [7:0] status_bits;
    reg [3:0] left_count_digit;
    reg [3:0] right_count_digit;
    reg [3:0] tidal_count_digit;
    reg [7:0] left_speed;
    reg [7:0] right_speed;
    reg [7:0] tidal_speed;
    always @* begin
        left_count_digit = (left_level == 2'd0) ? 4'd3 :
                           (left_level == 2'd2) ? 4'd6 : 4'd4;
        right_count_digit = (right_level == 2'd0) ? 4'd3 :
                            (right_level == 2'd2) ? 4'd6 : 4'd4;
        tidal_count_digit = (tidal_vehicle_level == 2'd0) ? 4'd3 :
                            (tidal_vehicle_level == 2'd2) ? 4'd6 : 4'd4;
        left_speed = (left_level == 2'd0) ? 8'd60 :
                     (left_level == 2'd2) ? 8'd35 : 8'd40;
        right_speed = (right_level == 2'd0) ? 8'd60 :
                      (right_level == 2'd2) ? 8'd35 : 8'd40;
        tidal_speed = (tidal_vehicle_level == 2'd0) ? 8'd60 :
                      (tidal_vehicle_level == 2'd2) ? 8'd35 : 8'd40;
        case (status_slot)
            5'd0: status_ascii = 8'h4C;
            5'd1: status_ascii = 8'h3A;
            5'd2: status_ascii = 8'h30 + left_count_digit;
            5'd3: status_ascii = 8'h53;
            5'd4: status_ascii = 8'h3A;
            5'd5: status_ascii = 8'h30 + (left_speed / 10);
            5'd6: status_ascii = 8'h30 + (left_speed % 10);
            5'd8: status_ascii = 8'h52;
            5'd9: status_ascii = 8'h3A;
            5'd10: status_ascii = 8'h30 + right_count_digit;
            5'd11: status_ascii = 8'h53;
            5'd12: status_ascii = 8'h3A;
            5'd13: status_ascii = 8'h30 + (right_speed / 10);
            5'd14: status_ascii = 8'h30 + (right_speed % 10);
            5'd16: status_ascii = 8'h54;
            5'd17: status_ascii = 8'h3A;
            5'd18: status_ascii = 8'h30 + tidal_count_digit;
            5'd19: status_ascii = 8'h53;
            5'd20: status_ascii = 8'h3A;
            5'd21: status_ascii = 8'h30 + (tidal_speed / 10);
            5'd22: status_ascii = 8'h30 + (tidal_speed % 10);
            default: status_ascii = 8'h20;
        endcase
    end
    font u_status_font(.ascii(status_ascii), .row(status_row), .bits(status_bits));
    wire status_on = status_area && status_bits[7-(draw_x[2:0])];

    // Keep direction, lock and operating-mode diagnostics on a second line.
    wire system_status_area = (draw_x >= 10'd16) && (draw_x < 10'd112) &&
                              (draw_y >= 10'd28) && (draw_y < 10'd36);
    wire [3:0] system_status_slot = (draw_x - 10'd16) >> 3;
    wire [2:0] system_status_row = draw_y - 10'd28;
    reg [7:0] system_status_ascii;
    wire [7:0] system_status_bits;
    always @* begin
        case (system_status_slot)
            4'd0: system_status_ascii = 8'h54;
            4'd1: system_status_ascii = 8'h3A;
            4'd2: system_status_ascii = (tidal_state != TIDAL_OPEN || emergency_mode) ? 8'h43 :
                                        (tidal_dir == DIR_RIGHT) ? 8'h52 : 8'h4C;
            4'd4: system_status_ascii = 8'h4B;
            4'd5: system_status_ascii = 8'h3A;
            4'd6: system_status_ascii = manual_lock ? 8'h31 : 8'h30;
            4'd8: system_status_ascii = 8'h4D;
            4'd9: system_status_ascii = 8'h3A;
            4'd10: system_status_ascii = (work_mode == 2'd1) ? 8'h41 :
                                         (work_mode == 2'd2) ? 8'h50 :
                                         (work_mode == 2'd3) ? 8'h45 : 8'h53;
            default: system_status_ascii = 8'h20;
        endcase
    end
    font u_system_status_font(.ascii(system_status_ascii),
                              .row(system_status_row), .bits(system_status_bits));
    wire system_status_on = system_status_area &&
                            system_status_bits[7-(draw_x[2:0])];

    // Page title: TIDAL LANE, rendered at 2x size for board readability.
    wire tidal_title_area = (draw_x >= 10'd240) && (draw_x < 10'd400) &&
                            (draw_y >= 10'd48) && (draw_y < 10'd64);
    wire [3:0] tidal_title_slot = (draw_x - 10'd240) >> 4;
    wire [2:0] tidal_title_row = (draw_y - 10'd48) >> 1;
    wire [2:0] tidal_title_col = (draw_x - 10'd240) >> 1;
    reg [7:0] tidal_title_ascii;
    wire [7:0] tidal_title_bits;
    always @* begin
        case (tidal_title_slot)
            4'd0: tidal_title_ascii = 8'h54; // T
            4'd1: tidal_title_ascii = 8'h49; // I
            4'd2: tidal_title_ascii = 8'h44; // D
            4'd3: tidal_title_ascii = 8'h41; // A
            4'd4: tidal_title_ascii = 8'h4C; // L
            4'd6: tidal_title_ascii = 8'h4C; // L
            4'd7: tidal_title_ascii = 8'h41; // A
            4'd8: tidal_title_ascii = 8'h4E; // N
            4'd9: tidal_title_ascii = 8'h45; // E
            default: tidal_title_ascii = 8'h20;
        endcase
    end
    font u_tidal_title_font(.ascii(tidal_title_ascii),
                            .row(tidal_title_row), .bits(tidal_title_bits));
    wire tidal_title_on = tidal_title_area &&
                          tidal_title_bits[7-tidal_title_col];

    // Four roadside speed-limit signs at the positions marked in the photo:
    // left-flow entry, both tidal-lane entries, and right-flow entry.
    wire left_speed_sign = (draw_x >= 10'd600) && (draw_x < 10'd632) &&
                           (draw_y >= 10'd60) && (draw_y < 10'd80);
    wire tidal_left_speed_sign = (draw_x >= 10'd8) && (draw_x < 10'd40) &&
                                 (draw_y >= 10'd232) && (draw_y < 10'd252);
    wire tidal_right_speed_sign = (draw_x >= 10'd600) && (draw_x < 10'd632) &&
                                  (draw_y >= 10'd232) && (draw_y < 10'd252);
    wire right_speed_sign = (draw_x >= 10'd8) && (draw_x < 10'd40) &&
                            (draw_y >= 10'd400) && (draw_y < 10'd420);
    wire speed_sign_area = left_speed_sign || tidal_left_speed_sign ||
                           tidal_right_speed_sign || right_speed_sign;
    wire hide_tidal_speed = emergency_mode &&
                            (tidal_left_speed_sign || tidal_right_speed_sign);
    reg [9:0] speed_sign_x0;
    reg [9:0] speed_sign_y0;
    reg [7:0] roadside_speed;
    always @* begin
        speed_sign_x0 = 10'd0;
        speed_sign_y0 = 10'd0;
        roadside_speed = 8'd0;
        if (left_speed_sign) begin
            speed_sign_x0 = 10'd600;
            speed_sign_y0 = 10'd60;
            roadside_speed = left_speed;
        end else if (tidal_left_speed_sign) begin
            speed_sign_x0 = 10'd8;
            speed_sign_y0 = 10'd232;
            roadside_speed = tidal_speed;
        end else if (tidal_right_speed_sign) begin
            speed_sign_x0 = 10'd600;
            speed_sign_y0 = 10'd232;
            roadside_speed = tidal_speed;
        end else if (right_speed_sign) begin
            speed_sign_x0 = 10'd8;
            speed_sign_y0 = 10'd400;
            roadside_speed = right_speed;
        end
    end
    wire speed_sign_border = speed_sign_area &&
        (((draw_x - speed_sign_x0) < 10'd2) ||
         ((draw_x - speed_sign_x0) >= 10'd30) ||
         ((draw_y - speed_sign_y0) < 10'd2) ||
         ((draw_y - speed_sign_y0) >= 10'd18));
    wire speed_sign_digit_area = speed_sign_area &&
        (draw_x >= speed_sign_x0 + 10'd8) &&
        (draw_x <  speed_sign_x0 + 10'd24) &&
        (draw_y >= speed_sign_y0 + 10'd6) &&
        (draw_y <  speed_sign_y0 + 10'd14);
    wire speed_sign_ones = (draw_x >= speed_sign_x0 + 10'd16);
    wire [7:0] speed_sign_ascii = speed_sign_ones ?
        (8'h30 + (roadside_speed % 10)) : (8'h30 + (roadside_speed / 10));
    wire [2:0] speed_sign_row = draw_y - speed_sign_y0 - 10'd6;
    wire [7:0] speed_sign_bits;
    font u_speed_sign_font(.ascii(speed_sign_ascii),
                           .row(speed_sign_row), .bits(speed_sign_bits));
    wire speed_sign_digit_on = speed_sign_digit_area &&
                               speed_sign_bits[7-draw_x[2:0]];

    // The normal 32-pixel speed signs are widened only in emergency mode so
    // the full nine-letter warning fits in both formerly empty black boxes.
    wire emergency_left_box = emergency_mode &&
                              (draw_x >= 10'd8) && (draw_x < 10'd48) &&
                              (draw_y >= 10'd232) && (draw_y < 10'd252);
    wire emergency_right_box = emergency_mode &&
                               (draw_x >= 10'd592) && (draw_x < 10'd632) &&
                               (draw_y >= 10'd232) && (draw_y < 10'd252);
    wire emergency_box = emergency_left_box || emergency_right_box;
    wire [9:0] emergency_x0 = emergency_left_box ? 10'd8 : 10'd592;
    wire [5:0] emergency_text_x = draw_x - emergency_x0 - 10'd2;
    wire [3:0] emergency_char = emergency_text_x >> 2;
    wire [1:0] emergency_col = emergency_text_x[1:0];
    wire [2:0] emergency_row = (draw_y - 10'd237) >> 1;

    function emergency_glyph_pixel;
        input [3:0] char_index;
        input [1:0] col;
        input [2:0] row;
        reg [2:0] row_bits;
        begin
            row_bits = 3'b000;
            case (char_index)
                4'd0, 4'd2, 4'd5: begin // E
                    case (row)
                        3'd0, 3'd2, 3'd4: row_bits = 3'b111;
                        default:          row_bits = 3'b100;
                    endcase
                end
                4'd1: begin // M
                    case (row)
                        3'd0:    row_bits = 3'b101;
                        3'd1:    row_bits = 3'b111;
                        default: row_bits = 3'b101;
                    endcase
                end
                4'd3: begin // R
                    case (row)
                        3'd0, 3'd2: row_bits = 3'b110;
                        3'd1:       row_bits = 3'b101;
                        3'd3:       row_bits = 3'b110;
                        default:    row_bits = 3'b101;
                    endcase
                end
                4'd4: begin // G
                    case (row)
                        3'd0:       row_bits = 3'b111;
                        3'd1:       row_bits = 3'b100;
                        3'd2:       row_bits = 3'b101;
                        3'd3:       row_bits = 3'b101;
                        default:    row_bits = 3'b111;
                    endcase
                end
                4'd6: begin // N
                    case (row)
                        3'd0, 3'd1: row_bits = 3'b110;
                        3'd2:       row_bits = 3'b111;
                        default:    row_bits = 3'b011;
                    endcase
                end
                4'd7: begin // C
                    case (row)
                        3'd0, 3'd4: row_bits = 3'b111;
                        default:    row_bits = 3'b100;
                    endcase
                end
                4'd8: begin // Y
                    case (row)
                        3'd0:       row_bits = 3'b101;
                        3'd1:       row_bits = 3'b101;
                        default:    row_bits = 3'b010;
                    endcase
                end
                default: row_bits = 3'b000;
            endcase
            if (col < 2'd3)
                emergency_glyph_pixel = row_bits[2-col];
            else
                emergency_glyph_pixel = 1'b0;
        end
    endfunction
    wire emergency_text_on = emergency_box &&
                             (draw_x >= emergency_x0 + 10'd2) &&
                             (draw_x < emergency_x0 + 10'd38) &&
                             (draw_y >= 10'd237) && (draw_y < 10'd247) &&
                             emergency_glyph_pixel(emergency_char,
                                                   emergency_col,
                                                   emergency_row);

    always @* begin
        case (left_level)
            2'd0: begin active_left = 3; spacing_left = 213; end
            2'd2: begin active_left = 6; spacing_left = 106; end
            default: begin active_left = 4; spacing_left = 160; end
        endcase
        case (right_level)
            2'd0: begin active_right = 3; spacing_right = 213; end
            2'd2: begin active_right = 6; spacing_right = 106; end
            default: begin active_right = 4; spacing_right = 160; end
        endcase
        case (tidal_vehicle_level)
            2'd0: begin active_tidal = 3; spacing_tidal = 213; end
            2'd2: begin active_tidal = 6; spacing_tidal = 106; end
            default: begin active_tidal = 4; spacing_tidal = 160; end
        endcase
        hit_left_body   = 1'b0;
        hit_left_glass  = 1'b0;
        hit_left_tyre   = 1'b0;
        hit_right_body  = 1'b0;
        hit_right_glass = 1'b0;
        hit_right_tyre  = 1'b0;
        hit_tidal_body  = 1'b0;
        hit_tidal_glass = 1'b0;
        hit_tidal_tyre  = 1'b0;
        phase_value = 12'd0;
        start_x = 10'd0;
        tidal_start_linear = 0;

        for (i=0; i<6; i=i+1) begin
            if (i < active_left) begin
                phase_value = 12'd640 - {2'b00,left_car_x} + i*spacing_left;
                start_x = wrap640(phase_value);
                hit_left_body  = hit_left_body  | car_body_hit(start_x, LANE0_CY, draw_x, draw_y);
                hit_left_glass = hit_left_glass | car_glass_hit(start_x, LANE0_CY, 1'b0, draw_x, draw_y);
                hit_left_tyre  = hit_left_tyre  | car_tyre_hit(start_x, LANE0_CY, draw_x, draw_y);
                start_x = wrap640(phase_value + (spacing_left >> 1));
                hit_left_body  = hit_left_body  | car_body_hit(start_x, LANE1_CY, draw_x, draw_y);
                hit_left_glass = hit_left_glass | car_glass_hit(start_x, LANE1_CY, 1'b0, draw_x, draw_y);
                hit_left_tyre  = hit_left_tyre  | car_tyre_hit(start_x, LANE1_CY, draw_x, draw_y);
            end

            if (i < active_right) begin
                phase_value = {2'b00,right_car_x} + i*spacing_right + 12'd53;
                start_x = wrap640(phase_value);
                hit_right_body  = hit_right_body  | car_body_hit(start_x, LANE3_CY, draw_x, draw_y);
                hit_right_glass = hit_right_glass | car_glass_hit(start_x, LANE3_CY, 1'b1, draw_x, draw_y);
                hit_right_tyre  = hit_right_tyre  | car_tyre_hit(start_x, LANE3_CY, draw_x, draw_y);
                start_x = wrap640(phase_value + (spacing_right >> 1));
                hit_right_body  = hit_right_body  | car_body_hit(start_x, LANE4_CY, draw_x, draw_y);
                hit_right_glass = hit_right_glass | car_glass_hit(start_x, LANE4_CY, 1'b1, draw_x, draw_y);
                hit_right_tyre  = hit_right_tyre  | car_tyre_hit(start_x, LANE4_CY, draw_x, draw_y);
            end

            if (i < active_tidal) begin
                if (tidal_state == TIDAL_OPEN && !emergency_mode) begin
                    if (tidal_dir == DIR_LEFT)
                        phase_value = 12'd640 - {2'b00,tidal_car_x} + i*spacing_tidal + 12'd80;
                    else
                        phase_value = {2'b00,tidal_car_x} + i*spacing_tidal + 12'd80;
                    start_x = wrap640(phase_value);
                    hit_tidal_body  = hit_tidal_body | car_body_hit(start_x,
                                               TIDAL_CY, draw_x, draw_y);
                    hit_tidal_glass = hit_tidal_glass | car_glass_hit(start_x,
                                               TIDAL_CY, (tidal_dir == DIR_RIGHT), draw_x, draw_y);
                    hit_tidal_tyre  = hit_tidal_tyre | car_tyre_hit(start_x,
                                               TIDAL_CY, draw_x, draw_y);
                end else if (tidal_state == TIDAL_PREWARN && !emergency_mode) begin
                    tidal_start_linear = (tidal_dir == DIR_LEFT) ?
                                         (640 - tidal_entry_phase + i*spacing_tidal) :
                                         (-30 + tidal_entry_phase - i*spacing_tidal);
                    hit_tidal_body  = hit_tidal_body  | linear_body_hit(tidal_start_linear,
                                               TIDAL_CY, draw_x, draw_y);
                    hit_tidal_glass = hit_tidal_glass | linear_glass_hit(tidal_start_linear,
                                               TIDAL_CY, (tidal_dir == DIR_RIGHT), draw_x, draw_y);
                    hit_tidal_tyre  = hit_tidal_tyre  | linear_tyre_hit(tidal_start_linear,
                                               TIDAL_CY, draw_x, draw_y);
                end else if (tidal_state == TIDAL_DRAIN) begin
                    if (tidal_dir == DIR_LEFT) begin
                        tidal_start_linear = 640 - tidal_close_phase + i*spacing_tidal - tidal_travel;
                    end else begin
                        tidal_start_linear = -30 + tidal_close_phase - i*spacing_tidal + tidal_travel;
                    end
                    hit_tidal_body  = hit_tidal_body | linear_body_hit(tidal_start_linear,
                                               TIDAL_CY, draw_x, draw_y);
                    hit_tidal_glass = hit_tidal_glass | linear_glass_hit(tidal_start_linear,
                                               TIDAL_CY, (tidal_dir == DIR_RIGHT), draw_x, draw_y);
                    hit_tidal_tyre  = hit_tidal_tyre | linear_tyre_hit(tidal_start_linear,
                                               TIDAL_CY, draw_x, draw_y);
                end
            end
        end
    end

    always @* begin
        pix_data = in_road ? ROAD : BACK;
        if (road_edge || normal_separator || tidal_separator)
            pix_data = WHITE;
        if (tidal_barrier)
            pix_data = RED;
        if (hit_left_body)
            pix_data = CAR_RED;
        if (hit_right_body)
            pix_data = CAR_BLUE;
        if (hit_tidal_body)
            pix_data = (tidal_dir == DIR_LEFT) ? CAR_YELLOW : CAR_GREEN;
        if (hit_left_glass || hit_right_glass || hit_tidal_glass)
            pix_data = GLASS;
        if (hit_left_tyre || hit_right_tyre || hit_tidal_tyre)
            pix_data = TYRE;

        if (signal_border)
            pix_data = WHITE;
        if (left_red_x || right_red_x)
            pix_data = RED;
        if (left_green_arrow || right_green_arrow)
            pix_data = GREEN;
        if (status_on)
            pix_data = WHITE;
        if (system_status_on)
            pix_data = WHITE;
        if (tidal_title_on)
            pix_data = GREEN;
        if (speed_sign_area)
            pix_data = BACK;
        if (emergency_box)
            pix_data = BACK;
        if (speed_sign_border && !hide_tidal_speed)
            pix_data = RED;
        if (speed_sign_digit_on && !hide_tidal_speed)
            pix_data = WHITE;
        if (emergency_text_on)
            pix_data = WHITE;
    end

    wire unused_inputs = vga_clk ^ sys_rst_n;
endmodule

// Compact third page: green-wave styling with one widened horizontal lane.
module single_lane_scene(
    input wire vga_clk, input wire sys_rst_n,
    input wire [9:0] pix_x, input wire [9:0] pix_y,
    input wire move_tick, input wire enable,
    input wire [2:0] speed_select,
    input wire [7:0] rom_index,
    output wire [9:0] car_x_out,
    output wire [9:0] sim_time_out,
    output wire       waiting_out,
    output wire [2:0] light_bits_out,
    output reg [15:0] pix_data
);
    localparam [15:0] BACK=16'h0000, ROAD=16'h2945, WHITE=16'hFFFF;
    localparam [15:0] RED=16'hF800, GREEN=16'h07E0, DIM=16'h0841;
    localparam [15:0] GLASS=16'hBDF7, LANE=16'h46AE;
    reg [9:0] x, y;
    reg [9:0] sim_time;
    reg [17:0] car_q8;
    reg [2:0] speed_select_d;
    reg car_visible;
    wire [9:0] car_x=car_q8[17:8];
    assign car_x_out = car_x;
    assign sim_time_out = sim_time;
    wire [15:0] car_color = (speed_select==3'd0) ? 16'hA145 : // 35: brown
                              (speed_select==3'd1) ? 16'hFA20 : // 40: orange red
                              (speed_select==3'd2) ? 16'h8010 : // 45: purple
                              (speed_select==3'd3) ? 16'h05FF : // 50: deep sky blue
                              (speed_select==3'd4) ? 16'h1C9F : // 55: dodger blue
                                                        16'h001F;  // 60: blue

    // Each speed has an independent repeatable trajectory. The scheduled
    // holds reproduce the requested red-light encounters while all signals
    // continue to follow the common 100-tick cycle.
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            x<=0; y<=0; sim_time<=0; car_q8<=18'd0;
            speed_select_d<=3'd0;
            car_visible<=1'b0;
        end
        else begin
            x<=pix_x; y<=pix_y;
            speed_select_d<=speed_select;
            if (!enable || (speed_select != speed_select_d)) begin
                sim_time<=0;
                car_q8<=18'd0;
                car_visible<=1'b0;
            end
            else if (move_tick) begin
                case(speed_select)
                  3'd0: begin // 35: red 2 at J1, green 3 at J2, red 4 at J3
                    if(sim_time>=10'd679) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      if(sim_time<10'd6) begin car_q8<=18'd0; car_visible<=1'b0; end
                      else if(sim_time<10'd169) begin car_q8<=car_q8+18'd190; car_visible<=1'b1; end
                      else if(sim_time==10'd169) car_q8<=(18'd121<<8);
                      else if(sim_time<10'd199) car_q8<=car_q8;
                      else if(sim_time<10'd274) car_q8<=car_q8+18'd546;
                      else if(sim_time==10'd274) car_q8<=(18'd281<<8);
                      else if(sim_time<10'd369) car_q8<=car_q8+18'd431;
                      else if(sim_time==10'd369) car_q8<=(18'd441<<8);
                      else if(sim_time<10'd399) car_q8<=car_q8;
                      else car_q8<=car_q8+18'd190;
                    end
                  end
                  3'd1: begin // 40: green 2 at J1, red 3 at J2, green 4 at J3
                    if(sim_time>=10'd549) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      if(sim_time<10'd7) begin car_q8<=18'd0; car_visible<=1'b0; end
                      else if(sim_time<10'd129) begin car_q8<=car_q8+18'd254; car_visible<=1'b1; end
                      else if(sim_time==10'd129) car_q8<=(18'd121<<8);
                      else if(sim_time<10'd219) car_q8<=car_q8+18'd455;
                      else if(sim_time==10'd219) car_q8<=(18'd281<<8);
                      else if(sim_time<10'd249) car_q8<=car_q8;
                      else if(sim_time<10'd329) car_q8<=car_q8+18'd512;
                      else if(sim_time==10'd329) car_q8<=(18'd441<<8);
                      else car_q8<=car_q8+18'd254;
                    end
                  end
                  3'd2: begin // 45: J3 crosses at the end of green 4
                    if(sim_time>=10'd519) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      if(sim_time<10'd27) begin car_q8<=18'd0; car_visible<=1'b0; end
                      else if(sim_time<10'd124) begin car_q8<=car_q8+18'd319; car_visible<=1'b1; end
                      else if(sim_time==10'd124) car_q8<=(18'd123<<8);
                      else if(sim_time<10'd189) car_q8<=car_q8+18'd630;
                      else if(sim_time==10'd189) car_q8<=(18'd283<<8);
                      else if(sim_time<10'd348) car_q8<=car_q8+18'd258;
                      else if(sim_time==10'd348) car_q8<=(18'd443<<8);
                      else car_q8<=car_q8+18'd319;
                    end
                  end
                  3'd3: begin // 50: green 2, green 2, green 3
                    if(sim_time>=10'd369) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      if(sim_time<10'd38) begin car_q8<=18'd0; car_visible<=1'b0; end
                      else if(sim_time<10'd119) begin car_q8<=car_q8+18'd382; car_visible<=1'b1; end
                      else if(sim_time==10'd119) car_q8<=(18'd123<<8);
                      else if(sim_time<10'd169) car_q8<=car_q8+18'd819;
                      else if(sim_time==10'd169) car_q8<=(18'd283<<8);
                      else if(sim_time<10'd219) car_q8<=car_q8+18'd819;
                      else if(sim_time==10'd219) car_q8<=(18'd443<<8);
                      else car_q8<=car_q8+18'd382;
                    end
                  end
                  3'd4: begin // 55: red 1, red 2, red 2
                    if(sim_time>=10'd329) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      car_visible<=1'b1;
                      if(sim_time<10'd69) car_q8<=car_q8+18'd449;
                      else if(sim_time==10'd69) car_q8<=(18'd121<<8);
                      else if(sim_time<10'd99) car_q8<=car_q8;
                      else if(sim_time<10'd124) car_q8<=car_q8+18'd1638;
                      else if(sim_time==10'd124) car_q8<=(18'd281<<8);
                      else if(sim_time<10'd149) car_q8<=car_q8;
                      else if(sim_time<10'd174) car_q8<=car_q8+18'd1638;
                      else if(sim_time==10'd174) car_q8<=(18'd441<<8);
                      else if(sim_time<10'd199) car_q8<=car_q8;
                      else car_q8<=car_q8+18'd449;
                    end
                  end
                  default: begin // 60: reaches every red stop before 55
                    if(sim_time>=10'd309) begin sim_time<=0; car_q8<=18'd0; car_visible<=1'b0; end
                    else begin
                      sim_time<=sim_time+1'b1;
                      car_visible<=1'b1;
                      if(sim_time<10'd59) car_q8<=car_q8+18'd525;
                      else if(sim_time==10'd59) car_q8<=(18'd121<<8);
                      else if(sim_time<10'd99) car_q8<=car_q8;
                      else if(sim_time<10'd119) car_q8<=car_q8+18'd2048;
                      else if(sim_time==10'd119) car_q8<=(18'd281<<8);
                      else if(sim_time<10'd149) car_q8<=car_q8;
                      else if(sim_time<10'd164) car_q8<=car_q8+18'd2731;
                      else if(sim_time==10'd164) car_q8<=(18'd441<<8);
                      else if(sim_time<10'd199) car_q8<=car_q8;
                      else car_q8<=car_q8+18'd525;
                    end
                  end
                endcase
            end
        end
    end
    wire [6:0] phase=sim_time%10'd100;
    wire sig13_green=phase<7'd50;
    wire sig2_green=phase>=7'd50;
    assign light_bits_out = {sig13_green, sig2_green, sig13_green};
    assign waiting_out = car_visible &&
        (((car_x >= 10'd118) && (car_x <= 10'd124) && !sig13_green) ||
         ((car_x >= 10'd278) && (car_x <= 10'd284) && !sig2_green) ||
         ((car_x >= 10'd438) && (car_x <= 10'd444) && !sig13_green));
    wire sig1=(x>=10'd112)&&(x<10'd146)&&(y>=10'd52)&&(y<10'd70);
    wire sig2=(x>=10'd272)&&(x<10'd306)&&(y>=10'd52)&&(y<10'd70);
    wire sig3=(x>=10'd432)&&(x<10'd466)&&(y>=10'd52)&&(y<10'd70);
    wire sigbox=sig1||sig2||sig3;
    wire [9:0] sigx=sig1?10'd112:(sig2?10'd272:10'd432);
    wire sigborder=sigbox&&((x==sigx)||(x==sigx+10'd33)||(y==10'd52)||(y==10'd69));
    wire redlamp=sigbox&&(x>=sigx+10'd3)&&(x<sigx+10'd11)&&(y>=10'd57)&&(y<10'd65);
    wire greenlamp=sigbox&&(x>=sigx+10'd23)&&(x<sigx+10'd31)&&(y>=10'd57)&&(y<10'd65);
    wire road=(y>=10'd90)&&(y<10'd162);
    wire road_edge_single=((y>=10'd90)&&(y<10'd94))||
                          ((y>=10'd158)&&(y<10'd162));
    wire c1=(x>=10'd150)&&(x<10'd210)&&(y>=10'd80)&&(y<10'd400);
    wire c2=(x>=10'd310)&&(x<10'd370)&&(y>=10'd80)&&(y<10'd400);
    wire c3=(x>=10'd470)&&(x<10'd530)&&(y>=10'd80)&&(y<10'd400);
    wire cross_edge=(((x>=10'd150)&&(x<10'd153))||((x>=10'd207)&&(x<10'd210))||
                     ((x>=10'd310)&&(x<10'd313))||((x>=10'd367)&&(x<10'd370))||
                     ((x>=10'd470)&&(x<10'd473))||((x>=10'd527)&&(x<10'd530)))&&
                     ((y<10'd90)||(y>=10'd162));
    wire stops=(((x>=10'd150)&&(x<10'd153))||((x>=10'd207)&&(x<10'd210))||
                ((x>=10'd310)&&(x<10'd313))||((x>=10'd367)&&(x<10'd370))||
                ((x>=10'd470)&&(x<10'd473))||((x>=10'd527)&&(x<10'd530)))&&road;
    wire body=car_visible&&(x>=car_x)&&(x<car_x+10'd28)&&
              (y>=10'd118)&&(y<10'd134);
    wire glass=car_visible&&(x>=car_x+10'd17)&&(x<car_x+10'd23)&&
               (y>=10'd121)&&(y<10'd131);
    wire title=(x>=10'd200)&&(x<10'd440)&&(y>=10'd2)&&(y<10'd18);
    wire filter_label=(x>=10'd16)&&(x<10'd160)&&(y>=10'd24)&&(y<10'd32);
    wire speed=(x>=10'd208)&&(x<10'd432)&&(y>=10'd20)&&(y<10'd36);
    reg [7:0] title_ascii, filter_ascii, speed_ascii;
    wire [7:0] title_bits, filter_bits, speed_bits;
    wire [2:0] single_title_row = (y - 10'd2) >> 1;
    wire [3:0] single_title_slot = (x - 10'd200) >> 4;
    wire [2:0] single_title_col = (x - 10'd200) >> 1;
    wire [2:0] filter_row = y - 10'd24;
    wire [4:0] filter_slot = (x - 10'd16) >> 3;
    wire [2:0] single_speed_row = (y - 10'd20) >> 1;
    wire [3:0] speed_slot = (x - 10'd208) >> 4;
    wire [2:0] speed_col = (x - 10'd208) >> 1;
    reg [7:0] speed_tens, speed_ones;
    reg [15:0] photo_rgb;
    // 424x318 keeps the original 640x480 aspect ratio. The uncovered sides
    // remain black while the image still covers the vertical-road layer.
    wire photo_area=(x>=10'd108)&&(x<10'd532)&&
                    (y>=10'd162)&&(y<10'd480);

    // Source-image trajectory coordinates. These waypoints follow the six
    // colored polylines in the 640x480 diagram. They use the same sim_time as
    // the car, so sloped segments mean driving and horizontal segments mean
    // waiting at a red light.
    reg [9:0] chart_src_x, chart_src_y;
    // Verilog keeps a multiply at the operand width unless it is widened
    // explicitly. Keeping the full 20-bit product prevents the trajectory
    // coordinate from wrapping while it moves between fixed waypoints.
    function [19:0] chart_mul;
        input [9:0] a;
        input [9:0] b;
        begin
            chart_mul={10'd0,a}*{10'd0,b};
        end
    endfunction
    always @* begin
        chart_src_x=10'd29;
        chart_src_y=10'd475;
        case(speed_select)
          3'd0: begin // 35: brown; stops at junctions 1 and 3
            if(sim_time<10'd6) begin chart_src_x=10'd29; chart_src_y=10'd475; end
            else if(sim_time<10'd169) begin chart_src_x=10'd29+chart_mul(sim_time-10'd6,10'd222)/10'd163; chart_src_y=10'd475-chart_mul(sim_time-10'd6,10'd195)/10'd163; end
            else if(sim_time<10'd199) begin chart_src_x=10'd251+chart_mul(sim_time-10'd169,10'd42)/10'd30; chart_src_y=10'd280; end
            else if(sim_time<10'd274) begin chart_src_x=10'd293+chart_mul(sim_time-10'd199,10'd109)/10'd75; chart_src_y=10'd280-chart_mul(sim_time-10'd199,10'd100)/10'd75; end
            else if(sim_time<10'd369) begin chart_src_x=10'd402+chart_mul(sim_time-10'd274,10'd106)/10'd95; chart_src_y=10'd180-chart_mul(sim_time-10'd274,10'd93)/10'd95; end
            else if(sim_time<10'd399) begin chart_src_x=10'd508+chart_mul(sim_time-10'd369,10'd48)/10'd30; chart_src_y=10'd87; end
            else begin chart_src_x=10'd556+chart_mul(sim_time-10'd399,10'd80)/10'd280; chart_src_y=10'd87-chart_mul(sim_time-10'd399,10'd82)/10'd280; end
          end
          3'd1: begin // 40: orange red; stops at junction 2
            if(sim_time<10'd7) begin chart_src_x=10'd29; chart_src_y=10'd475; end
            else if(sim_time<10'd129) begin chart_src_x=10'd29+chart_mul(sim_time-10'd7,10'd191)/10'd122; chart_src_y=10'd475-chart_mul(sim_time-10'd7,10'd195)/10'd122; end
            else if(sim_time<10'd219) begin chart_src_x=10'd220+chart_mul(sim_time-10'd129,10'd96)/10'd90; chart_src_y=10'd280-chart_mul(sim_time-10'd129,10'd100)/10'd90; end
            else if(sim_time<10'd249) begin chart_src_x=10'd316+chart_mul(sim_time-10'd219,10'd43)/10'd30; chart_src_y=10'd180; end
            else if(sim_time<10'd329) begin chart_src_x=10'd359+chart_mul(sim_time-10'd249,10'd91)/10'd80; chart_src_y=10'd180-chart_mul(sim_time-10'd249,10'd93)/10'd80; end
            else begin chart_src_x=10'd450+chart_mul(sim_time-10'd329,10'd83)/10'd220; chart_src_y=10'd87-chart_mul(sim_time-10'd329,10'd82)/10'd220; end
          end
          3'd2: begin // 45: purple
            if(sim_time<10'd27) begin chart_src_x=10'd29; chart_src_y=10'd475; end
            else if(sim_time<10'd124) begin chart_src_x=10'd29+chart_mul(sim_time-10'd27,10'd172)/10'd97; chart_src_y=10'd475-chart_mul(sim_time-10'd27,10'd195)/10'd97; end
            else if(sim_time<10'd189) begin chart_src_x=10'd201+chart_mul(sim_time-10'd124,10'd87)/10'd65; chart_src_y=10'd280-chart_mul(sim_time-10'd124,10'd100)/10'd65; end
            else if(sim_time<10'd348) begin chart_src_x=10'd288+chart_mul(sim_time-10'd189,10'd81)/10'd159; chart_src_y=10'd180-chart_mul(sim_time-10'd189,10'd93)/10'd159; end
            else begin chart_src_x=10'd369+chart_mul(sim_time-10'd348,10'd90)/10'd171; chart_src_y=10'd87-chart_mul(sim_time-10'd348,10'd82)/10'd171; end
          end
          3'd3: begin // 50: deep sky blue
            if(sim_time<10'd38) begin chart_src_x=10'd29; chart_src_y=10'd475; end
            else if(sim_time<10'd119) begin chart_src_x=10'd29+chart_mul(sim_time-10'd38,10'd142)/10'd81; chart_src_y=10'd475-chart_mul(sim_time-10'd38,10'd195)/10'd81; end
            else if(sim_time<10'd169) begin chart_src_x=10'd171+chart_mul(sim_time-10'd119,10'd67)/10'd50; chart_src_y=10'd280-chart_mul(sim_time-10'd119,10'd100)/10'd50; end
            else if(sim_time<10'd219) begin chart_src_x=10'd238+chart_mul(sim_time-10'd169,10'd62)/10'd50; chart_src_y=10'd180-chart_mul(sim_time-10'd169,10'd93)/10'd50; end
            else begin chart_src_x=10'd300+chart_mul(sim_time-10'd219,10'd55)/10'd150; chart_src_y=10'd87-chart_mul(sim_time-10'd219,10'd82)/10'd150; end
          end
          3'd4: begin // 55: dodger blue; stops at all three junctions
            if(sim_time<10'd69) begin chart_src_x=10'd29+chart_mul(sim_time,10'd106)/10'd69; chart_src_y=10'd475-chart_mul(sim_time,10'd195)/10'd69; end
            else if(sim_time<10'd99) begin chart_src_x=10'd135+chart_mul(sim_time-10'd69,10'd27)/10'd30; chart_src_y=10'd280; end
            else if(sim_time<10'd124) begin chart_src_x=10'd162+chart_mul(sim_time-10'd99,10'd41)/10'd25; chart_src_y=10'd280-chart_mul(sim_time-10'd99,10'd100)/10'd25; end
            else if(sim_time<10'd149) begin chart_src_x=10'd203+chart_mul(sim_time-10'd124,10'd26)/10'd25; chart_src_y=10'd180; end
            else if(sim_time<10'd174) begin chart_src_x=10'd229+chart_mul(sim_time-10'd149,10'd39)/10'd25; chart_src_y=10'd180-chart_mul(sim_time-10'd149,10'd93)/10'd25; end
            else if(sim_time<10'd199) begin chart_src_x=10'd268+chart_mul(sim_time-10'd174,10'd24)/10'd25; chart_src_y=10'd87; end
            else begin chart_src_x=10'd292+chart_mul(sim_time-10'd199,10'd30)/10'd130; chart_src_y=10'd87-chart_mul(sim_time-10'd199,10'd82)/10'd130; end
          end
          default: begin // 60: blue; stops at all three junctions
            if(sim_time<10'd59) begin chart_src_x=10'd29+chart_mul(sim_time,10'd84)/10'd59; chart_src_y=10'd475-chart_mul(sim_time,10'd195)/10'd59; end
            else if(sim_time<10'd99) begin chart_src_x=10'd113+chart_mul(sim_time-10'd59,10'd47)/10'd40; chart_src_y=10'd280; end
            else if(sim_time<10'd119) begin chart_src_x=10'd160+chart_mul(sim_time-10'd99,10'd20)/10'd20; chart_src_y=10'd280-chart_mul(sim_time-10'd99,10'd100)/10'd20; end
            else if(sim_time<10'd149) begin chart_src_x=10'd180+chart_mul(sim_time-10'd119,10'd47)/10'd30; chart_src_y=10'd180; end
            else if(sim_time<10'd164) begin chart_src_x=10'd227+chart_mul(sim_time-10'd149,10'd16)/10'd15; chart_src_y=10'd180-chart_mul(sim_time-10'd149,10'd93)/10'd15; end
            else if(sim_time<10'd199) begin chart_src_x=10'd243+chart_mul(sim_time-10'd164,10'd48)/10'd35; chart_src_y=10'd87; end
            else begin chart_src_x=10'd291+chart_mul(sim_time-10'd199,10'd14)/10'd110; chart_src_y=10'd87-chart_mul(sim_time-10'd199,10'd82)/10'd110; end
          end
        endcase
    end
    wire [15:0] chart_x_scaled={6'd0,chart_src_x}*16'd53;
    wire [15:0] chart_y_scaled={6'd0,chart_src_y}*16'd53;
    wire [9:0] chart_dot_x=10'd108+(chart_x_scaled/7'd80);
    wire [9:0] chart_dot_y=10'd162+(chart_y_scaled/7'd80);
    wire [10:0] chart_dot_dx=(x>=chart_dot_x)?(x-chart_dot_x):(chart_dot_x-x);
    wire [10:0] chart_dot_dy=(y>=chart_dot_y)?(y-chart_dot_y):(chart_dot_y-y);
    wire chart_dot=car_visible&&(chart_dot_dx<=11'd5)&&(chart_dot_dy<=11'd5)&&
                   ((chart_dot_dx+chart_dot_dy)<=11'd7);
    always @* begin
        case(single_title_slot)
          4'd0:title_ascii=8'h47;4'd1:title_ascii=8'h52;4'd2:title_ascii=8'h45;4'd3:title_ascii=8'h45;4'd4:title_ascii=8'h4e;
          4'd6:title_ascii=8'h57;4'd7:title_ascii=8'h41;4'd8:title_ascii=8'h56;4'd9:title_ascii=8'h45;4'd11:title_ascii=8'h4c;
          4'd12:title_ascii=8'h41;4'd13:title_ascii=8'h4e;4'd14:title_ascii=8'h45;default:title_ascii=8'h20;
        endcase
        case(speed_select)
          3'd0:begin speed_tens=8'h33; speed_ones=8'h35; end
          3'd1:begin speed_tens=8'h34; speed_ones=8'h30; end
          3'd2:begin speed_tens=8'h34; speed_ones=8'h35; end
          3'd3:begin speed_tens=8'h35; speed_ones=8'h30; end
          3'd4:begin speed_tens=8'h35; speed_ones=8'h35; end
          default:begin speed_tens=8'h36; speed_ones=8'h30; end
        endcase
        case(filter_slot)
          5'd0:filter_ascii=8'h46; 5'd1:filter_ascii=8'h49;
          5'd2:filter_ascii=8'h4c; 5'd3:filter_ascii=8'h54;
          5'd4:filter_ascii=8'h45; 5'd5:filter_ascii=8'h52;
          5'd6:filter_ascii=8'h20; 5'd7:filter_ascii=8'h53;
          5'd8:filter_ascii=8'h50; 5'd9:filter_ascii=8'h45;
          5'd10:filter_ascii=8'h45; 5'd11:filter_ascii=8'h44;
          5'd12:filter_ascii=8'h3a; 5'd13:filter_ascii=8'h34;
          5'd14:filter_ascii=8'h35; 5'd15:filter_ascii=8'h2d;
          5'd16:filter_ascii=8'h35; 5'd17:filter_ascii=8'h30;
          default:filter_ascii=8'h20;
        endcase
        case(speed_slot)
          4'd0:speed_ascii=8'h53; 4'd1:speed_ascii=8'h50;
          4'd2:speed_ascii=8'h45; 4'd3:speed_ascii=8'h45;
          4'd4:speed_ascii=8'h44; 4'd5:speed_ascii=8'h3a;
          4'd6:speed_ascii=8'h20; 4'd7:speed_ascii=speed_tens;
          4'd8:speed_ascii=speed_ones; 4'd9:speed_ascii=8'h20;
          4'd10:speed_ascii=8'h4b; 4'd11:speed_ascii=8'h4d;
          4'd12:speed_ascii=8'h2f; 4'd13:speed_ascii=8'h48;
          default:speed_ascii=8'h20;
        endcase
        case(rom_index)
          8'hFF: photo_rgb=16'h0000; // 000000 black
          8'hFB: photo_rgb=16'hF800; // FF0000 red
          8'h03: photo_rgb=16'h07E0; // 00FF00 green
          8'hFE: photo_rgb=16'h001F; // 0000FF blue
          8'hA8: photo_rgb=16'h1C9F; // 1E90FF dodger blue
          8'h82: photo_rgb=16'h05FF; // 00BFFF deep sky blue
          8'hFD: photo_rgb=16'h8010; // 800080 purple
          8'hD6: photo_rgb=16'hFA20; // FF4500 orange red
          8'hDE: photo_rgb=16'hA145; // A52A2A brown
          default: photo_rgb=16'hFFFF;
        endcase
    end
    font f_title(.ascii(title_ascii),.row(single_title_row),.bits(title_bits));
    font f_filter(.ascii(filter_ascii),.row(filter_row),.bits(filter_bits));
    font f_speed(.ascii(speed_ascii),.row(single_speed_row),.bits(speed_bits));
    always @* begin
        pix_data=BACK;
        if (road||c1||c2||c3) pix_data=ROAD;
        if (road&&(y>=10'd94)&&(y<10'd158)) pix_data=LANE;
        if (road_edge_single||cross_edge||stops) pix_data=WHITE;
        // The photograph starts immediately below the horizontal lane and
        // intentionally covers the vertical road layer only inside its frame.
        if (photo_area) pix_data=photo_rgb;
        if (sigbox) pix_data=BACK;
        if (sigborder) pix_data=WHITE;
        if (redlamp) pix_data=((sig2&&sig2_green)||((sig1||sig3)&&sig13_green))?DIM:RED;
        if (greenlamp) pix_data=((sig2&&sig2_green)||((sig1||sig3)&&sig13_green))?GREEN:DIM;
        if (body) pix_data=car_color;
        if (glass) pix_data=GLASS;
        if (title&&title_bits[7-single_title_col]) pix_data=GREEN;
        if (filter_label&&filter_bits[7-x[2:0]]) pix_data=WHITE;
        if (speed&&speed_bits[7-speed_col]) pix_data=16'hFFE0;
        if (chart_dot) pix_data=car_color;
    end
endmodule

// Three-intersection green-wave demonstration. The accelerated demo keeps the
// same ratios with 20 seconds between junctions and 0/20/40-second offsets.
module green_wave_scene(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire [15:0] bg_data,
    input  wire        move_tick,
    input  wire        enable,
    output wire [9:0]  fast_x_out,
    output wire [9:0]  wave55_x_out,
    output wire [9:0]  wave58_x_out,
    output wire [9:0]  wave60_x_out,
    output wire [9:0]  slow_x_out,
    output wire [2:0]  light_bits_out,
    output reg  [15:0] pix_data
);
    localparam USE_BG_IMAGE = 1'b1;
    localparam [15:0] BACK       = 16'h0000;
    localparam [15:0] ROAD       = 16'h2945;
    localparam [15:0] WHITE      = 16'hFFFF;
    localparam [15:0] RED        = 16'hF800;
    localparam [15:0] YELLOW     = 16'hFFE0;
    localparam [15:0] GREEN      = 16'h07E0;
    localparam [15:0] DIM_LAMP   = 16'h0841;
    localparam [15:0] FAST_CAR   = 16'hF945;
    localparam [15:0] WAVE_CAR   = 16'h481F;
    localparam [15:0] SLOW_CAR   = 16'h04DF;
    localparam [15:0] GLASS      = 16'hBDF7;
    localparam [15:0] LANE_GREEN   = 16'h46AE;
    localparam [15:0] CHART_GRID = 16'h4208;
    localparam [15:0] WAVE_BAND  = 16'h05E8;

    localparam [9:0] STOP_1 = 10'd126;
    localparam [9:0] STOP_2 = 10'd286;
    localparam [9:0] STOP_3 = 10'd446;
    localparam [17:0] CAR_START_Q8 = 18'd2560; // 10 pixels, left edge
    // One move_tick is one VGA frame.  Junction spacing is calibrated to
    // 12, 25 and 38 frames for fast, green-wave and slow cars.
    localparam [11:0] FAST_STEP_Q8 = 12'd3456;
    localparam [11:0] WAVE55_STEP_Q8 = 12'd1510;
    localparam [11:0] WAVE58_STEP_Q8 = 12'd1587;
    localparam [11:0] WAVE60_STEP_Q8 = 12'd1638;
    localparam [11:0] SLOW_STEP_Q8 = 12'd1078;

    reg [9:0] draw_x;
    reg [9:0] draw_y;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            draw_x <= 10'd0;
            draw_y <= 10'd0;
        end else begin
            draw_x <= pix_x;
            draw_y <= pix_y;
        end
    end

    reg [7:0] frame_count;
    reg [17:0] fast_car_q8;
    reg [17:0] wave55_car_q8;
    reg [17:0] wave58_car_q8;
    reg [17:0] wave60_car_q8;
    reg [17:0] slow_car_q8;

    wire [9:0] fast_car_x = fast_car_q8[17:8];
    wire [9:0] wave55_car_x = wave55_car_q8[17:8];
    wire [9:0] wave58_car_x = wave58_car_q8[17:8];
    wire [9:0] wave60_car_x = wave60_car_q8[17:8];
    wire [9:0] slow_car_x = slow_car_q8[17:8];
    assign fast_x_out=fast_car_x; assign wave55_x_out=wave55_car_x;
    assign wave58_x_out=wave58_car_x; assign wave60_x_out=wave60_car_x;
    assign slow_x_out=slow_car_x;

    wire [5:0] signal_phase = frame_count % 8'd50;
    wire green_1 = (signal_phase < 6'd25);
    wire green_2 = (signal_phase >= 6'd25);
    wire green_3 = green_1;
    assign light_bits_out = {green_3,green_2,green_1};
    wire yellow_1 = 1'b0;
    wire yellow_2 = 1'b0;
    wire yellow_3 = 1'b0;

    function should_stop;
        input [17:0] car_q8;
        input [11:0] step_q8;
        input       signal_green;
        input [9:0] stop_x;
        reg [20:0] next_q8;
        begin
            next_q8 = {3'd0,car_q8} + {9'd0,step_q8};
            should_stop = !signal_green &&
                          (car_q8 <= {stop_x,8'd0}) &&
                          (next_q8 >= {1'b0,stop_x,8'd0});
        end
    endfunction

    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n || !enable) begin
            frame_count   <= 8'd0;
            fast_car_q8   <= CAR_START_Q8;
            wave55_car_q8 <= CAR_START_Q8;
            wave58_car_q8 <= CAR_START_Q8;
            wave60_car_q8 <= CAR_START_Q8;
            slow_car_q8   <= CAR_START_Q8;
        end else if (move_tick) begin
            if (frame_count == 8'd149) begin
                frame_count   <= 8'd0;
                fast_car_q8   <= CAR_START_Q8;
                wave55_car_q8 <= CAR_START_Q8;
                wave58_car_q8 <= CAR_START_Q8;
                wave60_car_q8 <= CAR_START_Q8;
                slow_car_q8   <= CAR_START_Q8;
            end else begin
                frame_count <= frame_count + 1'b1;

                if (should_stop(fast_car_q8, FAST_STEP_Q8, green_1, STOP_1))
                    fast_car_q8 <= {STOP_1, 8'd0};
                else if (should_stop(fast_car_q8, FAST_STEP_Q8, green_2, STOP_2))
                    fast_car_q8 <= {STOP_2, 8'd0};
                else if (should_stop(fast_car_q8, FAST_STEP_Q8, green_3, STOP_3))
                    fast_car_q8 <= {STOP_3, 8'd0};
                else if (fast_car_x < 10'd616)
                    fast_car_q8 <= fast_car_q8 + FAST_STEP_Q8;

                if (should_stop(wave55_car_q8, WAVE55_STEP_Q8, green_1, STOP_1))
                    wave55_car_q8 <= {STOP_1, 8'd0};
                else if (should_stop(wave55_car_q8, WAVE55_STEP_Q8, green_2, STOP_2))
                    wave55_car_q8 <= {STOP_2, 8'd0};
                else if (should_stop(wave55_car_q8, WAVE55_STEP_Q8, green_3, STOP_3))
                    wave55_car_q8 <= {STOP_3, 8'd0};
                else if (wave55_car_x < 10'd616)
                    wave55_car_q8 <= wave55_car_q8 + WAVE55_STEP_Q8;

                if (should_stop(wave58_car_q8, WAVE58_STEP_Q8, green_1, STOP_1))
                    wave58_car_q8 <= {STOP_1, 8'd0};
                else if (should_stop(wave58_car_q8, WAVE58_STEP_Q8, green_2, STOP_2))
                    wave58_car_q8 <= {STOP_2, 8'd0};
                else if (should_stop(wave58_car_q8, WAVE58_STEP_Q8, green_3, STOP_3))
                    wave58_car_q8 <= {STOP_3, 8'd0};
                else if (wave58_car_x < 10'd616)
                    wave58_car_q8 <= wave58_car_q8 + WAVE58_STEP_Q8;

                if (should_stop(wave60_car_q8, WAVE60_STEP_Q8, green_1, STOP_1))
                    wave60_car_q8 <= {STOP_1, 8'd0};
                else if (should_stop(wave60_car_q8, WAVE60_STEP_Q8, green_2, STOP_2))
                    wave60_car_q8 <= {STOP_2, 8'd0};
                else if (should_stop(wave60_car_q8, WAVE60_STEP_Q8, green_3, STOP_3))
                    wave60_car_q8 <= {STOP_3, 8'd0};
                else if (wave60_car_x < 10'd616)
                    wave60_car_q8 <= wave60_car_q8 + WAVE60_STEP_Q8;

                if (should_stop(slow_car_q8, SLOW_STEP_Q8, green_1, STOP_1))
                    slow_car_q8 <= {STOP_1, 8'd0};
                else if (should_stop(slow_car_q8, SLOW_STEP_Q8, green_2, STOP_2))
                    slow_car_q8 <= {STOP_2, 8'd0};
                else if (should_stop(slow_car_q8, SLOW_STEP_Q8, green_3, STOP_3))
                    slow_car_q8 <= {STOP_3, 8'd0};
                else if (slow_car_x < 10'd616)
                    slow_car_q8 <= slow_car_q8 + SLOW_STEP_Q8;
            end
        end
    end

    // Top labels: GREEN WAVE LANE and FILTER SPEED:45-50KM/H.
    wire title_area = (draw_x >= 10'd200) && (draw_x < 10'd440) &&
                      (draw_y >= 10'd8) && (draw_y < 10'd24);
    wire [3:0] title_slot = (draw_x - 10'd200) >> 4;
    wire [2:0] title_row = (draw_y - 10'd8) >> 1;
    wire [2:0] title_col = (draw_x - 10'd200) >> 1;
    reg [7:0] title_ascii;
    wire [7:0] title_bits;
    always @* begin
        case (title_slot)
            4'd0:  title_ascii = 8'h47; // G
            4'd1:  title_ascii = 8'h52; // R
            4'd2:  title_ascii = 8'h45; // E
            4'd3:  title_ascii = 8'h45; // E
            4'd4:  title_ascii = 8'h4E; // N
            4'd6:  title_ascii = 8'h57; // W
            4'd7:  title_ascii = 8'h41; // A
            4'd8:  title_ascii = 8'h56; // V
            4'd9:  title_ascii = 8'h45; // E
            4'd11: title_ascii = 8'h4C; // L
            4'd12: title_ascii = 8'h41; // A
            4'd13: title_ascii = 8'h4E; // N
            4'd14: title_ascii = 8'h45; // E
            default: title_ascii = 8'h20;
        endcase
    end
    font u_green_wave_title_font(.ascii(title_ascii),
                                 .row(title_row), .bits(title_bits));

    wire speed_text_area = (draw_x >= 10'd232) && (draw_x < 10'd408) &&
                           (draw_y >= 10'd40) && (draw_y < 10'd48);
    wire [4:0] speed_text_slot = (draw_x - 10'd232) >> 3;
    wire [2:0] speed_text_row = draw_y - 10'd40;
    reg [7:0] speed_text_ascii;
    wire [7:0] speed_text_bits;
    always @* begin
        case (speed_text_slot)
            5'd0: speed_text_ascii=8'h46; 5'd1: speed_text_ascii=8'h49;
            5'd2: speed_text_ascii=8'h4C; 5'd3: speed_text_ascii=8'h54;
            5'd4: speed_text_ascii=8'h45; 5'd5: speed_text_ascii=8'h52;
            5'd6: speed_text_ascii=8'h20; 5'd7: speed_text_ascii=8'h53;
            5'd8: speed_text_ascii=8'h50; 5'd9: speed_text_ascii=8'h45;
            5'd10: speed_text_ascii=8'h45; 5'd11: speed_text_ascii=8'h44;
            5'd12: speed_text_ascii=8'h3A; 5'd13: speed_text_ascii=8'h34;
            5'd14: speed_text_ascii=8'h35; 5'd15: speed_text_ascii=8'h2D;
            5'd16: speed_text_ascii=8'h35; 5'd17: speed_text_ascii=8'h30;
            5'd18: speed_text_ascii=8'h4B; 5'd19: speed_text_ascii=8'h4D;
            5'd20: speed_text_ascii=8'h2F; 5'd21: speed_text_ascii=8'h48;
            default: speed_text_ascii=8'h20;
        endcase
    end
    font u_green_speed_font(.ascii(speed_text_ascii),
                            .row(speed_text_row), .bits(speed_text_bits));

    // Fixed speed tags follow the rear of all five vehicles.
    wire [9:0] fast_tag_x0 = fast_car_x - 10'd50;
    wire [9:0] wave55_tag_x0 = wave55_car_x - 10'd50;
    wire [9:0] wave58_tag_x0 = wave58_car_x - 10'd50;
    wire [9:0] wave60_tag_x0 = wave60_car_x - 10'd50;
    wire [9:0] slow_tag_x0 = slow_car_x - 10'd50;
    wire fast_tag_area = (draw_x >= fast_tag_x0) && (draw_x < fast_car_x-10'd2) &&
                         (draw_y >= 10'd100) && (draw_y < 10'd108);
    wire wave55_tag_area = (draw_x >= wave55_tag_x0) && (draw_x < wave55_car_x-10'd2) &&
                          (draw_y >= 10'd208) && (draw_y < 10'd216);
    wire wave58_tag_area = (draw_x >= wave58_tag_x0) && (draw_x < wave58_car_x-10'd2) &&
                           (draw_y >= 10'd172) && (draw_y < 10'd180);
    wire wave60_tag_area = (draw_x >= wave60_tag_x0) && (draw_x < wave60_car_x-10'd2) &&
                           (draw_y >= 10'd136) && (draw_y < 10'd144);
    wire slow_tag_area = (draw_x >= slow_tag_x0) && (draw_x < slow_car_x-10'd2) &&
                          (draw_y >= 10'd244) && (draw_y < 10'd252);
    reg [7:0] car_speed_ascii;
    reg [2:0] car_speed_row;
    reg [2:0] car_speed_col;
    reg [2:0] car_speed_slot;
    reg [15:0] car_speed_color;
    reg car_speed_text_area;
    wire [7:0] car_speed_bits;
    always @* begin
        car_speed_text_area = 1'b0;
        car_speed_slot = 3'd0;
        car_speed_row = 3'd0;
        car_speed_col = 3'd0;
        car_speed_color = WHITE;
        if (fast_tag_area) begin
            car_speed_text_area = 1'b1;
            car_speed_slot = (draw_x-fast_tag_x0) >> 3;
            car_speed_row = draw_y-10'd100;
            car_speed_col = draw_x-fast_tag_x0;
            car_speed_color = FAST_CAR;
        end else if (wave55_tag_area) begin
            car_speed_text_area = 1'b1;
            car_speed_slot = (draw_x-wave55_tag_x0) >> 3;
            car_speed_row = draw_y-10'd208;
            car_speed_col = draw_x-wave55_tag_x0;
            car_speed_color = WAVE_CAR;
        end else if (wave58_tag_area) begin
            car_speed_text_area = 1'b1;
            car_speed_slot = (draw_x-wave58_tag_x0) >> 3;
            car_speed_row = draw_y-10'd172;
            car_speed_col = draw_x-wave58_tag_x0;
            car_speed_color = WAVE_CAR;
        end else if (wave60_tag_area) begin
            car_speed_text_area = 1'b1;
            car_speed_slot = (draw_x-wave60_tag_x0) >> 3;
            car_speed_row = draw_y-10'd136;
            car_speed_col = draw_x-wave60_tag_x0;
            car_speed_color = WAVE_CAR;
        end else if (slow_tag_area) begin
            car_speed_text_area = 1'b1;
            car_speed_slot = (draw_x-slow_tag_x0) >> 3;
            car_speed_row = draw_y-10'd244;
            car_speed_col = draw_x-slow_tag_x0;
            car_speed_color = SLOW_CAR;
        end
        case (car_speed_slot)
            3'd0: car_speed_ascii = fast_tag_area ? 8'h36 :
                                          ((slow_tag_area || wave55_tag_area ||
                                            wave58_tag_area) ? 8'h34 : 8'h35);
            3'd1: car_speed_ascii = fast_tag_area ? 8'h30 :
                                          (wave55_tag_area ? 8'h35 :
                                          (wave58_tag_area ? 8'h38 :
                                            (wave60_tag_area ? 8'h30 : 8'h30)));
            3'd2: car_speed_ascii = 8'h4B; // K
            3'd3: car_speed_ascii = 8'h4D; // M
            3'd4: car_speed_ascii = 8'h2F; // /
            3'd5: car_speed_ascii = 8'h48; // H
            default: car_speed_ascii = 8'h20;
        endcase
    end
    font u_car_speed_font(.ascii(car_speed_ascii),
                          .row(car_speed_row), .bits(car_speed_bits));

    wire main_road = (draw_y >= 10'd90) && (draw_y < 10'd270);
    wire cross_1 = (draw_x >= 10'd150) && (draw_x < 10'd210) &&
                   (draw_y >= 10'd80) && (draw_y < 10'd400);
    wire cross_2 = (draw_x >= 10'd310) && (draw_x < 10'd370) &&
                   (draw_y >= 10'd80) && (draw_y < 10'd400);
    wire cross_3 = (draw_x >= 10'd470) && (draw_x < 10'd530) &&
                   (draw_y >= 10'd80) && (draw_y < 10'd400);
    wire any_road = main_road || cross_1 || cross_2 || cross_3;
    wire main_edge = ((draw_y >= 10'd90) && (draw_y < 10'd93)) ||
                     ((draw_y >= 10'd267) && (draw_y < 10'd270));
    wire lane_dash = main_road && (draw_x[5:0] < 6'd30) &&
                       (((draw_y >= 10'd126) && (draw_y < 10'd129)) ||
                       ((draw_y >= 10'd162) && (draw_y < 10'd165)) ||
                       ((draw_y >= 10'd198) && (draw_y < 10'd201)) ||
                       ((draw_y >= 10'd234) && (draw_y < 10'd237)));
    wire cross_edge = (((draw_x >= 10'd150) && (draw_x < 10'd153)) ||
                       ((draw_x >= 10'd207) && (draw_x < 10'd210)) ||
                       ((draw_x >= 10'd310) && (draw_x < 10'd313)) ||
                       ((draw_x >= 10'd367) && (draw_x < 10'd370)) ||
                       ((draw_x >= 10'd470) && (draw_x < 10'd473)) ||
                       ((draw_x >= 10'd527) && (draw_x < 10'd530))) &&
                       ((draw_y < 10'd90) || (draw_y >= 10'd270));
    wire cross_dash = (draw_y[5:0] < 6'd28) &&
                      (((draw_x >= 10'd178) && (draw_x < 10'd181)) ||
                       ((draw_x >= 10'd338) && (draw_x < 10'd341)) ||
                       ((draw_x >= 10'd498) && (draw_x < 10'd501))) &&
                       ((draw_y < 10'd90) || (draw_y >= 10'd270));
    wire stop_lines = (((draw_x >= 10'd150) && (draw_x < 10'd153)) ||
                       ((draw_x >= 10'd207) && (draw_x < 10'd210)) ||
                       ((draw_x >= 10'd310) && (draw_x < 10'd313)) ||
                       ((draw_x >= 10'd367) && (draw_x < 10'd370)) ||
                       ((draw_x >= 10'd470) && (draw_x < 10'd473)) ||
                       ((draw_x >= 10'd527) && (draw_x < 10'd530))) && main_road;

    // Reference-proportioned displacement-time chart in the lower-left.
    wire chart_panel = (draw_x >= 10'd8) && (draw_x < 10'd230) &&
                       (draw_y >= 10'd282) && (draw_y < 10'd479);
    wire chart_plot = (draw_x >= 10'd32) && (draw_x <= 10'd218) &&
                      (draw_y >= 10'd294) && (draw_y <= 10'd455);
    wire chart_axis = (((draw_x >= 10'd32) && (draw_x <= 10'd218)) &&
                       (draw_y >= 10'd453) && (draw_y <= 10'd455)) ||
                      (((draw_x >= 10'd31) && (draw_x <= 10'd33)) &&
                       (draw_y >= 10'd294) && (draw_y <= 10'd455));
    wire chart_arrow = ((draw_y >= 10'd294) && (draw_y <= 10'd302) &&
                        (draw_x >= 10'd32-(draw_y-10'd294)) &&
                        (draw_x <= 10'd32+(draw_y-10'd294))) ||
                       ((draw_x >= 10'd210) && (draw_x <= 10'd218) &&
                        (draw_y >= 10'd454-(draw_x-10'd210)) &&
                        (draw_y <= 10'd454+(draw_x-10'd210)));
    wire chart_h_grid = chart_plot &&
                        (((draw_y >= 10'd324) && (draw_y <= 10'd325)) ||
                         ((draw_y >= 10'd364) && (draw_y <= 10'd365)) ||
                         ((draw_y >= 10'd404) && (draw_y <= 10'd405)));
    wire chart_junction = chart_plot &&
                          (((draw_x >= 10'd79) && (draw_x <= 10'd81)) ||
                           ((draw_x >= 10'd134) && (draw_x <= 10'd136)) ||
                           ((draw_x >= 10'd192) && (draw_x <= 10'd194)));

    // The chart uses time vertically and displacement horizontally.  Each
    // signal column repeats the same 20-second cycle shown by the road lamps.
    wire chart_signal_1 = (draw_x >= 10'd78) && (draw_x <= 10'd83) &&
                          (draw_y >= 10'd304) && (draw_y <= 10'd444);
    wire chart_signal_2 = (draw_x >= 10'd133) && (draw_x <= 10'd138) &&
                          (draw_y >= 10'd304) && (draw_y <= 10'd444);
    wire chart_signal_3 = (draw_x >= 10'd191) && (draw_x <= 10'd196) &&
                          (draw_y >= 10'd304) && (draw_y <= 10'd444);
    // Chart vertical axis is frame/time (0 at the bottom, 100 at the top).
    wire [9:0] chart_time_px = 10'd444 - draw_y;
    wire [7:0] chart_frame = (chart_time_px * 8'd100) / 10'd140;
    wire [5:0] chart_phase = chart_frame % 8'd50;
    wire chart_signal_green = ((chart_signal_1 || chart_signal_3) &&
                               (chart_phase < 6'd25)) ||
                              (chart_signal_2 && (chart_phase >= 6'd25));
    wire chart_signal_gap = 1'b0;
    wire chart_signal_red = (chart_signal_1 || chart_signal_2 || chart_signal_3) &&
                            !chart_signal_green && !chart_signal_gap;

    function [9:0] fast_trace_x_at;
        input [9:0] t;
        begin
            if (t < 10'd12) fast_trace_x_at = 10'd80 + ((t*55)/12);
            else if (t < 10'd25) fast_trace_x_at = 10'd135;
            else if (t < 10'd37) fast_trace_x_at = 10'd135 + ((t-25)*58)/12;
            else fast_trace_x_at = 10'd193;
        end
    endfunction
    function [9:0] wave55_trace_x_at;
        input [9:0] t;
        begin
            if (t < 10'd25) wave55_trace_x_at = 10'd80 + (t*55)/25;
            else if (t < 10'd50) wave55_trace_x_at = 10'd135 + ((t-25)*58)/25;
            else wave55_trace_x_at = 10'd193;
        end
    endfunction
    function [9:0] wave58_trace_x_at;
        input [9:0] t;
        begin
            if (t < 10'd25) wave58_trace_x_at = 10'd80 + (t*55)/25;
            else if (t < 10'd50) wave58_trace_x_at = 10'd135 + ((t-25)*58)/25;
            else wave58_trace_x_at = 10'd193;
        end
    endfunction
    function [9:0] wave60_trace_x_at;
        input [9:0] t;
        begin
            if (t < 10'd25) wave60_trace_x_at = 10'd80 + (t*55)/25;
            else if (t < 10'd50) wave60_trace_x_at = 10'd135 + ((t-25)*58)/25;
            else wave60_trace_x_at = 10'd193;
        end
    endfunction
    function [9:0] slow_trace_x_at;
        input [9:0] t;
        begin
            if (t < 10'd38) slow_trace_x_at = 10'd80 + (t*55)/38;
            else if (t < 10'd50) slow_trace_x_at = 10'd135 + ((t-38)*58)/38;
            else if (t < 10'd76) slow_trace_x_at = 10'd193;
            else slow_trace_x_at = 10'd193;
        end
    endfunction

    wire [9:0] fast_trace_x = fast_trace_x_at(chart_frame);
    wire [9:0] wave55_trace_x = wave55_trace_x_at(chart_frame);
    wire [9:0] wave58_trace_x = wave58_trace_x_at(chart_frame);
    wire [9:0] wave60_trace_x = wave60_trace_x_at(chart_frame);
    wire [9:0] slow_trace_x = slow_trace_x_at(chart_frame);
    wire trace_time_range = (draw_y >= 10'd304) && (draw_y <= 10'd444);
    wire green_wave_band = trace_time_range &&
                           (draw_x >= wave55_trace_x-10'd4) &&
                           (draw_x <= wave60_trace_x+10'd4);
    wire fast_trace = trace_time_range && (draw_x >= fast_trace_x-10'd1) &&
                      (draw_x <= fast_trace_x+10'd1);
    wire wave55_trace = trace_time_range && (draw_x == wave55_trace_x);
    wire wave58_trace = trace_time_range && (draw_x == wave58_trace_x);
    wire wave60_trace = trace_time_range && (draw_x == wave60_trace_x);
    wire slow_trace = trace_time_range && (draw_x >= slow_trace_x-10'd1) &&
                      (draw_x <= slow_trace_x+10'd1);

    wire [9:0] dot_y = 10'd444 - ((frame_count * 10'd140) / 10'd100);
    wire [9:0] fast_dot_x = fast_trace_x_at(frame_count);
    wire [9:0] wave55_dot_x = wave55_trace_x_at(frame_count);
    wire [9:0] wave58_dot_x = wave58_trace_x_at(frame_count);
    wire [9:0] wave60_dot_x = wave60_trace_x_at(frame_count);
    wire [9:0] slow_dot_x = slow_trace_x_at(frame_count);
    wire fast_trace_dot = (fast_dot_x <= 10'd218) &&
                          (draw_x >= fast_dot_x-10'd2) && (draw_x <= fast_dot_x+10'd2) &&
                          (draw_y >= dot_y-10'd2) && (draw_y <= dot_y+10'd2);
    wire wave55_trace_dot = (wave55_dot_x <= 10'd218) &&
                          (draw_x >= wave55_dot_x-10'd2) && (draw_x <= wave55_dot_x+10'd2) &&
                          (draw_y >= dot_y-10'd2) && (draw_y <= dot_y+10'd2);
    wire wave58_trace_dot = (wave58_dot_x <= 10'd218) &&
                          (draw_x >= wave58_dot_x-10'd2) && (draw_x <= wave58_dot_x+10'd2) &&
                          (draw_y >= dot_y-10'd2) && (draw_y <= dot_y+10'd2);
    wire wave60_trace_dot = (wave60_dot_x <= 10'd218) &&
                          (draw_x >= wave60_dot_x-10'd2) && (draw_x <= wave60_dot_x+10'd2) &&
                          (draw_y >= dot_y-10'd2) && (draw_y <= dot_y+10'd2);
    wire slow_trace_dot = (slow_dot_x <= 10'd218) &&
                          (draw_x >= slow_dot_x-10'd2) && (draw_x <= slow_dot_x+10'd2) &&
                          (draw_y >= dot_y-10'd2) && (draw_y <= dot_y+10'd2);

    reg [7:0] chart_ascii;
    reg [2:0] chart_text_row;
    reg [2:0] chart_text_col;
    reg chart_text_area;
    reg chart_speed_text;
    wire [7:0] chart_text_bits;
    always @* begin
        chart_ascii = 8'h20;
        chart_text_row = 3'd0;
        chart_text_col = 3'd0;
        chart_text_area = 1'b0;
        chart_speed_text = 1'b0;
        if ((draw_x >= 10'd10) && (draw_x < 10'd42) &&
            (draw_y >= 10'd286) && (draw_y < 10'd294)) begin
            chart_text_area = 1'b1;
            chart_text_row = draw_y-10'd286;
            chart_text_col = draw_x-10'd10;
            case ((draw_x-10'd10)>>3)
                2'd0: chart_ascii=8'h54; 2'd1: chart_ascii=8'h49;
                2'd2: chart_ascii=8'h4D; default: chart_ascii=8'h45;
            endcase
        end else if ((draw_x >= 10'd219) && (draw_x < 10'd227) &&
                     (draw_y >= 10'd445) && (draw_y < 10'd453)) begin
            chart_text_area = 1'b1;
            chart_text_row = draw_y-10'd445;
            chart_text_col = draw_x-10'd219;
            chart_ascii = 8'h58; // X: junction position
        end else if ((draw_x >= 10'd70) && (draw_x < 10'd86) &&
                     (draw_y >= 10'd460) && (draw_y < 10'd468)) begin
            chart_text_area=1'b1; chart_text_row=draw_y-10'd460;
            chart_text_col=draw_x-10'd70;
            chart_ascii=((draw_x-10'd70)<10'd8) ? 8'h4A : 8'h31;
        end else if ((draw_x >= 10'd125) && (draw_x < 10'd141) &&
                     (draw_y >= 10'd460) && (draw_y < 10'd468)) begin
            chart_text_area=1'b1; chart_text_row=draw_y-10'd460;
            chart_text_col=draw_x-10'd125;
            chart_ascii=((draw_x-10'd125)<10'd8) ? 8'h4A : 8'h32;
        end else if ((draw_x >= 10'd183) && (draw_x < 10'd199) &&
                     (draw_y >= 10'd460) && (draw_y < 10'd468)) begin
            chart_text_area=1'b1; chart_text_row=draw_y-10'd460;
            chart_text_col=draw_x-10'd183;
            chart_ascii=((draw_x-10'd183)<10'd8) ? 8'h4A : 8'h33;
        end else if ((draw_x >= 10'd204) && (draw_x < 10'd220) &&
                     (draw_y >= 10'd326) && (draw_y < 10'd334)) begin
            chart_text_area=1'b1; chart_speed_text=1'b1;
            chart_text_row=draw_y-10'd326; chart_text_col=draw_x-10'd204;
            chart_ascii=((draw_x-10'd204)<10'd8) ? 8'h35 : 8'h35;
        end else if ((draw_x >= 10'd204) && (draw_x < 10'd220) &&
                     (draw_y >= 10'd344) && (draw_y < 10'd352)) begin
            chart_text_area=1'b1; chart_speed_text=1'b1;
            chart_text_row=draw_y-10'd344; chart_text_col=draw_x-10'd204;
            chart_ascii=((draw_x-10'd204)<10'd8) ? 8'h36 : 8'h30;
        end
    end
    font u_chart_font(.ascii(chart_ascii), .row(chart_text_row),
                      .bits(chart_text_bits));

    wire signal_1_box = (draw_x >= 10'd112) && (draw_x < 10'd146) &&
                        (draw_y >= 10'd52) && (draw_y < 10'd70);
    wire signal_2_box = (draw_x >= 10'd272) && (draw_x < 10'd306) &&
                        (draw_y >= 10'd52) && (draw_y < 10'd70);
    wire signal_3_box = (draw_x >= 10'd432) && (draw_x < 10'd466) &&
                        (draw_y >= 10'd52) && (draw_y < 10'd70);
    wire signal_box = signal_1_box || signal_2_box || signal_3_box;
    reg [9:0] signal_x0;
    reg signal_green;
    reg signal_yellow;
    always @* begin
        signal_x0 = 10'd0;
        signal_green = 1'b0;
        signal_yellow = 1'b0;
        if (signal_1_box) begin
            signal_x0 = 10'd112; signal_green = green_1; signal_yellow = yellow_1;
        end else if (signal_2_box) begin
            signal_x0 = 10'd272; signal_green = green_2; signal_yellow = yellow_2;
        end else if (signal_3_box) begin
            signal_x0 = 10'd432; signal_green = green_3; signal_yellow = yellow_3;
        end
    end
    wire signal_border = signal_box &&
        ((draw_x == signal_x0) || (draw_x == signal_x0+10'd33) ||
         (draw_y == 10'd52) || (draw_y == 10'd69));
    wire red_lamp = signal_box && (draw_x >= signal_x0+10'd3) &&
                    (draw_x < signal_x0+10'd11) &&
                    (draw_y >= 10'd57) && (draw_y < 10'd65);
    wire yellow_lamp = signal_box && (draw_x >= signal_x0+10'd13) &&
                       (draw_x < signal_x0+10'd21) &&
                       (draw_y >= 10'd57) && (draw_y < 10'd65);
    wire green_lamp = signal_box && (draw_x >= signal_x0+10'd23) &&
                      (draw_x < signal_x0+10'd31) &&
                      (draw_y >= 10'd57) && (draw_y < 10'd65);

    wire fast_body = (draw_x >= fast_car_x) && (draw_x < fast_car_x+10'd24) &&
                      (draw_y >= 10'd98) && (draw_y < 10'd114);
    // Tidal lanes are ordered top-to-bottom as 60, 58, 55 km/h.
    wire wave60_body = (draw_x >= wave60_car_x) && (draw_x < wave60_car_x+10'd24) &&
                      (draw_y >= 10'd134) && (draw_y < 10'd150);
    wire wave58_body = (draw_x >= wave58_car_x) && (draw_x < wave58_car_x+10'd24) &&
                       (draw_y >= 10'd170) && (draw_y < 10'd186);
    wire wave55_body = (draw_x >= wave55_car_x) && (draw_x < wave55_car_x+10'd24) &&
                       (draw_y >= 10'd206) && (draw_y < 10'd222);
    wire slow_body = (draw_x >= slow_car_x) && (draw_x < slow_car_x+10'd24) &&
                      (draw_y >= 10'd242) && (draw_y < 10'd258);
    wire car_glass = ((draw_x >= fast_car_x+10'd15) && (draw_x < fast_car_x+10'd20) &&
                      (draw_y >= 10'd101) && (draw_y < 10'd111)) ||
                     ((draw_x >= wave60_car_x+10'd15) && (draw_x < wave60_car_x+10'd20) &&
                      (draw_y >= 10'd137) && (draw_y < 10'd147)) ||
                     ((draw_x >= wave58_car_x+10'd15) && (draw_x < wave58_car_x+10'd20) &&
                      (draw_y >= 10'd173) && (draw_y < 10'd183)) ||
                     ((draw_x >= wave55_car_x+10'd15) && (draw_x < wave55_car_x+10'd20) &&
                      (draw_y >= 10'd209) && (draw_y < 10'd219)) ||
                     ((draw_x >= slow_car_x+10'd15) && (draw_x < slow_car_x+10'd20) &&
                      (draw_y >= 10'd245) && (draw_y < 10'd255));

    always @* begin
        pix_data = bg_data;
        if (!USE_BG_IMAGE && any_road)
            pix_data = ROAD;
        if (!USE_BG_IMAGE && main_road && (draw_y >= 10'd129) && (draw_y < 10'd234))
            pix_data = LANE_GREEN;
        if (!USE_BG_IMAGE && (main_edge || lane_dash || cross_edge || cross_dash || stop_lines))
            pix_data = WHITE;
        if (signal_box)
            pix_data = BACK;
        if (signal_border)
            pix_data = WHITE;
        if (red_lamp)
            pix_data = (!signal_green && !signal_yellow) ? RED : DIM_LAMP;
        if (yellow_lamp)
            pix_data = signal_yellow ? YELLOW : DIM_LAMP;
        if (green_lamp)
            pix_data = signal_green ? GREEN : DIM_LAMP;
        if (fast_body)
            pix_data = FAST_CAR;
        if (wave55_body || wave58_body || wave60_body)
            pix_data = WAVE_CAR;
        if (slow_body)
            pix_data = SLOW_CAR;
        if (car_glass)
            pix_data = GLASS;
        if (car_speed_text_area && car_speed_bits[7-car_speed_col])
            pix_data = car_speed_color;
        if (title_area && title_bits[7-title_col])
            pix_data = GREEN;
        if (speed_text_area && speed_text_bits[7-draw_x[2:0]])
            pix_data = WHITE;
    end
endmodule

