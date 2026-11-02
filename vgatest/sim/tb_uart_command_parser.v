`timescale 1ns/1ps

module tb_uart_command_parser;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg byte_valid = 1'b0;
    reg [7:0] byte_data = 8'd0;
    wire command_valid;
    wire [3:0] command_code;
    integer command_count = 0;
    reg [3:0] commands [0:15];

    always #5 clk = ~clk;

    uart_command_parser #(.CLK_HZ(1000)) dut (
        .clk(clk), .rst_n(rst_n),
        .byte_valid(byte_valid), .byte_data(byte_data),
        .command_valid(command_valid), .command_code(command_code)
    );

    always @(posedge clk) begin
        if (command_valid) begin
            commands[command_count] <= command_code;
            command_count <= command_count + 1;
        end
    end

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            byte_data = value;
            byte_valid = 1'b1;
            @(negedge clk);
            byte_valid = 1'b0;
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;

        send_byte("D"); send_byte(8'h0D);
        send_byte("c"); send_byte(8'h0D);

        send_byte("m"); send_byte("o"); send_byte("d"); send_byte("e");
        send_byte(" "); send_byte("m"); send_byte("o"); send_byte("r");
        send_byte("n"); send_byte("i"); send_byte("n"); send_byte("g");
        send_byte(8'h0D);

        send_byte("L"); send_byte("O"); send_byte("C"); send_byte("K");
        send_byte(" "); send_byte("O"); send_byte("N"); send_byte(8'h0A);

        send_byte("F"); send_byte("O"); send_byte("R"); send_byte("C");
        send_byte("E"); send_byte(" "); send_byte("S"); send_byte("W");
        send_byte("I"); send_byte("T"); send_byte("C"); send_byte("H");
        send_byte(8'h0D);

        send_byte("B"); send_byte("A"); send_byte("D"); send_byte(8'h0D);

        // Complete word commands must work without CR/LF.
        send_byte("M"); send_byte("O"); send_byte("D"); send_byte("E");
        send_byte(" "); send_byte("E"); send_byte("V"); send_byte("E");
        send_byte("N"); send_byte("I"); send_byte("N"); send_byte("G");
        send_byte("L"); send_byte("O"); send_byte("C"); send_byte("K");
        send_byte(" "); send_byte("O"); send_byte("F"); send_byte("F");

        // A truncated command must time out instead of blocking a later D.
        send_byte("M"); send_byte("O");
        repeat (110) @(posedge clk);
        send_byte("D");
        repeat (4) @(posedge clk);

        if (command_count !== 9 || commands[0] !== 1 || commands[1] !== 2 ||
            commands[2] !== 4 || commands[3] !== 7 || commands[4] !== 9 ||
            commands[5] !== 15 || commands[6] !== 5 || commands[7] !== 8 ||
            commands[8] !== 1) begin
            $display("FAIL: command parser mismatch count=%0d", command_count);
            $finish;
        end
        $display("PASS: readable UART command parser verified");
        $finish;
    end
endmodule
