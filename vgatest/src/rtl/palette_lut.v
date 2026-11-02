// palette_lut.v -- 4bit Ë÷Òýµ½ RGB565
module palette_lut(
  input  wire       clk,
  input  wire [3:0] idx,
  output reg [15:0] rgb
);
  always @(posedge clk) begin
    case(idx)
      4'd0: rgb <= 16'h0000; // IDX_BG: ºÚ
      4'd1: rgb <= 16'h2104; // IDX_ROAD: Éî»Ò(Ô¼)
      4'd2: rgb <= 16'hFFFF; // IDX_EDGE: °×
      4'd3: rgb <= 16'hFFE0; // IDX_CZ_YEL: »Æ
      4'd4: rgb <= 16'hE71C; // IDX_LANE_W: µ­°×(½ü°×)
      4'd5: rgb <= 16'hFFFF; // IDX_ZEBRA: °×
      4'd6: rgb <= 16'h8410; // IDX_BOX: ÖÐ»Ò
      default: rgb <= 16'h0000;
    endcase
  end
endmodule
