# FPGA traffic control and OneNET gateway

## Run

Start `release_onenet/TRAFFIC.exe`.

1. Select the FPGA serial port and open it. The serial format is fixed at 115200, 8N1.
2. Enter the OneNET Product AccessKey or a complete authentication Token.
3. Select `Connect OneNET`.

The default product settings are:

```text
Product ID: GXF8j2l1pC
Device name: traffic_device_01
Host: GXF8j2l1pC.mqtts.acc.cmcconenet.cn
Port: 1883
TLS: off
```

The settings are stored only in `onenet.ini` beside the executable. Do not share that file because it contains the AccessKey or Token.

## Cloud behavior

- All traffic properties are uploaded once per second.
- OneNET property-set commands are translated to the existing FPGA binary UART protocol.
- `tidal_safe_switch` invokes the safe lane reversal action.
- `lab_reset` restores the traffic-lab defaults.
- The six lab metrics are deterministic simulation values calculated by the PC application because the current FPGA UART protocol does not expose those card values.
