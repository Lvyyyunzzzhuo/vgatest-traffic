`timescale 1ns/1ps

module tb_event_log_uart;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'h00;
    reg [1:0] mode = 2'd0;
    reg [1:0] method = 2'd0;
    reg [1:0] state = 2'd0;
    reg [1:0] direction = 2'd1;
    reg [1:0] target = 2'd2;
    reg [1:0] left = 2'd0;
    reg [1:0] right = 2'd0;
    reg lock = 1'b0;
    reg force_event = 1'b0;
    wire tx;
    integer tx_byte_count = 0;
    integer dump_bytes;
    integer empty_dump_start;
    integer one_dump_start;
    integer status_start;
    integer reply_start;
    integer clear_start;
    reg [7:0] tx_bytes [0:2047];

    always #5 clk = ~clk;

    event_log_uart #(
        .CLK_HZ(20), .BAUD(10), .ADDR_W(3), .STATUS_INTERVAL_S(100000)
    ) dut (
        .clk(clk), .rst_n(rst_n), .rx_valid(rx_valid), .rx_data(rx_data),
        .work_mode(mode), .switch_method(method), .tidal_state(state),
        .tidal_dir(direction), .target_dir(target), .left_level(left),
        .right_level(right), .manual_lock(lock), .force_event(force_event),
        .uart_tx(tx)
    );

    always @(posedge clk) begin
        if (dut.tx_valid && dut.tx_ready) begin
            tx_bytes[tx_byte_count] <= dut.tx_data;
            tx_byte_count <= tx_byte_count + 1;
        end
    end

    task wait_clocks;
        input integer count;
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) @(posedge clk);
        end
    endtask

    task send_command;
        input [7:0] command;
        begin
            @(negedge clk);
            rx_data = command;
            rx_valid = 1'b1;
            @(negedge clk);
            rx_valid = 1'b0;
        end
    endtask

    initial begin
        wait_clocks(3);
        #1 rst_n = 1'b1;
        wait_clocks(3);             // boot
        #1 left = 2'd2;
        wait_clocks(3);             // traffic change
        #1 state = 2'd3;
        wait_clocks(3);             // prewarning starts
        #1 state = 2'd1;
        wait_clocks(3);             // prewarning cancelled
        #1 state = 2'd2;
        wait_clocks(3);             // all red
        #1 direction = 2'd2;
        state = 2'd0;
        wait_clocks(3);             // switch complete

        if (dut.record_count !== 6) begin
            $display("FAIL: expected 6 records, got %0d", dut.record_count);
            $finish;
        end
        if (dut.log_mem[0][63:56] !== 8'hA5 ||
            dut.log_mem[0][23:20] !== 4'h0 ||
            dut.log_mem[2][23:20] !== 4'h3 ||
            dut.log_mem[3][23:20] !== 4'h4 ||
            dut.log_mem[5][23:20] !== 4'h6) begin
            $display("FAIL: record format/event sequence mismatch");
            $finish;
        end

        send_command(8'd1);
        wait (dut.uart_state != 0);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        dump_bytes = tx_byte_count;
        if (dump_bytes !== 960 || dut.unread_count !== 0 ||
            tx_bytes[0] !== "L" || tx_bytes[1] !== "O" || tx_bytes[2] !== "G" ||
            tx_bytes[3] !== "_" || tx_bytes[16] !== "0" ||
            tx_bytes[17] !== "0" || tx_bytes[18] !== "6" ||
            tx_bytes[19] !== 8'h0D || tx_bytes[20] !== 8'h0A ||
            tx_bytes[21] !== "L" || tx_bytes[22] !== "O" || tx_bytes[23] !== "G" ||
            tx_bytes[47] !== "b" || tx_bytes[202] !== "t" ||
            tx_bytes[357] !== "p" || tx_bytes[512] !== "p" ||
            tx_bytes[667] !== "a" || tx_bytes[822] !== "s" ||
            tx_bytes[951] !== "L" || tx_bytes[958] !== 8'h0D ||
            tx_bytes[959] !== 8'h0A) begin
            $display("FAIL: ASCII log dump mismatch (%0d bytes)", dump_bytes);
            $finish;
        end

        // A second D has no new records and therefore returns an empty block.
        empty_dump_start = tx_byte_count;
        send_command(8'd1);
        wait (dut.uart_state != 0);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== empty_dump_start + 30 ||
            tx_bytes[empty_dump_start+16] !== "0" ||
            tx_bytes[empty_dump_start+17] !== "0" ||
            tx_bytes[empty_dump_start+18] !== "0") begin
            $display("FAIL: empty incremental dump mismatch");
            $finish;
        end

        // One new event must be the only record in the next D response.
        #1 mode = 2'd1;
        wait_clocks(3);
        if (dut.unread_count !== 1) begin
            $display("FAIL: expected one unread event");
            $finish;
        end
        one_dump_start = tx_byte_count;
        send_command(8'd1);
        wait (dut.uart_state != 0);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== one_dump_start + 185 ||
            tx_bytes[one_dump_start+16] !== "0" ||
            tx_bytes[one_dump_start+17] !== "0" ||
            tx_bytes[one_dump_start+18] !== "1" ||
            tx_bytes[one_dump_start+47] !== "m" ||
            dut.unread_count !== 0) begin
            $display("FAIL: one-record incremental dump mismatch");
            $finish;
        end

        // Trigger a periodic snapshot and verify its complete ASCII line.
        status_start = tx_byte_count;
        @(negedge clk);
        dut.status_second_count = 99999;
        dut.second_counter = 19;
        @(posedge clk);
        wait (dut.uart_state == 2);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== status_start + 111 ||
            tx_bytes[status_start] !== "S" || tx_bytes[status_start+1] !== "T" ||
            tx_bytes[status_start+109] !== 8'h0D ||
            tx_bytes[status_start+110] !== 8'h0A) begin
            $display("FAIL: periodic STATUS line mismatch");
            $finish;
        end

        // FORCE SWITCH is explicitly rejected while locked.
        #1 lock = 1'b1;
        wait_clocks(3);
        reply_start = tx_byte_count;
        send_command(8'd9);
        wait (dut.uart_state == 11);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== reply_start + 29 ||
            tx_bytes[reply_start] !== "E" || tx_bytes[reply_start+6] !== "F") begin
            $display("FAIL: locked force rejection mismatch");
            $finish;
        end

        #1 lock = 1'b0;
        wait_clocks(3);
        reply_start = tx_byte_count;
        send_command(8'd9);
        wait (dut.uart_state == 11);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== reply_start + 27 ||
            tx_bytes[reply_start] !== "O" || tx_bytes[reply_start+3] !== "F") begin
            $display("FAIL: unlocked force acknowledgement mismatch");
            $finish;
        end

        reply_start = tx_byte_count;
        send_command(8'd3);
        wait (dut.uart_state == 11);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (tx_byte_count !== reply_start + 18 ||
            tx_bytes[reply_start] !== "O" || tx_bytes[reply_start+3] !== "M") begin
            $display("FAIL: mode acknowledgement mismatch");
            $finish;
        end

        clear_start = tx_byte_count;
        send_command(8'd2);
        wait (dut.uart_state == 10);
        wait (dut.uart_state == 0);
        wait_clocks(2);
        if (dut.record_count !== 0 || tx_byte_count !== clear_start + 16 ||
            tx_bytes[clear_start] !== "O" || tx_bytes[clear_start+1] !== "K" ||
            tx_bytes[clear_start+14] !== 8'h0D ||
            tx_bytes[clear_start+15] !== 8'h0A) begin
            $display("FAIL: clear acknowledgement count=%0d start=%0d total=%0d bytes=%02x %02x %02x %02x",
                dut.record_count, clear_start, tx_byte_count,
                tx_bytes[clear_start], tx_bytes[clear_start+1],
                tx_bytes[clear_start+14], tx_bytes[clear_start+15]);
            $finish;
        end

        $display("PASS: BRAM log, ASCII dump, periodic status, and clear verified");
        $finish;
    end
endmodule
