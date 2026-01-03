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
2025-12-30 - PCBs arrived!
2026-01-01 - Initial power up of PCBs gives all the correct voltages
2025-01-03 - Bring up of board with simple ROM/RAM/Console working.


### Memory Map
The memory map is subject to change in some parts, though I expect the RAM, ROM and Peripheral blocks to stay the same.

#### High Level
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0x0000|0xBEAF| 48816 | 0xBEB0 | RAM | This includes Zeropage and other bits BASIC may need (more below) |
| 0xBEB0|0xBFFF| 336 | 0x150 | peripherals | This is where the peripherals are mapped (see below) |
| 0xC000|0xFFFF| 12288 | 0x3000 | ROM | holding EhBASIC, eWoz monitor and vectors |

##### RAM breakdown
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0x0000|0x02FF| 768 | 0x300 | RAM | This includes Zeropage and other bits BASIC may need |
| 0x0300|0x07FF| 1280 | 0x500 | RAM | This is going to be for the compact flash reading/writing |
| 0x0800|0xBEAF| 46768 | 0xB6B0 | ROM | BASIC RAM available |

##### peripherals
| Address | subAddr range | RW | What is it | Notes |
|-------|-----|----|----|---------------|
|0xBEBO|BEB0-BFAF|RW| Expansion slot | |
|0xBFBO|0-7|RW| Compact Flash |  |
|0xBFCO|0-F|RW| 65C22 |  on board VIA |
|0xBFDO|0-F|RW| Display |   |
|0xBFEO|0-F|RW| 65C21 | internal keyboard  |
|0xBFF0|0-1|RW| Console | FTDI USB console port   |



