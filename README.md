# LT6502
A 6502 based laptop design

Yes, I know I'm crazy, but I figured why not. I'm enjoying working the [PC6502](https://github.com/TechPaula/PC6502/) project but having a little tower of PCBs on the sofa isn't the best.
It'll be simple, these are the preliminary specs;
* 65C02 running at 8MHz
* 46K RAM
* BASIC in ROM
* 65C22 VIA (for timers and some IO)
* 10.1" DIsplay (with built in font/simple graphics)
* Built in keyboard
* Compact Flash for storage
* 10000mAh battery built in
* USBC powered/charged
* Serial Console
* 1 internal expansion slot


## Latest picture
![Picture of the 6502 laptop as of 5th Jan 2026](https://raw.githubusercontent.com/TechPaula/LT6502/refs/heads/main/Images/Keyboard_hello_basic_Test.jpeg)

## Status
* 2025-11-12 - Initial commit with work in progress PCB, Schematics complete.
* 2025-12-30 - PCBs arrived!
* 2026-01-01 - Initial power up of PCBs gives all the correct voltages
* 2025-01-03 - Bring up of board with simple ROM/RAM/Console working.
* 2025-01-04 - VIA working, ACIA working, comms to/from the keyboard in basic working. Begun integrating keyboard into firmware
* 2025-01-05 - Keyboard now integrated into firmware, so you can type on the keyboard and don't need the console for input
* 2025-01-09 - Compact flash working, Beeper also now working. Also runs from battery just fine.
* 2025-01-16 - Connected a 4.3" 800x480 RA8875 based display and got that working. I failed to get the LT7683 based display working.
* 2025-01-17 - work on a number of case related things that did not quite work in actual life.
* 2025-01-18 - Tweaked CPLD to slow down FTDI read/writes. Also begun work on bios, added start beep and begun work on load/save functions

## In Progress
* Add SAVE / LOAD / DIR style commands
  
## To do (probably in order)
* add in larger display (going to try a 10.1" RA8889 based 1024x600, fall back is a 9" RA8875 based 800x480)
* Fix buggy keyscan code on MEGA644P


### Memory Map
The memory map is subject to change in some parts, though I expect the RAM, ROM and Peripheral blocks to stay the same.

#### High Level
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0x0000|0xBEAF| 48816 | 0xBEB0 | RAM | This includes Zeropage and other bits BASIC may need (more below) |
| 0xBE00|0xBFFF| 512 | 0x200 | peripherals | This is where the peripherals are mapped (see below) |
| 0xC000|0xFFFF| 12288 | 0x3000 | ROM | holding EhBASIC, eWoz monitor, bootstrap and vectors |

##### ROM breakdown
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0xC000|0xFAFF| 15104 | 0x3B0 | EhBASIC | EhBASIC 2.22p5 |
| 0xFB00|0xFDFF| 768 | 0x300 | eWozMon | [Enhanced Wozmon](https://gist.github.com/BigEd/2760560) |
| 0xFE00|0xFFF9| 506 | 0x1FA | Bootstrap | startup messages and also input/output/load/save vectors|
| 0xFFFA|0xFFFF| 6 | 0x0A | 6502 Vectors | |


##### RAM breakdown
| Start | End | Size (Dec) | Size (Hex) | What is it | Notes |
|-------|-----|----|----|----|---------------|
| 0x0000|0x02FF| 768 | 0x300 | RAM | This includes Zeropage and other bits BASIC may need |
| 0x0300|0x07FF| 1280 | 0x500 | RAM | This is going to be for the compact flash reading/writing |
| 0x0800|0xBDFF| 46592 | 0xB6B0 | ROM | BASIC RAM available |

##### peripherals
| Address | subAddr range | RW | What is it | Notes |
|-------|-----|----|----|---------------|
|0xBE0O|00-FF|RW| Expansion slot | |
|0xBF00|00-9F|  | Unused Currently | |
|0xBFAO|0-0| W| Beeper | just write 0xFF and 0x00 to turn on/off the speaker |
|0xBFBO|0-7|RW| Compact Flash |  |
|0xBFCO|0-F|RW| 65C22 |  on board VIA |
|0xBFDO|0-F|0-1| Display |   |
|0xBFEO|0-F|RW| 65C21 | internal keyboard  |
|0xBFF0|0-1|RW| Console | FTDI USB console port   |



