# TRAFFIC Qt Control Panel

这是一个基于 Qt Widgets 的交通控制上位机，用于显示交通状态、控制 FPGA 参数并通过 MQTT/OneNET 交换数据。

## 目录

```text
TRAFFIC/
|-- README.md
|-- src/          # Qt/C++ 源码、UI、资源和工程文件
|-- sim/          # 本地联调与验证说明
|-- build/        # 构建命令和构建说明
|-- board/        # 上位机与 FPGA 联调说明
|-- data/         # 示例数据目录
|-- skill/        # Qt 开发环境说明
`-- report/       # OneNET 与联调文档
```

## 构建

在 Qt 5/Qt 6 环境中打开 `src/TRAFFIC.pro`，选择 Desktop Kit 后执行 qmake、构建并运行。工程依赖 Qt Widgets、Qt Network 和 MQTT 相关组件。

## 功能

- 交通状态监视与控制
- 登录、注册和日志窗口
- 曲线显示（QCustomPlot）
- MQTT/OneNET 云端通信
- 与 FPGA UART 协议联调

构建输出、Qt Creator 用户配置和中间文件已被 `.gitignore` 排除。
