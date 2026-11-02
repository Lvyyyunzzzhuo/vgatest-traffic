`timescale 1ns / 1ps

module vga_colorbar(
    input  wire       sys_clk,
    input  wire       key_in,          // left-flow amount: low/normal/high
    input  wire       key_model,       // right-flow amount: low/normal/high
    input  wire       ped_sw_1,
    input  wire       car_sw,          // mode demo: smart -> morning -> evening
    input  wire       car_sw2,         // edge toggle: force tidal direction reversal
    input  wire       mode_adapt_sw,   // lock switch: each press toggles manual lock
    input  wire       uart_rx_pin,
    output wire       uart_tx_pin,
    output wire       hsync,
    output wire       vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);
    wire vga_clk;
    wire locked;
    wire rst_n = locked;

    clk_wiz_0 u_clk (
        .clk_out1(vga_clk), .reset(1'b0),
        .locked(locked), .clk_in1(sys_clk)
    );

    // Receive and parse host commands in the 100 MHz domain. This parser drives
    // the same control registers as the board buttons.
    localparam [3:0] CMD_DUMP          = 4'd1;
    localparam [3:0] CMD_CLEAR         = 4'd2;
    localparam [3:0] CMD_MODE_ADAPTIVE = 4'd3;
    localparam [3:0] CMD_MODE_MORNING  = 4'd4;
    localparam [3:0] CMD_MODE_EVENING  = 4'd5;
    localparam [3:0] CMD_MODE_HOLD     = 4'd6;
    localparam [3:0] CMD_LOCK_ON       = 4'd7;
    localparam [3:0] CMD_LOCK_OFF      = 4'd8;
    localparam [3:0] CMD_FORCE_SWITCH  = 4'd9;

    wire uart_rx_valid_sys;
    wire [7:0] uart_rx_data_sys;
    uart_rx #(.CLK_HZ(100_000_000), .BAUD(115200)) u_uart_rx (
        .clk(sys_clk), .rst_n(rst_n), .rx(uart_rx_pin),
        .valid(uart_rx_valid_sys), .data(uart_rx_data_sys)
    );

    wire uart_command_valid_sys;
    wire [3:0] uart_command_sys;
    uart_command_parser u_uart_command_parser (
        .clk(sys_clk), .rst_n(rst_n),
        .byte_valid(uart_rx_valid_sys), .byte_data(uart_rx_data_sys),
        .command_valid(uart_command_valid_sys), .command_code(uart_command_sys)
    );
    wire [7:0] ascii_lrs, ascii_lrl, ascii_lrr, ascii_tbs, ascii_tbl, ascii_tbr;
    wire ascii_lrs_up, ascii_lrl_up, ascii_lrr_up, ascii_tbs_up, ascii_tbl_up, ascii_tbr_up;
    cfg_uart_simple u_ascii_cross_cfg (
        .clk(sys_clk), .rst_n(rst_n), .rx_valid(uart_rx_valid_sys), .rx_data(uart_rx_data_sys),
        .LRS(ascii_lrs), .LRL(ascii_lrl), .LRR(ascii_lrr),
        .TBS(ascii_tbs), .TBL(ascii_tbl), .TBR(ascii_tbr),
        .LRS_up(ascii_lrs_up), .LRL_up(ascii_lrl_up), .LRR_up(ascii_lrr_up),
        .TBS_up(ascii_tbs_up), .TBL_up(ascii_tbl_up), .TBR_up(ascii_tbr_up)
    );

    wire [9:0] pix_x, pix_y;
    wire [15:0] pix_data;
    wire [15:0] tidal_pix_data;
    wire [15:0] green_wave_pix_data;
    wire [15:0] green_wave_bg_data;
    green_wave_bg_rom u_green_wave_bg (
        .clk(vga_clk), .x(pix_x), .y(pix_y), .rgb(green_wave_bg_data)
    );
    wire [15:0] single_lane_pix_data;
    wire [15:0] intersection_pix_data;
    wire [15:0] traffic_lab_pix_data;
    wire [15:0] vga_rgb_int;
    // Preserve the source image's 4:3 aspect ratio in the 318-pixel-high area.
    // The 424x318 picture is centered, leaving 108 black pixels on each side.
    // Both axes use the same Q10 scale factor (1546/1024 ~= 640/424).
    // The last generated source coordinates are (638,478), so no labels are
    // clipped by an out-of-range address at the right or bottom boundary.
    wire photo_addr_area = (pix_x >= 10'd108) && (pix_x < 10'd532) &&
                           (pix_y >= 10'd162) && (pix_y < 10'd480);
    wire [9:0] photo_col = photo_addr_area ? (pix_x - 10'd108) : 10'd0;
    wire [9:0] photo_row = photo_addr_area ? (pix_y - 10'd162) : 10'd0;
    wire [20:0] photo_x_scaled = photo_col * 11'd1546;
    wire [20:0] photo_y_scaled = photo_row * 11'd1546;
    wire [9:0] photo_x = photo_x_scaled[19:10];
    wire [9:0] photo_y = photo_y_scaled[19:10];
    wire [18:0] photo_rom_addr = ({9'd0, photo_y} << 9) +
                                  ({9'd0, photo_y} << 7) + {9'd0, photo_x};
    wire [7:0] photo_rom_index;

    // The 640x480 indexed image is stored once and shared by the page logic.
    tidal_bg_rom u_tidal_bg_rom (
        .clka(vga_clk), .ena(1'b1),
        .addra(photo_rom_addr), .douta(photo_rom_index)
    );

    // The two board buttons independently cycle each side through 3/4/6 cars.
    wire left_key_flag;
    wire right_key_flag;
    wire lock_key_flag;
    wire mode_key_flag;
    wire force_key_flag;
    wire page_key_flag;
    reg [1:0] left_level_sys;
    reg [1:0] right_level_sys;
    reg       manual_lock_sys;
    reg [1:0] work_mode_sys; // 0=smart, 1=morning(left), 2=evening(right)
    reg [2:0] page_index_sys; // 0=tidal, 1=green-wave, 2=single, 3=intersection, 4=traffic lab
    reg [2:0] single_speed_sys; // 0..5 = 35,40,45,50,55,60 km/h
    reg       force_event_sys;
    reg       cross_lr_dense_sys;
    reg       cross_tb_dense_sys;
    reg       cross_ped_high_sys;
    reg       cross_adaptive_sys;
    reg [7:0] cross_lrs_sys, cross_lrl_sys, cross_lrr_sys;
    reg [7:0] cross_tbs_sys, cross_tbl_sys, cross_tbr_sys;
    reg [7:0] page_cmd_type_sys, page_cmd_page_sys, page_cmd_item_sys;
    reg [15:0] page_cmd_value_sys;
    reg page_cmd_toggle_sys;
    localparam [2:0] PAGE_LAST = 3'd4;

    localparam [7:0] PTYPE_SET = 8'h10, PTYPE_GET = 8'h11,
                     PTYPE_ACTION = 8'h12;
    wire proto_command_valid;
    wire [7:0] proto_command_type, proto_command_seq;
    wire [7:0] proto_command_page, proto_command_item;
    wire [15:0] proto_command_value;
    wire [7:0] proto_query_page, proto_query_item;
    reg [15:0] proto_query_value;
    reg proto_query_valid, proto_command_supported;
    wire protocol_tx, protocol_tx_select, protocol_tx_busy;
    wire legacy_tx, legacy_tx_busy;

    // Telemetry returned by the VGA-domain scene modules.
    wire [9:0] green_fast_x, green_wave55_x, green_wave58_x, green_wave60_x, green_slow_x;
    wire [2:0] green_light_bits;
    wire [9:0] single_car_x_out, single_time_out;
    wire single_waiting_out;
    wire [2:0] single_light_bits;
    wire [4:0] cross_car_lr_out, cross_car_tb_out;
    wire [4:0] cross_ped_lr_out, cross_ped_tb_out;
    wire [7:0] cross_green_lrs_out, cross_green_lrl_out, cross_green_lrr_out;
    wire [7:0] cross_green_tbs_out, cross_green_tbl_out, cross_green_tbr_out;
    wire [11:0] cross_light_bits;
    wire [6:0] lab_green_out, lab_red_out;
    wire [9:0] lab_length_out, lab_rate_out;
    wire lab_phase_out, lab_ctrl_out;
    wire [9:0] lab_avg_out, lab_max_out, lab_flow_out, lab_overflow_out;
    wire [9:0] lab_stops_out, lab_queue_out;
    reg [1:0] tidal_state_sys0, tidal_state_sys1;
    reg [1:0] tidal_dir_sys0, tidal_dir_sys1;
    reg [1:0] target_dir_sys0, target_dir_sys1;

    always @* begin
        proto_command_supported = 1'b0;
        if (proto_command_type == PTYPE_GET)
            proto_command_supported = proto_query_valid;
        else case (proto_command_page)
            8'hFF: proto_command_supported =
                (proto_command_type == PTYPE_SET) &&
                (proto_command_item == 0) && (proto_command_value <= 4);
            8'd0: begin
                case (proto_command_item)
                    0: proto_command_supported = (proto_command_type == PTYPE_SET) && (proto_command_value <= 3);
                    1,2: proto_command_supported = (proto_command_type == PTYPE_SET) && (proto_command_value <= 2);
                    3: proto_command_supported = (proto_command_type == PTYPE_SET) && (proto_command_value <= 1);
                    4: proto_command_supported = (proto_command_type == PTYPE_ACTION);
                    default: proto_command_supported = (proto_command_type == PTYPE_GET);
                endcase
            end
            8'd1: proto_command_supported = (proto_command_type == PTYPE_GET);
            8'd2: proto_command_supported =
                ((proto_command_item == 0) && (proto_command_type == PTYPE_SET) &&
                 ((proto_command_value == 35) || (proto_command_value == 40) ||
                  (proto_command_value == 45) || (proto_command_value == 50) ||
                  (proto_command_value == 55) || (proto_command_value == 60))) ||
                (proto_command_type == PTYPE_GET);
            8'd3: begin
                if (proto_command_item <= 3)
                    proto_command_supported = (proto_command_type == PTYPE_SET) || (proto_command_type == PTYPE_GET);
                else if ((proto_command_item >= 8'h10) && (proto_command_item <= 8'h15))
                    proto_command_supported = (proto_command_type == PTYPE_GET);
                else proto_command_supported = (proto_command_type == PTYPE_GET);
            end
            8'd4: begin
                case (proto_command_item)
                    0: proto_command_supported = ((proto_command_type == PTYPE_SET) &&
                        ((proto_command_value == 15) || (proto_command_value == 30) || (proto_command_value == 45))) || (proto_command_type == PTYPE_GET);
                    1: proto_command_supported = ((proto_command_type == PTYPE_SET) &&
                        ((proto_command_value == 30) || (proto_command_value == 45) || (proto_command_value == 60))) || (proto_command_type == PTYPE_GET);
                    2: proto_command_supported = ((proto_command_type == PTYPE_SET) &&
                        ((proto_command_value == 80) || (proto_command_value == 200) || (proto_command_value == 500))) || (proto_command_type == PTYPE_GET);
                    3: proto_command_supported = ((proto_command_type == PTYPE_SET) &&
                        ((proto_command_value == 600) || (proto_command_value == 900))) || (proto_command_type == PTYPE_GET);
                    4,5: proto_command_supported = ((proto_command_type == PTYPE_SET) && (proto_command_value <= 1)) || (proto_command_type == PTYPE_GET);
                    6: proto_command_supported = (proto_command_type == PTYPE_ACTION);
                    default: proto_command_supported = (proto_command_type == PTYPE_GET);
                endcase
            end
            default: proto_command_supported = 1'b0;
        endcase
    end

    always @* begin
        proto_query_valid = 1'b1;
        proto_query_value = 16'd0;
        case (proto_query_page)
            8'hFF: if (proto_query_item == 0) proto_query_value = {13'd0,page_index_sys}; else proto_query_valid = 1'b0;
            8'd0: case (proto_query_item)
                0: proto_query_value = {14'd0,work_mode_sys};
                1: proto_query_value = {14'd0,left_level_sys};
                2: proto_query_value = {14'd0,right_level_sys};
                3: proto_query_value = {15'd0,manual_lock_sys};
                8'h20: proto_query_value = {14'd0,tidal_state_sys1};
                8'h21: proto_query_value = {14'd0,tidal_dir_sys1};
                8'h22: proto_query_value = {14'd0,target_dir_sys1};
                default: proto_query_valid = 1'b0;
            endcase
            8'd1: case (proto_query_item)
                0: proto_query_value = green_fast_x;
                1: proto_query_value = green_wave55_x;
                2: proto_query_value = green_wave58_x;
                3: proto_query_value = green_wave60_x;
                4: proto_query_value = green_slow_x;
                8'h20: proto_query_value = {13'd0,green_light_bits};
                default: proto_query_valid = 1'b0;
            endcase
            8'd2: case (proto_query_item)
                0: proto_query_value = (single_speed_sys==0)?35:(single_speed_sys==1)?40:(single_speed_sys==2)?45:(single_speed_sys==3)?50:(single_speed_sys==4)?55:60;
                8'h20: proto_query_value = single_car_x_out;
                8'h21: proto_query_value = single_time_out;
                8'h22: proto_query_value = {15'd0,single_waiting_out};
                8'h23: proto_query_value = {13'd0,single_light_bits};
                default: proto_query_valid = 1'b0;
            endcase
            8'd3: case (proto_query_item)
                0: proto_query_value = {15'd0,cross_lr_dense_sys};
                1: proto_query_value = {15'd0,cross_tb_dense_sys};
                2: proto_query_value = cross_ped_high_sys ? 16'd10 : 16'd4;
                3: proto_query_value = {15'd0,cross_adaptive_sys};
                8'h10: proto_query_value = cross_green_lrs_out;
                8'h11: proto_query_value = cross_green_lrl_out;
                8'h12: proto_query_value = cross_green_lrr_out;
                8'h13: proto_query_value = cross_green_tbs_out;
                8'h14: proto_query_value = cross_green_tbl_out;
                8'h15: proto_query_value = cross_green_tbr_out;
                8'h20: proto_query_value = cross_car_lr_out;
                8'h21: proto_query_value = cross_car_tb_out;
                8'h22: proto_query_value = cross_ped_lr_out;
                8'h23: proto_query_value = cross_ped_tb_out;
                8'h24: proto_query_value = cross_light_bits;
                default: proto_query_valid = 1'b0;
            endcase
            8'd4: case (proto_query_item)
                0: proto_query_value = lab_green_out;
                1: proto_query_value = lab_red_out;
                2: proto_query_value = lab_length_out;
                3: proto_query_value = lab_rate_out;
                4: proto_query_value = {15'd0,lab_phase_out};
                5: proto_query_value = {15'd0,lab_ctrl_out};
                8'h20: proto_query_value = lab_avg_out;
                8'h21: proto_query_value = lab_max_out;
                8'h22: proto_query_value = lab_flow_out;
                8'h23: proto_query_value = lab_overflow_out;
                8'h24: proto_query_value = lab_stops_out;
                8'h25: proto_query_value = lab_queue_out;
                default: proto_query_valid = 1'b0;
            endcase
            default: proto_query_valid = 1'b0;
        endcase
    end

    uart_protocol u_uart_protocol (
        .clk(sys_clk), .rst_n(rst_n),
        .rx_valid(uart_rx_valid_sys), .rx_data(uart_rx_data_sys),
        .legacy_tx_busy(legacy_tx_busy), .current_page(page_index_sys),
        .command_valid(proto_command_valid), .command_type(proto_command_type),
        .command_seq(proto_command_seq), .command_page(proto_command_page),
        .command_item(proto_command_item), .command_value(proto_command_value),
        .command_supported(proto_command_supported),
        .query_page(proto_query_page), .query_item(proto_query_item),
        .query_value(proto_query_value), .query_valid(proto_query_valid),
        .tx(protocol_tx), .tx_select(protocol_tx_select), .tx_busy(protocol_tx_busy)
    );

    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_left_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(key_in), .key_flag(left_key_flag)
    );

    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_right_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(key_model), .key_flag(right_key_flag)
    );

    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_lock_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(mode_adapt_sw), .key_flag(lock_key_flag)
    );

    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_mode_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(car_sw), .key_flag(mode_key_flag)
    );

    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_force_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(car_sw2), .key_flag(force_key_flag)
    );

    // Page selection uses the same debounced press-event behavior as mode.
    key_filter #(
        .CLK_HZ(100_000_000), .DEBOUNCE_MS(20), .ACTIVE_LOW(1)
    ) u_page_key (
        .sys_clk(sys_clk), .sys_rst_n(rst_n),
        .key_in(ped_sw_1), .key_flag(page_key_flag)
    );

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            left_level_sys  <= 2'd0;
            right_level_sys <= 2'd0;
            manual_lock_sys <= 1'b0;
            work_mode_sys   <= 2'd0;
            page_index_sys  <= 3'd0;
            single_speed_sys <= 3'd0;
            force_event_sys <= 1'b0;
            cross_lr_dense_sys <= 1'b0;
            cross_tb_dense_sys <= 1'b0;
            cross_ped_high_sys <= 1'b0;
            cross_adaptive_sys <= 1'b1;
            cross_lrs_sys <= 8'd40; cross_lrl_sys <= 8'd30; cross_lrr_sys <= 8'd20;
            cross_tbs_sys <= 8'd40; cross_tbl_sys <= 8'd30; cross_tbr_sys <= 8'd20;
            page_cmd_type_sys <= 0; page_cmd_page_sys <= 0; page_cmd_item_sys <= 0;
            page_cmd_value_sys <= 0; page_cmd_toggle_sys <= 0;
        end else begin
            if (left_key_flag) begin
                if (page_index_sys == 3'd4) begin
                end else if (page_index_sys == 3'd2)
                    single_speed_sys <= (single_speed_sys == 3'd5) ?
                                        3'd0 : single_speed_sys + 1'b1;
                else if (page_index_sys == 3'd3)
                    cross_lr_dense_sys <= ~cross_lr_dense_sys;
                else
                    left_level_sys <= (left_level_sys == 2'd2) ?
                                      2'd0 : left_level_sys + 1'b1;
            end
            if (right_key_flag) begin
                if (page_index_sys == 3'd4) begin
                end else if (page_index_sys == 3'd3)
                    cross_tb_dense_sys <= ~cross_tb_dense_sys;
                else
                    right_level_sys <= (right_level_sys == 2'd2) ?
                                       2'd0 : right_level_sys + 1'b1;
            end
            if (lock_key_flag) begin
                if (page_index_sys == 3'd4) begin
                end else if (page_index_sys == 3'd3)
                    cross_adaptive_sys <= ~cross_adaptive_sys;
                else
                    manual_lock_sys <= ~manual_lock_sys;
            end
            if (mode_key_flag) begin
                if (page_index_sys == 3'd4) begin
                end else if (page_index_sys == 3'd3)
                    cross_ped_high_sys <= ~cross_ped_high_sys;
                else begin
                    work_mode_sys <= (work_mode_sys == 2'd3) ? 2'd0 : work_mode_sys + 1'b1;
                    // Entering A/P also initializes the peak-direction demand.
                    if (work_mode_sys == 2'd0) begin
                        left_level_sys  <= 2'd2;
                        right_level_sys <= 2'd0;
                    end else if (work_mode_sys == 2'd1) begin
                        left_level_sys  <= 2'd0;
                        right_level_sys <= 2'd2;
                    end
                end
            end
            if (page_key_flag)
                page_index_sys <= (page_index_sys == PAGE_LAST) ?
                                  3'd0 : page_index_sys + 1'b1;
            if (force_key_flag) begin
                if ((page_index_sys != 3'd3) && (page_index_sys != 3'd4) && !manual_lock_sys)
                    force_event_sys <= ~force_event_sys;
            end
            if (uart_command_valid_sys) begin
                case (uart_command_sys)
                    CMD_MODE_ADAPTIVE: work_mode_sys <= 2'd0;
                    CMD_MODE_MORNING: begin
                        work_mode_sys   <= 2'd1;
                        left_level_sys  <= 2'd2;
                        right_level_sys <= 2'd0;
                    end
                    CMD_MODE_EVENING: begin
                        work_mode_sys   <= 2'd2;
                        left_level_sys  <= 2'd0;
                        right_level_sys <= 2'd2;
                    end
                    CMD_MODE_HOLD:     work_mode_sys <= 2'd3;
                    CMD_LOCK_ON:       manual_lock_sys <= 1'b1;
                    CMD_LOCK_OFF:      manual_lock_sys <= 1'b0;
                    CMD_FORCE_SWITCH: begin
                        if (!manual_lock_sys)
                            force_event_sys <= ~force_event_sys;
                    end
                    default: ;
                endcase
            end
            // The six crossroad green times are internal display/status values.
            // They are intentionally not writable through UART.
            if (proto_command_valid) begin
                page_cmd_type_sys <= proto_command_type;
                page_cmd_page_sys <= proto_command_page;
                page_cmd_item_sys <= proto_command_item;
                page_cmd_value_sys <= proto_command_value;
                page_cmd_toggle_sys <= ~page_cmd_toggle_sys;
                case (proto_command_page)
                    8'hFF: if ((proto_command_type == PTYPE_SET) && (proto_command_item == 0))
                        page_index_sys <= proto_command_value[2:0];
                    8'd0: case (proto_command_item)
                        0: if (proto_command_type == PTYPE_SET) work_mode_sys <= proto_command_value[1:0];
                        1: if (proto_command_type == PTYPE_SET) left_level_sys <= proto_command_value[1:0];
                        2: if (proto_command_type == PTYPE_SET) right_level_sys <= proto_command_value[1:0];
                        3: if (proto_command_type == PTYPE_SET) manual_lock_sys <= proto_command_value[0];
                        4: if ((proto_command_type == PTYPE_ACTION) && !manual_lock_sys) force_event_sys <= ~force_event_sys;
                        default: ;
                    endcase
                    8'd2: if ((proto_command_type == PTYPE_SET) && (proto_command_item == 0)) begin
                        case (proto_command_value)
                            35: single_speed_sys <= 0; 40: single_speed_sys <= 1;
                            45: single_speed_sys <= 2; 50: single_speed_sys <= 3;
                            55: single_speed_sys <= 4; default: single_speed_sys <= 5;
                        endcase
                    end
                    8'd3: case (proto_command_item)
                        0: if (proto_command_type == PTYPE_SET) cross_lr_dense_sys <= proto_command_value[0];
                        1: if (proto_command_type == PTYPE_SET) cross_tb_dense_sys <= proto_command_value[0];
                        2: if (proto_command_type == PTYPE_SET) cross_ped_high_sys <= (proto_command_value == 10);
                        3: if (proto_command_type == PTYPE_SET) cross_adaptive_sys <= proto_command_value[0];
                        // Items 10..15 are display-only internal timings.
                        default: ;
                    endcase
                    default: ;
                endcase
            end
        end
    end

    // Synchronize button-controlled levels and the manual switch into vga_clk.
    reg [1:0] left_level_vga0, left_level_vga1;
    reg [1:0] right_level_vga0, right_level_vga1;
    reg manual_lock_vga0, manual_lock_vga1;
    reg [1:0] work_mode_vga0, work_mode_vga1;
    reg [2:0] page_index_vga0, page_index_vga1;
    reg [2:0] single_speed_vga0, single_speed_vga1;
    reg force_event_vga0, force_event_vga1, force_event_vga_d;
    reg cross_lr_vga0, cross_lr_vga1;
    reg cross_tb_vga0, cross_tb_vga1;
    reg cross_ped_vga0, cross_ped_vga1;
    reg cross_adaptive_vga0, cross_adaptive_vga1;
    reg [7:0] cross_lrs_vga0, cross_lrs_vga1, cross_lrl_vga0, cross_lrl_vga1;
    reg [7:0] cross_lrr_vga0, cross_lrr_vga1, cross_tbs_vga0, cross_tbs_vga1;
    reg [7:0] cross_tbl_vga0, cross_tbl_vga1, cross_tbr_vga0, cross_tbr_vga1;
    reg [7:0] page_cmd_type_vga0, page_cmd_type_vga1;
    reg [7:0] page_cmd_page_vga0, page_cmd_page_vga1;
    reg [7:0] page_cmd_item_vga0, page_cmd_item_vga1;
    reg [15:0] page_cmd_value_vga0, page_cmd_value_vga1;
    reg page_cmd_toggle_vga0, page_cmd_toggle_vga1, page_cmd_toggle_vga_d;
    always @(posedge vga_clk or negedge rst_n) begin
        if (!rst_n) begin
            left_level_vga0  <= 2'd0;
            left_level_vga1  <= 2'd0;
            right_level_vga0 <= 2'd0;
            right_level_vga1 <= 2'd0;
            manual_lock_vga0 <= 1'b0;
            manual_lock_vga1 <= 1'b0;
            work_mode_vga0   <= 2'd0;
            work_mode_vga1   <= 2'd0;
            page_index_vga0  <= 3'd0;
            page_index_vga1  <= 3'd0;
            single_speed_vga0 <= 3'd0;
            single_speed_vga1 <= 3'd0;
            force_event_vga0 <= 1'b0;
            force_event_vga1 <= 1'b0;
            force_event_vga_d <= 1'b0;
            cross_lr_vga0 <= 1'b0;
            cross_lr_vga1 <= 1'b0;
            cross_tb_vga0 <= 1'b0;
            cross_tb_vga1 <= 1'b0;
            cross_ped_vga0 <= 1'b0;
            cross_ped_vga1 <= 1'b0;
            cross_adaptive_vga0 <= 1'b1;
            cross_adaptive_vga1 <= 1'b1;
            cross_lrs_vga0<=40; cross_lrs_vga1<=40; cross_lrl_vga0<=30; cross_lrl_vga1<=30;
            cross_lrr_vga0<=20; cross_lrr_vga1<=20; cross_tbs_vga0<=40; cross_tbs_vga1<=40;
            cross_tbl_vga0<=30; cross_tbl_vga1<=30; cross_tbr_vga0<=20; cross_tbr_vga1<=20;
            page_cmd_type_vga0<=0; page_cmd_type_vga1<=0; page_cmd_page_vga0<=0; page_cmd_page_vga1<=0;
            page_cmd_item_vga0<=0; page_cmd_item_vga1<=0; page_cmd_value_vga0<=0; page_cmd_value_vga1<=0;
            page_cmd_toggle_vga0<=0; page_cmd_toggle_vga1<=0; page_cmd_toggle_vga_d<=0;
        end else begin
            left_level_vga0  <= left_level_sys;
            left_level_vga1  <= left_level_vga0;
            right_level_vga0 <= right_level_sys;
            right_level_vga1 <= right_level_vga0;
            manual_lock_vga0 <= manual_lock_sys;
            manual_lock_vga1 <= manual_lock_vga0;
            work_mode_vga0   <= work_mode_sys;
            work_mode_vga1   <= work_mode_vga0;
            page_index_vga0  <= page_index_sys;
            page_index_vga1  <= page_index_vga0;
            single_speed_vga0 <= single_speed_sys;
            single_speed_vga1 <= single_speed_vga0;
            force_event_vga0 <= force_event_sys;
            force_event_vga1 <= force_event_vga0;
            force_event_vga_d <= force_event_vga1;
            cross_lr_vga0 <= cross_lr_dense_sys;
            cross_lr_vga1 <= cross_lr_vga0;
            cross_tb_vga0 <= cross_tb_dense_sys;
            cross_tb_vga1 <= cross_tb_vga0;
            cross_ped_vga0 <= cross_ped_high_sys;
            cross_ped_vga1 <= cross_ped_vga0;
            cross_adaptive_vga0 <= cross_adaptive_sys;
            cross_adaptive_vga1 <= cross_adaptive_vga0;
            cross_lrs_vga0<=cross_lrs_sys; cross_lrs_vga1<=cross_lrs_vga0;
            cross_lrl_vga0<=cross_lrl_sys; cross_lrl_vga1<=cross_lrl_vga0;
            cross_lrr_vga0<=cross_lrr_sys; cross_lrr_vga1<=cross_lrr_vga0;
            cross_tbs_vga0<=cross_tbs_sys; cross_tbs_vga1<=cross_tbs_vga0;
            cross_tbl_vga0<=cross_tbl_sys; cross_tbl_vga1<=cross_tbl_vga0;
            cross_tbr_vga0<=cross_tbr_sys; cross_tbr_vga1<=cross_tbr_vga0;
            page_cmd_type_vga0<=page_cmd_type_sys; page_cmd_type_vga1<=page_cmd_type_vga0;
            page_cmd_page_vga0<=page_cmd_page_sys; page_cmd_page_vga1<=page_cmd_page_vga0;
            page_cmd_item_vga0<=page_cmd_item_sys; page_cmd_item_vga1<=page_cmd_item_vga0;
            page_cmd_value_vga0<=page_cmd_value_sys; page_cmd_value_vga1<=page_cmd_value_vga0;
            page_cmd_toggle_vga0<=page_cmd_toggle_sys; page_cmd_toggle_vga1<=page_cmd_toggle_vga0;
            page_cmd_toggle_vga_d<=page_cmd_toggle_vga1;
        end
    end
    wire page_cmd_valid_vga = page_cmd_toggle_vga1 ^ page_cmd_toggle_vga_d;

    wire [1:0] left_level  = left_level_vga1;
    wire [1:0] right_level = right_level_vga1;
    wire manual_lock = manual_lock_vga1;
    // k is the manual lock switch.  It gates direction changes in every
    // operating mode, including morning (A), evening (P), and smart (S).
    wire effective_lock = manual_lock;
    wire force_edge = force_event_vga1 ^ force_event_vga_d;

    // A clean 30 Hz movement pulse derived from vertical sync. Each traffic
    // level has its own Q2 phase so 60/40/35 km/h are visibly fast/medium/slow.
    reg [11:0] left_phase_q2;
    reg [11:0] right_phase_q2;
    reg [11:0] tidal_phase_q2;
    reg frame_div;
    reg vsync_d;
    wire vsync_rise = vsync && !vsync_d;
    wire move_tick = vsync_rise && frame_div;

    wire [1:0] tidal_vehicle_level;
    wire [3:0] left_step_q2  = (left_level  == 2'd0) ? 4'd12 :
                               (left_level  == 2'd2) ? 4'd7  : 4'd8;
    wire [3:0] right_step_q2 = (right_level == 2'd0) ? 4'd12 :
                               (right_level == 2'd2) ? 4'd7  : 4'd8;
    wire [3:0] tidal_step_q2 = (tidal_vehicle_level == 2'd0) ? 4'd12 :
                               (tidal_vehicle_level == 2'd2) ? 4'd7  : 4'd8;
    wire [9:0] left_car_x  = left_phase_q2[11:2];
    wire [9:0] right_car_x = right_phase_q2[11:2];
    wire [9:0] tidal_car_x = tidal_phase_q2[11:2];

    function [11:0] advance_phase_q2;
        input [11:0] phase_q2;
        input [3:0] step_q2;
        reg [12:0] phase_sum;
        begin
            phase_sum = {1'b0, phase_q2} + {9'd0, step_q2};
            advance_phase_q2 = (phase_sum >= 13'd2560) ?
                               phase_sum - 13'd2560 : phase_sum[11:0];
        end
    endfunction

    always @(posedge vga_clk or negedge rst_n) begin
        if (!rst_n) begin
            left_phase_q2  <= 12'd0;
            right_phase_q2 <= 12'd0;
            tidal_phase_q2 <= 12'd0;
            frame_div <= 1'b0;
            vsync_d <= 1'b0;
        end else begin
            vsync_d <= vsync;
            if (vsync_rise) begin
                frame_div <= ~frame_div;
                if (frame_div) begin
                    left_phase_q2  <= advance_phase_q2(left_phase_q2, left_step_q2);
                    right_phase_q2 <= advance_phase_q2(right_phase_q2, right_step_q2);
                    tidal_phase_q2 <= advance_phase_q2(tidal_phase_q2, tidal_step_q2);
                end
            end
        end
    end

    localparam [1:0] TIDAL_OPEN    = 2'd0;
    localparam [1:0] TIDAL_DRAIN   = 2'd1;
    localparam [1:0] TIDAL_ALL_RED = 2'd2;
    localparam [1:0] TIDAL_PREWARN = 2'd3;
    localparam [1:0] DIR_LEFT      = 2'd1;
    localparam [1:0] DIR_RIGHT     = 2'd2;

    reg [1:0] tidal_state;
    reg [1:0] tidal_dir;
    reg [1:0] target_dir;
    reg [1:0] drain_level;
    reg [10:0] tidal_close_phase;
    reg [9:0] tidal_travel;
    // 11 bits are required: six cars at 106-pixel spacing need a phase
    // range of 640 + 5*106 before the stream restarts.
    reg [10:0] tidal_entry_phase;
    reg [7:0] all_red_ticks;
    reg [3:0] tidal_spawn_count;
    reg [5:0] tidal_spawn_timer;
    reg [1:0] tidal_motion_frac;

    wire [4:0] tidal_motion_sum = {3'd0, tidal_motion_frac} +
                                   {1'b0, tidal_step_q2};
    wire [2:0] tidal_motion_px = tidal_motion_sum[4:2];
    wire [1:0] tidal_motion_next_frac = tidal_motion_sum[1:0];

    // With equal demand, retain the current direction to prevent oscillation.
    wire [1:0] automatic_dir = (left_level > right_level) ? DIR_LEFT :
                               (right_level > left_level) ? DIR_RIGHT : tidal_dir;
    wire [1:0] mode_dir = (work_mode_vga1 == 2'd1) ? DIR_LEFT :
                          (work_mode_vga1 == 2'd2) ? DIR_RIGHT :
                          (work_mode_vga1 == 2'd3) ? tidal_dir : automatic_dir;
    reg force_pending;
    reg [1:0] force_target;
    reg force_mode_hold;
    reg [1:0] force_mode_seen;
    // When k=1 the current direction is held; k=0 permits A/P/S requests.
    wire [1:0] requested_dir = effective_lock ? tidal_dir :
                                (force_mode_hold ? force_target : mode_dir);

    // car_sw2 is a one-shot direction reversal. The lock switch blocks it;
    // in a peak mode it overrides the default direction until that mode changes.
    always @(posedge vga_clk or negedge rst_n) begin
        if (!rst_n) begin
            force_pending <= 1'b0;
            force_target <= DIR_RIGHT;
            force_mode_hold <= 1'b0;
            force_mode_seen <= 2'd0;
        end else begin
            if (work_mode_vga1 != force_mode_seen) begin
                force_mode_seen <= work_mode_vga1;
                force_mode_hold <= 1'b0;
            end
            if (force_edge && !effective_lock) begin
                force_target <= (tidal_dir == DIR_LEFT) ? DIR_RIGHT : DIR_LEFT;
                force_pending <= 1'b1;
                if ((work_mode_vga1 == 2'd1) || (work_mode_vga1 == 2'd2))
                    force_mode_hold <= 1'b1;
            end else if (force_pending && (tidal_state == TIDAL_OPEN) &&
                         (tidal_dir == force_target)) begin
                force_pending <= 1'b0;
            end
        end
    end

    // Safe reversal: stop admission, drain every vehicle, hold all-red for one
    // second, then open the lane in the requested direction.
    always @(posedge vga_clk or negedge rst_n) begin
        if (!rst_n) begin
            tidal_state       <= TIDAL_OPEN;
            tidal_dir         <= DIR_LEFT;
            target_dir        <= DIR_RIGHT;
            drain_level       <= 2'd1;
            tidal_close_phase <= 10'd0;
            tidal_travel      <= 10'd0;
            tidal_entry_phase <= 11'd0;
            all_red_ticks     <= 8'd0;
            tidal_spawn_count <= 4'd6;
            tidal_spawn_timer <= 6'd0;
            tidal_motion_frac <= 2'd0;
        end else if (move_tick) begin
            tidal_motion_frac <= tidal_motion_next_frac;
            case (tidal_state)
                TIDAL_OPEN: begin
                    tidal_travel  <= 10'd0;
                    all_red_ticks <= 8'd0;
                    if (tidal_entry_phase >= (11'd1276 - tidal_motion_px))
                        tidal_entry_phase <= 11'd0;
                    else
                        tidal_entry_phase <= tidal_entry_phase + tidal_motion_px;
                    if ((force_pending ? force_target : requested_dir) != tidal_dir) begin
                        tidal_state       <= TIDAL_PREWARN;
                        target_dir        <= force_pending ? force_target : requested_dir;
                        drain_level       <= (tidal_dir == DIR_LEFT) ? left_level : right_level;
                        tidal_close_phase <= tidal_entry_phase;
                        tidal_travel      <= 10'd0;
                    end
                end

                TIDAL_PREWARN: begin
                    if (tidal_entry_phase >= (11'd1276 - tidal_motion_px))
                        tidal_entry_phase <= 11'd0;
                    else
                        tidal_entry_phase <= tidal_entry_phase + tidal_motion_px;
                    if (all_red_ticks >= 8'd59) begin
                        tidal_state   <= TIDAL_DRAIN;
                        all_red_ticks <= 8'd0;
                        tidal_travel  <= tidal_motion_px;
                    end else begin
                        all_red_ticks <= all_red_ticks + 1'b1;
                    end
                end

                TIDAL_DRAIN: begin
                    if (tidal_travel >= 10'd668) begin
                        tidal_state   <= TIDAL_ALL_RED;
                        all_red_ticks <= 8'd0;
                    end else begin
                        tidal_travel <= tidal_travel + tidal_motion_px;
                    end
                end

                default: begin // TIDAL_ALL_RED
                    if (all_red_ticks >= 8'd29) begin
                        tidal_dir     <= target_dir;
                        tidal_state   <= TIDAL_OPEN;
                        tidal_travel  <= 10'd0;
                        all_red_ticks <= 8'd0;
                        tidal_spawn_count <= 4'd6;
                        tidal_spawn_timer <= 6'd0;
                        tidal_entry_phase <= 11'd0;
                    end else begin
                        all_red_ticks <= all_red_ticks + 1'b1;
                    end
                end
            endcase
        end
    end

    // 0=adaptive, 1=scheduled peak mode, 2=forced reversal, 3=hold/demo.
    wire [1:0] log_switch_method = (force_edge || force_pending) ? 2'd2 :
                                   ((work_mode_vga1 == 2'd1) ||
                                    (work_mode_vga1 == 2'd2)) ? 2'd1 :
                                   (work_mode_vga1 == 2'd3) ? 2'd3 : 2'd0;

    reg force_event_log_d;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            tidal_state_sys0<=0; tidal_state_sys1<=0;
            tidal_dir_sys0<=DIR_LEFT; tidal_dir_sys1<=DIR_LEFT;
            target_dir_sys0<=DIR_RIGHT; target_dir_sys1<=DIR_RIGHT;
            force_event_log_d<=0;
        end else begin
            tidal_state_sys0<=tidal_state; tidal_state_sys1<=tidal_state_sys0;
            tidal_dir_sys0<=tidal_dir; tidal_dir_sys1<=tidal_dir_sys0;
            target_dir_sys0<=target_dir; target_dir_sys1<=target_dir_sys0;
            force_event_log_d<=force_event_sys;
        end
    end
    wire force_event_log_pulse = force_event_sys ^ force_event_log_d;
    wire [1:0] log_switch_method_sys = force_event_log_pulse ? 2'd2 :
        ((work_mode_sys==1)||(work_mode_sys==2)) ? 2'd1 :
        (work_mode_sys==3) ? 2'd3 : 2'd0;

    event_log_uart #(
        .CLK_HZ(100_000_000), .BAUD(115200), .ADDR_W(9)
    ) u_event_log (
        .clk(sys_clk), .rst_n(rst_n),
        .rx_valid(uart_command_valid_sys), .rx_data({4'd0, uart_command_sys}),
        .work_mode(work_mode_sys), .switch_method(log_switch_method_sys),
        .tidal_state(tidal_state_sys1), .tidal_dir(tidal_dir_sys1), .target_dir(target_dir_sys1),
        .left_level(left_level_sys), .right_level(right_level_sys),
        .manual_lock(manual_lock_sys), .force_event(force_event_log_pulse),
        .tx_inhibit(protocol_tx_busy), .tx_busy(legacy_tx_busy), .uart_tx(legacy_tx)
    );
    assign uart_tx_pin = protocol_tx_select ? protocol_tx : legacy_tx;

    // The reversible lane mirrors the demand, count and speed of the direction
    // it currently serves: 3/4/6 cars correspond to 60/40/35 km/h.
    assign tidal_vehicle_level = ((work_mode_vga1 == 2'd1) ||
                                  (work_mode_vga1 == 2'd2)) ? 2'd2 :
                                 (tidal_dir == DIR_LEFT) ? left_level : right_level;

    tidal_scene u_tidal (
        .vga_clk(vga_clk), .sys_rst_n(rst_n),
        .pix_x(pix_x), .pix_y(pix_y),
        .left_car_x(left_car_x), .right_car_x(right_car_x),
        .tidal_car_x(tidal_car_x),
        .left_level(left_level), .right_level(right_level),
        .tidal_dir(tidal_dir), .target_dir(target_dir),
        .tidal_state(tidal_state), .move_tick(move_tick),
        .manual_lock(effective_lock), .work_mode(work_mode_vga1),
        .tidal_vehicle_level(tidal_vehicle_level),
        .tidal_spawn_count(tidal_spawn_count),
        .tidal_close_phase(tidal_close_phase), .tidal_travel(tidal_travel),
        .tidal_entry_phase(tidal_entry_phase),
        .pix_data(tidal_pix_data)
    );

    green_wave_scene u_green_wave (
        .vga_clk(vga_clk), .sys_rst_n(rst_n),
        .pix_x(pix_x), .pix_y(pix_y),
        .bg_data(green_wave_bg_data),
        .move_tick(move_tick),
        .enable(page_index_vga1 == 2'd1),
        .fast_x_out(green_fast_x), .wave55_x_out(green_wave55_x),
        .wave58_x_out(green_wave58_x), .wave60_x_out(green_wave60_x),
        .slow_x_out(green_slow_x), .light_bits_out(green_light_bits),
        .pix_data(green_wave_pix_data)
    );

    single_lane_scene u_single_lane (
        .vga_clk(vga_clk), .sys_rst_n(rst_n),
        .pix_x(pix_x), .pix_y(pix_y),
        .move_tick(move_tick),
        .enable(page_index_vga1 == 2'd2),
        .speed_select(single_speed_vga1),
        .rom_index(photo_rom_index),
        .car_x_out(single_car_x_out), .sim_time_out(single_time_out),
        .waiting_out(single_waiting_out), .light_bits_out(single_light_bits),
        .pix_data(single_lane_pix_data)
    );

    // Keep the original crossroad movement, queueing, pedestrian, and signal
    // state machines. Only its BRAM background is disabled; the module's
    // procedural road drawing is used so this page fits beside the other pages.
    scene_cross #(
        .ZB_OFF(35),
        .USE_BG(0)
    ) u_intersection (
        .vga_clk(vga_clk), .sys_rst_n(rst_n),
        .pix_x(pix_x), .pix_y(pix_y),
        .l2r_head_ext(16'd0), .r2l_head_ext(16'd0),
        .rst_key(1'b1), .people_count(8'd0),
        .ped_sw_1(~cross_ped_vga1),
        .car_sw(cross_lr_vga1),
        .car_sw2(cross_tb_vga1),
        .mode_adapt_sw(cross_adaptive_vga1),
        .PED_N_LR(5'd0), .PED_N_TB(5'd0),
        .uart_rx_valid(1'b0), .uart_rx_byte(8'd0),
        .cfg_LRS_in(cross_lrs_vga1), .cfg_LRL_in(cross_lrl_vga1), .cfg_LRR_in(cross_lrr_vga1),
        .cfg_TBS_in(cross_tbs_vga1), .cfg_TBL_in(cross_tbl_vga1), .cfg_TBR_in(cross_tbr_vga1),
        .pix_cross(intersection_pix_data),
        .ped_n_lr_out(cross_ped_lr_out), .ped_n_tb_out(cross_ped_tb_out),
        .ped_has_lr_out(), .ped_has_tb_out(),
        .ped_cross_lr_out(), .ped_cross_tb_out(),
        .car_n_lr_status(cross_car_lr_out), .car_n_tb_status(cross_car_tb_out),
        .green_LRS_status(cross_green_lrs_out), .green_LRL_status(cross_green_lrl_out),
        .green_LRR_status(cross_green_lrr_out), .green_TBS_status(cross_green_tbs_out),
        .green_TBL_status(cross_green_tbl_out), .green_TBR_status(cross_green_tbr_out),
        .light_status(cross_light_bits)
    );

    traffic_lab_scene u_traffic_lab (
        .clk(vga_clk), .rst_n(rst_n),
        .enable(page_index_vga1 == 3'd4),
        .x(pix_x), .y(pix_y),
        .sw1(car_sw), .sw2(car_sw2), .sw3(mode_adapt_sw),
        .key_plus_n(key_in), .key_minus_n(key_model),
        .uart_cfg_valid(page_cmd_valid_vga && (page_cmd_page_vga1==8'd4)),
        .uart_cfg_type(page_cmd_type_vga1), .uart_cfg_item(page_cmd_item_vga1),
        .uart_cfg_value(page_cmd_value_vga1),
        .green_seconds_out(lab_green_out), .red_seconds_out(lab_red_out),
        .length_m_out(lab_length_out), .rate_vph_out(lab_rate_out),
        .phase_out(lab_phase_out), .ctrl_out(lab_ctrl_out),
        .avg_out(lab_avg_out), .max_out(lab_max_out), .flow_out(lab_flow_out),
        .overflow_out(lab_overflow_out), .stops_out(lab_stops_out), .queue_out(lab_queue_out),
        .pix_data(traffic_lab_pix_data)
    );

    assign pix_data = (page_index_vga1 == 3'd1) ? green_wave_pix_data :
                      (page_index_vga1 == 3'd2) ? single_lane_pix_data :
                      (page_index_vga1 == 3'd3) ? intersection_pix_data :
                      (page_index_vga1 == 3'd4) ? traffic_lab_pix_data :
                      tidal_pix_data;

    vga_ctrl u_ctrl (
        .vga_clk(vga_clk), .sys_rst_n(rst_n), .pix_data(pix_data),
        .pix_x(pix_x), .pix_y(pix_y), .hsync(hsync), .vsync(vsync),
        .vga_rgb(vga_rgb_int)
    );

    assign vga_r = vga_rgb_int[15:12];
    assign vga_g = vga_rgb_int[10:7];
    assign vga_b = vga_rgb_int[4:1];

endmodule

// Keep the ROM implementation in the parent checkpoint. This avoids relying
// on an out-of-context DCP being stitched by an already-open Vivado project.
module tidal_bg_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [18:0] addra,
    output reg  [7:0]  douta
);
    (* rom_style = "block" *) reg [7:0] rom [0:307199];

    initial begin
        $readmemb("D:/vivado/vgatest/vgatest.srcs/sources_1/ip/tidal_bg_rom/tidal_bg_rom.mif", rom);
    end

    always @(posedge clka) begin
        if (ena)
            douta <= rom[addra];
    end
endmodule

