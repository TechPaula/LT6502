	.feature labels_without_colons
	.feature force_range

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



BEEP_PW			= $FF		; pitch of "low" beep
BEEP_PW2		= $7F		; pitch of "high" beep
BEEP_LN			= $20

DELAY_LEN1		= $05		; Also affects pitch

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


; display init
DISP_INIT

	rts

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

	RTS	

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


; system vectors

	.segment "VECTS"
	.org	$FFFA

	.word	NMI_vec		; NMI vector
	.word	RES_vec		; RESET vector
	.word	IRQ_vec		; IRQ vector

