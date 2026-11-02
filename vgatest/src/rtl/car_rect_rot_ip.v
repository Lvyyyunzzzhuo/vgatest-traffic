// car_rect_rot_ip.v
// ��������(pix_x,pix_y)����������(cx,cy)���볤���(halfL,halfW)����ת�ǵ� cos/sin��Q8.8��
// ������ˮ��S1����dx/dy��S2���˼Ӳ��Ƚϣ���� hit��valid ͬ������
`timescale 1ns/1ps
module car_rect_rot_ip #(
  parameter integer Q = 8  // С��λ
)(
  input  wire        clk,
  input  wire        valid_in,

  input  wire [9:0]  pix_x,
  input  wire [9:0]  pix_y,
  input  wire signed [15:0] cx,
  input  wire signed [15:0] cy,
  input  wire signed [15:0] halfL, // ����
  input  wire signed [15:0] halfW, // ����
  input  wire signed [15:0] cos_q, // Q8.8
  input  wire signed [15:0] sin_q, // Q8.8

  output reg         hit,
  output reg         valid_out
);
  // S1: ��ֵ
  reg signed [17:0] dx_s1, dy_s1;
  reg signed [15:0] halfL_s1, halfW_s1;
  reg signed [15:0] cos_s1, sin_s1;
  reg               v_s1;
  always @(posedge clk) begin
    dx_s1   <= $signed({1'b0,pix_x}) - cx;
    dy_s1   <= $signed({1'b0,pix_y}) - cy;
    halfL_s1<= halfL;
    halfW_s1<= halfW;
    cos_s1  <= cos_q;
    sin_s1  <= sin_q;
    v_s1    <= valid_in;
  end

  // S2: ��ת�任 + ���αȽ�
  // x' =  dx*cos + dy*sin
  // y' = -dx*sin + dy*cos
  reg signed [31:0] xp_q, yp_q;
  reg               hit_s2;
  reg               v_s2;
  always @(posedge clk) begin
    xp_q <= $signed(dx_s1)*$signed(cos_s1) + $signed(dy_s1)*$signed(sin_s1);
    yp_q <= -$signed(dx_s1)*$signed(sin_s1) + $signed(dy_s1)*$signed(cos_s1);

    // ���� Q �õ���������
    // �Ƚ����䣺[-halfL, halfL) / [-halfW, halfW)
    hit_s2 <= ( $signed(xp_q >>> Q) >= -halfL_s1 ) && ( $signed(xp_q >>> Q) < halfL_s1 ) &&
              ( $signed(yp_q >>> Q) >= -halfW_s1 ) && ( $signed(yp_q >>> Q) < halfW_s1 );
    v_s2   <= v_s1;
  end

  always @(posedge clk) begin
    hit       <= hit_s2;
    valid_out <= v_s2;
  end
endmodule
