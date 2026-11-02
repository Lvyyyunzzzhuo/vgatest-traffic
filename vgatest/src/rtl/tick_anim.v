module tick_anim(
    input wire clk,     // 25MHz
    input wire rst_n,
    output reg tick_anim
);
    parameter DIV_ANIM = 833_333;   // 25MHz / 30 ¡Ö 833333
    reg [19:0] cnt;

    always @(posedge clk or negedge rst_n)
        if(!rst_n) begin
            cnt <= 0;
            tick_anim <= 0;
        end
        else if(cnt >= DIV_ANIM - 1) begin
            cnt <= 0;
            tick_anim <= 1'b1;
        end
        else begin
            cnt <= cnt + 1'b1;
            tick_anim <= 1'b0;
        end
endmodule
