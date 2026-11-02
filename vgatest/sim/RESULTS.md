# Verification Results

## Included checks

- `tb_vga_colorbar.v`: VGA scene and display timing testbench
- `tb_vga_ctrl.v`: VGA controller timing testbench
- `tb_uart_command_parser.v`: UART command parser testbench
- `tb_event_log_uart.v`: event log UART testbench
- `tb_vga_colorbar_behav.wcfg`: waveform configuration for the VGA simulation

## Recorded run evidence

The source workspace contains a Vivado Simulator 2019.1 behavioral simulation log. The compile phase analyzed the VGA, UART, traffic-control and IP modules. The log contains warnings about `packet_claim` declaration order and a duplicate `tidal_bg_rom` definition; these should be reviewed when reproducing the run.

This repository intentionally does not commit generated `.wdb`, `xsim.dir`, cache, or run directories. Re-run the testbenches with the scripts and sources in this directory to produce fresh waveforms and pass/fail evidence.

## Reproduction

1. Open or recreate the project with `build/create_project.tcl`.
2. Add the testbench files from `sim/` to the Simulation Sources.
3. Run behavioral simulation in Vivado and inspect the waveform and simulator transcript.
