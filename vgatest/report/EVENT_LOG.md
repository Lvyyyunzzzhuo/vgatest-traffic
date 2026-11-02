# FPGA BRAM Event Log and UART Status

The FPGA stores up to 512 64-bit event records in one circular block RAM.
After the RAM is full, the oldest record is overwritten. Time is measured in
seconds since FPGA reset.

## Serial settings

- Port on the current PC: `COM12`
- Baud rate: `115200`
- Format: 8 data bits, no parity, 1 stop bit, no flow control
- FPGA RX: `V17`
- FPGA TX: `W18`

The UART output is now plain ASCII. In a serial terminal, select ASCII receive
mode and enable automatic line wrapping.

## Automatic status

Every five seconds the FPGA sends one complete line:

```text
STATUS time=0000000025 mode=adaptive state=open       dir=left  target=right flow=low   /high   warn=0 lock=0
```

Status output is delayed while a log dump or clear acknowledgement is active,
so protocol lines cannot be interleaved.

## Commands

Send ASCII `D` or `d` to receive records added since the previous `D`, oldest
first:

```text
LOG_BEGIN count=008
LOG time=0000000000 event=boot                    mode=adaptive method=adaptive  state=open       dir=left  target=right flow=low   /low    warn=0 lock=0
LOG time=0000000005 event=manual_lock_changed     mode=adaptive method=adaptive  state=open       dir=left  target=right flow=low   /low    warn=0 lock=1
LOG_END
```

Send ASCII `C` or `c` to clear the log. The FPGA returns:

```text
OK log_cleared
```

After a successful `D`, those records are marked as read. A repeated `D` with
no new events returns `LOG_BEGIN count=000` followed by `LOG_END`. Reading does
not erase BRAM data; `C` still clears the complete retained history.

## Control commands

Word commands are case-insensitive and execute as soon as the complete command
is received. Enter (CR or LF) is optional. A truncated or noisy command is
discarded after about 100 ms so it cannot block later commands:

```text
MODE ADAPTIVE
MODE MORNING
MODE EVENING
MODE HOLD
LOCK ON
LOCK OFF
FORCE SWITCH
```

Examples of explicit responses:

```text
OK MODE morning
OK LOCK on
OK FORCE switch_requested
ERROR FORCE blocked_by_lock
ERROR unknown_command
```

Board buttons and UART commands update the same control registers. `LOCK ON`
holds the current direction. While locked, `FORCE SWITCH` is rejected and mode
changes cannot change the active lane direction until `LOCK OFF`.

## Python CSV client

The serial terminal is sufficient for normal monitoring. Python is only needed
for CSV export or timed replay. Close the serial terminal before using it.

```powershell
cd D:\vivado\vgatest
py -3 -m pip install pyserial
py -3 tools\event_log_client.py COM12 --csv history.csv
py -3 tools\event_log_client.py COM12 --replay-speed 10
py -3 tools\event_log_client.py COM12 --clear
```

## Recorded events

- Boot and reset
- Work-mode changes
- Left/right traffic-level changes
- Prewarning start and cancellation
- All-red start and switch completion
- Manual-lock changes
- Forced-switch requests
