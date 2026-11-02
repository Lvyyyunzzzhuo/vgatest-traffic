module sincos90_q88 #(
  parameter integer ANG_STEPS = 12,
  parameter integer DEPTH = 256
)(
  input  wire clk,
  input  wire [7:0] idx,
  output reg  signed [15:0] cos_q, // Q8.8
  output reg  signed [15:0] sin_q  // Q8.8
);
  // 强制 BRAM
  (* rom_style="block", ram_style="block" *)
  reg signed [15:0] cos_rom [0:DEPTH-1];
  (* rom_style="block", ram_style="block" *)
  reg signed [15:0] sin_rom [0:DEPTH-1];

  integer i;
  initial begin
    for (i=0;i<DEPTH;i=i+1) begin cos_rom[i]=16'sd0; sin_rom[i]=16'sd0; end
    // 0..16 样本（Q8.8）
    cos_rom[ 0]=16'sd256; sin_rom[ 0]=16'sd0;
    cos_rom[ 1]=16'sd255; sin_rom[ 1]=16'sd27;
    cos_rom[ 2]=16'sd251; sin_rom[ 2]=16'sd53;
    cos_rom[ 3]=16'sd243; sin_rom[ 3]=16'sd79;
    cos_rom[ 4]=16'sd234; sin_rom[ 4]=16'sd104;
    cos_rom[ 5]=16'sd222; sin_rom[ 5]=16'sd128;
    cos_rom[ 6]=16'sd207; sin_rom[ 6]=16'sd150;
    cos_rom[ 7]=16'sd190; sin_rom[ 7]=16'sd171;
    cos_rom[ 8]=16'sd171; sin_rom[ 8]=16'sd190;
    cos_rom[ 9]=16'sd150; sin_rom[ 9]=16'sd207;
    cos_rom[10]=16'sd128; sin_rom[10]=16'sd222;
    cos_rom[11]=16'sd104; sin_rom[11]=16'sd234;
    cos_rom[12]=16'sd79;  sin_rom[12]=16'sd243;
    cos_rom[13]=16'sd53;  sin_rom[13]=16'sd251;
    cos_rom[14]=16'sd27;  sin_rom[14]=16'sd255;
    cos_rom[15]=16'sd9;   sin_rom[15]=16'sd256;
    cos_rom[16]=16'sd0;   sin_rom[16]=16'sd256;
    for (i=17;i<DEPTH;i=i+1) begin
      cos_rom[i]=cos_rom[16]; sin_rom[i]=sin_rom[16];
    end
  end

  always @(posedge clk) begin
    cos_q <= cos_rom[idx];
    sin_q <= sin_rom[idx];
  end
endmodule
