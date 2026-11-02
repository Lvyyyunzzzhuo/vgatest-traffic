# VGA Traffic System

本仓库合并了 FPGA VGA 交通场景工程和 Qt 交通控制上位机，适合按“工程包”提交和复现。

```text
vgatest-traffic/
|-- README.md
|-- vgatest/       # FPGA/Vivado 工程：RTL、仿真、构建脚本、板级约束和报告
`-- traffic/       # Qt 上位机：C++ 源码、UI、构建说明和 OneNET 文档
```

## FPGA 工程

进入 `vgatest/` 查看 Verilog 源码、Vivado IP、VGA/UART 仿真 testbench、构建 Tcl 脚本、测试数据和时序/资源报告。详细说明见 `vgatest/README.md`。

## Qt 上位机

进入 `traffic/` 查看 Qt Widgets 源码和 `src/TRAFFIC.pro`。详细说明见 `traffic/README.md`。构建输出和 Qt Creator 用户配置已排除。

## 复现顺序

1. 在 Vivado 中完成 FPGA 综合、实现和 bitstream 生成。
2. 在 Qt Creator 中打开 `traffic/src/TRAFFIC.pro` 并构建上位机。
3. 根据 `vgatest/report/UART_PROTOCOL.md` 完成 UART 联调，并按 `traffic/report/README_ONENET.md` 配置云端连接。

请勿提交真实账号、密码、设备密钥、访问令牌或其他敏感配置。
