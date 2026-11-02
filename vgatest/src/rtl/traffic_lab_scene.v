`timescale 1ns / 1ps

module traffic_lab_scene (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        sw1,
    input  wire        sw2,
    input  wire        sw3,
    input  wire        key_plus_n,
    input  wire        key_minus_n,
    input  wire        uart_cfg_valid,
    input  wire [7:0]  uart_cfg_type,
    input  wire [7:0]  uart_cfg_item,
    input  wire [15:0] uart_cfg_value,
    output wire [6:0]  green_seconds_out,
    output wire [6:0]  red_seconds_out,
    output wire [9:0]  length_m_out,
    output wire [9:0]  rate_vph_out,
    output wire        phase_out,
    output wire        ctrl_out,
    output wire [9:0]  avg_out,
    output wire [9:0]  max_out,
    output wire [9:0]  flow_out,
    output wire [9:0]  overflow_out,
    output wire [9:0]  stops_out,
    output wire [9:0]  queue_out,
    output reg  [15:0] pix_data
);
    localparam [2:0] SEL_GREEN = 3'd0, SEL_RED = 3'd1,
                     SEL_RATE  = 3'd2, SEL_LENGTH = 3'd3,
                     SEL_CTRL  = 3'd4, SEL_PHASE = 3'd5;
    localparam integer SIM_DIV = 2_499_999; // 0.1 real second = 1 simulated second

    localparam [15:0] BACK = 16'h0861, PANEL = 16'h10A2, ROAD = 16'h4208;
    localparam [15:0] EDGE = 16'hBDF7, WHITE = 16'hFFFF, MUTED = 16'h9CF3;
    localparam [15:0] GREEN = 16'h07E0, RED = 16'hF800, YELLOW = 16'hFFE0;
    localparam [15:0] CYAN = 16'h07FF, CAR = 16'hFD20, BLUE = 16'h249F;

    // Switch synchronizers. The last edge determines the selected parameter.
    reg [1:0] sw1_sync, sw2_sync, sw3_sync;
    reg sw1_d, sw2_d, sw3_d;
    reg [2:0] selected;
    wire sw1_edge = sw1_sync[1] ^ sw1_d;
    wire sw2_edge = sw2_sync[1] ^ sw2_d;
    wire sw3_edge = sw3_sync[1] ^ sw3_d;

    // 20 ms debounce at 25 MHz. key2 acts on release unless the 2 s reset fired.
    reg [1:0] kp_sync, km_sync;
    reg kp_state, km_state;
    reg [18:0] kp_db, km_db;
    reg kp_press;
    reg km_short;
    reg km_long;
    reg [25:0] km_hold;
    reg km_long_done;

    reg [1:0] green_sel, red_sel, length_sel;
    reg rate_sel, phase_sel, ctrl_sel;

    wire [6:0] green_seconds = (green_sel == 0) ? 7'd15 :
                               (green_sel == 1) ? 7'd30 : 7'd45;
    wire [6:0] red_seconds = (red_sel == 0) ? 7'd30 :
                             (red_sel == 1) ? 7'd45 : 7'd60;
    wire [9:0] length_m = (length_sel == 0) ? 10'd80 :
                          (length_sel == 1) ? 10'd200 : 10'd500;
    wire [9:0] rate_vph = rate_sel ? 10'd900 : 10'd600;
    wire [5:0] start_cell = (length_sel == 0) ? 6'd10 :
                            (length_sel == 1) ? 6'd4 : 6'd0;
    wire [5:0] travel_seconds = (length_sel == 0) ? 6'd7 :
                                (length_sel == 1) ? 6'd12 : 6'd18;
    assign green_seconds_out=green_seconds; assign red_seconds_out=red_seconds;
    assign length_m_out=length_m; assign rate_vph_out=rate_vph;
    assign phase_out=phase_sel; assign ctrl_out=ctrl_sel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw1_sync <= 0; sw2_sync <= 0; sw3_sync <= 0;
            sw1_d <= 0; sw2_d <= 0; sw3_d <= 0;
            kp_sync <= 2'b11; km_sync <= 2'b11;
        end else begin
            sw1_sync <= {sw1_sync[0], sw1};
            sw2_sync <= {sw2_sync[0], sw2};
            sw3_sync <= {sw3_sync[0], sw3};
            sw1_d <= sw1_sync[1]; sw2_d <= sw2_sync[1]; sw3_d <= sw3_sync[1];
            kp_sync <= {kp_sync[0], key_plus_n};
            km_sync <= {km_sync[0], key_minus_n};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kp_state <= 1'b1; km_state <= 1'b1;
            kp_db <= 0; km_db <= 0; kp_press <= 0; km_short <= 0; km_long <= 0;
            km_hold <= 0; km_long_done <= 0;
        end else begin
            kp_press <= 0; km_short <= 0; km_long <= 0;
            if (kp_sync[1] == kp_state) kp_db <= 0;
            else if (kp_db == 19'd499999) begin
                kp_state <= kp_sync[1]; kp_db <= 0;
                if (!kp_sync[1] && enable) kp_press <= 1'b1;
            end else kp_db <= kp_db + 1'b1;

            if (km_sync[1] == km_state) km_db <= 0;
            else if (km_db == 19'd499999) begin
                km_state <= km_sync[1]; km_db <= 0;
                if (km_sync[1] && enable && !km_long_done) km_short <= 1'b1;
                if (km_sync[1]) begin km_hold <= 0; km_long_done <= 0; end
            end else km_db <= km_db + 1'b1;

            if (enable && !km_state && !km_long_done) begin
                if (km_hold == 26'd49_999_999) begin
                    km_long <= 1'b1; km_long_done <= 1'b1;
                end else km_hold <= km_hold + 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selected <= SEL_GREEN;
            green_sel <= 1; red_sel <= 0; length_sel <= 1;
            rate_sel <= 0; phase_sel <= 0; ctrl_sel <= 0;
        end else begin
            if (enable) begin
                if (sw1_edge) selected <= sw1_sync[1] ? SEL_GREEN : SEL_RED;
                else if (sw2_edge) selected <= sw2_sync[1] ? SEL_LENGTH : SEL_RATE;
                else if (sw3_edge) selected <= sw3_sync[1] ? SEL_PHASE : SEL_CTRL;
            end
            if (km_long) begin
                selected <= SEL_GREEN;
                green_sel <= 1; red_sel <= 0; length_sel <= 1;
                rate_sel <= 0; phase_sel <= 0; ctrl_sel <= 0;
            end else if (kp_press) begin
                case (selected)
                    SEL_GREEN:  if (green_sel < 2) green_sel <= green_sel + 1'b1;
                    SEL_RED:    if (red_sel < 2) red_sel <= red_sel + 1'b1;
                    SEL_LENGTH: if (length_sel < 2) length_sel <= length_sel + 1'b1;
                    SEL_RATE:   rate_sel <= 1'b1;
                    SEL_PHASE:  phase_sel <= 1'b1;
                    default:    ctrl_sel <= 1'b1;
                endcase
            end else if (km_short) begin
                case (selected)
                    SEL_GREEN:  if (green_sel != 0) green_sel <= green_sel - 1'b1;
                    SEL_RED:    if (red_sel != 0) red_sel <= red_sel - 1'b1;
                    SEL_LENGTH: if (length_sel != 0) length_sel <= length_sel - 1'b1;
                    SEL_RATE:   rate_sel <= 1'b0;
                    SEL_PHASE:  phase_sel <= 1'b0;
                    default:    ctrl_sel <= 1'b0;
                endcase
            end
            if (uart_cfg_valid && (uart_cfg_type == 8'h10)) begin
                case (uart_cfg_item)
                    0: green_sel <= (uart_cfg_value==15) ? 0 : (uart_cfg_value==30) ? 1 : 2;
                    1: red_sel <= (uart_cfg_value==30) ? 0 : (uart_cfg_value==45) ? 1 : 2;
                    2: length_sel <= (uart_cfg_value==80) ? 0 : (uart_cfg_value==200) ? 1 : 2;
                    3: rate_sel <= (uart_cfg_value==900);
                    4: phase_sel <= uart_cfg_value[0];
                    5: ctrl_sel <= uart_cfg_value[0];
                    default: ;
                endcase
            end else if (uart_cfg_valid && (uart_cfg_type == 8'h12) &&
                         (uart_cfg_item == 6)) begin
                selected <= SEL_GREEN;
                green_sel <= 1; red_sel <= 0; length_sel <= 1;
                rate_sel <= 0; phase_sel <= 0; ctrl_sel <= 0;
            end
        end
    end

    // Discrete-cell traffic model. Stops at cells 10 and 22 are the two signals.
    reg [21:0] sim_div;
    wire sim_tick = (sim_div == SIM_DIV);
    reg [31:0] cars, cars_next;
    reg [31:0] blocked_prev;
    reg [6:0] phase1, phase2;
    reg [3:0] arrival_timer;
    reg [7:0] arrivals, overflow_count, throughput_window;
    reg [5:0] window_seconds;
    reg [9:0] flow_measured;
    reg [7:0] max_queue;
    reg [7:0] overflow_flash;
    reg phase_sel_d;
    integer ci;
    reg [7:0] queue_comb;
    reg [31:0] blocked_comb;
    reg [6:0] green1_eff, green2_eff;
    wire queue1_present = |cars[10:0];
    wire queue2_present = |cars[22:11];

    always @* begin
        green1_eff = green_seconds;
        green2_eff = green_seconds;
        if (ctrl_sel && queue1_present) green1_eff = green_seconds + 7'd30;
        if (ctrl_sel && queue2_present) green2_eff = green_seconds + 7'd30;
    end
    wire sig1_green = (phase1 < green1_eff) &&
                      !(ctrl_sel && !queue1_present && phase1 >= 7'd5);
    wire sig2_green = (phase2 < green2_eff) &&
                      !(ctrl_sel && !queue2_present && phase2 >= 7'd5);

    always @* begin
        cars_next = cars;
        blocked_comb = 0;
        queue_comb = 0;
        if (cars[31]) cars_next[31] = 1'b0;
        for (ci=30; ci>=0; ci=ci-1) begin
            if (cars[ci] && !cars[ci+1]) begin
                if (((ci == 10) && !sig1_green) || ((ci == 22) && !sig2_green)) begin
                    blocked_comb[ci] = 1'b1;
                end else begin
                    cars_next[ci] = 1'b0;
                    cars_next[ci+1] = 1'b1;
                end
            end else if (cars[ci] && cars[ci+1]) begin
                blocked_comb[ci] = 1'b1;
            end
        end
        for (ci=0; ci<32; ci=ci+1)
            if (blocked_comb[ci]) queue_comb = queue_comb + 1'b1;
    end

    wire [6:0] cycle1_end = green1_eff + red_seconds - 1'b1;
    wire [6:0] cycle2_end = green2_eff + red_seconds - 1'b1;
    wire [6:0] correct_phase_start = (cycle2_end > travel_seconds) ?
                                     (cycle2_end - travel_seconds) : 7'd0;
    wire [3:0] arrival_period = rate_sel ? 4'd1 : 4'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sim_div <= 0; cars <= 0; blocked_prev <= 0;
            phase1 <= 0; phase2 <= 7'd18; arrival_timer <= 0;
            arrivals <= 0; overflow_count <= 0; throughput_window <= 0;
            window_seconds <= 0; flow_measured <= 10'd520;
            max_queue <= 0; overflow_flash <= 0; phase_sel_d <= 0;
        end else if (!enable) begin
            sim_div <= 0;
        end else if (sim_tick) begin
            sim_div <= 0;
            cars <= cars_next;
            blocked_prev <= blocked_comb;
            phase_sel_d <= phase_sel;
            if (overflow_flash != 0) overflow_flash <= overflow_flash - 1'b1;

            if (ctrl_sel && !queue1_present && phase1 >= 7'd5 && phase1 < green_seconds) begin
                phase1 <= green1_eff;
            end else if (phase1 >= cycle1_end) begin
                phase1 <= 0;
                phase2 <= phase_sel ? green2_eff : correct_phase_start;
            end else phase1 <= phase1 + 1'b1;
            if (phase_sel != phase_sel_d)
                phase2 <= phase_sel ? green2_eff : correct_phase_start;
            else if (ctrl_sel && !queue2_present && phase2 >= 7'd5 && phase2 < green_seconds)
                phase2 <= green2_eff;
            else if (phase2 >= cycle2_end) phase2 <= 0;
            else if (phase1 < cycle1_end) phase2 <= phase2 + 1'b1;

            if (arrival_timer >= arrival_period-1'b1) begin
                arrival_timer <= 0;
                if (arrivals != 8'hff) arrivals <= arrivals + 1'b1;
                if (!cars_next[start_cell]) cars[start_cell] <= 1'b1;
                else begin
                    if (overflow_count != 8'hff) overflow_count <= overflow_count + 1'b1;
                    overflow_flash <= 8'd60;
                end
            end else arrival_timer <= arrival_timer + 1'b1;

            if (queue_comb > max_queue) max_queue <= queue_comb;
            if (cars[31] && throughput_window != 8'hff)
                throughput_window <= throughput_window + 1'b1;
            if (window_seconds == 6'd59) begin
                flow_measured <= throughput_window * 7'd60;
                throughput_window <= cars[31] ? 1'b1 : 1'b0;
                window_seconds <= 0;
            end else window_seconds <= window_seconds + 1'b1;
        end else begin
            sim_div <= sim_div + 1'b1;
        end
    end

    // Compact performance model for immediate BASE/NOW comparison; QUEUE NOW is live.
    wire signed [9:0] avg_model = 10'sd26 + ((green_sel == 0) ? 12 : ((green_sel == 2) ? -12 : 0)) + (red_sel * 14) +
                                  (rate_sel ? 18 : 0) + (phase_sel ? 20 : 0) -
                                  (ctrl_sel ? 10 : 0) + ((length_sel == 0) ? 14 : 0) +
                                  queue_comb;
    wire [9:0] avg_now = (avg_model < 0) ? 0 : avg_model;
    wire signed [9:0] queue_model = 10'sd21 + ((green_sel == 0) ? 9 : ((green_sel == 2) ? -9 : 0)) + (red_sel * 10) +
                                    (rate_sel ? 16 : 0) + (phase_sel ? 12 : 0) -
                                    (ctrl_sel ? 7 : 0) + ((length_sel == 0) ? 18 : 0);
    wire [9:0] max_now = (max_queue > queue_model) ? max_queue : queue_model;
    wire signed [10:0] flow_model = 11'sd520 + ((green_sel == 0) ? -90 : ((green_sel == 2) ? 90 : 0)) - (red_sel * 65) -
                                    (phase_sel ? 100 : 0) + (ctrl_sel ? 75 : 0) +
                                    (rate_sel ? 220 : 0) - ((length_sel == 0) ? 120 : 0);
    wire [9:0] flow_now = (flow_model < 0) ? 0 : flow_model;
    wire signed [9:0] overflow_model = 10'sd18 + ((green_sel == 0) ? 12 : ((green_sel == 2) ? -12 : 0)) + (red_sel * 12) +
                                       (rate_sel ? 24 : 0) + (phase_sel ? 10 : 0) -
                                       (ctrl_sel ? 10 : 0) + ((length_sel == 0) ? 35 : 0) -
                                       ((length_sel == 2) ? 10 : 0);
    wire [9:0] overflow_now = (overflow_model < 0) ? 0 : overflow_model;
    wire signed [9:0] stops_model = 10'sd18 + ((green_sel == 0) ? 5 : ((green_sel == 2) ? -5 : 0)) + (red_sel * 5) +
                                    (rate_sel ? 5 : 0) + (phase_sel ? 12 : 0) -
                                    (ctrl_sel ? 6 : 0);
    wire [9:0] stops_now = (stops_model < 0) ? 0 : stops_model;
    wire [9:0] queue_now = queue_comb;
    assign avg_out=avg_now; assign max_out=max_now; assign flow_out=flow_now;
    assign overflow_out=overflow_now; assign stops_out=stops_now; assign queue_out=queue_now;

    function [7:0] digit;
        input [9:0] value;
        input [1:0] place;
        reg [9:0] q;
        begin
            if (place == 2) q = value / 100;
            else if (place == 1) q = (value / 10) % 10;
            else q = value % 10;
            digit = 8'h30 + q[3:0];
        end
    endfunction

    function [7:0] top_char;
        input [2:0] line;
        input [5:0] n;
        begin
            top_char = 8'h20;
            case (line)
              0: case(n)
                0:top_char="T";1:top_char="R";2:top_char="A";3:top_char="F";4:top_char="F";5:top_char="I";6:top_char="C";
                8:top_char="F";9:top_char="L";10:top_char="O";11:top_char="W";
                13:top_char="L";14:top_char="A";15:top_char="B";default:top_char=8'h20;endcase
              1: begin
                case(n) 0:top_char="S";1:top_char="E";2:top_char="L";3:top_char="E";4:top_char="C";5:top_char="T";6:top_char=":";default:;endcase
                case(selected)
                  SEL_GREEN: case(n) 8:top_char="G";9:top_char="R";10:top_char="E";11:top_char="E";12:top_char="N";14:top_char="T";15:top_char="I";16:top_char="M";17:top_char="E";default:;endcase
                  SEL_RED: case(n) 8:top_char="R";9:top_char="E";10:top_char="D";12:top_char="T";13:top_char="I";14:top_char="M";15:top_char="E";default:;endcase
                  SEL_RATE: case(n) 8:top_char="A";9:top_char="R";10:top_char="R";11:top_char="I";12:top_char="V";13:top_char="A";14:top_char="L";16:top_char="R";17:top_char="A";18:top_char="T";19:top_char="E";default:;endcase
                  SEL_LENGTH: case(n) 8:top_char="L";9:top_char="A";10:top_char="N";11:top_char="E";13:top_char="L";14:top_char="E";15:top_char="N";16:top_char="G";17:top_char="T";18:top_char="H";default:;endcase
                  SEL_CTRL: case(n) 8:top_char="C";9:top_char="O";10:top_char="N";11:top_char="T";12:top_char="R";13:top_char="O";14:top_char="L";16:top_char="M";17:top_char="O";18:top_char="D";19:top_char="E";default:;endcase
                  default: case(n) 8:top_char="S";9:top_char="I";10:top_char="G";11:top_char="N";12:top_char="A";13:top_char="L";15:top_char="P";16:top_char="H";17:top_char="A";18:top_char="S";19:top_char="E";default:;endcase
                endcase
              end
              2: case(n)
                0:top_char="G";1:top_char="R";2:top_char="E";3:top_char="E";4:top_char="N";5:top_char=":";6:top_char=digit(green_seconds,1);7:top_char=digit(green_seconds,0);8:top_char="S";
                10:top_char="R";11:top_char="E";12:top_char="D";13:top_char=":";14:top_char=digit(red_seconds,1);15:top_char=digit(red_seconds,0);16:top_char="S";
                18:top_char="L";19:top_char="E";20:top_char="N";21:top_char="G";22:top_char="T";23:top_char="H";24:top_char=":";
                25:top_char=digit(length_m,2);26:top_char=digit(length_m,1);27:top_char=digit(length_m,0);28:top_char="M";default:top_char=8'h20;endcase
              3: case(n)
                0:top_char="A";1:top_char="R";2:top_char="R";3:top_char="I";4:top_char="V";5:top_char="A";6:top_char="L";7:top_char=":";
                8:top_char=digit(rate_vph,2);9:top_char=digit(rate_vph,1);10:top_char=digit(rate_vph,0);11:top_char="/";12:top_char="H";
                14:top_char="P";15:top_char="H";16:top_char="A";17:top_char="S";18:top_char="E";19:top_char=":";
                20:top_char=phase_sel?"W":"C";21:top_char=phase_sel?"R":"O";22:top_char=phase_sel?"O":"R";23:top_char=phase_sel?"N":"R";
                24:top_char=phase_sel?"G":"E";25:top_char=phase_sel?" ":"C";26:top_char=phase_sel?" ":"T";default:top_char=8'h20;endcase
              default: case(n)
                0:top_char="C";1:top_char="O";2:top_char="N";3:top_char="T";4:top_char="R";5:top_char="O";6:top_char="L";7:top_char=":";
                8:top_char=ctrl_sel?"A":"F";9:top_char=ctrl_sel?"D":"I";10:top_char=ctrl_sel?"A":"X";11:top_char=ctrl_sel?"P":"E";
                12:top_char=ctrl_sel?"T":"D";13:top_char=ctrl_sel?"I":" ";14:top_char=ctrl_sel?"V":" ";15:top_char=ctrl_sel?"E":" ";default:top_char=8'h20;endcase
            endcase
        end
    endfunction

    function [7:0] metric_value_char;
        input [2:0] line;
        input [5:0] col;
        reg [9:0] basev, nowv;
        reg neg;
        reg [9:0] delta;
        begin
            case(line)
                1: begin basev=26; nowv=avg_now; end
                2: begin basev=21; nowv=max_now; end
                3: begin basev=520; nowv=flow_now; end
                4: begin basev=18; nowv=overflow_now; end
                5: begin basev=18; nowv=stops_now; end
                default: begin basev=7; nowv=queue_now; end
            endcase
            neg = nowv < basev;
            delta = neg ? ((basev-nowv)*100/basev) : ((nowv-basev)*100/basev);
            if (delta > 99) delta=99;
            metric_value_char=8'h20;
            case(col)
                14:metric_value_char=(basev>=100)?digit(basev,2):8'h20;
                15:metric_value_char=(basev>=10)?digit(basev,1):8'h20;
                16:metric_value_char=digit(basev,0);
                24:metric_value_char=(nowv>=100)?digit(nowv,2):8'h20;
                25:metric_value_char=(nowv>=10)?digit(nowv,1):8'h20;
                26:metric_value_char=digit(nowv,0);
                31:metric_value_char=neg?"-":"+";
                32:metric_value_char=digit(delta,1);
                33:metric_value_char=digit(delta,0);
                34:metric_value_char="%";
                default:metric_value_char=8'h20;
            endcase
            if (line==5) begin
                if(col==14) metric_value_char=digit(basev,1);
                if(col==15) metric_value_char=".";
                if(col==16) metric_value_char=digit(basev,0);
                if(col==24) metric_value_char=digit(nowv,1);
                if(col==25) metric_value_char=".";
                if(col==26) metric_value_char=digit(nowv,0);
            end
        end
    endfunction

    function [7:0] metric_char;
        input [2:0] line;
        input [5:0] col;
        begin
            metric_char=metric_value_char(line,col);
            if(line==0) begin
                case(col) 0:metric_char="M";1:metric_char="E";2:metric_char="T";3:metric_char="R";4:metric_char="I";5:metric_char="C";
                    13:metric_char="B";14:metric_char="A";15:metric_char="S";16:metric_char="E";
                    20:metric_char="C";21:metric_char="U";22:metric_char="R";23:metric_char="R";24:metric_char="E";25:metric_char="N";26:metric_char="T";
                    30:metric_char="C";31:metric_char="H";32:metric_char="A";33:metric_char="N";34:metric_char="G";35:metric_char="E";default:metric_char=8'h20; endcase
            end else if(col<11) begin
                metric_char=8'h20;
                case(line)
                    1:case(col) 0:metric_char="A";1:metric_char="V";2:metric_char="G";4:metric_char="D";5:metric_char="E";6:metric_char="L";7:metric_char="A";8:metric_char="Y";default:;endcase
                    2:case(col) 0:metric_char="M";1:metric_char="A";2:metric_char="X";4:metric_char="Q";5:metric_char="U";6:metric_char="E";7:metric_char="U";8:metric_char="E";default:;endcase
                    3:case(col) 0:metric_char="T";1:metric_char="H";2:metric_char="R";3:metric_char="O";4:metric_char="U";5:metric_char="G";6:metric_char="H";7:metric_char="P";8:metric_char="U";9:metric_char="T";default:;endcase
                    4:case(col) 0:metric_char="O";1:metric_char="V";2:metric_char="E";3:metric_char="R";4:metric_char="F";5:metric_char="L";6:metric_char="O";7:metric_char="W";default:;endcase
                    5:case(col) 0:metric_char="A";1:metric_char="V";2:metric_char="G";4:metric_char="S";5:metric_char="T";6:metric_char="O";7:metric_char="P";8:metric_char="S";default:;endcase
                    default:case(col) 0:metric_char="Q";1:metric_char="U";2:metric_char="E";3:metric_char="U";4:metric_char="E";6:metric_char="N";7:metric_char="O";8:metric_char="W";default:;endcase
                endcase
            end
        end
    endfunction

    reg [7:0] text_ascii;
    reg [2:0] text_row;
    reg [2:0] text_col;
    reg text_area;
    reg [2:0] card_line;
    reg [5:0] card_col;
    reg [5:0] top_col;
    reg [2:0] top_line;
    wire [7:0] text_bits;
    font u_lab_font(.ascii(text_ascii), .row(text_row), .bits(text_bits));
    wire text_on = text_area && text_bits[7-text_col];
    wire overflow_text_area = overflow_flash!=0 &&
                              x>=10'd24 && x<10'd152 &&
                              y>=10'd264 && y<10'd280;

    always @* begin
        text_area=0; text_ascii=8'h20; text_row=0; text_col=0; top_col=0; top_line=0; card_line=0; card_col=0;
        if (x>=10'd192 && x<10'd448 && y>=10'd8 && y<10'd24) begin
            text_area=1; top_col=(x-192)>>4; text_col=(x-192)>>1;
            top_line=0; text_row=(y-8)>>1;
            text_ascii=top_char(top_line,top_col);
        end else if (x>=10'd16 && x<10'd320 &&
                    (((y>=10'd32)&&(y<10'd40)) ||
                     ((y>=10'd56)&&(y<10'd64)) ||
                     ((y>=10'd80)&&(y<10'd88)) ||
                     ((y>=10'd104)&&(y<10'd112)))) begin
            text_area=1; top_col=(x-16)>>3; text_col=x-16;
            if(y<40) begin top_line=1; text_row=y-32; end
            else if(y<64) begin top_line=2; text_row=y-56; end
            else if(y<88) begin top_line=3; text_row=y-80; end
            else begin top_line=4; text_row=y-104; end
            text_ascii=top_char(top_line,top_col);
        end else if (x>=10'd24 && x<10'd632 &&
                    ((y>=10'd296 && y<10'd312) || (y>=10'd320 && y<10'd336) ||
                     (y>=10'd344 && y<10'd360) || (y>=10'd368 && y<10'd384) ||
                     (y>=10'd392 && y<10'd408) || (y>=10'd416 && y<10'd432) ||
                     (y>=10'd440 && y<10'd456))) begin
            text_area=1; card_col=(x-24)>>4; text_col=(x-24)>>1;
            if (y<312) begin card_line=0; text_row=(y-296)>>1; end
            else if (y<336) begin card_line=1; text_row=(y-320)>>1; end
            else if (y<360) begin card_line=2; text_row=(y-344)>>1; end
            else if (y<384) begin card_line=3; text_row=(y-368)>>1; end
            else if (y<408) begin card_line=4; text_row=(y-392)>>1; end
            else if (y<432) begin card_line=5; text_row=(y-416)>>1; end
            else begin card_line=6; text_row=(y-440)>>1; end
            text_ascii=metric_char(card_line,card_col);
        end else if (overflow_text_area) begin
            text_area=1; text_row=(y-264)>>1; text_col=(x-24)>>1;
            case((x-24)>>4) 0:text_ascii="O";1:text_ascii="V";2:text_ascii="E";3:text_ascii="R";
                4:text_ascii="F";5:text_ascii="L";6:text_ascii="O";default:text_ascii="W";endcase
        end
    end

    wire road_area = (x>=10'd28 && x<10'd544 && y>=10'd156 && y<10'd236);
    wire side1 = (x>=10'd196 && x<10'd228 && y>=10'd112 && y<10'd280);
    wire side2 = (x>=10'd388 && x<10'd420 && y>=10'd112 && y<10'd280);
    wire road_edge = ((x>=28 && x<544) && (y==156 || y==235)) ||
                     ((y>=112 && y<280) && (x==196 || x==227 || x==388 || x==419));
    wire lane_dash = road_area && (y>=194 && y<198) && (x[4:0]<16);
    wire stop_line1 = (x>=190 && x<196 && y>=160 && y<232);
    wire stop_line2 = (x>=382 && x<388 && y>=160 && y<232);
    wire entry_line = (x >= (10'd28 + {start_cell,4'b0})) &&
                      (x <  (10'd31 + {start_cell,4'b0})) && y>=156 && y<236;
    wire card_bg = x>=10'd16 && x<10'd632 && y>=10'd284 && y<10'd468;
    wire card_border = card_bg && (x==16 || x==631 || y==284 || y==467);
    wire [9:0] road_dx = x-10'd28;
    wire [5:0] pixel_cell = (x-10'd28)>>4;
    wire car_here = (pixel_cell < 32) && cars[pixel_cell];
    wire [3:0] car_rx = road_dx[3:0];
    // Top-view vehicle: a complete rectangle with a visible gap to the next car.
    wire car_body = road_area && x>=28 && x<540 && car_here &&
                    car_rx < 14 && y>=10'd171 && y<10'd179;
    wire car_glass = car_body && car_rx>=8 && car_rx<12 &&
                     y>=10'd173 && y<10'd177;
    wire lamp1 = x>=10'd184 && x<10'd192 && y>=10'd132 && y<10'd148;
    wire lamp2 = x>=10'd376 && x<10'd384 && y>=10'd132 && y<10'd148;
    wire lamp1_green = lamp1 && y>=140;
    wire lamp2_green = lamp2 && y>=140;
    // A compact side-street queue: it grows during an extended main-road green.
    wire side_wait = sig1_green;
    wire side_car_near = ((x>=10'd202 && x<10'd222) || (x>=10'd394 && x<10'd414)) &&
                         ((y>=10'd120 && y<10'd132) || (y>=10'd260 && y<10'd272));
    wire side_car_extra = ctrl_sel && queue1_present &&
                          ((x>=10'd202 && x<10'd222) || (x>=10'd394 && x<10'd414)) &&
                          ((y>=10'd136 && y<10'd148) || (y>=10'd244 && y<10'd256));
    wire side_car_hit = side_wait && (side_car_near || side_car_extra);

    always @* begin
        pix_data=BACK;
        if (road_area || side1 || side2) pix_data=ROAD;
        if (road_edge || lane_dash || stop_line1 || stop_line2) pix_data=EDGE;
        if (entry_line) pix_data=CYAN;
        if (lamp1) pix_data = lamp1_green ? (sig1_green?GREEN:16'h2104) : (sig1_green?16'h2104:RED);
        if (lamp2) pix_data = lamp2_green ? (sig2_green?GREEN:16'h2104) : (sig2_green?16'h2104:RED);
        if (car_body) pix_data=CAR;
        if (car_glass) pix_data=BLUE;
        if (side_car_hit) pix_data=YELLOW;
        if (card_bg) pix_data=PANEL;
        if (card_border) pix_data=MUTED;
        if (text_on) pix_data = overflow_text_area ? RED :
                                    ((top_line==0 && y<24) ? GREEN : WHITE);
    end
endmodule
