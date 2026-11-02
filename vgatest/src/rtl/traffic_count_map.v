// traffic_count_map.v
// 根据 modenum输出上下车道要显示的车数量
module traffic_count_map #(
    // 三种模式下的车辆数配置（可以改）
    parameter integer UP_LOW    = 4,   // 低谷模式上行车数量
    parameter integer UP_NORMAL = 8,   // 平时模式上行车数量
    parameter integer UP_MANY   = 12,  // 高峰模式上行车数量
    parameter integer DN_LOW    = 4,
    parameter integer DN_NORMAL = 8,
    parameter integer DN_MANY   = 12,
    parameter integer PEOPLE_LOW    = 1,
    parameter integer PEOPLE_NORMAL = 7,
    parameter integer PEOPLE_MANY   = 13
)(
    input  wire [1:0] mode,             // 模式号：0=低谷 1=平时 2=高峰
    output reg  [7:0] people_count,     // 显示行人数
    output reg  [7:0] car_count_up,     // 上行车数量
    output reg  [7:0] car_count_down    // 下行车数量
);
    localparam [1:0] LOW=2'd0, NORMAL=2'd1, MANY=2'd2;

    always @(*) begin
        case (mode)
            LOW: begin
                car_count_up   = UP_LOW;
                car_count_down = DN_LOW;
                 people_count   = PEOPLE_LOW;
            end
            NORMAL: begin
                car_count_up   = UP_NORMAL;
                car_count_down = DN_NORMAL;
                 people_count   = PEOPLE_NORMAL;
            end
            default: begin
                car_count_up   = UP_MANY;
                car_count_down = DN_MANY;
                 people_count   = PEOPLE_MANY;
            end
        endcase
    end
endmodule
