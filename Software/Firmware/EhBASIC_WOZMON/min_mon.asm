	.feature labels_without_colons
	.feature force_range
	.pc02

; minimal monitor for EhBASIC and 6502 simulator V1.05

; To run EhBASIC on the simulator load and assemble [F7] this file, start the simulator
; running [F6] then start the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

	.include "basic.asm"

    .include "ewoz.asm"
	
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

A_Beeper		= $BFA0 ; Beeper address

; compact flash bits n bobs
CF_ADDRESS		= $BFB0	; Compact flash address
CF_BUFF1 		= $0400	; First 256 bytes of 512 Byte buffer for compact flash read/write
CF_BUFF2 		= $0500	; Second 256 bytes of 512 Byte buffer for compact flash read/write
CF_LB			= $0600 ; Place for low byte of sector address
CF_MB			= $0601 ; Place for middle byte of sector address
CF_HB			= $0602 ; Place for high byte of sector address


; 256 byte page used for my loops and bits (away from basic)
MyDL 			= $610
MyDL2		 	= $611
MyDL3			= $612
MyLP1			= $620
MyLP2			= $621
MyTEMP			= $650



BEEP_PW			= $FF
BEEP_PW2		= $7F
BEEP_LN			= $80

; bits for load/save
;Itempl            = $11       ; temporary integer low byte, defined in EhBASIC
;Itemph            = Itempl+1  ; temporary integer high byte, defined in EhBASIC

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

; now do the signon message, Y = $00 here
LAB_signon
	LDA	LAB_mess,Y		; get byte from sign on message
	BEQ KYB_msg			; display next message

	JSR	V_OUTP			; output character
	INY					; increment index
	BNE	LAB_signon		; loop, branch always


; send signon message to keyboard
KYB_msg
	LDY #$00

KYB_signon
	LDA KYB_mess,Y
	BEQ	LAB_nokey		; exit loop if done

	JSR KEYBout			;
	INY					; increment index
	BNE KYB_signon		; loop, always

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
	
	JSR PWR_BEEP_HIGH
	JMP	LAB_COLD		; do EhBASIC cold start

LAB_dowarm
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR PWR_BEEP_HIGH
	JMP	LAB_WARM		; do EhBASIC warm start
LAB_dowoz
	LDA #$0D
	STA A_txd			; clear keyboard screen
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






; end of screen output code
	RTS						; end of ACIAout


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


; byte in from simulated ACIA or Keyboard
ACIAin
	LDA	ACIAStatus
	AND	#1
	CMP	#1
	BNE	NoDataIn
	LDA	ACIAData
	SEC		; Carry set if key available
	RTS
NoDataIn:
	CLC		; Carry clear if no key pressed

KEY_WAIT_Rx
    LDA A_sts       ; get ACIA status
    AND #$08        ; mask rx buffer status flag
    BEQ KEYB_NoData ; loop if rx buffer empty

    LDA A_rxd       ; get byte from ACIA data port
	SEC				; Carry set if key available
	RTS
	 
KEYB_NoData
	CLC				; Carry clear if no key pressed
	RTS



IO_LOAD				; load vector for EhBASIC
	JSR CF_LDSV_INIT	; set sector based on command line value


	RTS


IO_SAVE				; save vector for EhBASIC
	JSR CF_LDSV_INIT	; Set sector based on command line value


	RTS


IO_DIR				; dir vector for EhBASIC
	PHY
	JSR CF_INIT	

	LDA #$00		; Set address for "DIR" file
	STA CF_LB
	STA CF_HB
	LDA #$01		; "DIR" file stored atin sectors $000100 - $0001FF 
	STA CF_MB
	JSR CF_SET_LBA

	JSR CF_READ_SECTOR

IO_DIR_SHOW
	LDA #$00
	STA MyLP1

IO_DIR_SHOW_LP1
	LDY MyLP1
	LDA CF_BUFF1,Y

	; '0' IS START OF NEW LINE
	; HERE WE NEED TO SKIP 2 BYTES 
	; NEXT TWO BYTES ARE LINE NUMBER, LSByte THEN MSByte 
	; THEN WE HAVE LINE DATA WHICH WE DISPLAY UNTIL WE HIT '0'

IO_DIR_NEXTCHAR	
	LDA MyLP1
	CLC
	ADC #$01
	STA MyLP1
	BCC IO_DIR_SHOW_LP1

	
	



	PLY
    RTS



	; init CF card
CF_INIT
		; SET 8 BIT MODE
	LDA #$01
	STA CF_ADDRESS+1
	LDA #$EF
	STA CF_ADDRESS+7
	JSR CF_WAIT
		; SET ONE SECTOR (512 BYTES) AT A TIME
	LDA #$01
	STA CF_ADDRESS+2
	JSR CF_WAIT

	RTS

	; Wait for flag MSB of status register to be clear
CF_WAIT
    LDA CF_ADDRESS + 7
    BMI CF_WAIT
    RTS

	; set the block address to read from
CF_SET_LBA
	LDA CF_LB			; LOWER BYTE FETCH
	STA CF_ADDRESS+3
	JSR CF_WAIT
	LDA CF_MB			; MIDDLE BYTE FETCH
	STA CF_ADDRESS+4
	JSR CF_WAIT
	LDA CF_HB			; HIGH BYTE FETCH
	STA CF_ADDRESS+5
	JSR CF_WAIT
	LDA #$E0			; DRIVE/HEAD REGISTER
	STA CF_ADDRESS+6
	JSR CF_WAIT
	RTS

	; Read sector from CF and dump in buffer
CF_READ_SECTOR
	LDA #$20
	STA CF_ADDRESS+7
	JSR CF_WAIT

	LDY #0


CF_RD_LP1
	LDA CF_ADDRESS
	STA CF_BUFF1,Y

	JSR CF_WAIT
	INY
	BNE CF_RD_LP1

	LDY #0

CF_RD_LP2
	LDA CF_ADDRESS
	STA CF_BUFF2,Y
	JSR CF_WAIT
	INY
	BNE CF_RD_LP2

CF_RD_EXIT
	RTS

CF_LDSV_INIT
	JSR LAB_GFPN	; Get fixed point number as intenger

	LDA #$00
	STA CF_LB		; We start at the beginning of the save location

	LDA Itempl		; This is the low byte from command line

		; Increment by 1 and remember if we did for next byte
	LDY #$00	
	STY MyTEMP		; Set to 0 for later
	CLC				; clear carry (just to be safe)
	ADC #$01		; add 1 to A (using INA does NOT change carry flag)
	BCC CF_LDSV_BCC ; if carry clear (i.e. we didn't go over 255) skip these next two bits

	LDY #$01
	STY MyTEMP
CF_LDSV_BCC	 
	STA CF_MB  
	LDA Itemph		; this is the high byte from command line
	CLC					; clear carry to be safe
	ADC MyTEMP			; add in 0 or 1 depending if MB rolled over.
	STA CF_HB

	JSR PRBYTE		; DEBUGGING OUTPUT SHOWING CHOSEN LOAD/SAVE LOCATION IN HEX
	LDA CF_MB
	JSR PRBYTE
	
	
	JSR CF_SET_LBA
	RTS	





; display init
DISP_INIT

	rts

; power on beep
PWR_BEEP_LOW
	LDA #BEEP_PW		; PULSE WIDTH	
	STA MyDL	

	LDA #BEEP_LN		; LENGTH	
	STA MyDL2

BEEP_LP1
	LDA #$FF
	STA A_Beeper
	NOP
	DEC MyDL
	BNE BEEP_LP1

	LDA #$FF			; SLOW DOWN
	STA MyDL	
BEEP_LP1A
	NOP
	DEC MyDL
	BNE BEEP_LP1A

	LDA #BEEP_PW
	STA MyDL

BEEP_LP2
	LDA #$00
	STA A_Beeper
	NOP
	DEC MyDL
	BNE BEEP_LP2

	DEC MyDL2
	BNE BEEP_LP1

	LDA #$FF			; SLOW DOWN
	STA MyDL	
BEEP_LP2A
	NOP
	DEC MyDL
	BNE BEEP_LP2A

	RTS

PWR_BEEP_HIGH
	; Second beep, higher pitch
	LDA #BEEP_PW2		; PULSE WIDTH	
	STA MyDL	

	LDA #BEEP_LN		; LENGTH	
	STA MyDL2

BEEP_LP3
	LDA #$FF
	STA A_Beeper
	DEC MyDL
	BNE BEEP_LP3
	
	LDA #BEEP_PW2
	STA MyDL

BEEP_LP4
	LDA #$00
	STA A_Beeper
	DEC MyDL
	BNE BEEP_LP4

	DEC MyDL2
	BNE BEEP_LP3

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
	.byte	$0D,"C/W/M ?",$00

	

; system vectors

	.segment "VECTS"
	.org	$FFFA

	.word	NMI_vec		; NMI vector
	.word	RES_vec		; RESET vector
	.word	IRQ_vec		; IRQ vector

