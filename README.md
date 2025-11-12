# LT6502
A 6502 based laptop design

Yes, I know I'm crazy, but I figured why not. I'm enjoying working the [PC6502](https://github.com/TechPaula/PC6502/) project but having a little tower of PCBs on the sofa isn't the best.
It'll be simple, these are the preliminary specs;
* 65C02 running at 14MHz
* 48K RAM
* 12K of ROM
* 65C22 VIA (for timers and some IO)
* 10.1" DIsplay (with built in font/simple graphics)
* Built in keyboard
* Compact Flash for storage
* 10000mAh battery built in
* USBC powered/charged
* Serial Console
* 1 internal expansion slot and 1 external expansion slot

## Status
2025-11-12 - Initial commit with work in progress PCB, Schematics complete.


### Memory Map
The memory map is subject to change in some parts, though I expect the RAM, ROM and Peripheral blocks to stay the same.

#### High Level
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0x0000|0xBFFF| 49152 | 0xC000 | RAM | This includes Zeropage and other bits BASIC may need |
| 0xC000|0xEFFF| 12288 | 0x3000 | ROM | holding OSI basic to start, maybe EhBasic later |
| 0xF000|0xFFF9|  4089 | 0x0FF9 | Peripherals | to be figured out |
