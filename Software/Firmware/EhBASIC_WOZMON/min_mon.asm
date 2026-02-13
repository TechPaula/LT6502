; Heavily edited to work with the LT6502 project
;	https://github.com/TechPaula/LT6502
;
; TODO - Add cursor move command  
; TODO - Move ALL the writing of RG and DT into a table to be read by a loop (save code space)
; TODO - compact flash LOAD/SAVE/DIR
; TODO - Add, if possible, more versatile beep, something with more pitch range and length?

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
BEEP_PW			= $70		; pitch of "low" beep
BEEP_PW2		= $F0		; pitch of "high" beep
BEEP_LN			= $20
DELAY_LEN1		= $05		; Also affects pitch
BEEP_LN_CALC	= $05

; compact flash bits n bobs
CF_BASE			= $BFB0	; Compact flash address
CF_DATA     	= CF_BASE+0
CF_FEATURE  	= CF_BASE+1
CF_ERROR    	= CF_BASE+1
CF_SEC_CNT  	= CF_BASE+2
CF_SECTOR   	= CF_BASE+3
CF_CYL_LOW  	= CF_BASE+4
CF_CYL_HI   	= CF_BASE+5
CF_HEAD     	= CF_BASE+6
CF_STATUS   	= CF_BASE+7
CF_COMMAND  	= CF_BASE+7
CF_LBA0     	= CF_BASE+3
CF_LBA1     	= CF_BASE+4
CF_LBA2     	= CF_BASE+5
CF_LBA3     	= CF_BASE+6

CMD_READ    	= $20
CMD_WRITE   	= $30
CMD_FEATURE 	= $EF

CF_BUFFER 		= $04	; Start of two pages (512 bytes) of buffer

BUFPTR      	= $40         ; Pointer to CF Read/Write Buffer (16 bit)
BUFPTRL     	= $40         ; Pointer to CF Read/Write Buffer Low Byte
BUFPTRH     	= $41         ; Pointer to CF Read/Write Buffer Low Byte
LBA_0       	= $42         ; Temp storage for LBA Byte 0
LBA_1       	= LBA_0+1     ; ... LBA Byte 1
LBA_2       	= LBA_0+2     ; ... LBA Byte 2
LBA_3       	= LBA_0+3     ; ... LBA Byte 3 (lower 4 bits only)
PAGES       	= LBA_0+4     ; Counter for number of mem pages to use
LOC				= LBA_0+5	  ; Pointer for location on CF (16 bit)
LOC_L			= LBA_0+5	  ; low byte of location on CF to save
LOC_H			= LOC_L+1	  ; low byte of location on CF to save

CF_LB			= $0600 ; Place for low byte of sector address
CF_MB			= $0601 ; Place for middle byte of sector address
CF_HB			= $0602 ; Place for high byte of sector address
CF_LDSV			= $0603 ; Store the "are we accessing CF" variable here, used to redirect input/output
BUFF_NEWCHAR	= $604



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
DISP_ccol		= $624	; current coloumn (useful for delete)
DISP_crow		= $625	; current row (used for scrolling)
DISP_initcom	= $626
			; lines below used for plot, square, circle, line, etc
DISP_posx_h		= $627	; X position high byte
DISP_posx_l		= $628	; X position low byte
DISP_posy_h		= $629	; Y position high byte
DISP_posy_l		= $62A	; Y position low byte
DISP_posw_h		= $62B	; width high byte
DISP_posw_l		= $62C	; width low byte
DISP_posh_h		= $62D	; height high byte
DISP_posh_l		= $62E	; height low byte
DISP_col_l		= $62F	; colour for line or outline
DISP_col_t		= $630  ; colour for TEXT
DISP_fill		= $631	; fill?
DISP_dim_h		= $632
DISP_dim_l		= $632

			; Bunch of temporary values
MyTEMP			= $650
MyTEMP2			= $651
MyTEMP3			= $652
gthan			= $653

OutK_Y			= $655
OutK_X			= $656


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
	JSR PWR_BEEP_HIGH	; beep after display init

	; other bits of system init
	LDA #$00
	STA CF_LDSV		; no redirect of input/output to CF


	; Set colours
	LDA #%11111100
	STA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct
	LDY #$0
LAB_dobanner
	LDA	LAB_banner,Y	; get byte from sign on message
	CMP #$0D
	BNE LAB_dobanner_char
	JSR	V_OUTP			; output character (CR)
	DEC DISP_col_t		; Change colour based on row
	DEC DISP_col_t
	DEC DISP_col_t
	DEC DISP_col_t
	JSR DISP_TEXT_COLOUR_direct

LAB_dobanner_char
	CMP #$00
	BEQ LAB_presignon	; display next message
	JSR	V_OUTP			; output character
	INY					; increment index
	BNE	LAB_dobanner	; loop, branch always

LAB_presignon
	LDY #$0
	LDA #%11100100
	STA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct

LAB_signon				; now do the signon message, Y = $00 here
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
	BEQ LAB_docold 
	JMP RES_vec

LAB_docold
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR KYB_basmsg
	JMP	LAB_COLD		; do EhBASIC cold start

LAB_dowarm
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR KYB_basmsg
	JMP	LAB_WARM		; do EhBASIC warm start
LAB_dowoz
	LDA #$0D
	STA A_txd			; clear keyboard screen
	JSR KYB_wozmsg
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

	; Send output to display
	PHA
	JSR DISP_TEXT_WR
	PLA

ACIAout_exit
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


; ----- DISPLAY BITS
; display driver for the LT6502 project using the RA8875 driver
; the display is set to 800x480 pixels
DISP_INIT
		; write to reg 0 and read back driver chip number
	LDA #$00
	STA DISP_RG
	JSR DISP_CHK_BUSY
	LDA DISP_DT
	CMP #$75		;$75 means it's an RA8875 driver chip
	BEQ DISP_OK
	JMP DISP_ERR

DISP_OK	

	; 56 bytes in our initialisation array
	LDX #$00
DISP_initloop
	LDA	DISP_INIT_data,X		; get REGISTER value from array
	INX
	LDY DISP_INIT_data,X		; get DATA value from array
	JSR DISP_writereg			; WRITE DATA
	INX
	TXA
	CMP #56
	BNE DISP_initloop

	JSR DISP_CLR_SCREEN	
	JSR DISP_TEXT_MODE
	JSR DISP_CURSOR_SETXY
	PHA
	LDA #%11100100
	STA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct
	PLA
	RTS
	; end of DISP_INIT

DISP_ERR				; Show error message
	STA MyERR
	JSR DISP_flt
	RTS

DISP_CLR_SCREEN			; Fills the screen with black
	PHA
	PHX
	PHY
			
	; 24 bytes in our clear array
	LDX #$00
DISP_clrloop
	LDA	DISP_CLR_data,X		; get REGISTER value from array
	INX
	LDY DISP_CLR_data,X		; get DATA value from array
	JSR DISP_writereg
	INX
	TXA
	CMP #24
	BNE DISP_clrloop

DISP_fillcomp	
	LDA #$90				; CHECK IF WE'RE DONE
	STA DISP_RG
	LDA DISP_DT				; read status
	JSR DISP_CHK_BUSY

DISP_resetxy
	LDA #$00			; reset current coloumn and row
	STA DISP_ccol
	STA DISP_crow
	JSR DISP_CURSOR_SETXY

	PLY
	PLX
	PLA
	RTS

DISP_CLS
	JSR DISP_CLR_SCREEN	
	JSR DISP_TEXT_MODE

	JSR DISP_CURSOR_SETXY
	JSR DISP_TEXT_COLOUR_direct
	RTS

DISP_TEXT_MODE
	PHA
	PHX
	PHY

	LDA #$40
	LDY #$E0
	JSR DISP_writereg
	
	LDA #$44
	LDY #$20
	JSR DISP_writereg

	LDA #$21			; FONT control register 0
	LDY #$00
	JSR DISP_writereg

	LDA #$22			; FONT control register 1
	LDY #$00
	JSR DISP_writereg

	LDA #$29			; FONT distance setting register
	LDY #$00
	JSR DISP_writereg

	LDA #$2E			; FONT write type setting register
	LDY #$00
	JSR DISP_writereg

	PLY
	PLX
	PLA
	RTS

DISP_GRAPHICS_MODE
	LDA #$40
	STA DISP_RG
	LDA #$00
	STA DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_CURSOR_SETXY
	LDA #$00
	STA MyTEMP2
	LDA DISP_ccol
	STA MyTEMP  		; this holds the low byte for X
	CLC
	ROL MyTEMP			; multiply by 8 as each character is 8 bits wide
	ROL MyTEMP2
	CLC
	ROL MyTEMP
	ROL MyTEMP2
	CLC
	ROL MyTEMP
	ROL MyTEMP2

	LDA #$2A
	STA DISP_RG	
	LDA MyTEMP			; x position low byts
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$2B			
	STA DISP_RG
	LDA MyTEMP2			; x position high byte
	STA DISP_DT
	JSR DISP_CHK_BUSY

	LDA #$00
	STA MyTEMP2			; this holds the high byte for Y

	LDA DISP_crow
	STA MyTEMP  		; this holds the low byte for Y
	CLC
	ROL MyTEMP			; multiply by 16 as each character is 16 bits high
	ROL MyTEMP2
	CLC
	ROL MyTEMP
	ROL MyTEMP2
	CLC
	ROL MyTEMP
	ROL MyTEMP2
	CLC
	ROL MyTEMP
	ROL MyTEMP2

	LDA #$2C
	STA DISP_RG
	LDA MyTEMP			; y position low byts
	STA DISP_DT
	JSR DISP_CHK_BUSY
	LDA #$2D
	STA DISP_RG
	LDA MyTEMP2			; y position high byts
	STA DISP_DT
	JSR DISP_CHK_BUSY

	RTS

DISP_TEXT_COLOUR
	JSR LAB_GTBY		; GET NEXT BYTE (puts it in X)
	TXA
	STA DISP_col_t		; Used in VARI_BEEP routine

DISP_TEXT_COLOUR_direct
	LDA #$63			; RED colour, bits 0,1,2
	STA DISP_RG
	LDA DISP_col_t		; get text colour
	LSR
	LSR
	LSR
	LSR
	LSR
	STA DISP_DT
	JSR DISP_CHK_BUSY

	LDA #$64			; GREEN colour, bits 0,1,2
	STA DISP_RG
	LDA DISP_col_t		; get text colour
	AND #%00011100
	LSR
	LSR
	STA DISP_DT
	JSR DISP_CHK_BUSY

	LDA #$65			; BLUE colour, bits 0,1,2
	STA DISP_RG
	LDA DISP_col_t		; get text colour
	AND #%00000011
	STA DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_TEXT_WR
	STA DISP_temp		; Save character

	LDA DISP_temp				
	CMP #$20				; check for regular character
	BMI DISP_text_nonascii

	CMP #$7F				; check for delete character
	BEQ DISP_textexit		; for now we ignore it

DISP_normalchar	
;	jsr DISP_CURSOR_SETXY	; adding this double spaces everything, but backspace behaves

	LDA #$02			
	STA DISP_RG			; send "WRITE TEXT COMMAND"
	LDA DISP_temp
	STA DISP_DT			; send to display
	JSR DISP_CHK_BUSY
	INC DISP_ccol		; increase coloumn counter (needed for backspace)
	JMP DISP_textexit
			; no need to word wrap as display does this automatically 

DISP_text_nonascii
	LDA DISP_temp
	CMP #$08				; check for backspace
	BNE DISP_textcheckCR

	LDA DISP_ccol				;? holds correct value
	CMP #$00				; don't do anything if at col 0
	BEQ DISP_textexit

	DEC DISP_ccol				;? holds correct updated value
	JSR DISP_CURSOR_SETXY		;? but jumps forward???
	JMP DISP_textexit

DISP_textcheckCR
	LDA DISP_temp
	CMP #$0D				; check for CR
	BNE DISP_text_checkLF

	LDA #$00				; do carriage return
	STA DISP_ccol
	JSR DISP_CURSOR_SETXY
	JMP DISP_textexit

DISP_text_checkLF
	LDA DISP_temp
	CMP #$0A				; check for LF
	BNE DISP_textexit
	INC DISP_crow			; Do LF	

	LDA DISP_crow			; Check for bottom of screen
	CMP #30
	BNE DISP_textexit		; if not bottom sckip scroll
	JSR DISP_doscrollup		; else scroll

DISP_textexit
	JSR DISP_CURSOR_SETXY
	LDA #$00
	STA DISP_temp		; clear temp variable
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

; Switches display mode, 0 = text, 1 = graphics
IO_MODE
	PHY
	PHX
	PHA

	JSR LAB_GFPN		; Gets value of variable AFTER the command
	LDA Itempl			; This is the low byte of the value
	STA MyTEMP			; REMEMBER THIS

	; check if mode 1 (graphics)
	CMP #$01
	BNE IO_MODE_text
	JSR DISP_GRAPHICS_MODE
	JMP IO_MODE_exit

	; else mode 0 (text)
	; do text mode
IO_MODE_text
	JSR DISP_TEXT_MODE


IO_MODE_exit
	PLA
	PLX
	PLY
	RTS

DISP_clearbottomline	
	PHA
	PHX
	PHY

	; 24 bytes in our clear bottom line array
	LDX #$00
DISP_clrbotlineloop
	LDA	DISP_bottomline_data,X	; get REGISTER value from array
	INX
	LDY DISP_bottomline_data,X	; get DATA value from array
	JSR DISP_writereg
	INX
	TXA
	CMP #24
	BNE DISP_clrbotlineloop


	LDA #$90				; CHECK IF WE'RE DONE
	STA DISP_RG
	LDA DISP_DT				; read status
	JSR DISP_CHK_BUSY

	PLY
	PLX
	PLA
	RTS

DISP_readreg
	STA	DISP_RG
	LDA DISP_DT
	RTS

DISP_writereg
	STA	DISP_RG
	STY DISP_DT
	JSR DISP_CHK_BUSY
	RTS

DISP_doscrollup
	phy               ; preserve Y

	;; set up for move. I do this out of line so that the actual transfer
	;; happens as quickly as it can. Look up the current foreground
	;; color, cache it on the stack, and set the foreground to black.
	;; look up current color values and save them
	lda #$63
	jsr DISP_readreg
	pha

	lda #$64
	jsr DISP_readreg
	pha

	lda #$65
	jsr DISP_readreg
	pha

	;; now set color to black, ready for painting the block after the move
	lda #$63
	ldy #0
	jsr DISP_writereg
	lda #$64
	ldy #0
	jsr DISP_writereg
	lda #$65
	ldy #0
	jsr DISP_writereg

	;; setup completed. next, do the block move.
	;; set up source address
	;; NOTE address includes layer specification. I'm setting this
	;; to zero, which means Layer 1. I'm not even sure right now which
	;; layer I'm using!
	lda #$54          ; LSB of X coordinate
	ldy #0            ; starting at 0, 16
	jsr DISP_writereg
	lda #$55          ; MSB of X coordinate
	ldy #0            ; starting at 0, 16
	jsr DISP_writereg
	lda #$56          ; LSB of Y coordinate
	ldy #$10          
	jsr DISP_writereg
	lda #$57          ; MSB of Y coordinate
	ldy #0
	jsr DISP_writereg
	

	;; set up destination address
	lda #$58          ; LSB of X coordinate
	ldy #0            ; copying to 0,0
	jsr DISP_writereg
	lda #$59          ; MSB of X coordinate
	ldy #0
	jsr DISP_writereg
	lda #$5A          ; LSB of Y coordinate
	ldy #0
	jsr DISP_writereg
	lda #$5B          ; MSB of Y coordinate
	ldy #0
	jsr DISP_writereg

	;; set BTE width and hight
	lda #$5C          ; LSB of width
	ldy #$20          ; width is 800 ($320)
	jsr DISP_writereg
	lda #$5D          ; MSB of width
	ldy #$03
	jsr DISP_writereg

	lda #$5E          ; LSB of X coordinate
	ldy #$D0          ; height is 464 ($1D0)
	jsr DISP_writereg
	lda #$5F          ; MSB of X coordinate
	ldy #$01
	jsr DISP_writereg

	;; set BTE function
	;; function is "move in a positive direction". The "positive direction"
	;; means that we start at the beginning and move toward the end; since
	;; the source and destination regions overlap, that's what we need.
	;; ROP is "destionation = source" (ie, straight copy).
	;; ROP is %1100 = $C, ROP is %0010 = $02
	;; result is $C2
	lda #$51
	ldy #$C2
	jsr DISP_writereg

	;; enable BTE function
	lda #$50
	ldy #$80
	jsr DISP_writereg

	;; wait for block transfer to complete. Read register $50 until
	;; the top bit is clear.
DISP_scroll_busyloop
	lda #$50
	jsr DISP_readreg
	bmi DISP_scroll_busyloop

		; clear bottom line
	JSR DISP_clearbottomline

	;; reset color. 
	pla
	tay
	lda #$65
	jsr DISP_writereg
	pla
	tay
	lda #$64
	jsr DISP_writereg
	pla
	tay
	lda #$63
	jsr DISP_writereg


	DEC DISP_crow
	JSR DISP_CURSOR_SETXY

	ply               ; restore Y
	rts

	; PLOT XXXX,YYYY,CC
DISP_PLOT
	PHA
	PHX
	PHY
			; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY

			; GET COLOUR
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_l
			; PLOT THE DOT
	LDY DISP_posx_l
	LDA #$46
	JSR DISP_writereg

	LDY DISP_posx_h
	LDA #$47
	JSR DISP_writereg

	LDY DISP_posy_l
	LDA #$48
	JSR DISP_writereg

	LDY DISP_posy_h
	LDA #$49
	JSR DISP_writereg

	LDY DISP_col_l
	LDA #$02
	JSR DISP_writereg

	PLY
	PLX
	PLA
	RTS

DISP_GETXY
		; GET PARAMETERS AND SAVE THEM
			; XXXX
	JSR LAB_EVNM		; evaluate expression and check is numeric,
                        ; else do type mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer
	LDA	Itemph
	STA DISP_posx_h
	LDA	Itempl
	STA DISP_posx_l
			; YYYY
	JSR LAB_1C01        ; scan for "," , else do syntax error then warm start
	JSR LAB_EVNM        ; evaluate expression and check is numeric,
                        ; else do typDISP_CIRCLEe mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer
	LDA	Itemph
	STA DISP_posy_h
	LDA	Itempl
	STA DISP_posy_l

	RTS

DISP_GETENDXY
		; GET PARAMETERS AND SAVE THEM
			; END XXXX
	JSR LAB_1C01        ; scan for "," , else do syntax error then warm start
	JSR LAB_EVNM        ; evaluate expression and check is numeric,
                        ; else do typDISP_CIRCLEe mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer
	LDA	Itemph
	STA DISP_posw_h
	LDA	Itempl
	STA DISP_posw_l
			; END YYYY
	JSR LAB_1C01        ; scan for "," , else do syntax error then warm start
	JSR LAB_EVNM        ; evaluate expression and check is numeric,
                        ; else do typDISP_CIRCLEe mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer
	LDA	Itemph
	STA DISP_posh_h
	LDA	Itempl
	STA DISP_posh_l

	RTS

	; CIRCLE XXXX,YYYY,RR,CC,FF
DISP_CIRCLE
	PHA
	PHX
	PHY
		; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY
			; RR
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_dim_l
			; CC
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_t
			; FF
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_fill

		; DRAW CIRCLE
			; SET X
	LDY DISP_posx_l
	LDA #$99
	JSR DISP_writereg	
	LDY DISP_posx_h
	LDA #$9A
	JSR DISP_writereg
			; SET Y
	LDY DISP_posy_l
	LDA #$9B
	JSR DISP_writereg	
	LDY DISP_posy_h
	LDA #$9C
	JSR DISP_writereg
			; SET RADIUS
	LDY DISP_dim_l
	LDA #$9D
	JSR DISP_writereg
			; SET COLOUR
	JSR DISP_TEXT_COLOUR_direct
			; DRAW


	LDA DISP_fill
	BEQ DISP_circlenofill

	LDA #$60		; DO CIRCLE ($40) AND FILL ($20)
	STA DISP_fill
	JMP DISP_circledoit

DISP_circlenofill
	LDA #$40		; DO CIRCLE ($40)
	STA DISP_fill

DISP_circledoit
	LDY DISP_fill
	LDA #$90
	JSR DISP_writereg

			; wait for display to be done
	JSR DISP_busyloop

	PLY
	PLX
	PLA
	RTS


DISP_busyloop
	LDA #$90			; CHECK DCR
	JSR DISP_readreg
	ROL
	BMI DISP_busyloop

	LDA #$90				; CHECK IF WE'RE DONE
	STA DISP_RG
	LDA DISP_DT				; read status
	JSR DISP_CHK_BUSY
	RTS

DISP_SETXY_ENDXY
			; SET X
	LDY DISP_posx_l
	LDA #$91
	JSR DISP_writereg	
	LDY DISP_posx_h
	LDA #$92
	JSR DISP_writereg
			; SET Y
	LDY DISP_posy_l
	LDA #$93
	JSR DISP_writereg	
	LDY DISP_posy_h
	LDA #$94
	JSR DISP_writereg

			; SET END X
	LDY DISP_posw_l
	LDA #$95
	JSR DISP_writereg	
	LDY DISP_posw_h
	LDA #$96
	JSR DISP_writereg
			; SET END Y
	LDY DISP_posh_l
	LDA #$97
	JSR DISP_writereg	
	LDY DISP_posh_h
	LDA #$98
	JSR DISP_writereg

	RTS


DISP_LINE
	PHA
	PHX
	PHY
		; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY
	JSR DISP_GETENDXY
			; CC
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_t

			; SET START/END POINTS 
	JSR DISP_SETXY_ENDXY

			; SET COLOUR
	LDA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct

			; DRAW LINE
	LDY #$80
	LDA #$90
	JSR DISP_writereg	

			; wait for display to be done
	JSR DISP_busyloop

	PLY
	PLX
	PLA
	RTS

DISP_SQUARE
	PHA
	PHX
	PHY
		; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY
	JSR DISP_GETENDXY
			; CC
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_t
			; FF
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_fill

			; SET START/END POINTS 
	JSR DISP_SETXY_ENDXY

			; SET COLOUR
	LDA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct

			; CHECK FOR FILL
	LDY #$90					; $50 is square command
	LDA DISP_fill
	CMP #$00
	BEQ DISP_SQUARE_nofill
	TYA
	ORA #$20					; OR in extra bit for fill
	TAY

DISP_SQUARE_nofill
			; DRAW SQUARE
	; Y ALREADY HOLDS COMMAND
	LDA #$90
	JSR DISP_writereg	

			; wait for display to be done
	JSR DISP_busyloop

	PLY
	PLX
	PLA
	RTS

DISP_ELIPSE
	PHA
	PHX
	PHY
		; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY
	JSR DISP_GETENDXY   ; ACTUALL RX AND RY
			; CC
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_t
			; FF
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_fill

		; SET UP PARAMETERS
			; SET X
	LDY DISP_posx_l
	LDA #$A5
	JSR DISP_writereg	
	LDY DISP_posx_h
	LDA #$A6
	JSR DISP_writereg
			; SET Y
	LDY DISP_posy_l
	LDA #$A7
	JSR DISP_writereg	
	LDY DISP_posy_h
	LDA #$A8
	JSR DISP_writereg

			; SET RADIUS X
	LDY DISP_posw_l
	LDA #$A1
	JSR DISP_writereg	
	LDY DISP_posw_h
	LDA #$A2
	JSR DISP_writereg
			; SET RADIUS Y
	LDY DISP_posh_l
	LDA #$A3
	JSR DISP_writereg	
	LDY DISP_posh_h
	LDA #$A4
	JSR DISP_writereg

			; SET COLOUR
	LDA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct

			; CHECK FOR FILL
	LDY #$80
	LDA DISP_fill
	CMP #$00
	BEQ DISP_ELIPSE_nofill
	TYA
	ORA #$40					; OR in extra bit for fill
	TAY

DISP_ELIPSE_nofill
			; DRAW SQUARE
	; Y ALREADY HOLDS COMMAND
	LDA #$A0
	JSR DISP_writereg	

			; wait for display to be done
	JSR DISP_busyloop

	PLY
	PLX
	PLA
	RTS


DISP_TRIANGLE
	PHA
	PHX
	PHY

		; GET PARAMETERS AND SAVE THEM
	JSR DISP_GETXY		; POINT 0 (TOP)
	JSR DISP_GETENDXY	; POINT 1 (BOTTOM LEFT)
			; SET POINT 0 AND POINT 1
	JSR DISP_SETXY_ENDXY

	JSR DISP_GETENDXY	; GET POINT 2 (BOTTOM RIGHT)

			; CC
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_col_t

			; FF
	JSR LAB_SGBY		; Scan for "," and get next byte, return in X
	TXA
	STA DISP_fill

			; SET POINT 3
	LDY DISP_posw_l
	LDA #$A9
	JSR DISP_writereg	
	LDY DISP_posw_h
	LDA #$AA
	JSR DISP_writereg
			; SET Y
	LDY DISP_posh_l
	LDA #$AB
	JSR DISP_writereg	
	LDY DISP_posh_h
	LDA #$AC
	JSR DISP_writereg

	LDA DISP_col_t
	JSR DISP_TEXT_COLOUR_direct


			; CHECK FOR FILL
	LDY #$81					; TRIANGLE COMMAND
	LDA DISP_fill
	CMP #$00
	BEQ DISP_TRIANGLE_nofill
	TYA
	ORA #$20					; OR in extra bit for fill
	TAY

DISP_TRIANGLE_nofill
	; Y ALREADY HOLDS COMMAND
	LDA #$90
	JSR DISP_writereg	

			; wait for display to be done
	JSR DISP_busyloop

	PLY
	PLX
	PLA
	RTS




IO_CLS
	JSR DISP_CLS
	RTS

; ------ END OF DISPLAY BITS


; ------ BEEPS
BEEP_CMD
	PHX
	PHY
	PHA

	JSR LAB_GTBY		; GET NEXT BYTE (puts it in X)
	TXA
	STA MyTEMP			; Used in VARI_BEEP routine

	JSR VARI_BEEP

	PLA
	PLY
	PLX
	RTS

; HIGH BEEP
PWR_BEEP_HIGH
	LDA #BEEP_PW2		; PULSE WIDTH	
	STA MyTEMP
	JSR VARI_BEEP
	RTS

; LOW BEEP
PWR_BEEP_LOW
	LDA #BEEP_PW		; PULSE WIDTH	
	STA MyTEMP
	JSR VARI_BEEP
	RTS

; ERROR BEEP called by BASIC on error
ERROR_BEEP
	PHY
	PHX
	PHA

	LDA #$00		; LOW NOTE
	STA MyTEMP
	JSR VARI_BEEP
	LDA #$00		; LOW NOTE
	STA MyTEMP
	JSR VARI_BEEP
	LDA #$00		; LOW NOTE
	STA MyTEMP
	JSR VARI_BEEP

	PLA
	PLX
	PLY
	RTS	

; VARIABLE PITCH BEEP
VARI_BEEP
	LDA MyTEMP			; PULSE WIDTH
	STA MyTEMP2			; SAVE TO USE TO CALC LENGTH	
	EOR #$FF			; INVERT SO LOW NUMBER = LOW PITCH
	CMP #$0
	BNE VARI_BEEP_pok
	INC

VARI_BEEP_pok
	STA MyTEMP
	STA MyDL	

	; FIGURE OUT LENGTH OF NOTE
	;	HIGHER NOTES = MORE LOOPS
	EOR #$FF
	LSR 
	LSR
	LSR
	CLC
	ADC #$10
	STA MyDL2

VARI_BEEP_LP1
	LDA #$FF
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE VARI_BEEP_LP1
	
	LDA MyTEMP
	STA MyDL

VARI_BEEP_LP2
	LDA #$00
	STA A_Beeper
	JSR DELAY1
	DEC MyDL
	BNE VARI_BEEP_LP2

	DEC MyDL2
	BNE VARI_BEEP_LP1

	RTS	


; ------ END BEEPS

; ------ Compact Flash bits

; empty load vector for EhBASIC
IO_LOAD
	JSR LAB_EVNM		; evaluate expression and check is numeric,
                        ; else do type mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer

	LDA	Itemph
	STA LOC_H			; save the CF "Slot"
	STA LBA_2
	LDA	Itempl
	STA LOC_L			; save the CF "Slot"
	STA LBA_1

	LDA #$00
	STA LBA_0
	STA LBA_3

	; LOAD "INFO" SECTOR
	LDA #$04			; Set START (BUFFER)
	STA BUFPTRH
	LDA #$00
	STA BUFPTRL

	JSR CF_INIT
	JSR CF_READ_SECTOR
	JSR IO_LOAD_SAVE_incrlba

	; ADD CHECK FOR FIRST BYTE BEING ASCII, IF NOT IT'S EMPTY!!! RETURN WITH AN EMPTY ERROR

	LDA $0400
	CMP #$20
	BMI IO_LOAD_ERROR
	LDA $0400
	CMP #$7E
	BPL IO_LOAD_ERROR
	

	; show loading message and file name
	LDY #$00
IO_LOAD_message				; now do the loading message
	LDA	LOAD_mess,Y			; get byte from sign on message
	BEQ IO_LOAD_showname	; display filename

	JSR	V_OUTP			; output character
	INY					; increment index
	BNE	IO_LOAD_message	; loop, branch always

IO_LOAD_showname
	LDY #$00
IO_LOAD_showname_lp
	LDA $0400,Y
	JSR V_OUTP
	INY
	TYA
	CMP #$10
	BNE IO_LOAD_showname_lp

	; get important things from the INFO sector
	LDA $0410
	STA Smemh
	LDA $0411
	STA Smeml
	LDA $0412
	STA Svarh
	LDA $0413
	STA Svarl

	; LOAD ACTUAL BASIC CODE
	LDA #$08			; Set START (basic)
	STA BUFPTRH
	LDA #$00
	STA BUFPTRL

IO_LOAD_loop			; ! HACKY, JUST READ 46K OF CF CARD TO RAM
	JSR CF_READ_SECTOR

	JSR IO_LOAD_SAVE_incrlba
	LDA BUFPTRH
	CMP #$BE
;	CMP Svarh			; TODO - IS THIS A BETTER WAY TO DO IT???
	BNE IO_LOAD_loop

	; PRINT "Ready"
	LDA   #<LAB_RMSG        ; point to "Ready" message low byte
	LDY   #>LAB_RMSG        ; point to "Ready" message high byte
	JSR   LAB_18C3          ; go do print string

	; VOODOO that EhBASIC needs
	STZ $F8   		; VOODOO that EhBASIC needs
    JMP LAB_1319 	; VOODOO that EhBASIC needs


; load error
IO_LOAD_ERROR
	LDY #$00
IO_LOAD_err_lp				; now do the loading message
	LDA	LOAD_nofile_mess,Y	; get byte from sign on message
	BEQ IO_LOAD_ERROR_exit	; display filename

	JSR	V_OUTP			; output character
	INY					; increment index
	BNE	IO_LOAD_err_lp	; loop, branch always

	; LOAD_nofile_mess
IO_LOAD_ERROR_exit
	JSR ERROR_BEEP
	RTS


; SAVE vector for EhBASIC
;	usage - SAVE nnnn,"PROG NAME"
;	where nnnn is save location
IO_SAVE
	JSR LAB_EVNM		; evaluate expression and check is numeric,
                        ; else do type mismatch
	JSR LAB_F2FX        ; save integer part of FAC1 in temporary integer

	LDA	Itemph
	STA LOC_H			; save the CF "Slot"
	STA LBA_2
	LDA	Itempl
	STA LOC_L			; save the CF "Slot"
	STA LBA_1

	LDA #$00
	STA LBA_0
	STA LBA_3

	JSR LAB_1C01        ; scan for "," , else do syntax error then warm start

    JSR LAB_EVEX        ; evaluate expression
    BIT Dtypef          ; test data type flag, $FF=string, $00=numeric
    BMI IO_SAVE_string  ; branch if string
	JSR ERROR_BEEP		; SHOULD NOT BE NUMERIC
	JMP IO_SAVE_exit

IO_SAVE_string
; save string to buffer
	JSR LAB_22B6        ; pop string off descriptor stack, or from top of string
						; space returns with A = length, X=$71=pointer low byte,
						; Y=$72=pointer high byte
	LDY #$00           	; reset index
	TAX                 ; copy length to X

IO_SAVE_stringloop
	LDA (ut1_pl),Y     		; get next byte
	STA $0400,Y          	; Put char into buffer
	INY                     ; increment index

	TYA
	CMP #$10
	BEQ IO_SAVE_createinfo	; break if more than 16 characters long

	DEX                     ; decrement count
	BNE IO_SAVE_stringloop 	; loop if not done yet

	; PAD OUT REST WITH SPACES
IO_SAVE_pad
	LDA #$20	     		; get next byte
	STA $0400,Y          	; Put char into buffer
	INY                     ; increment index
	TYA
	CMP #$10
	BEQ IO_SAVE_createinfo	; break if more than 16 characters long
	DEX                     ; decrement count
	BNE IO_SAVE_pad 	; loop if not done yet

IO_SAVE_createinfo
;  CREATE "INFO" SECTOR (FIRST SECTOR OF BLOCK)
	LDA Smemh
	STA $0410
	LDA Smeml
	STA $0411
	LDA Svarh
	STA $0412
	LDA Svarl
	STA $0413

	LDA #$04			; Set START (basic)
	STA BUFPTRH
	LDA #$00
	STA BUFPTRL

	JSR CF_INIT
	JSR CF_WRITE_SECTOR
	JSR IO_LOAD_SAVE_incrlba

	; SAVE ACTUAL BASIC CODE
	LDA #$08			; Set START (basic)
	STA BUFPTRH
	LDA #$00
	STA BUFPTRL

IO_SAVE_loop			; ! HACKY, JUST DUMP ALL 46K OF RAM TO CF CARD
	JSR CF_WRITE_SECTOR

	JSR IO_LOAD_SAVE_incrlba
	LDA BUFPTRH
	CMP #$BE
;	CMP Svarh			; TODO - IS THIS A BETTER WAY TO DO IT???
	BNE IO_SAVE_loop

IO_SAVE_exit
	RTS


; empty DIR vector for EhBASIC
IO_DIR
	LDA #$00	; with LBA to 0,0,0
	STA LBA_0	; this STAYS at $00
	STA LBA_1
	STA LBA_2
	STA LBA_3	; this STAYS at $00

	JSR CF_INIT

IO_DIR_read_lp

	LDA #$04
	STA BUFPTRH
	LDA #$00
	STA BUFPTRL

	JSR CF_SET_LBA
	JSR CF_READ_SECTOR

	; Check slot has valid data, if not skip it
	LDA $0400

	CMP #$20
	BMI IO_DIR_nextslot
	LDA $0400
	CMP #$7E
	BPL IO_DIR_nextslot

	; print slot number
	LDA LBA_2
	LDX LBA_1
	JSR LAB_295E

	; seperator
	LDA #$20
	JSR V_OUTP
	LDA #$2D
	JSR V_OUTP
	LDA #$20
	JSR V_OUTP

	; print slot name
IO_DIR_showname
	LDY #$00
IO_DIR_showname_lp
	LDA $0400,Y
	JSR V_OUTP
	INY
	TYA
	CMP #$10
	BNE IO_DIR_showname_lp

	LDA #$0D
	JSR V_OUTP
	LDA #$0A
	JSR V_OUTP

IO_DIR_nextslot
	CLC
	LDA LBA_1
	ADC #$01
	STA LBA_1

	LDA LBA_2
	ADC #$00
	STA LBA_2

	CMP #$08
	BNE IO_DIR_read_lp

IO_DIR_end
	RTS


IO_LOAD_SAVE_incrlba
	LDA LBA_0
	INC
	STA LBA_0

	RTS

IO_INTtoASCII

	RTS

;-------------------------------------------------------------------------------
; CF_INIT - Set 8 bit mode, write 1 to feature register
;			then $EF to command register to execute    
;-------------------------------------------------------------------------------
CF_INIT:
    PHY
    PHX
    PHA
    JSR     CF_WAIT
    LDA     #$01
    STA     CF_FEATURE
    LDA     #CMD_FEATURE
    STA     CF_COMMAND
    PLA
    PLX
    PLY
    RTS








;-------------------------------------------------------------------------------
; CF_WAIT - Checks the CF card isn't busy
; 
; Wait for flag MSB of status register to be clear
; 
; TODO - Implement time out?
;
;-------------------------------------------------------------------------------
CF_WAIT:
    LDA     CF_STATUS
    BMI     CF_WAIT
    RTS



;-------------------------------------------------------------------------------
; CF_SET_LBA - Sets up the CF Card with LBA and Sector Count parameters
; 
; LBA values are read from Zero Page at $42(LBA0) to $45(LBA3)
; 
; Sector count is always 1
;
;-------------------------------------------------------------------------------
CF_SET_LBA:
    JSR     CF_WAIT

    ; SET ONE SECTOR (512 BYTES) AT A TIME
    LDA     #$01
    STA     CF_SEC_CNT
    JSR     CF_WAIT


    LDA     LBA_0           ; Lower Byte
    STA     CF_LBA0
    JSR     CF_WAIT
  
    LDA     LBA_1           ; Lower Middle Byte
    STA     CF_LBA1
    JSR     CF_WAIT

    LDA     LBA_2           ; Upper Middle Byte
    STA     CF_LBA2
    JSR     CF_WAIT

    LDA     LBA_3           ; Upper Nybble
    AND     #$0F            ; Ensure top 4 bits are 0000
    ORA     #$E0            ; Then force top 4 bits to 1110
    STA     CF_LBA3
    JSR     CF_WAIT
    RTS


;-------------------------------------------------------------------------------
; CF_READ_SECTOR - Reads a single sector from CF into a buffer
; 
; Buffer address should always be page aligned. Set BUFPTRL to 0, and 
; BUFPTRH to high byte of buffer address
; Set number of memory pages to use for buffer in PAGES, default = 2
;
;-------------------------------------------------------------------------------
CF_READ_SECTOR:
    JSR     CF_SET_LBA
    JSR     CF_WAIT

    LDA     #CMD_READ           ; Send the Read command to the CF
    STA     CF_COMMAND
    JSR     CF_WAIT             ; de dum de dum

    LDA     #$02                ; Set page count to 2
    STA     PAGES

    LDY     #$00                ; Clear Y

CF_RD_LP1:
    LDA     CF_DATA             ; Read CF Data Register
    STA     (BUFPTRL),Y         ; Save to buffer

    INY                         ; Increment buffer pointer
    BNE     CF_RD_LP1           ; If it's zero, we need a new page, otherwise repeat
    
    INC     BUFPTRH             ; Increment the high byte of the buffer pointer
                                ; (So subsequent reads don't need to set up pointer)

    DEC     PAGES               ; decrement page counter
    BEQ     CF_RD_EXIT          ; if it's zero, we're done, so exit

    LDY     #$00                ; Clear Y (it should be already, but JFDI)
    BRA     CF_RD_LP1           ; and repeat for another 256 bytes

CF_RD_EXIT:
    RTS

;-------------------------------------------------------------------------------
; CF_WRITE_SECTOR - writes a single sector from buffer into a CF
; 
; Buffer address should always be page aligned. Set BUFPTRL to 0, and 
; BUFPTRH to high byte of buffer address
; Set number of memory pages to use for buffer in PAGES, default = 2
;-------------------------------------------------------------------------------
CF_WRITE_SECTOR:
    JSR     CF_SET_LBA
    JSR     CF_WAIT

    LDA     #CMD_WRITE          ; Send the Read command to the CF
    STA     CF_COMMAND
    JSR     CF_WAIT             ; de dum de dum;

    LDA     #$02                ; Set page count to 2
    STA     PAGES

    LDY     #$00                ; Clear Y

CF_WR_LP1:
    LDA     (BUFPTRL),Y         ; Read from buffer
    STA     CF_DATA             ; Write to CF Data Register

    INY                         ; Increment buffer pointer
    BNE     CF_WR_LP1           ; If it's zero, we need a new page, otherwise repeat

    INC     BUFPTRH             ; Increment the high byte of the buffer pointer
                                ; (So subsequent writes don't need to set pointer)

    DEC     PAGES               ; decrement page counter
    BEQ     CF_WR_EXIT          ; if it's zero, we're done, so exit


    LDY     #$00                ; Clear Y (it should be already, but JFDI)
    BRA     CF_WR_LP1           ; and repeat for another 256 bytes

CF_WR_EXIT:
    RTS

;-------------------------------------------------------------------------------
; CLR_CFBUFFER - Clears the Compact Flash read/write buffer
; 
; Buffer address should always be page aligned. Set BUFPTRL to 0, and 
; BUFPTRH to high byte of buffer address
; Set number of memory pages to clear in PAGES
;
;-------------------------------------------------------------------------------
 CLR_CFBUFFER:

    LDY     #$00            ; Set offset to 0

    LDA     #$00            ; Value to write
CLRLOOP:
    STA     (BUFPTR),Y      ; Write data to memory
    INY                     ; Point to next byte
    BNE     CLRLOOP         ; do it 256 times

    DEC     PAGES           ; Check if all done
    BEQ     CLRDONE         ; if so, exit

    LDY     #$00            ; if not, clear offset again
    INC     BUFPTRH         ; Increment page counter
    BRA     CLRLOOP         ; and repeat
CLRDONE:
    RTS






; ------ END compact flash


; ----- OUTK send text to keyboard display
;			we always print to the next character, don't need ; or , 
;			CRLF is not auto sent
OUTK
	PHY
	PHX
	PHA

	; send result to keyboard
    JSR LAB_EVEX        ; evaluate expression
    BIT Dtypef          ; test data type flag, $FF=string, $00=numeric
    BMI OUTK_string     ; branch if string
	JSR LAB_296E        ; convert FAC1 to string

	LDY #$00			; Reset offset
OUTK_lp	
	LDA $00F0,Y			; Read string
	CMP #$00
	BEQ OUTK_exit		; if end of string, exit
	CMP #$20			
	BEQ OUTK_skip		; if " " then skip
	JSR KEYBout			; send character

OUTK_skip	
	INY
	JMP OUTK_lp

OUTK_exit
	PLA
	PLX
	PLY
	RTS

OUTK_string
	LDA #$0D				; Clear the display BEFORE sending text
	JSR KEYBout

	JSR LAB_22B6        ; pop string off descriptor stack, or from top of string
						; space returns with A = length, X=$71=pointer low byte,
						; Y=$72=pointer high byte
	LDY #$00           	; reset index
	TAX                 ; copy length to X
	BEQ OUTK_exit       ; exit (RTS) if null string

OUTK_string_loop
	LDA (ut1_pl),Y     		; get next byte
	JSR KEYBout          	; go print the character
	INY                     ; increment index
	DEX                     ; decrement count
	BNE OUTK_string_loop  	; loop if not done yet

	JMP OUTK_exit
; ----- END OF OUTK


; Delay loop for random things
DELAY1
	LDA #DELAY_LEN1
	STA MyDL3

DELAY1_LP
	DEC MyDL3
	BNE DELAY1_LP

	RTS

DELAY2
	LDA #DELAY_LEN1
	STA MyDL3

DELAY2_LP
	NOP
	NOP
	NOP
	NOP
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
	.word 	IO_CLS		; CLS vector for EhBASIC		EhBASIC = V_CLS
	.word	IO_MODE		; MODE vector for EhBASIC		EhBASIC = V_MODE
	.word   BEEP_CMD	; BEEP vector for EhBASIC		EhBASIC = V_BEEP
	.word	EWOZ		; WOZMON vector					EhBASIC = V_WOZMON
	.word	DISP_TEXT_COLOUR	; COLOUR vector			EhBASIC = V_COLOUR
	.word	DISP_PLOT	; PLOT vector					EhBASIC = V_PLOT
	.word	DISP_CIRCLE	; CIRCLE vector					EhBASIC = V_CIRCLE
	.word	DISP_LINE	; LINE vector					EhBASIC = V_LINE
	.word	DISP_SQUARE	; SQUARE vector					EhBASIC = V_SQUARE
	.word	DISP_ELIPSE	; ELIPSE vector					EhBASIC = V_ELIPSE
	.word	DISP_TRIANGLE; TRIANGLE vector				EhBASIC = V_TRIANGLE
	.word 	OUTK		; OUTK vector					EhBASIC = V_OUTK
	.word 	DISP_TEXT_MODE ; set display back to text mode EhBASIC = V_TEXTMODE

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

DISP_INIT_data 		 	; order is reg, then data, 56 BYTES
	.byte  	$01,$01,$01,$00,$88,$0A,$89,$02,$10,$00,$04,$81,$14,$63,$15,$00
	.byte	$16,$03,$17,$03,$18,$0B,$19,$DF,$1A,$01,$1B,$1F,$1C,$00,$1D,$16
	.byte	$1E,$00,$1F,$01,$30,$00,$31,$00,$34,$1F,$35,$03,$32,$00,$33,$00
	.byte	$36,$DF,$37,$01,$01,$80,$C7,$01

DISP_CLR_data 		 	; order is reg, then data, 24 BYTES
	.byte	$91,$00,$92,$00,$93,$00,$94,$00,$95,$1F,$96,$03,$97,$DF,$98,$01
	.byte	$63,$00,$64,$00,$65,$00,$90,$B0

DISP_bottomline_data	; order is reg, then data, 24 BYTES
	.byte 	$91,$00,$92,$00,$93,$D0,$94,$01,$95,$1F,$96,$03,$97,$DF,$98,$01
	.byte	$63,$00,$64,$00,$65,$00,$90,$B0

DISP_doscroll_data		; order is reg, data, 34 bytes
	.byte	$63,$00,$64,$00,$65,$00,$54,$00,$55,$00,$56,$10,$57,$00,$58,$00
	.byte	$59,$00,$5A,$00,$5B,$00,$5C,$20,$5D,$03,$5E,$D0,$5F,$01,$51,$C2
	.byte	$50,$80




	; banner done with https://www.asciiart.eu/text-to-ascii-art
LAB_banner
	.byte	$0D,"    __   ______ _____  ______ ____  ___ ",$0D,$0A		; "  <- stops weird colours in editor
	.byte		"   / /  /_  __// ___/ / ____// __ \|__ \",$0D,$0A		; "  <- stops weird colours in editor  
	.byte		"  / /    / /  / __ \ /___ \ / / / /__/ /",$0D,$0A		; "  <- stops weird colours in editor    
	.byte		" / /___ / /  / /_/ /____/ // /_/ // __/ ",$0D,$0A		; "  <- stops weird colours in editor    
	.byte		"/_____//_/   \____//_____/ \____//____/ ",$0A,$00		; "  <- stops weird colours in editor    


LAB_mess 					; sign on string (Console)
	.byte	$0D,"[C]Cold/[W]arm or [M]onitor ?",$00

KYB_mess					; sign on string (Keyboard)
	.byte	$0D,"C/W/M ? ",$00
KYB_basmess_str
	.byte	$0D,$0D,"EhBASIC ",$00
KYB_wozmess_str
	.byte	$0D,$0D,"eWOZMON ",$00
LOAD_mess
	.byte   "Loading - ",$00
LOAD_nofile_mess
	.byte   "NO FILE FOUND",$0D,$0A,$00


ERR_disp
	.byte	$0D,$0A,"D_ERR:",$00


; system vectors

	.segment "VECTS"
	.org	$FFFA

	.word	NMI_vec		; NMI vector
	.word	RES_vec		; RESET vector
	.word	IRQ_vec		; IRQ vector

