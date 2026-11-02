# UART protocol

Serial format is 115200 baud, 8 data bits, no parity, 1 stop bit.

The FPGA accepts the existing ASCII commands (`MODE ADAPTIVE`, `MODE MORNING`,
`MODE EVENING`, `MODE HOLD`, `LOCK ON`, `LOCK OFF`, `FORCE SWITCH`, `D`, and
`C`) and the binary frames below. ASCII commands remain useful in a terminal;
the PC application should use binary frames.

## Binary frame

Every frame is 10 bytes:

```text
AA 55 06 TYPE SEQ PAGE ITEM VALUE_L VALUE_H CRC8
```

`CRC8` is calculated over `06` through `VALUE_H`, polynomial `0x07`, initial
value `0x00`. `TYPE` values are `10` set, `11` get, `12` action. FPGA replies
use `80` ACK, `81` NACK, and periodically sends `90` status frames.

## Pages and items

Page `FF` is global: item `00` selects the VGA page (`0` tidal, `1` green-wave,
`2` single-lane, `3` intersection, `4` traffic lab).

Page `00` tidal: item `00` mode (`0` adaptive, `1` morning, `2` evening,
`3` hold), `01` left flow (`0..2`), `02` right flow (`0..2`), `03` lock
(`0/1`), and action item `04` requests a safe reversal.

Page `02` single-lane: set item `00` to speed `35`, `40`, `45`, `50`, `55`, or
`60` km/h.

Page `03` intersection: items `00/01` select horizontal/vertical car density
(`0/1`), item `02` pedestrian count (`4/10`), and item `03` adaptive mode
(`0/1`). Read-only items `10..15` return the displayed horizontal/vertical
straight, left and right green times. Fixed mode keeps 40/30/20 seconds;
adaptive mode shows clear simulated changes based on vehicle and pedestrian
demand. The lower-left screen uses full English labels instead of abbreviations.

Page `04` traffic lab: item `00` green seconds (`15/30/45`), `01` red seconds
(`30/45/60`), `02` lane length (`80/200/500`), `03` arrival rate (`600/900`),
`04` phase (`0/1`), `05` control (`0` timed, `1` adaptive), and action item `06`
restores defaults.

For any page, `TYPE=11` with a supported `ITEM` requests its current value.
`TYPE=10` receives an ACK only after the value passes range validation.
