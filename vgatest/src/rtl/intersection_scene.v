`timescale 1ns / 1ps

// Resource-conscious four-way adaptive intersection page. Twelve vehicle
// routes share one signal controller and the same piecewise-linear renderer.
module intersection_scene (
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire        move_tick,
    input  wire        enable,
    input  wire [1:0]  lr_level,
    input  wire [1:0]  tb_level,
    input  wire        ped_high,
    input  wire        adaptive_mode,
    input  wire        force_phase,
    input  wire        uart_rx_valid,
    input  wire [7:0]  uart_rx_byte,
    output reg  [15:0] pix_data
);
    localparam [15:0] BLACK   = 16'h0000;
    localparam [15:0] ROAD    = 16'h2945;
    localparam [15:0] WHITE   = 16'hFFFF;
    localparam [15:0] YELLOW  = 16'hFFE0;
    localparam [15:0] RED     = 16'hF800;
    localparam [15:0] GREEN   = 16'h07E0;
    localparam [15:0] DIM     = 16'h0841;
    localparam [15:0] LR_CAR  = 16'hFA20;
    localparam [15:0] TB_CAR  = 16'h05FF;
    localparam [15:0] GLASS   = 16'hBDF7;
    localparam [15:0] PED     = 16'hFFFF;

    localparam [1:0] ST_GREEN = 2'd0;
    localparam [1:0] ST_YELLOW = 2'd1;
    localparam [1:0] ST_ALL_RED = 2'd2;

    reg [9:0] draw_x, draw_y;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            draw_x <= 10'd0;
            draw_y <= 10'd0;
        end else begin
            draw_x <= pix_x;
            draw_y <= pix_y;
        end
    end

    // UART commands are compatible with the original crossroad page:
    // LRS/LRL/LRR/TBS/TBL/TBR=<seconds> followed by CR, LF, or ';'.
    wire [7:0] cfg_lrs, cfg_lrl, cfg_lrr;
    wire [7:0] cfg_tbs, cfg_tbl, cfg_tbr;
    wire cfg_lrs_up, cfg_lrl_up, cfg_lrr_up;
    wire cfg_tbs_up, cfg_tbl_up, cfg_tbr_up;
    cfg_uart_simple #(
        .DEF_LRS(8'd40), .DEF_LRL(8'd30), .DEF_LRR(8'd20),
        .DEF_TBS(8'd40), .DEF_TBL(8'd30), .DEF_TBR(8'd20)
    ) u_cross_cfg (
        .clk(vga_clk), .rst_n(sys_rst_n),
        .rx_valid(uart_rx_valid), .rx_data(uart_rx_byte),
        .LRS(cfg_lrs), .LRL(cfg_lrl), .LRR(cfg_lrr),
        .TBS(cfg_tbs), .TBL(cfg_tbl), .TBR(cfg_tbr),
        .LRS_up(cfg_lrs_up), .LRL_up(cfg_lrl_up), .LRR_up(cfg_lrr_up),
        .TBS_up(cfg_tbs_up), .TBL_up(cfg_tbl_up), .TBR_up(cfg_tbr_up)
    );

    function [7:0] clamp_duration;
        input [7:0] base;
        input [1:0] own_level;
        input [1:0] other_level;
        input       pedestrian_high;
        reg [9:0] adjusted;
        begin
            adjusted = {2'd0, base};
            if (adaptive_mode) begin
                if (own_level > other_level)
                    adjusted = adjusted + 10'd10;
                else if ((own_level < other_level) && (adjusted > 10'd10))
                    adjusted = adjusted - 10'd5;
                if (pedestrian_high)
                    adjusted = adjusted + 10'd5;
            end
            if (adjusted < 10'd5)
                clamp_duration = 8'd5;
            else if (adjusted > 10'd99)
                clamp_duration = 8'd99;
            else
                clamp_duration = adjusted[7:0];
        end
    endfunction

    reg [5:0] move_div;
    reg [7:0] second_count;
    wire second_tick = move_tick && (move_div == 6'd29);
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n || !enable)
            move_div <= 6'd0;
        else if (move_tick)
            move_div <= (move_div == 6'd29) ? 6'd0 : move_div + 1'b1;
    end

    reg [2:0] phase_group; // 0/1/2=LR S/L/R, 3/4/5=TB S/L/R
    reg [1:0] light_stage;
    reg [7:0] stage_elapsed;
    reg [7:0] green_duration;
    reg force_phase_d;
    wire force_phase_edge = force_phase ^ force_phase_d;

    function [7:0] selected_duration;
        input [2:0] group_id;
        begin
            case (group_id)
                3'd0: selected_duration = clamp_duration(cfg_lrs, lr_level, tb_level, ped_high);
                3'd1: selected_duration = clamp_duration(cfg_lrl, lr_level, tb_level, 1'b0);
                3'd2: selected_duration = clamp_duration(cfg_lrr, lr_level, tb_level, 1'b0);
                3'd3: selected_duration = clamp_duration(cfg_tbs, tb_level, lr_level, ped_high);
                3'd4: selected_duration = clamp_duration(cfg_tbl, tb_level, lr_level, 1'b0);
                default: selected_duration = clamp_duration(cfg_tbr, tb_level, lr_level, 1'b0);
            endcase
        end
    endfunction

    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n || !enable) begin
            phase_group <= 3'd0;
            light_stage <= ST_GREEN;
            stage_elapsed <= 8'd0;
            green_duration <= 8'd40;
            force_phase_d <= force_phase;
            second_count <= 8'd0;
        end else begin
            force_phase_d <= force_phase;
            if (second_tick)
                second_count <= second_count + 1'b1;

            if (force_phase_edge && (light_stage == ST_GREEN)) begin
                light_stage <= ST_YELLOW;
                stage_elapsed <= 8'd0;
            end else if (second_tick) begin
                case (light_stage)
                    ST_GREEN: begin
                        if (stage_elapsed + 1'b1 >= green_duration) begin
                            light_stage <= ST_YELLOW;
                            stage_elapsed <= 8'd0;
                        end else
                            stage_elapsed <= stage_elapsed + 1'b1;
                    end
                    ST_YELLOW: begin
                        if (stage_elapsed >= 8'd2) begin
                            light_stage <= ST_ALL_RED;
                            stage_elapsed <= 8'd0;
                        end else
                            stage_elapsed <= stage_elapsed + 1'b1;
                    end
                    default: begin
                        if (stage_elapsed >= 8'd0) begin
                            phase_group <= (phase_group == 3'd5) ? 3'd0 : phase_group + 1'b1;
                            light_stage <= ST_GREEN;
                            stage_elapsed <= 8'd0;
                            green_duration <= selected_duration(
                                (phase_group == 3'd5) ? 3'd0 : phase_group + 1'b1);
                        end
                    end
                endcase
            end
        end
    end

    wire group_green = (light_stage == ST_GREEN);
    wire group_yellow = (light_stage == ST_YELLOW);
    wire lrs_green = group_green && (phase_group == 3'd0);
    wire lrl_green = group_green && (phase_group == 3'd1);
    wire lrr_green = group_green && (phase_group == 3'd2);
    wire tbs_green = group_green && (phase_group == 3'd3);
    wire tbl_green = group_green && (phase_group == 3'd4);
    wire tbr_green = group_green && (phase_group == 3'd5);

    function route_green;
        input [3:0] route;
        begin
            case (route)
                4'd0, 4'd3: route_green = lrs_green;
                4'd1, 4'd4: route_green = lrl_green;
                4'd2, 4'd5: route_green = lrr_green;
                4'd6, 4'd9: route_green = tbs_green;
                4'd7, 4'd10: route_green = tbl_green;
                default: route_green = tbr_green;
            endcase
        end
    endfunction

    function [3:0] active_cars;
        input [1:0] level;
        begin
            active_cars = (level == 2'd0) ? 4'd2 :
                          (level == 2'd2) ? 4'd6 : 4'd4;
        end
    endfunction

    function [3:0] route_speed;
        input [1:0] level;
        begin
            route_speed = (level == 2'd0) ? 4'd5 :
                          (level == 2'd2) ? 4'd3 : 4'd4;
        end
    endfunction

    // Six cars are retained for every one of the twelve movements. A shared
    // update rule replaces the original per-route state-machine duplication.
    reg [9:0] car_progress [0:11][0:5];
    integer route_i, car_i;
    integer stop_progress;
    reg [3:0] step_now;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n || !enable) begin
            for (route_i=0; route_i<12; route_i=route_i+1)
                for (car_i=0; car_i<6; car_i=car_i+1)
                    car_progress[route_i][car_i] <= (route_i*17 + car_i*120) % 760;
        end else if (move_tick) begin
            for (route_i=0; route_i<12; route_i=route_i+1) begin
                step_now = route_speed((route_i < 6) ? lr_level : tb_level);
                for (car_i=0; car_i<6; car_i=car_i+1) begin
                    stop_progress = 260 - car_i*22;
                    if (!route_green(route_i[3:0]) &&
                        (car_progress[route_i][car_i] <= stop_progress) &&
                        (car_progress[route_i][car_i] + step_now >= stop_progress))
                        car_progress[route_i][car_i] <= stop_progress;
                    else if (car_progress[route_i][car_i] >= 10'd756)
                        car_progress[route_i][car_i] <= car_progress[route_i][car_i] - 10'd756;
                    else
                        car_progress[route_i][car_i] <= car_progress[route_i][car_i] + step_now;
                end
            end
        end
    end

    function vehicle_hit;
        input [3:0] route;
        input [9:0] progress;
        input [9:0] sample_x;
        input [9:0] sample_y;
        integer cx, cy, q;
        begin
            cx = -40;
            cy = -40;
            q = progress - 260;
            case (route)
                4'd0: begin cx=progress-40; cy=10'd285; end // L straight
                4'd1: begin // L to north
                    if (progress<260) begin cx=progress-40; cy=245; end
                    else if (progress<320) begin cx=220+q; cy=245-q; end
                    else begin cx=280; cy=185-(progress-320); end
                end
                4'd2: begin // L to south
                    if (progress<260) begin cx=progress-40; cy=305; end
                    else if (progress<320) begin cx=220+q; cy=305+q; end
                    else begin cx=280; cy=365+(progress-320); end
                end
                4'd3: begin cx=680-progress; cy=10'd195; end // R straight
                4'd4: begin // R to south
                    if (progress<260) begin cx=680-progress; cy=235; end
                    else if (progress<320) begin cx=420-q; cy=235+q; end
                    else begin cx=360; cy=295+(progress-320); end
                end
                4'd5: begin // R to north
                    if (progress<260) begin cx=680-progress; cy=175; end
                    else if (progress<320) begin cx=420-q; cy=175-q; end
                    else begin cx=360; cy=115-(progress-320); end
                end
                4'd6: begin cx=10'd365; cy=progress-40; end // T straight
                4'd7: begin // T to east
                    if (progress<260) begin cx=325; cy=progress-40; end
                    else if (progress<320) begin cx=325+q; cy=220+q; end
                    else begin cx=385+(progress-320); cy=280; end
                end
                4'd8: begin // T to west
                    if (progress<260) begin cx=385; cy=progress-40; end
                    else if (progress<320) begin cx=385-q; cy=220+q; end
                    else begin cx=325-(progress-320); cy=280; end
                end
                4'd9: begin cx=10'd275; cy=520-progress; end // B straight
                4'd10: begin // B to west
                    if (progress<260) begin cx=315; cy=520-progress; end
                    else if (progress<320) begin cx=315-q; cy=260-q; end
                    else begin cx=255-(progress-320); cy=200; end
                end
                default: begin // B to east
                    if (progress<260) begin cx=255; cy=520-progress; end
                    else if (progress<320) begin cx=255+q; cy=260-q; end
                    else begin cx=315+(progress-320); cy=200; end
                end
            endcase
            vehicle_hit = (sample_x >= cx-7) && (sample_x <= cx+7) &&
                          (sample_y >= cy-4) && (sample_y <= cy+4);
        end
    endfunction

    function vehicle_glass_hit;
        input [3:0] route;
        input [9:0] progress;
        input [9:0] sample_x;
        input [9:0] sample_y;
        integer cx, cy, q;
        begin
            cx = -40;
            cy = -40;
            q = progress - 260;
            case (route)
                4'd0: begin cx=progress-36; cy=285; end
                4'd1: if(progress<260) begin cx=progress-36;cy=245;end else if(progress<320) begin cx=224+q;cy=245-q;end else begin cx=280;cy=181-(progress-320);end
                4'd2: if(progress<260) begin cx=progress-36;cy=305;end else if(progress<320) begin cx=224+q;cy=305+q;end else begin cx=280;cy=369+(progress-320);end
                4'd3: begin cx=676-progress; cy=195; end
                4'd4: if(progress<260) begin cx=676-progress;cy=235;end else if(progress<320) begin cx=416-q;cy=235+q;end else begin cx=360;cy=299+(progress-320);end
                4'd5: if(progress<260) begin cx=676-progress;cy=175;end else if(progress<320) begin cx=416-q;cy=175-q;end else begin cx=360;cy=111-(progress-320);end
                4'd6: begin cx=365; cy=progress-36; end
                4'd7: if(progress<260) begin cx=325;cy=progress-36;end else if(progress<320) begin cx=325+q;cy=224+q;end else begin cx=389+(progress-320);cy=280;end
                4'd8: if(progress<260) begin cx=385;cy=progress-36;end else if(progress<320) begin cx=385-q;cy=224+q;end else begin cx=321-(progress-320);cy=280;end
                4'd9: begin cx=275; cy=516-progress; end
                4'd10: if(progress<260) begin cx=315;cy=516-progress;end else if(progress<320) begin cx=315-q;cy=256-q;end else begin cx=251-(progress-320);cy=200;end
                default: if(progress<260) begin cx=255;cy=516-progress;end else if(progress<320) begin cx=255+q;cy=256-q;end else begin cx=319+(progress-320);cy=200;end
            endcase
            vehicle_glass_hit = (sample_x >= cx-2) && (sample_x <= cx+2) &&
                                (sample_y >= cy-2) && (sample_y <= cy+2);
        end
    endfunction

    reg lr_car_hit, tb_car_hit, glass_hit;
    integer draw_route, draw_car;
    always @* begin
        lr_car_hit = 1'b0;
        tb_car_hit = 1'b0;
        glass_hit = 1'b0;
        for (draw_route=0; draw_route<12; draw_route=draw_route+1) begin
            for (draw_car=0; draw_car<6; draw_car=draw_car+1) begin
                if (draw_car < active_cars((draw_route<6) ? lr_level : tb_level)) begin
                    if (vehicle_hit(draw_route[3:0], car_progress[draw_route][draw_car], draw_x, draw_y)) begin
                        if (draw_route < 6) lr_car_hit = 1'b1;
                        else tb_car_hit = 1'b1;
                    end
                    if (vehicle_glass_hit(draw_route[3:0], car_progress[draw_route][draw_car], draw_x, draw_y))
                        glass_hit = 1'b1;
                end
            end
        end
    end

    // Pedestrians cross parallel to the active straight-through phase.
    wire [4:0] ped_count = ped_high ? 5'd10 : 5'd4;
    reg [7:0] ped_phase;
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n || !enable)
            ped_phase <= 8'd0;
        else if (move_tick && (lrs_green || tbs_green))
            ped_phase <= (ped_phase == 8'd199) ? 8'd0 : ped_phase + 1'b1;
    end

    reg pedestrian_hit;
    integer ped_i;
    integer ped_offset;
    always @* begin
        pedestrian_hit = 1'b0;
        for (ped_i=0; ped_i<10; ped_i=ped_i+1) begin
            if (ped_i < ped_count) begin
                ped_offset = ped_phase + ped_i*17;
                if (ped_offset >= 200)
                    ped_offset = ped_offset - 200;
                if (lrs_green) begin
                    if ((draw_x>=10'd216+ped_offset) && (draw_x<10'd219+ped_offset) &&
                        ((draw_y>=10'd142 && draw_y<10'd147) ||
                         (draw_y>=10'd333 && draw_y<10'd338)))
                        pedestrian_hit = 1'b1;
                end else begin
                    if ((draw_x>=10'd210-(ped_i/2)*4) &&
                        (draw_x< 10'd213-(ped_i/2)*4) &&
                        (((ped_i & 1)==0 && draw_y>=10'd142 && draw_y<10'd147) ||
                         ((ped_i & 1)!=0 && draw_y>=10'd333 && draw_y<10'd338)))
                        pedestrian_hit = 1'b1;
                end
                if (tbs_green) begin
                    if ((draw_y>=10'd136+ped_offset) && (draw_y<10'd139+ped_offset) &&
                        ((draw_x>=10'd218 && draw_x<10'd223) ||
                         (draw_x>=10'd417 && draw_x<10'd422)))
                        pedestrian_hit = 1'b1;
                end else begin
                    if ((draw_y>=10'd130-(ped_i/2)*4) &&
                        (draw_y< 10'd133-(ped_i/2)*4) &&
                        (((ped_i & 1)==0 && draw_x>=10'd218 && draw_x<10'd223) ||
                         ((ped_i & 1)!=0 && draw_x>=10'd417 && draw_x<10'd422)))
                        pedestrian_hit = 1'b1;
                end
            end
        end
    end

    wire h_road = (draw_y >= 10'd150) && (draw_y < 10'd330);
    wire v_road = (draw_x >= 10'd230) && (draw_x < 10'd410);
    wire road_area = h_road || v_road;
    wire road_edge = ((draw_y>=10'd150)&&(draw_y<10'd153)) ||
                     ((draw_y>=10'd327)&&(draw_y<10'd330)) ||
                     ((draw_x>=10'd230)&&(draw_x<10'd233)) ||
                     ((draw_x>=10'd407)&&(draw_x<10'd410));
    wire lane_dash = (((draw_y>=10'd238)&&(draw_y<10'd241)) && h_road &&
                      !v_road && (draw_x[4:0]<5'd15)) ||
                     (((draw_x>=10'd318)&&(draw_x<10'd321)) && v_road &&
                      !h_road && (draw_y[4:0]<5'd15));
    wire stop_lines = (((draw_x>=10'd216)&&(draw_x<10'd220)) && h_road) ||
                      (((draw_x>=10'd420)&&(draw_x<10'd424)) && h_road) ||
                      (((draw_y>=10'd136)&&(draw_y<10'd140)) && v_road) ||
                      (((draw_y>=10'd340)&&(draw_y<10'd344)) && v_road);
    wire zebra = ((((draw_x>=10'd204)&&(draw_x<10'd216)) ||
                    ((draw_x>=10'd424)&&(draw_x<10'd436))) && h_road &&
                   (draw_y[3:0]<4'd8)) ||
                  ((((draw_y>=10'd124)&&(draw_y<10'd136)) ||
                    ((draw_y>=10'd344)&&(draw_y<10'd356))) && v_road &&
                   (draw_x[3:0]<4'd8));

    // Six compact signal heads show the current movement-group colors.
    wire signal_box = ((draw_x>=10'd12)&&(draw_x<10'd114)&&(draw_y>=10'd112)&&(draw_y<10'd136)) ||
                      ((draw_x>=10'd526)&&(draw_x<10'd628)&&(draw_y>=10'd344)&&(draw_y<10'd368)) ||
                      ((draw_x>=10'd420)&&(draw_x<10'd444)&&(draw_y>=10'd12)&&(draw_y<10'd114)) ||
                      ((draw_x>=10'd196)&&(draw_x<10'd220)&&(draw_y>=10'd366)&&(draw_y<10'd468));
    wire signal_border = signal_box &&
                         ((draw_x==10'd12)||(draw_x==10'd113)||
                          (draw_x==10'd526)||(draw_x==10'd627)||
                          (draw_x==10'd420)||(draw_x==10'd443)||
                          (draw_x==10'd196)||(draw_x==10'd219)||
                          (draw_y==10'd112)||(draw_y==10'd135)||
                          (draw_y==10'd344)||(draw_y==10'd367)||
                          (draw_y==10'd12)||(draw_y==10'd113)||
                          (draw_y==10'd366)||(draw_y==10'd467));

    function [15:0] lamp_color;
        input [2:0] group_id;
        begin
            if (phase_group == group_id)
                lamp_color = group_green ? GREEN : (group_yellow ? YELLOW : RED);
            else
                lamp_color = RED;
        end
    endfunction

    reg lamp_hit;
    reg [15:0] lamp_rgb;
    integer lamp_slot;
    always @* begin
        lamp_hit = 1'b0;
        lamp_rgb = DIM;
        if ((draw_y>=10'd119)&&(draw_y<10'd129)) begin
            for (lamp_slot=0; lamp_slot<3; lamp_slot=lamp_slot+1) begin
                if ((draw_x>=10'd20+lamp_slot*30)&&(draw_x<10'd30+lamp_slot*30)) begin
                    lamp_hit=1'b1; lamp_rgb=lamp_color(lamp_slot[2:0]);
                end
            end
        end
        if ((draw_y>=10'd351)&&(draw_y<10'd361)) begin
            for (lamp_slot=0; lamp_slot<3; lamp_slot=lamp_slot+1) begin
                if ((draw_x>=10'd534+lamp_slot*30)&&(draw_x<10'd544+lamp_slot*30)) begin
                    lamp_hit=1'b1; lamp_rgb=lamp_color(lamp_slot[2:0]);
                end
            end
        end
        if ((draw_x>=10'd427)&&(draw_x<10'd437)) begin
            for (lamp_slot=0; lamp_slot<3; lamp_slot=lamp_slot+1) begin
                if ((draw_y>=10'd20+lamp_slot*30)&&(draw_y<10'd30+lamp_slot*30)) begin
                    lamp_hit=1'b1; lamp_rgb=lamp_color(lamp_slot[2:0]+3'd3);
                end
            end
        end
        if ((draw_x>=10'd203)&&(draw_x<10'd213)) begin
            for (lamp_slot=0; lamp_slot<3; lamp_slot=lamp_slot+1) begin
                if ((draw_y>=10'd374+lamp_slot*30)&&(draw_y<10'd384+lamp_slot*30)) begin
                    lamp_hit=1'b1; lamp_rgb=lamp_color(lamp_slot[2:0]+3'd3);
                end
            end
        end
    end

    // One shared font renderer draws the title, demand/status panel and all
    // six configured green durations.
    reg [7:0] text_ascii;
    reg [2:0] text_row;
    reg [2:0] text_col;
    reg text_area;
    reg [4:0] text_slot;
    reg [7:0] shown_value;
    reg [3:0] duration_text_row;
    wire [7:0] text_bits;
    font u_cross_font(.ascii(text_ascii), .row(text_row), .bits(text_bits));

    function [7:0] level_char;
        input [1:0] level;
        begin
            level_char = (level==2'd0) ? 8'h4C :
                         (level==2'd2) ? 8'h48 : 8'h4D; // L/M/H
        end
    endfunction

    always @* begin
        text_ascii = 8'h20;
        text_row = 3'd0;
        text_col = 3'd0;
        text_area = 1'b0;
        text_slot = 5'd0;
        shown_value = 8'd0;
        duration_text_row = 4'd0;

        if ((draw_x>=10'd168)&&(draw_x<10'd472)&&(draw_y>=10'd4)&&(draw_y<10'd20)) begin
            text_area=1'b1; text_row=(draw_y-10'd4)>>1;
            text_slot=(draw_x-10'd168)>>4; text_col=(draw_x-10'd168)>>1;
            case(text_slot)
                0:text_ascii="S"; 1:text_ascii="M"; 2:text_ascii="A";
                3:text_ascii="R"; 4:text_ascii="T";
                6:text_ascii="I"; 7:text_ascii="N"; 8:text_ascii="T";
                9:text_ascii="E"; 10:text_ascii="R"; 11:text_ascii="S";
                12:text_ascii="E"; 13:text_ascii="C"; 14:text_ascii="T";
                15:text_ascii="I"; 16:text_ascii="O"; 17:text_ascii="N";
                default:text_ascii=8'h20;
            endcase
        end else if ((draw_x>=10'd8)&&(draw_x<10'd152)&&(draw_y>=10'd28)&&(draw_y<10'd36)) begin
            text_area=1'b1; text_row=draw_y-10'd28;
            text_slot=(draw_x-10'd8)>>3; text_col=draw_x-10'd8;
            case(text_slot)
                0:text_ascii="M";1:text_ascii="O";2:text_ascii="D";3:text_ascii="E";
                4:text_ascii=":";6:text_ascii=adaptive_mode?"A":"M";
                default:text_ascii=8'h20;
            endcase
        end else if ((draw_x>=10'd8)&&(draw_x<10'd104)&&(draw_y>=10'd42)&&(draw_y<10'd50)) begin
            text_area=1'b1; text_row=draw_y-10'd42;
            text_slot=(draw_x-10'd8)>>3; text_col=draw_x-10'd8;
            case(text_slot)
                0:text_ascii="L";1:text_ascii="R";2:text_ascii=":";
                4:text_ascii=level_char(lr_level); default:text_ascii=8'h20;
            endcase
        end else if ((draw_x>=10'd8)&&(draw_x<10'd104)&&(draw_y>=10'd56)&&(draw_y<10'd64)) begin
            text_area=1'b1; text_row=draw_y-10'd56;
            text_slot=(draw_x-10'd8)>>3; text_col=draw_x-10'd8;
            case(text_slot)
                0:text_ascii="T";1:text_ascii="B";2:text_ascii=":";
                4:text_ascii=level_char(tb_level); default:text_ascii=8'h20;
            endcase
        end else if ((draw_x>=10'd8)&&(draw_x<10'd104)&&(draw_y>=10'd70)&&(draw_y<10'd78)) begin
            text_area=1'b1; text_row=draw_y-10'd70;
            text_slot=(draw_x-10'd8)>>3; text_col=draw_x-10'd8;
            case(text_slot)
                0:text_ascii="P";1:text_ascii="E";2:text_ascii="D";3:text_ascii=":";
                5:text_ascii=ped_high?"H":"L"; default:text_ascii=8'h20;
            endcase
        end else if ((draw_x>=10'd488)&&(draw_x<10'd632)&&(draw_y>=10'd28)&&(draw_y<10'd112)) begin
            duration_text_row=(draw_y-10'd28)%14;
            text_area=(duration_text_row < 4'd8);
            text_row=duration_text_row[2:0];
            text_slot=(draw_x-10'd488)>>3;
            text_col=draw_x-10'd488;
            case((draw_y-10'd28)/14)
                0: begin shown_value=cfg_lrs; text_ascii=(text_slot==0)?"L":(text_slot==1)?"R":(text_slot==2)?"S":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
                1: begin shown_value=cfg_lrl; text_ascii=(text_slot==0)?"L":(text_slot==1)?"R":(text_slot==2)?"L":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
                2: begin shown_value=cfg_lrr; text_ascii=(text_slot==0)?"L":(text_slot==1)?"R":(text_slot==2)?"R":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
                3: begin shown_value=cfg_tbs; text_ascii=(text_slot==0)?"T":(text_slot==1)?"B":(text_slot==2)?"S":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
                4: begin shown_value=cfg_tbl; text_ascii=(text_slot==0)?"T":(text_slot==1)?"B":(text_slot==2)?"L":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
                default: begin shown_value=cfg_tbr; text_ascii=(text_slot==0)?"T":(text_slot==1)?"B":(text_slot==2)?"R":(text_slot==3)?":":(text_slot==5)?(8'h30+shown_value/10):(text_slot==6)?(8'h30+shown_value%10):8'h20; end
            endcase
        end
    end
    wire text_pixel = text_area && text_bits[7-text_col[2:0]];

    always @* begin
        pix_data = BLACK;
        if (road_area)
            pix_data = ROAD;
        if (road_edge || lane_dash || stop_lines || zebra)
            pix_data = WHITE;
        if (signal_box)
            pix_data = BLACK;
        if (signal_border)
            pix_data = WHITE;
        if (lamp_hit)
            pix_data = lamp_rgb;
        if (lr_car_hit)
            pix_data = LR_CAR;
        if (tb_car_hit)
            pix_data = TB_CAR;
        if (glass_hit)
            pix_data = GLASS;
        if (pedestrian_hit)
            pix_data = PED;
        if (text_pixel)
            pix_data = WHITE;
    end

    wire unused_updates = cfg_lrs_up ^ cfg_lrl_up ^ cfg_lrr_up ^
                          cfg_tbs_up ^ cfg_tbl_up ^ cfg_tbr_up ^
                          second_count[0];
endmodule
