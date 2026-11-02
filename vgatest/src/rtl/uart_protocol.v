`timescale 1ns/1ps

// Fixed binary protocol used by the PC application.
// Request:  AA 55 06 TYPE SEQ PAGE ITEM VALUE_L VALUE_H CRC8
// Response: AA 55 06 TYPE SEQ PAGE ITEM VALUE_L VALUE_H CRC8
// CRC-8 polynomial 0x07, initial value 0, covering LEN through VALUE_H.
module uart_protocol #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD = 115200,
    parameter integer STATUS_HZ = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        legacy_tx_busy,
    input  wire [2:0]  current_page,

    output reg         command_valid,
    output reg  [7:0]  command_type,
    output reg  [7:0]  command_seq,
    output reg  [7:0]  command_page,
    output reg  [7:0]  command_item,
    output reg  [15:0] command_value,
    input  wire        command_supported,

    output wire [7:0]  query_page,
    output wire [7:0]  query_item,
    input  wire [15:0] query_value,
    input  wire        query_valid,

    output wire        tx,
    output wire        tx_select,
    output wire        tx_busy
);
    localparam [7:0] TYPE_SET    = 8'h10;
    localparam [7:0] TYPE_GET    = 8'h11;
    localparam [7:0] TYPE_ACTION = 8'h12;
    localparam [7:0] TYPE_ACK    = 8'h80;
    localparam [7:0] TYPE_NACK   = 8'h81;
    localparam [7:0] TYPE_STATUS = 8'h90;

    function [7:0] crc8_next;
        input [7:0] crc;
        input [7:0] data;
        integer k;
        reg [7:0] c;
        begin
            c = crc ^ data;
            for (k = 0; k < 8; k = k + 1)
                c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
            crc8_next = c;
        end
    endfunction

    localparam [3:0] R_SYNC1 = 4'd0, R_SYNC2 = 4'd1, R_LEN = 4'd2,
                     R_TYPE  = 4'd3, R_SEQ   = 4'd4, R_PAGE = 4'd5,
                     R_ITEM  = 4'd6, R_VL    = 4'd7, R_VH   = 4'd8,
                     R_CRC   = 4'd9;
    reg [3:0] rx_state;
    reg [7:0] rx_type, rx_seq, rx_page, rx_item, rx_vl, rx_vh, rx_crc;
    reg frame_done, frame_crc_ok;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= R_SYNC1;
            rx_type <= 0; rx_seq <= 0; rx_page <= 0; rx_item <= 0;
            rx_vl <= 0; rx_vh <= 0; rx_crc <= 0;
            frame_done <= 0; frame_crc_ok <= 0;
        end else begin
            frame_done <= 1'b0;
            if (rx_valid) begin
                case (rx_state)
                    R_SYNC1: if (rx_data == 8'hAA) rx_state <= R_SYNC2;
                    R_SYNC2: begin
                        if (rx_data == 8'h55) rx_state <= R_LEN;
                        else rx_state <= (rx_data == 8'hAA) ? R_SYNC2 : R_SYNC1;
                    end
                    R_LEN: begin
                        if (rx_data == 8'h06) begin
                            rx_crc <= crc8_next(8'h00, rx_data);
                            rx_state <= R_TYPE;
                        end else rx_state <= R_SYNC1;
                    end
                    R_TYPE: begin rx_type <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_SEQ; end
                    R_SEQ:  begin rx_seq  <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_PAGE; end
                    R_PAGE: begin rx_page <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_ITEM; end
                    R_ITEM: begin rx_item <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_VL; end
                    R_VL:   begin rx_vl   <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_VH; end
                    R_VH:   begin rx_vh   <= rx_data; rx_crc <= crc8_next(rx_crc, rx_data); rx_state <= R_CRC; end
                    default: begin
                        frame_done <= 1'b1;
                        frame_crc_ok <= (rx_data == rx_crc);
                        rx_state <= R_SYNC1;
                    end
                endcase
            end
        end
    end

    reg response_pending;
    reg [7:0] response_type, response_seq, response_page, response_item;
    reg [15:0] response_value;
    reg [7:0] status_item;
    reg [31:0] status_count;
    localparam integer STATUS_TICKS = CLK_HZ / STATUS_HZ;
    wire status_tick = (status_count == STATUS_TICKS-1);
    reg status_pending;
    reg request_pending, request_crc_ok;

    assign query_page = request_pending ? command_page : {5'd0, current_page};
    assign query_item = request_pending ? command_item : status_item;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            command_valid <= 0;
            command_type <= 0; command_seq <= 0; command_page <= 0;
            command_item <= 0; command_value <= 0;
            response_pending <= 0;
            response_type <= 0; response_seq <= 0; response_page <= 0;
            response_item <= 0; response_value <= 0;
            status_count <= 0; status_item <= 0; status_pending <= 0;
            request_pending <= 0; request_crc_ok <= 0;
        end else begin
            command_valid <= 1'b0;
            if (status_tick) begin
                status_count <= 0;
                status_pending <= 1'b1;
            end else status_count <= status_count + 1'b1;

            if (frame_done) begin
                command_type <= rx_type;
                command_seq <= rx_seq;
                command_page <= rx_page;
                command_item <= rx_item;
                command_value <= {rx_vh, rx_vl};
                request_crc_ok <= frame_crc_ok;
                request_pending <= 1'b1;
            end

            // Validate one clock after latching the request. This keeps the
            // original top-level command_* validation path and avoids a wide
            // duplicate request bus across the already congested design.
            if (request_pending) begin
                request_pending <= 1'b0;
                response_pending <= 1'b1;
                response_seq <= command_seq;
                response_page <= command_page;
                response_item <= command_item;
                response_value <= (command_type == TYPE_GET) ? query_value : command_value;
                if (!request_crc_ok ||
                    !((command_type == TYPE_SET) || (command_type == TYPE_GET) ||
                      (command_type == TYPE_ACTION)) ||
                    !command_supported || ((command_type == TYPE_GET) && !query_valid))
                    response_type <= TYPE_NACK;
                else begin
                    response_type <= TYPE_ACK;
                    if (command_type != TYPE_GET)
                        command_valid <= 1'b1;
                end
            end

            if (!response_pending && status_pending && query_valid) begin
                response_pending <= 1'b1;
                response_type <= TYPE_STATUS;
                response_seq <= 8'h00;
                response_page <= {5'd0, current_page};
                response_item <= status_item;
                response_value <= query_value;
                status_pending <= 1'b0;
                status_item <= status_item + 1'b1;
            end else if (!response_pending && status_pending && !query_valid) begin
                status_item <= status_item + 1'b1;
            end

            if (packet_claim) response_pending <= 1'b0;
        end
    end

    function [7:0] packet_crc;
        input [7:0] typ, seq, page, item, vl, vh;
        reg [7:0] c;
        begin
            c = crc8_next(8'h00, 8'h06);
            c = crc8_next(c, typ); c = crc8_next(c, seq);
            c = crc8_next(c, page); c = crc8_next(c, item);
            c = crc8_next(c, vl); c = crc8_next(c, vh);
            packet_crc = c;
        end
    endfunction

    reg [7:0] tx_type, tx_seq, tx_page, tx_item;
    reg [15:0] tx_value;
    reg [3:0] tx_index;
    reg sending;
    reg [7:0] byte_data;
    wire byte_ready;
    wire byte_valid = sending;
    // Keep the protocol selected until the final UART byte (CRC) has fully
    // shifted out.  Dropping tx_select when tx_index reached 9 previously
    // switched the pin back to the legacy ASCII transmitter one byte early.
    wire packet_claim = response_pending && !legacy_tx_busy && !sending && byte_ready;
    assign tx_select = sending || !byte_ready;
    assign tx_busy = sending || !byte_ready || response_pending;

    always @* begin
        case (tx_index)
            0: byte_data = 8'hAA;
            1: byte_data = 8'h55;
            2: byte_data = 8'h06;
            3: byte_data = tx_type;
            4: byte_data = tx_seq;
            5: byte_data = tx_page;
            6: byte_data = tx_item;
            7: byte_data = tx_value[7:0];
            8: byte_data = tx_value[15:8];
            default: byte_data = packet_crc(tx_type, tx_seq, tx_page, tx_item,
                                            tx_value[7:0], tx_value[15:8]);
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sending <= 0; tx_index <= 0;
            tx_type <= 0; tx_seq <= 0; tx_page <= 0; tx_item <= 0; tx_value <= 0;
        end else begin
            if (packet_claim) begin
                tx_type <= response_type; tx_seq <= response_seq;
                tx_page <= response_page; tx_item <= response_item;
                tx_value <= response_value;
                tx_index <= 0; sending <= 1'b1;
            end else if (sending && byte_ready) begin
                if (tx_index == 4'd9) begin
                    sending <= 1'b0;
                    tx_index <= 0;
                end else tx_index <= tx_index + 1'b1;
            end
        end
    end

    uart_tx_byte #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .valid(byte_valid), .data(byte_data),
        .ready(byte_ready), .tx(tx)
    );
endmodule
