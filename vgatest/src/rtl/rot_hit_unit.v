// rot_hit_unit.v
// 封装：内部查表 sincos（1拍）+ 旋转命中（1拍）= 总体 2 拍；输出带 valid_out
`timescale 1ns/1ps
module rot_hit_unit #(
  parameter integer Q = 8,
  parameter integer ANG_STEPS = 16
)(
  input  wire        clk,
  input  wire        valid_in,
  input  wire [9:0]  pix_x,
  input  wire [9:0]  pix_y,
  input  wire signed [15:0] cx,
  input  wire signed [15:0] cy,
  input  wire signed [15:0] halfL,
  input  wire signed [15:0] halfW,
  input  wire [7:0]  ang_idx_req,  // 这拍给地址 → 下一拍 sin/cos 生效（同步ROM）

  output wire        hit,
  output wire        valid_out
);
  // 1拍：sincos ROM
  wire signed [15:0] COS_Q, SIN_Q;
  sincos90_q88 #(.ANG_STEPS(ANG_STEPS)) u_sincos (
    .clk  (clk),
    .idx  (ang_idx_req),
    .cos_q(COS_Q),
    .sin_q(SIN_Q)
  );

  // 再1拍：旋转命中
  car_rect_rot_ip #(.Q(Q)) u_rot (
    .clk      (clk),
    .valid_in (valid_in),
    .pix_x    (pix_x),
    .pix_y    (pix_y),
    .cx       (cx),
    .cy       (cy),
    .halfL    (halfL),
    .halfW    (halfW),
    .cos_q    (COS_Q),
    .sin_q    (SIN_Q),
    .hit      (hit),
    .valid_out(valid_out)
  );
endmodule
