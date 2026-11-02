// 640x480 RGB565 background generated from diagramnew.png.
// The registered output aligns with green_wave_scene's registered draw coordinates.
module green_wave_bg_rom(
    input  wire        clk,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    output reg  [15:0] rgb
);
    localparam integer DEPTH = 640 * 480;
    (* rom_style = "block" *) reg [15:0] mem [0:DEPTH-1];
    initial $readmemh("D:/vivado/vgatest/vgatest.srcs/sources_1/ip/green_wave_bg_rom/green_wave_bg_rom.mem", mem);
    wire [18:0] addr = (y < 10'd480 && x < 10'd640) ? (y * 19'd640 + x) : 19'd0;
    always @(posedge clk) rgb <= mem[addr];
endmodule
