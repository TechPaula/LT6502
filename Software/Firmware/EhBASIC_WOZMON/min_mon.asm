	.feature labels_without_colons
	.feature force_range
	.pc02

; minimal monitor for EhBASIC and 6502 simulator V1.05

; To run EhBASIC on the simulator load and assemble [F7] this file, start the simulator
; running [F6] then start the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

	.include "basic.asm"
    .include "ewoz.asm"
	.include ""
	
; put the IRQ and MNI code in RAM so that it can be changed

IRQ_vec	= VEC_SV+2		; IRQ code vector
NMI_vec	= IRQ_vec+$0A	; NMI code vector

; setup for the 6502 simulator environment

IO_AREA	= $BFF0		; set I/O area for this monitor (Console port)


;ACIAsimwr	= IO_AREA+$01	; simulated ACIA write port
;ACIAsimrd	= IO_AREA+$04	; simulated ACIA read port
ACIAStatus	= IO_AREA		; FT245 Status
ACIAData	= IO_AREA+$01	; FT245 Data in/out

; Keyboard ACIA (65c51) memory locations
A_rxd           = $BFE0 ; ACIA receive data port
A_txd           = $BFE0 ; ACIA transmit data port
A_sts           = $BFE1 ; ACIA status port
A_res           = $BFE1 ; ACIA reset port
A_cmd           = $BFE2 ; ACIA command port
A_ctl           = $BFE3 ; ACIA control port

; Beeper bits
A_Beeper		= $BFA0 ; Beeper address
BEEP_PW			= $FF		; pitch of "low" beep
BEEP_PW2		= $7F		; pitch of "high" beep
BEEP_LN			= $20
DELAY_LEN1		= $05		; Also affects pitch

; compact flash bits n bobs
CF_ADDRESS		= $BFB0	; Compact flash address
CF_BUFF1 		= $0400	; First 256 bytes of 512 Byte buffer for compact flash read/write
CF_BUFF2 		= $0500	; Second 256 bytes of 512 Byte buffer for compact flash read/write
CF_LB			= $0600 ; Place for low byte of sector address
CF_MB			= $0601 ; Place for middle byte of sector address
CF_HB			= $0602 ; Place for high byte of sector address

; display addresses
DISP_DT			= $BFD0
DISP_RG			= $BFD1
DISP_WAIT		= $BFD2  ; This is the Glue logic, Bit 2 is LOW when display is busy, IGNORE all other bits


; 256 byte page used for my loops and bits (away from basic)
MyDL 			= $610
MyDL2		 	= $611
MyDL3			= $612

MyLP1			= $620
MyLP2			= $621
MyERR			= $622

DISP_temp		= $623

MyTEMP			= $650



; now the code. all this does is set up the vectors and interrupt code
; and wait for the user to select [C]old or [W]arm start. nothing else
; fits in less than 128 bytes
	.segment "IOHANDLER"
	.org	$F300			; pretend this is in a 1/8K ROM

; reset vector points here

RES_vec
	CLD				; clear decimal mode
	LDX	#$FF		; empty stack
	TXS				; set the stack

; set up vectors and interrupt code, copy them to page 2

	LDY	#END_CODE-LAB_vec	; set index/count
LAB_stlp
	LDA	LAB_vec-1,Y		; get byte from interrupt code
	STA	VEC_IN-1,Y		; save to RAM
	DEY					; decrement index/count
	BNE	LAB_stlp		; loop if more to do

; set up 65c51
    STA A_res       ; soft reset (value not important)
    LDA #$0B        ; set specific modes and functions
    	            ; no parity, no echo, no Tx interrupt
        	        ; no Rx interrupt, enable Tx/Rx
    STA A_cmd       ; save to command register
    LDA #$10        ; 8-N-1, 115200 baud
    STA A_ctl       ; set control register

	JSR PWR_BEEP_LOW	; power beep

	JSR DISP_INIT		; initialise screen


; now do the signon message, Y = $00 here
LAB_signon
	LDA	LAB_mess,Y		; get byte from sign on message
	BEQ KYB_msg			; display next message

	JSR	V_OUTP			; output character
	INY					; increment index
	BNE	LAB_signon		; loop, branch always

KYB_msg
	JSR KYB_cwmmsg

LAB_nokey
	JSR	V_INPT			; call scan input device
	BCC	LAB_nokey		; loop if no key

	JSR	ACIAout			; output character

	AND	#$DF			; mask xx0x xxxx, ensure upper case
	CMP	#'W'			; compare with [W]arm start
	BEQ	LAB_dowarm		; branch if [W]arm start

    CMP #'M'
    BEQ LAB_dowoz

	CMP	#'C'			; compare with [C]old start
	BNE	RES_vec			; loop if not [C]old start

	LDA #$0D
	STA A_txd			; clear keyboard screen
	
	JSR KYB_basmsg
	JSR PWR_BEEP_HIGH

	JMP	LAB_COLD		; do EhBASIC cold start

LAB_dowarm
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR PWR_BEEP_HIGH
	JSR KYB_basmsg
	JMP	LAB_WARM		; do EhBASIC warm start
LAB_dowoz
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR KYB_wozmsg
	JSR PWR_BEEP_HIGH
    JMP EWOZ

; byte out to simulated ACIA
ACIAout
	PHA
SWait:
	LDA	ACIAStatus
	AND	#2
	CMP	#2
	BNE	SWait
	PLA
	STA	ACIAData

; When screen is working insert screen text output code here
	PHA
	JSR DISP_TEXT_WR
	PLA

; end of screen output code
	RTS						; end of ACIAout





; byte in from simulated ACIA

; byte out to keyboard 65c51
KEYBout
	STA A_txd			; send character to keyboard display
	PHA					; save A

	LDA #$FF			
	STA MyDL
KEYDL				; Outer loop
	LDA #$40
	STA MyDL2
KEYDL2				; Inner loop
	DEC MyDL2
	BNE	KEYDL2

	DEC MyDL
	BNE KEYDL		; if not 0 increment more

	PLA
	RTS

LAB_WAIT_Rx
    LDA A_sts       ; get ACIA status
    AND #$08        ; mask rx buffer status flag
    BEQ LAB_WAIT_Rx ; loop if rx buffer empty
 
    LDA A_rxd       ; get byte from ACIA data port


; byte in from simulated ACIA (CONSOLE) or Keyboard
ACIAin
	LDA	ACIAStatus
	AND	#1
	CMP	#1
	BNE	NoDataIn
	LDA	ACIAData
	SEC		; Carry set if key available
	RTS
NoDataIn:	; nothing from console port
	CLC		; Carry clear if no key pressed
	
KEY_RX		; we get here if there is no data from console
    LDA A_sts       ; get ACIA status
    AND #$08        ; mask rx buffer status flag
    BEQ KEYB_NoData ; skip if rx buffer empty

    LDA A_rxd       ; get byte from ACIA data port
	SEC				; Carry set if key available
	RTS
	 
KEYB_NoData
	CLC				; Carry clear if no key pressed
	RTS


; Show "EhBASIC " on keyboard display
KYB_basmsg
	LDY #$00

KYB_basmsg_lp
	LDA KYB_basmess_str,Y
	BEQ	KYB_basmsg_exit	; exit loop if done

	JSR KEYBout			;
	INY					; increment index
	BNE KYB_basmsg_lp	; loop, always

KYB_basmsg_exit
	RTS

; Show "eWOZMON " on keyboard display
KYB_wozmsg
	LDY #$00

KYB_wozmsg_lp
	LDA KYB_wozmess_str,Y
	BEQ	KYB_wozmsg_exit	; exit loop if done

	JSR KEYBout			;
	INY					; increment index
	BNE KYB_wozmsg_lp	; loop, always

KYB_wozmsg_exit
	RTS

; send signon message to keyboard
KYB_cwmmsg
	LDY #$00

KYB_signon
	LDA KYB_mess,Y
	BEQ	KEYB_exit		; exit loop if done

	JSR KEYBout			;
	INY					; increment index
	BNE KYB_signon		; loop, always
KEYB_exit
	RTS

; empty load vector for EhBASIC
IO_LOAD
	RTS
; empty save vector for EhBASIC
IO_SAVE
	RTS
; empty DIR vector for EhBASIC
IO_DIR
	RTS


; ----- DISPLAY BITS
; display driver for the LT6502 project using the RA8875 driver
; the display is set to 800x480 pixels
DISP_INIT
		; write to reg 0 and read back driver chip number
	LDA #$00
	STA DISP_RG
	JSR DISP_CHK_BUSY
	LDA DISP_DT
	CMP #$75		; $75 means it's an RA8875 driver chip
	BEQ DISP_OK
	JMP DISP_ERR

DISP_OK	
		; soft reset
	LDA #$01
	STA DISP_RG
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$01
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY

		; PLL init (800x480)
	LDA #$88
	STA DISP_RG
	LDA #$0A
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$89
	STA DISP_RG
	LDA #$02
	STA DISP_DT
	JSR DISP_CHK_BUSY

		; Set colour depth and interface width
	LDA #$10
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	
		; Set pixelclk
	LDA #$04
	STA DISP_RG
	LDA #$81
	STA DISP_DT
	JSR DISP_CHK_BUSY

		; Horizontal set
	LDA #$14
	STA DISP_RG
	LDA #$63
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$15
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$16
	STA DISP_RG
	LDA #$03
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$17
	STA DISP_RG
	LDA #$03
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$18
	STA DISP_RG
	LDA #$0B
	STA DISP_DT
	JSR DISP_CHK_BUSY
	
		; Vertical set
	LDA #$19
	STA DISP_RG
	LDA #$DF
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1A
	STA DISP_RG
	LDA #$01
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1B
	STA DISP_RG
	LDA #$1F
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1C
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1D
	STA DISP_RG
	LDA #$16
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1E
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$1F
	STA DISP_RG
	LDA #$01
	STA DISP_DT
	JSR DISP_CHK_BUSY

		; Active window
	LDA #$30
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$31
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$34
	STA DISP_RG
	LDA #$1F
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$35
	STA DISP_RG
	LDA #$03
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$32
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$33
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$36
	STA DISP_RG
	LDA #$DF
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$37
	STA DISP_RG
	LDA #$01
	STA DISP_DT
	JSR DISP_CHK_BUSY

		; Display on
	LDA #$01
	STA DISP_RG
	LDA #$80
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$C7
	STA DISP_RG
	LDA #$01
	STA DISP_DT
	JSR DISP_CHK_BUSY
		
	JSR DISP_CLR_SCREEN	
	JSR DISP_TEXT_MODE
	JSR DISP_CURSOR_HOME
	JSR DISP_TEXT_COLOUR


	RTS
	; end of DISP_INIT

DISP_ERR				; Show error message
	STA MyERR
	JSR DISP_flt
	RTS

DISP_CLR_SCREEN			; Fills the screen with black
	LDA #$91
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$92
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$93
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$94
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$95
	STA DISP_RG
	LDA #$1F
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$96
	STA DISP_RG
	LDA #$03
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$97
	STA DISP_RG
	LDA #$DF
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$98
	STA DISP_RG
	LDA #$01
	STA DISP_DT
	JSR DISP_CHK_BUSY

	LDA #$63				; RED colour, bits 0,1,2
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$64				; GREEN colour, bits 0,1,2
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$65				; BLUE colour, bits 0,1
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$90				; Start fill
	STA DISP_RG
	LDA #$B0
	STA DISP_DT
	JSR DISP_CHK_BUSY

DISP_fillcomp	
	LDA #$90				; CHECK IF WE'RE DONE
	STA DISP_RG
	LDA DISP_DT				; read status
	JSR DISP_CHK_BUSY
	RTS

DISP_TEXT_MODE
	LDA #$40
	STA DISP_RG
	LDA #$E0
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$44
	STA DISP_RG
	LDA #$20
	STA DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_CURSOR_HOME
	LDA #$2A
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$2B
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$2C
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$2D
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_TEXT_COLOUR
	LDA #$63			; RED colour, bits 0,1,2
	STA DISP_RG
	LDA #$03
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$64			; GREEN colour, bits 0,1,2
	STA DISP_RG
	LDA #$02
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$65			; BLUE colour, bits 0,1,2
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_TEXT_WR
	STA DISP_temp		; Save character
	LDA #$02			
	STA DISP_RG

	LDA DISP_temp				
	CMP #20				; check for regular character
	BMI DISP_text_nonascii

	STA DISP_DT			; send to display
	JSR DISP_CHK_BUSY
	JMP DISP_textexit

DISP_text_nonascii
	LDA DISP_temp
	CMP #$0D
	BNE DISP_textexit

	; TODO insert CARRIAGE RETURN code here
	
	LDA DISP_temp
	CMP #$0A
	BNE DISP_textexit

	; TODO insert LINE FEED code here

	; TODO add in scrolling if needed (USING BLOCK TRANSFER ENGINE)

DISP_textexit
	RTS
	

DISP_CHK_BUSY			; Read BIT2 from Glue, if it's LOW the display is busy
	LDA DISP_WAIT		; Get wait status
	AND #$04			; it's in BIT2
	CMP #$04			; Compare bit2
	BNE DISP_CHK_BUSY	; if it's not the same, i.e. it's ZERO then recheck
	RTS					; else return, i.e. display is ready

; DISPLAY ERROR
DISP_flt
	LDY #$00

DISP_flt_lp				; Display error message
	LDA ERR_disp,Y
	BEQ	DISP_flt_exit	; exit loop if done
	JSR ACIAout			; Send to console
	JSR KEYBout			; Send to keyboard display
	INY					; increment index
	BNE DISP_flt_lp	; loop, always

DISP_flt_exit
	LDA MyERR			
	JSR PRBYTE			; Add byte to error message
	LDA MyERR
	JSR KEYBout			; show on keyboard (may get weird things)
	RTS

; ------ END OF DISPLAY BITS


; ------ BEEPS
; HIGH BEEP
PWR_BEEP_HIGH
	LDA #BEEP_PW2		; PULSE WIDTH	
	STA MyDL	

	LDA #BEEP_LN		; LENGTH	
	STA MyDL2

BEEP_LP3
	LDA #$FF
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE BEEP_LP3
	
	LDA #BEEP_PW2
	STA MyDL

BEEP_LP4
	LDA #$00
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE BEEP_LP4

	DEC MyDL2
	BNE BEEP_LP3

	RTS	

; LOW BEEP
PWR_BEEP_LOW
	PHY
	PHX
	PHA
	LDA #BEEP_PW		; PULSE WIDTH	
	STA MyDL	

	LDA #BEEP_LN		; LENGTH	
	STA MyDL2

BEEP_LOW1
	LDA #$FF
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE BEEP_LOW1
	
	LDA #BEEP_PW
	STA MyDL

BEEP_LOW2
	LDA #$00
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE BEEP_LOW2

	DEC MyDL2
	BNE BEEP_LOW1

	PLA
	PLX
	PLY

	RTS	
; ------ END BEEPS





; Delay loop for random things
DELAY1
	LDA #DELAY_LEN1
	STA MyDL3

DELAY1_LP
	DEC MyDL3
	BNE DELAY1_LP

	RTS



; vector tables
LAB_vec
	.word	ACIAin		; byte in from simulated ACIA  	EhBASIC = V_INPT
	.word	ACIAout		; byte out to simulated ACIA   	EhBASIC = V_OUTP
	.word	IO_LOAD		; load vector for EhBASIC		EhBASIC = V_LOAD
	.word	IO_SAVE		; save vector for EhBASIC		EhBASIC = V_SAVE
	.word   IO_DIR		; dir vector for EhBASIC		EhBASIC = V_DIR

; EhBASIC IRQ support
IRQ_CODE
	PHA				; save A
	LDA	IrqBase		; get the IRQ flag byte
	LSR				; shift the set b7 to b6, and on down ...
	ORA	IrqBase		; OR the original back in
	STA	IrqBase		; save the new IRQ flag byte
	PLA				; restore A
	RTI

; EhBASIC NMI support
NMI_CODE
	PHA				; save A
	LDA	NmiBase		; get the NMI flag byte
	LSR				; shift the set b7 to b6, and on down ...
	ORA	NmiBase		; OR the original back in
	STA	NmiBase		; save the new NMI flag byte
	PLA				; restore A
	RTI




END_CODE

LAB_mess 					; sign on string (Console)
	.byte	$0D,$0A,"LT6502 - [C]Cold/[W]arm or [M]onitor ?",$00

KYB_mess					; sign on string (Keyboard)
	.byte	$0D,"C/W/M ? ",$00
KYB_basmess_str
	.byte	$0D,$0D,"EhBASIC ",$00
KYB_wozmess_str
	.byte	$0D,$0D,"eWOZMON ",$00

ERR_disp
	.byte	$0D,$0A,"D_ERR:",$00


; system vectors

	.segment "VECTS"
	.org	$FFFA

	.word	NMI_vec		; NMI vector
	.word	RES_vec		; RESET vector
	.word	IRQ_vec		; IRQ vector

