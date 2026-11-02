# FPGA Build Skill Pack

本目录记录工程复现所需的软件和流程。

## 工具链

- Vivado：综合、实现、仿真和 bitstream 生成
- Vivado Tcl Console：执行 `build/` 下的自动化脚本
- Git：版本管理

## 检查清单

- 确认目标器件和板卡约束与 `src/constraints` 匹配。
- 先运行行为级仿真，再执行综合和实现。
- 检查 `report/` 中的时序裕量、资源利用率和路由状态。
