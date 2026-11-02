`timescale 1ns/1ps

// 512-entry circular event log with a human-readable UART interface.
// The FPGA emits a STATUS line every STATUS_INTERVAL_S seconds. Commands:
//   D/d - dump all retained event records as ASCII lines
//   C/c - clear the log and return an acknowledgement
module event_log_uart #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD = 115200,
    parameter integer ADDR_W = 9,
    parameter integer STATUS_INTERVAL_S = 5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_valid,
    input  wire [7:0] rx_data,
    input  wire [1:0] work_mode,
    input  wire [1:0] switch_method,
    input  wire [1:0] tidal_state,
    input  wire [1:0] tidal_dir,
    input  wire [1:0] target_dir,
    input  wire [1:0] left_level,
    input  wire [1:0] right_level,
    input  wire       manual_lock,
    input  wire       force_event,
    input  wire       tx_inhibit,
    output wire       tx_busy,
    output wire       uart_tx
);
    localparam integer DEPTH = (1 << ADDR_W);

    localparam [3:0] EV_BOOT          = 4'h0;
    localparam [3:0] EV_MODE          = 4'h1;
    localparam [3:0] EV_FLOW          = 4'h2;
    localparam [3:0] EV_PREWARN       = 4'h3;
    localparam [3:0] EV_WARN_CANCEL   = 4'h4;
    localparam [3:0] EV_ALL_RED       = 4'h5;
    localparam [3:0] EV_SWITCH_DONE   = 4'h6;
    localparam [3:0] EV_LOCK          = 4'h7;
    localparam [3:0] EV_FORCE_REQUEST = 4'h8;
    localparam [3:0] EV_STATE         = 4'h9;

    localparam [1:0] ST_OPEN    = 2'd0;
    localparam [1:0] ST_ALL_RED = 2'd2;
    localparam [1:0] ST_PREWARN = 2'd3;

    localparam [3:0] CMD_DUMP          = 4'd1;
    localparam [3:0] CMD_CLEAR         = 4'd2;
    localparam [3:0] CMD_MODE_ADAPTIVE = 4'd3;
    localparam [3:0] CMD_MODE_MORNING  = 4'd4;
    localparam [3:0] CMD_MODE_EVENING  = 4'd5;
    localparam [3:0] CMD_MODE_HOLD     = 4'd6;
    localparam [3:0] CMD_LOCK_ON       = 4'd7;
    localparam [3:0] CMD_LOCK_OFF      = 4'd8;
    localparam [3:0] CMD_FORCE_SWITCH  = 4'd9;
    localparam [3:0] REPLY_FORCE_LOCKED = 4'd10;
    localparam [3:0] CMD_UNKNOWN       = 4'd15;

    (* ram_style = "block" *) reg [63:0] log_mem [0:DEPTH-1];
    reg [ADDR_W-1:0] write_ptr;
    reg [ADDR_W:0] record_count;
    reg [ADDR_W-1:0] unread_ptr;
    reg [ADDR_W:0] unread_count;
    wire dump_consume;

    reg [31:0] second_counter;
    reg [31:0] uptime_seconds;
    wire second_tick = (second_counter == CLK_HZ-1);
    always @(posedge clk) begin
        if (!rst_n) begin
            second_counter <= 32'd0;
            uptime_seconds <= 32'd0;
        end else if (second_tick) begin
            second_counter <= 32'd0;
            uptime_seconds <= uptime_seconds + 1'b1;
        end else begin
            second_counter <= second_counter + 1'b1;
        end
    end

    reg [1:0] prev_mode, prev_state;
    reg [1:0] prev_left, prev_right;
    reg prev_lock, boot_pending;
    reg event_valid;
    reg [3:0] event_code;

    always @(*) begin
        event_valid = 1'b1;
        if (boot_pending)
            event_code = EV_BOOT;
        else if (tidal_state != prev_state) begin
            if (tidal_state == ST_PREWARN)
                event_code = EV_PREWARN;
            else if (prev_state == ST_PREWARN)
                event_code = EV_WARN_CANCEL;
            else if (tidal_state == ST_ALL_RED)
                event_code = EV_ALL_RED;
            else if ((prev_state == ST_ALL_RED) && (tidal_state == ST_OPEN))
                event_code = EV_SWITCH_DONE;
            else
                event_code = EV_STATE;
        end else if (force_event)
            event_code = EV_FORCE_REQUEST;
        else if (work_mode != prev_mode)
            event_code = EV_MODE;
        else if ((left_level != prev_left) || (right_level != prev_right))
            event_code = EV_FLOW;
        else if (manual_lock != prev_lock)
            event_code = EV_LOCK;
        else begin
            event_valid = 1'b0;
            event_code = EV_BOOT;
        end
    end

    wire warning_active = (tidal_state == ST_PREWARN);
    reg clear_execute;
    wire memory_write_enable = event_valid && !clear_execute;
    wire [63:0] event_record = {
        8'hA5, uptime_seconds, event_code, work_mode, switch_method,
        tidal_state, tidal_dir, target_dir, left_level, right_level,
        warning_active, manual_lock, 4'b0000
    };

    always @(posedge clk) begin
        if (!rst_n) begin
            write_ptr    <= {ADDR_W{1'b0}};
            record_count <= {(ADDR_W+1){1'b0}};
            unread_ptr   <= {ADDR_W{1'b0}};
            unread_count <= {(ADDR_W+1){1'b0}};
            prev_mode    <= 2'd0;
            prev_state   <= ST_OPEN;
            prev_left    <= 2'd0;
            prev_right   <= 2'd0;
            prev_lock    <= 1'b0;
            boot_pending <= 1'b1;
        end else begin
            prev_mode  <= work_mode;
            prev_state <= tidal_state;
            prev_left  <= left_level;
            prev_right <= right_level;
            prev_lock  <= manual_lock;
            if (clear_execute) begin
                write_ptr    <= {ADDR_W{1'b0}};
                record_count <= {(ADDR_W+1){1'b0}};
                unread_ptr   <= {ADDR_W{1'b0}};
                unread_count <= {(ADDR_W+1){1'b0}};
                boot_pending <= 1'b0;
            end else begin
                if (dump_consume) begin
                    if (event_valid) begin
                        unread_ptr <= write_ptr;
                        unread_count <= {{ADDR_W{1'b0}}, 1'b1};
                    end else begin
                        unread_ptr <= write_ptr;
                        unread_count <= {(ADDR_W+1){1'b0}};
                    end
                end else if (event_valid) begin
                    if (unread_count < DEPTH)
                        unread_count <= unread_count + 1'b1;
                    else
                        unread_ptr <= unread_ptr + 1'b1;
                end

                if (event_valid) begin
                    write_ptr <= write_ptr + 1'b1;
                    if (record_count < DEPTH)
                        record_count <= record_count + 1'b1;
                    boot_pending <= 1'b0;
                end
            end
        end
    end

    // Keep the memory write process free of resets so Vivado can infer BRAM.
    always @(posedge clk) begin
        if (memory_write_enable)
            log_mem[write_ptr] <= event_record;
    end

    // Capture a coherent periodic snapshot. A dump has priority, so status text
    // never appears in the middle of LOG_BEGIN ... LOG_END.
    reg [31:0] status_time;
    reg [1:0] status_mode, status_state, status_dir, status_target;
    reg [1:0] status_left, status_right;
    reg status_warn, status_lock, status_pending;
    reg [31:0] status_second_count;
    reg status_claim;
    always @(posedge clk) begin
        if (!rst_n) begin
            status_second_count <= 32'd0;
            status_pending <= 1'b0;
            status_time <= 32'd0;
            status_mode <= 2'd0;
            status_state <= 2'd0;
            status_dir <= 2'd0;
            status_target <= 2'd0;
            status_left <= 2'd0;
            status_right <= 2'd0;
            status_warn <= 1'b0;
            status_lock <= 1'b0;
        end else begin
            if (status_claim)
                status_pending <= 1'b0;
            if (second_tick) begin
                if (status_second_count == STATUS_INTERVAL_S-1) begin
                    status_second_count <= 32'd0;
                    status_pending <= 1'b1;
                    status_time <= uptime_seconds + 1'b1;
                    status_mode <= work_mode;
                    status_state <= tidal_state;
                    status_dir <= tidal_dir;
                    status_target <= target_dir;
                    status_left <= left_level;
                    status_right <= right_level;
                    status_warn <= warning_active;
                    status_lock <= manual_lock;
                end else begin
                    status_second_count <= status_second_count + 1'b1;
                end
            end
        end
    end

    wire tx_ready;
    reg tx_valid;
    reg [7:0] tx_data;
    uart_tx_byte #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .valid(tx_valid), .data(tx_data),
        .ready(tx_ready), .tx(uart_tx)
    );

    localparam [3:0] U_IDLE        = 4'd0;
    localparam [3:0] U_BCD_STATUS  = 4'd1;
    localparam [3:0] U_SEND_STATUS = 4'd2;
    localparam [3:0] U_SEND_BEGIN  = 4'd3;
    localparam [3:0] U_READ_SET    = 4'd4;
    localparam [3:0] U_READ_WAIT   = 4'd5;
    localparam [3:0] U_READ_LATCH  = 4'd6;
    localparam [3:0] U_BCD_LOG     = 4'd7;
    localparam [3:0] U_SEND_LOG    = 4'd8;
    localparam [3:0] U_SEND_END    = 4'd9;
    localparam [3:0] U_SEND_CLEAR  = 4'd10;
    localparam [3:0] U_SEND_REPLY  = 4'd11;

    localparam integer STATUS_LEN = 111;
    localparam integer BEGIN_LEN  = 21;
    localparam integer LOG_LEN    = 155;
    localparam integer END_LEN    = 9;
    localparam integer CLEAR_LEN  = 16;

    reg [3:0] uart_state;
    assign tx_busy = (uart_state != U_IDLE) || tx_valid;
    reg dump_pending, clear_pending, reply_pending;
    reg [3:0] reply_code;
    reg [ADDR_W:0] dump_remaining;
    reg [15:0] dump_count;
    reg [ADDR_W-1:0] dump_addr, read_addr;
    reg [63:0] mem_read_data, log_record;
    reg [7:0] char_index;

    always @(posedge clk)
        mem_read_data <= log_mem[read_addr];

    assign dump_consume = (uart_state == U_IDLE) && !tx_valid &&
                          !clear_pending && dump_pending;

    // Sequential double-dabble conversion avoids large 32-bit divider logic.
    reg [71:0] bcd_shift;
    reg [5:0] bcd_count;
    reg [39:0] time_bcd;
    reg [71:0] bcd_adjusted, bcd_next;
    integer bcd_i;
    always @(*) begin
        bcd_adjusted = bcd_shift;
        for (bcd_i = 0; bcd_i < 10; bcd_i = bcd_i + 1)
            if (bcd_adjusted[32 + bcd_i*4 +: 4] >= 5)
                bcd_adjusted[32 + bcd_i*4 +: 4] =
                    bcd_adjusted[32 + bcd_i*4 +: 4] + 3;
        bcd_next = bcd_adjusted << 1;
    end

    function [7:0] string_char;
        input [511:0] text;
        input [6:0] length;
        input [6:0] position;
        begin
            string_char = text[((length-position)*8)-1 -: 8];
        end
    endfunction

    function [7:0] bcd_char;
        input [3:0] position;
        begin
            case (position)
                0: bcd_char = "0" + time_bcd[39:36];
                1: bcd_char = "0" + time_bcd[35:32];
                2: bcd_char = "0" + time_bcd[31:28];
                3: bcd_char = "0" + time_bcd[27:24];
                4: bcd_char = "0" + time_bcd[23:20];
                5: bcd_char = "0" + time_bcd[19:16];
                6: bcd_char = "0" + time_bcd[15:12];
                7: bcd_char = "0" + time_bcd[11:8];
                8: bcd_char = "0" + time_bcd[7:4];
                default: bcd_char = "0" + time_bcd[3:0];
            endcase
        end
    endfunction

    function [7:0] mode_char;
        input [1:0] value;
        input [3:0] position;
        begin
            case (value)
                0: mode_char = string_char("adaptive", 8, position);
                1: mode_char = (position < 7) ? string_char("morning", 7, position) : " ";
                2: mode_char = (position < 7) ? string_char("evening", 7, position) : " ";
                default: mode_char = (position < 4) ? string_char("hold", 4, position) : " ";
            endcase
        end
    endfunction

    function [7:0] method_char;
        input [1:0] value;
        input [3:0] position;
        begin
            case (value)
                0: method_char = (position < 8) ? string_char("adaptive", 8, position) : " ";
                1: method_char = string_char("scheduled", 9, position);
                2: method_char = (position < 6) ? string_char("forced", 6, position) : " ";
                default: method_char = (position < 4) ? string_char("hold", 4, position) : " ";
            endcase
        end
    endfunction

    function [7:0] state_char;
        input [1:0] value;
        input [3:0] position;
        begin
            case (value)
                0: state_char = (position < 4) ? string_char("open", 4, position) : " ";
                1: state_char = (position < 8) ? string_char("draining", 8, position) : " ";
                2: state_char = (position < 7) ? string_char("all_red", 7, position) : " ";
                default: state_char = string_char("prewarning", 10, position);
            endcase
        end
    endfunction

    function [7:0] direction_char;
        input [1:0] value;
        input [2:0] position;
        begin
            case (value)
                0: direction_char = (position < 4) ? string_char("none", 4, position) : " ";
                1: direction_char = (position < 4) ? string_char("left", 4, position) : " ";
                2: direction_char = string_char("right", 5, position);
                default: direction_char = string_char("resvd", 5, position);
            endcase
        end
    endfunction

    function [7:0] level_char;
        input [1:0] value;
        input [2:0] position;
        begin
            case (value)
                0: level_char = (position < 3) ? string_char("low", 3, position) : " ";
                1: level_char = string_char("normal", 6, position);
                2: level_char = (position < 4) ? string_char("high", 4, position) : " ";
                default: level_char = (position < 5) ? string_char("resvd", 5, position) : " ";
            endcase
        end
    endfunction

    function [7:0] event_char;
        input [3:0] value;
        input [4:0] position;
        begin
            event_char = " ";
            case (value)
                0: if (position < 4)  event_char = string_char("boot", 4, position);
                1: if (position < 12) event_char = string_char("mode_changed", 12, position);
                2: if (position < 15) event_char = string_char("traffic_changed", 15, position);
                3: if (position < 18) event_char = string_char("prewarning_started", 18, position);
                4: if (position < 20) event_char = string_char("prewarning_cancelled", 20, position);
                5: if (position < 15) event_char = string_char("all_red_started", 15, position);
                6: if (position < 16) event_char = string_char("switch_completed", 16, position);
                7: if (position < 19) event_char = string_char("manual_lock_changed", 19, position);
                8: event_char = string_char("forced_switch_requested", 23, position);
                9: if (position < 13) event_char = string_char("state_changed", 13, position);
                default: if (position < 7) event_char = string_char("unknown", 7, position);
            endcase
        end
    endfunction

    function [7:0] count_char;
        input [1:0] position;
        reg [9:0] count_value;
        begin
            count_value = dump_count[9:0];
            case (position)
                0: count_char = "0" + (count_value / 100);
                1: count_char = "0" + ((count_value / 10) % 10);
                default: count_char = "0" + (count_value % 10);
            endcase
        end
    endfunction

    function [7:0] status_ascii;
        input [7:0] position;
        begin
            if (position < 12) status_ascii = string_char("STATUS time=", 12, position);
            else if (position < 22) status_ascii = bcd_char(position-12);
            else if (position < 28) status_ascii = string_char(" mode=", 6, position-22);
            else if (position < 36) status_ascii = mode_char(status_mode, position-28);
            else if (position < 43) status_ascii = string_char(" state=", 7, position-36);
            else if (position < 53) status_ascii = state_char(status_state, position-43);
            else if (position < 58) status_ascii = string_char(" dir=", 5, position-53);
            else if (position < 63) status_ascii = direction_char(status_dir, position-58);
            else if (position < 71) status_ascii = string_char(" target=", 8, position-63);
            else if (position < 76) status_ascii = direction_char(status_target, position-71);
            else if (position < 82) status_ascii = string_char(" flow=", 6, position-76);
            else if (position < 88) status_ascii = level_char(status_left, position-82);
            else if (position == 88) status_ascii = "/";
            else if (position < 95) status_ascii = level_char(status_right, position-89);
            else if (position < 101) status_ascii = string_char(" warn=", 6, position-95);
            else if (position == 101) status_ascii = "0" + status_warn;
            else if (position < 108) status_ascii = string_char(" lock=", 6, position-102);
            else if (position == 108) status_ascii = "0" + status_lock;
            else if (position == 109) status_ascii = 8'h0D;
            else status_ascii = 8'h0A;
        end
    endfunction

    function [7:0] begin_ascii;
        input [7:0] position;
        begin
            if (position < 16) begin_ascii = string_char("LOG_BEGIN count=", 16, position);
            else if (position < 19) begin_ascii = count_char(position-16);
            else if (position == 19) begin_ascii = 8'h0D;
            else begin_ascii = 8'h0A;
        end
    endfunction

    function [7:0] log_ascii;
        input [7:0] position;
        begin
            if (position < 9) log_ascii = string_char("LOG time=", 9, position);
            else if (position < 19) log_ascii = bcd_char(position-9);
            else if (position < 26) log_ascii = string_char(" event=", 7, position-19);
            else if (position < 49) log_ascii = event_char(log_record[23:20], position-26);
            else if (position < 55) log_ascii = string_char(" mode=", 6, position-49);
            else if (position < 63) log_ascii = mode_char(log_record[19:18], position-55);
            else if (position < 71) log_ascii = string_char(" method=", 8, position-63);
            else if (position < 80) log_ascii = method_char(log_record[17:16], position-71);
            else if (position < 87) log_ascii = string_char(" state=", 7, position-80);
            else if (position < 97) log_ascii = state_char(log_record[15:14], position-87);
            else if (position < 102) log_ascii = string_char(" dir=", 5, position-97);
            else if (position < 107) log_ascii = direction_char(log_record[13:12], position-102);
            else if (position < 115) log_ascii = string_char(" target=", 8, position-107);
            else if (position < 120) log_ascii = direction_char(log_record[11:10], position-115);
            else if (position < 126) log_ascii = string_char(" flow=", 6, position-120);
            else if (position < 132) log_ascii = level_char(log_record[9:8], position-126);
            else if (position == 132) log_ascii = "/";
            else if (position < 139) log_ascii = level_char(log_record[7:6], position-133);
            else if (position < 145) log_ascii = string_char(" warn=", 6, position-139);
            else if (position == 145) log_ascii = "0" + log_record[5];
            else if (position < 152) log_ascii = string_char(" lock=", 6, position-146);
            else if (position == 152) log_ascii = "0" + log_record[4];
            else if (position == 153) log_ascii = 8'h0D;
            else log_ascii = 8'h0A;
        end
    endfunction

    function [7:0] end_ascii;
        input [7:0] position;
        begin
            if (position < 7) end_ascii = string_char("LOG_END", 7, position);
            else if (position == 7) end_ascii = 8'h0D;
            else end_ascii = 8'h0A;
        end
    endfunction

    function [7:0] clear_ascii;
        input [7:0] position;
        begin
            if (position < 14) clear_ascii = string_char("OK log_cleared", 14, position);
            else if (position == 14) clear_ascii = 8'h0D;
            else clear_ascii = 8'h0A;
        end
    endfunction

    function [5:0] reply_text_length;
        input [3:0] code;
        begin
            case (code)
                CMD_MODE_ADAPTIVE: reply_text_length = 16;
                CMD_MODE_MORNING:  reply_text_length = 15;
                CMD_MODE_EVENING:  reply_text_length = 15;
                CMD_MODE_HOLD:     reply_text_length = 12;
                CMD_LOCK_ON:       reply_text_length = 10;
                CMD_LOCK_OFF:      reply_text_length = 11;
                CMD_FORCE_SWITCH:  reply_text_length = 25;
                REPLY_FORCE_LOCKED: reply_text_length = 27;
                default:           reply_text_length = 21;
            endcase
        end
    endfunction

    function [7:0] reply_ascii;
        input [7:0] position;
        reg [5:0] text_length;
        begin
            text_length = reply_text_length(reply_code);
            if (position < text_length) begin
                case (reply_code)
                    CMD_MODE_ADAPTIVE: reply_ascii = string_char("OK MODE adaptive", 16, position);
                    CMD_MODE_MORNING:  reply_ascii = string_char("OK MODE morning", 15, position);
                    CMD_MODE_EVENING:  reply_ascii = string_char("OK MODE evening", 15, position);
                    CMD_MODE_HOLD:     reply_ascii = string_char("OK MODE hold", 12, position);
                    CMD_LOCK_ON:       reply_ascii = string_char("OK LOCK on", 10, position);
                    CMD_LOCK_OFF:      reply_ascii = string_char("OK LOCK off", 11, position);
                    CMD_FORCE_SWITCH:  reply_ascii = string_char("OK FORCE switch_requested", 25, position);
                    REPLY_FORCE_LOCKED: reply_ascii = string_char("ERROR FORCE blocked_by_lock", 27, position);
                    default:           reply_ascii = string_char("ERROR unknown_command", 21, position);
                endcase
            end else if (position == text_length)
                reply_ascii = 8'h0D;
            else
                reply_ascii = 8'h0A;
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            uart_state <= U_IDLE;
            dump_pending <= 1'b0;
            clear_pending <= 1'b0;
            reply_pending <= 1'b0;
            reply_code <= 4'd0;
            clear_execute <= 1'b0;
            status_claim <= 1'b0;
            dump_remaining <= {(ADDR_W+1){1'b0}};
            dump_count <= 16'd0;
            dump_addr <= {ADDR_W{1'b0}};
            read_addr <= {ADDR_W{1'b0}};
            log_record <= 64'd0;
            char_index <= 8'd0;
            bcd_shift <= 72'd0;
            bcd_count <= 6'd0;
            time_bcd <= 40'd0;
            tx_valid <= 1'b0;
            tx_data <= 8'h00;
        end else begin
            clear_execute <= 1'b0;
            status_claim <= 1'b0;
            if (rx_valid) begin
                case (rx_data[3:0])
                    CMD_DUMP:  dump_pending <= 1'b1;
                    CMD_CLEAR: clear_pending <= 1'b1;
                    CMD_MODE_ADAPTIVE,
                    CMD_MODE_MORNING,
                    CMD_MODE_EVENING,
                    CMD_MODE_HOLD,
                    CMD_LOCK_ON,
                    CMD_LOCK_OFF: begin
                        reply_pending <= 1'b1;
                        reply_code <= rx_data[3:0];
                    end
                    CMD_FORCE_SWITCH: begin
                        reply_pending <= 1'b1;
                        reply_code <= manual_lock ? REPLY_FORCE_LOCKED : CMD_FORCE_SWITCH;
                    end
                    default: begin
                        reply_pending <= 1'b1;
                        reply_code <= CMD_UNKNOWN;
                    end
                endcase
            end

            if (tx_valid && tx_ready) begin
                tx_valid <= 1'b0;
                case (uart_state)
                    U_SEND_STATUS: begin
                        if (char_index == STATUS_LEN-1) uart_state <= U_IDLE;
                        else char_index <= char_index + 1'b1;
                    end
                    U_SEND_BEGIN: begin
                        if (char_index == BEGIN_LEN-1) begin
                            uart_state <= (dump_remaining == 0) ? U_SEND_END : U_READ_SET;
                            char_index <= 8'd0;
                        end else char_index <= char_index + 1'b1;
                    end
                    U_SEND_LOG: begin
                        if (char_index == LOG_LEN-1) begin
                            dump_remaining <= dump_remaining - 1'b1;
                            dump_addr <= dump_addr + 1'b1;
                            char_index <= 8'd0;
                            uart_state <= (dump_remaining == 1) ? U_SEND_END : U_READ_SET;
                        end else char_index <= char_index + 1'b1;
                    end
                    U_SEND_END: begin
                        if (char_index == END_LEN-1) uart_state <= U_IDLE;
                        else char_index <= char_index + 1'b1;
                    end
                    U_SEND_CLEAR: begin
                        if (char_index == CLEAR_LEN-1) uart_state <= U_IDLE;
                        else char_index <= char_index + 1'b1;
                    end
                    U_SEND_REPLY: begin
                        if (char_index == reply_text_length(reply_code)+1)
                            uart_state <= U_IDLE;
                        else
                            char_index <= char_index + 1'b1;
                    end
                    default: ;
                endcase
            end else if (!tx_valid) begin
                case (uart_state)
                    U_IDLE: begin
                        char_index <= 8'd0;
                        if (!tx_inhibit && clear_pending) begin
                            clear_pending <= 1'b0;
                            clear_execute <= 1'b1;
                            uart_state <= U_SEND_CLEAR;
                        end else if (!tx_inhibit && dump_pending) begin
                            dump_pending <= 1'b0;
                            dump_remaining <= unread_count;
                            dump_count <= unread_count;
                            dump_addr <= unread_ptr;
                            uart_state <= U_SEND_BEGIN;
                        end else if (!tx_inhibit && reply_pending) begin
                            reply_pending <= 1'b0;
                            uart_state <= U_SEND_REPLY;
                        end else if (!tx_inhibit && status_pending) begin
                            status_claim <= 1'b1;
                            bcd_shift <= {40'd0, status_time};
                            bcd_count <= 6'd0;
                            uart_state <= U_BCD_STATUS;
                        end
                    end
                    U_BCD_STATUS: begin
                        bcd_shift <= bcd_next;
                        if (bcd_count == 31) begin
                            time_bcd <= bcd_next[71:32];
                            char_index <= 8'd0;
                            uart_state <= U_SEND_STATUS;
                        end else bcd_count <= bcd_count + 1'b1;
                    end
                    U_SEND_STATUS: begin tx_data <= status_ascii(char_index); tx_valid <= 1'b1; end
                    U_SEND_BEGIN: begin tx_data <= begin_ascii(char_index); tx_valid <= 1'b1; end
                    U_READ_SET: begin read_addr <= dump_addr; uart_state <= U_READ_WAIT; end
                    U_READ_WAIT: uart_state <= U_READ_LATCH;
                    U_READ_LATCH: begin
                        log_record <= mem_read_data;
                        bcd_shift <= {40'd0, mem_read_data[55:24]};
                        bcd_count <= 6'd0;
                        uart_state <= U_BCD_LOG;
                    end
                    U_BCD_LOG: begin
                        bcd_shift <= bcd_next;
                        if (bcd_count == 31) begin
                            time_bcd <= bcd_next[71:32];
                            char_index <= 8'd0;
                            uart_state <= U_SEND_LOG;
                        end else bcd_count <= bcd_count + 1'b1;
                    end
                    U_SEND_LOG: begin tx_data <= log_ascii(char_index); tx_valid <= 1'b1; end
                    U_SEND_END: begin tx_data <= end_ascii(char_index); tx_valid <= 1'b1; end
                    U_SEND_CLEAR: begin tx_data <= clear_ascii(char_index); tx_valid <= 1'b1; end
                    U_SEND_REPLY: begin tx_data <= reply_ascii(char_index); tx_valid <= 1'b1; end
                    default: uart_state <= U_IDLE;
                endcase
            end
        end
    end
endmodule

module uart_tx_byte #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD = 115200
)(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire [7:0] data,
    output wire ready,
    output reg tx
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer COUNT_W = $clog2(CLKS_PER_BIT);
    reg [COUNT_W-1:0] baud_count;
    reg [3:0] bit_index;
    reg [9:0] shift_reg;
    reg busy;
    assign ready = !busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1;
            baud_count <= {COUNT_W{1'b0}};
            bit_index <= 4'd0;
            shift_reg <= 10'h3FF;
            busy <= 1'b0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (valid) begin
                shift_reg <= {1'b1, data, 1'b0};
                tx <= 1'b0;
                baud_count <= {COUNT_W{1'b0}};
                bit_index <= 4'd0;
                busy <= 1'b1;
            end
        end else if (baud_count == CLKS_PER_BIT-1) begin
            baud_count <= {COUNT_W{1'b0}};
            if (bit_index == 4'd9) begin
                tx <= 1'b1;
                busy <= 1'b0;
            end else begin
                shift_reg <= {1'b1, shift_reg[9:1]};
                tx <= shift_reg[1];
                bit_index <= bit_index + 1'b1;
            end
        end else begin
            baud_count <= baud_count + 1'b1;
        end
    end
endmodule
