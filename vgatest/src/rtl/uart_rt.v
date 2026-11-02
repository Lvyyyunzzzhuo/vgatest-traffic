// uart_rx.v  -- 100MHz 时钟, 115200bps, 8N1, 16x oversampling
module uart_rx #(
  parameter CLK_HZ = 100_000_000,
  parameter BAUD   = 115200
)(
  input  wire clk,
  input  wire rst_n,
  input  wire rx,          // 外部串口RX脚（FTDI TX 连接此脚）
  output reg  valid,       // 拉高1拍表示有一个新字节
  output reg  [7:0] data
);
  localparam integer OSR = 16;
  localparam integer DIV = CLK_HZ / (BAUD*OSR); // 100e6/(115200*16) ≈ 54
  reg [$clog2(DIV)-1:0] divcnt;
  reg osr_tick;

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin divcnt<=0; osr_tick<=1'b0; end
    else begin
      if (divcnt==DIV-1) begin divcnt<=0; osr_tick<=1'b1; end
      else begin divcnt<=divcnt+1'b1; osr_tick<=1'b0; end
    end
  end

  // 同步/去毛刺
  reg [2:0] rx_sync;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) rx_sync<=3'b111;
    else       rx_sync<={rx_sync[1:0], rx};
  end
  wire rx_i = rx_sync[2];

  // 采样状态机
  reg [3:0] osr_cnt;      // 0..15
  reg [3:0] bit_cnt;      // 0..9 (start + 8 data + stop)
  reg       busy;
  
  reg [7:0] sh;

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      busy<=1'b0; osr_cnt<=0; bit_cnt<=0; valid<=1'b0; data<=8'h00;
    end else begin
      valid <= 1'b0;
      if(!busy) begin
        // 起始位检测（rx 从1->0）
        if(osr_tick && rx_i==1'b0) begin
          busy<=1'b1; osr_cnt<=0; bit_cnt<=0;
        end
      end else if(osr_tick) begin
        osr_cnt <= osr_cnt + 1'b1;
        // 在每个比特的中间（osr_cnt==7）处采样
        if (osr_cnt==4'd7) begin
          bit_cnt <= bit_cnt + 1'b1;
          case(bit_cnt)
            4'd0: ; // start 位丢弃
            4'd1: sh[0] <= rx_i;
            4'd2: sh[1] <= rx_i;
            4'd3: sh[2] <= rx_i;
            4'd4: sh[3] <= rx_i;
            4'd5: sh[4] <= rx_i;
            4'd6: sh[5] <= rx_i;
            4'd7: sh[6] <= rx_i;
            4'd8: sh[7] <= rx_i;
            4'd9: begin // stop
              data  <= sh;
              valid <= 1'b1;
              busy  <= 1'b0;
            end
            default: ;
          endcase
        end
      end
    end
  end
endmodule
