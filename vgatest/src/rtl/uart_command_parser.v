`timescale 1ns/1ps

// Line-oriented, case-insensitive command parser. D and C are accepted as
// single-byte commands for compatibility with the CSV client; word commands
// are completed by CR or LF from a serial terminal.
module uart_command_parser #(
    parameter integer CLK_HZ = 100_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       byte_valid,
    input  wire [7:0] byte_data,
    output reg        command_valid,
    output reg  [3:0] command_code
);
    localparam [3:0] CMD_DUMP          = 4'd1;
    localparam [3:0] CMD_CLEAR         = 4'd2;
    localparam [3:0] CMD_MODE_ADAPTIVE = 4'd3;
    localparam [3:0] CMD_MODE_MORNING  = 4'd4;
    localparam [3:0] CMD_MODE_EVENING  = 4'd5;
    localparam [3:0] CMD_MODE_HOLD     = 4'd6;
    localparam [3:0] CMD_LOCK_ON       = 4'd7;
    localparam [3:0] CMD_LOCK_OFF      = 4'd8;
    localparam [3:0] CMD_FORCE_SWITCH  = 4'd9;
    localparam [3:0] CMD_UNKNOWN       = 4'd15;

    reg [159:0] command_buffer;
    reg [4:0] command_length;
    reg overflow;
    localparam integer TIMEOUT_TICKS = (CLK_HZ >= 10) ? (CLK_HZ / 10) : 1;
    localparam integer TIMEOUT_W = (TIMEOUT_TICKS <= 1) ? 1 : $clog2(TIMEOUT_TICKS);
    reg [TIMEOUT_W-1:0] idle_counter;
    reg binary_header_wait;
    reg [3:0] binary_remaining;
    reg config_line_candidate;
    wire [7:0] upper_data = ((byte_data >= "a") && (byte_data <= "z")) ?
                            (byte_data - 8'd32) : byte_data;
    wire [159:0] next_command = {command_buffer[151:0], upper_data};
    wire ascii_byte_valid = byte_valid && !binary_header_wait &&
                            (binary_remaining == 0) && (byte_data != 8'hAA);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_header_wait <= 1'b0;
            binary_remaining <= 4'd0;
        end else if (byte_valid) begin
            if (binary_remaining != 0)
                binary_remaining <= binary_remaining - 1'b1;
            else if (binary_header_wait) begin
                binary_header_wait <= 1'b0;
                if (byte_data == 8'h55) binary_remaining <= 4'd8;
            end else if (byte_data == 8'hAA)
                binary_header_wait <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            command_buffer <= 160'd0;
            command_length <= 5'd0;
            overflow       <= 1'b0;
            idle_counter   <= {TIMEOUT_W{1'b0}};
            command_valid  <= 1'b0;
            command_code   <= 4'd0;
            config_line_candidate <= 1'b0;
        end else begin
            command_valid <= 1'b0;
            if (byte_valid && (byte_data == 8'hAA)) begin
                command_buffer <= 160'd0;
                command_length <= 5'd0;
                overflow <= 1'b0;
                config_line_candidate <= 1'b0;
            end else if (ascii_byte_valid) begin
                idle_counter <= {TIMEOUT_W{1'b0}};
                if ((byte_data == 8'h0D) || (byte_data == 8'h0A)) begin
                    if ((command_length != 0) && !config_line_candidate) begin
                        command_valid <= 1'b1;
                        if (!overflow && (command_buffer == "MODE ADAPTIVE"))
                            command_code <= CMD_MODE_ADAPTIVE;
                        else if (!overflow && (command_buffer == "MODE MORNING"))
                            command_code <= CMD_MODE_MORNING;
                        else if (!overflow && (command_buffer == "MODE EVENING"))
                            command_code <= CMD_MODE_EVENING;
                        else if (!overflow && (command_buffer == "MODE HOLD"))
                            command_code <= CMD_MODE_HOLD;
                        else if (!overflow && (command_buffer == "LOCK ON"))
                            command_code <= CMD_LOCK_ON;
                        else if (!overflow && (command_buffer == "LOCK OFF"))
                            command_code <= CMD_LOCK_OFF;
                        else if (!overflow && (command_buffer == "FORCE SWITCH"))
                            command_code <= CMD_FORCE_SWITCH;
                        else
                            command_code <= CMD_UNKNOWN;
                    end
                    command_buffer <= 160'd0;
                    command_length <= 5'd0;
                    overflow       <= 1'b0;
                    config_line_candidate <= 1'b0;
                end else if ((command_length == 0) &&
                             ((upper_data == "D") || (upper_data == "C"))) begin
                    command_valid <= 1'b1;
                    command_code <= (upper_data == "D") ? CMD_DUMP : CMD_CLEAR;
                end else if (command_length < 20) begin
                    if (command_length == 0)
                        config_line_candidate <= (upper_data == "L") || (upper_data == "T");
                    else if ((command_length == 1) && config_line_candidate)
                        config_line_candidate <= ((command_buffer[7:0] == "L") && (upper_data == "R")) ||
                                                 ((command_buffer[7:0] == "T") && (upper_data == "B"));
                    // Execute complete readable commands immediately. A serial
                    // terminal may append CR/LF, but it is no longer required.
                    if (next_command == "MODE ADAPTIVE") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_MODE_ADAPTIVE;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "MODE MORNING") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_MODE_MORNING;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "MODE EVENING") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_MODE_EVENING;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "MODE HOLD") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_MODE_HOLD;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "LOCK ON") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_LOCK_ON;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "LOCK OFF") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_LOCK_OFF;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else if (next_command == "FORCE SWITCH") begin
                        command_valid <= 1'b1;
                        command_code <= CMD_FORCE_SWITCH;
                        command_buffer <= 160'd0;
                        command_length <= 5'd0;
                    end else begin
                        command_buffer <= next_command;
                        command_length <= command_length + 1'b1;
                    end
                end else begin
                    overflow <= 1'b1;
                end
            end else if ((command_length != 0) || overflow) begin
                // Discard a truncated/noisy command after 100 ms so it cannot
                // poison every command that follows.
                if (idle_counter == TIMEOUT_TICKS-1) begin
                    command_buffer <= 160'd0;
                    command_length <= 5'd0;
                    overflow       <= 1'b0;
                    config_line_candidate <= 1'b0;
                    idle_counter   <= {TIMEOUT_W{1'b0}};
                end else begin
                    idle_counter <= idle_counter + 1'b1;
                end
            end else begin
                idle_counter <= {TIMEOUT_W{1'b0}};
            end
        end
    end
endmodule
