# LT6502
A 6502 based laptop design

Yes, I know I'm crazy, but I figured why not. I'm enjoying working the [PC6502](https://github.com/TechPaula/PC6502/) project but having a little tower of PCBs on the sofa isn't the best.
It's very simple, these are the specs
* 65C02 running at 8MHz
* 46K RAM
* BASIC in ROM
* 65C22 VIA (for timers and some IO)
* 9" DIsplay (with built in font/simple graphics)
* Built in keyboard
* Compact Flash for storage
* 10000mAh battery built in
* USBC powered/charged
* Serial Console
* 1 internal expansion slot


## Pictures
Assembled front view
![Picture of the assembled 6502 laptop in it's 3D printed case from the front](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_Front_Open.jpeg?raw=true)
Assembled rear view
![Picture of the assembled 6502 laptop in it's 3D printed case from the rear](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_Rear_Open.jpeg?raw=true)
Assembled LHS view
![Picture of the assembled 6502 laptop in it's 3D printed case from the left hand side](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_LHS_Open.jpeg?raw=true)
Assembled RHS view
![Picture of the assembled 6502 laptop in it's 3D printed case from the right hand side](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_RHS_Open.jpeg?raw=true)

Assembled closed front view
![Picture of the assembled 6502 laptop in it's 3D printed case from the front when closed](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_Front_Closed.jpeg?raw=true)
Assembled closed rear view
![Picture of the assembled 6502 laptop in it's 3D printed case from the rear when closed](https://github.com/TechPaula/LT6502/blob/main/Images/Assembled_Rear_Closed.jpeg?raw=true)


Lower parts (main board, battery, keyboard) in it's case
![Picture of the 6502 laptop base in it's 3D printed case](https://github.com/TechPaula/LT6502/blob/main/Images/LT6502_BaseCase.jpeg?raw=true)
Screen with BASIC code
![Picture of the 6502 laptop with screen and basic Jan 2026](https://raw.githubusercontent.com/TechPaula/LT6502/refs/heads/main/Images/LT6502_SCREEN_BASIC.jpeg)
First bring up
![Picture of the 6502 laptop as of 5th Jan 2026](https://raw.githubusercontent.com/TechPaula/LT6502/refs/heads/main/Images/Keyboard_hello_basic_Test.jpeg)

## Status
* 2025-11-12 - Initial commit with work in progress PCB, Schematics complete.
* 2025-12-30 - PCBs arrived!
* 2026-01-01 - Initial power up of PCBs gives all the correct voltages
* 2026-01-03 - Bring up of board with simple ROM/RAM/Console working.
* 2026-01-04 - VIA working, ACIA working, comms to/from the keyboard in basic working. Begun integrating keyboard into firmware
* 2026-01-05 - Keyboard now integrated into firmware, so you can type on the keyboard and don't need the console for input
* 2026-01-09 - Compact flash working, Beeper also now working. Also runs from battery just fine.
* 2026-01-16 - Connected a 4.3" 800x480 RA8875 based display and got that working. I failed to get the LT7683 based display working.
* 2026-01-17 - work on a number of case related things that did not quite work in actual life.
* 2026-01-18 - Tweaked CPLD to slow down FTDI read/writes. Also begun work on bios, added start beep and begun work on load/save functions
* 2026-02-08 - Added more commands, notably SAVE,LOAD and DIR for compact flash
* 2026-02-13 - Added more graphics commands :)
* 2026-02-14 - Assembled the case

## In Progress
* Expansion board
  
## To do (probably in order)
* add in larger display (going to try a 10.1" RA8889 based 1024x600, fall back is a 9" RA8875 based 800x480)
* Fix buggy keyscan code on MEGA644P

## Memory Map
The memory map is fairly stable at the moment, everything seems to be working fine.

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
| 0xF000|0xF2FF| 768 | 0x300 | eWozMon | [Enhanced Wozmon](https://gist.github.com/BigEd/2760560) |
| 0xF300|0xFFF9| 3322| 0xCFA | Bootstrap | startup messages and also input/output/load/save functions |
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

## EhBASIC Extra commands
I've Added a some extra commands to EhBASIC and they are as follows;


* BEEP P,L - Pitch (P) is 0-255, length (L) = 0 to 255
* CIRCLE X,Y,R,C,F - Draws a Circle, X is 0-799, Y is 0-479, R(radius) is 1 - 65535, C is 8bit RGB Value (RRRGGGBB), F is fill (0 = no fill, 1 = fill)
* CLS - Clear screen (both graphic and text mode)
* COLOUR <0-255> - Sets the colour (text) to 8bit RGB value, in the form RRRGGGBB
* DIR - Scans the Compact Flash card and shows slot number and name for any files present
* ELIPSE - X,Y,RX,RY,C,F - Draws an elipse, X is 0-799, Y is 0-479, RX is X radius, RY is Y radius, C is colour and F is fill
* LINE X,Y,EX,EY,C - Draws a line, X is 0-799, Y is 0-479, EX is X end point (0-799), EY is Y end point (0-479), C is colour
* LOAD <0-2047> - LOAD a file from CF
* MODE <0,1> - Sets the display mode, MODE 0 is text, MODE 1 is graphics
* OUTK - Outputs Text to the 8 character display on the keybed, can be a string or value, anything more than 8 characters will result in text shifting. a String will clear the display and then output the characters
* PLOT X,Y,C - Plots a dot, X is 0-799, Y is 0-479 and C is 8bit RGB Value (RRRGGGBB)
* SAVE <0-2047>,"<FILENAME>" - SAVE current BASIC program into a SLOT and give it a name, upto 16 characters
* SQUARE - X,Y,EX,EY,C,F - Draws a square, X is 0-799, Y is 0-479, EX is X end point (0-799), EY is Y end point (0-479), C is colour and F is fill
* WOZMON - Jumps to wozmon, Q will exit WOZMON and return to basic (Handy for check chunks of memory)





