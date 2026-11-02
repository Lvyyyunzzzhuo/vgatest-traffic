# VGA Traffic Display FPGA Project

这是一个基于 Verilog HDL 和 Vivado 的 VGA 交通场景显示与交通控制工程。

## 目录

```text
vgatest/
|-- README.md
|-- src/          # RTL、Vivado IP 配置和时序约束
|-- sim/          # 仿真 testbench 和波形配置
|-- build/        # 可复现的 Vivado Tcl 脚本和最终 bitstream
|-- board/        # 板级工程文件和板卡约束
|-- data/         # ROM、字体和场景测试数据
|-- skill/        # 工程复现说明
`-- report/       # 时序、资源和协议报告
```

## 快速复现

1. 使用 Vivado 打开 `board/vgatest.xpr`，或新建工程并加入 `src/rtl`、`src/ip` 和 `src/constraints`。
2. 在 Vivado Tcl Console 中执行 `build_uart_protocol_fix.tcl` 或其他 `build_*.tcl` 脚本。
3. 在 Simulation Sources 中加入 `sim` 下的 testbench，运行行为级仿真。
4. 生成 bitstream 后下载到目标 FPGA 开发板，并根据 `report/` 中的报告检查时序和资源占用。

## 设计内容

- 640x480 VGA 时序与场景渲染
- 交通灯、车辆、行人和自适应交通控制逻辑
- UART 配置与事件日志协议
- ROM 背景、字体和图形素材

## 环境

- AMD/Xilinx Vivado 2020.2 或更高版本
- 支持 Verilog 的 FPGA 开发板

生成的 Vivado 缓存、runs、临时日志和系统转储被 `.gitignore` 排除。
