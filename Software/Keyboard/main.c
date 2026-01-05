/* 
 * This is the code for the PC6502 KeyBed
 * File:   main.c
 * Author: paula
 *
 * Created on 08 November 2025, 11:55
 * TODO:
 *      Get CAPS LOCK on/off (Shift+CTRL) to function
 *      Figure out what to do with the 'F' keys
 */

//#include <xc.h>
#include <avr/iom644p.h>

// ATmega644P Configuration Bit Settings *** VERY IMPORTANT ***
//FUSES = {
//   	.low = 0xFF,        // LOW {SUT_CKSEL=EXTXOSC_8MHZ_XX_16KCK_65MS, CKOUT=CLEAR, CKDIV8=CLEAR}
//	.high = 0x99,       // HIGH {BOOTRST=CLEAR, BOOTSZ=4096W_7000, EESAVE=CLEAR, WDTON=CLEAR, SPIEN=SET, JTAGEN=SET, OCDEN=CLEAR}
//	.extended = 0xFF,   // EXTENDED {BODLEVEL=DISABLED}
//};

//LOCKBITS = 0xFF; // {LB=NO_LOCK, BLB0=NO_LOCK, BLB1=NO_LOCK}


// defines that libs things may depend on
#define F_CPU (20000000UL)
#define BAUD 115200UL    // desired baud
#define BAUD_TOL 2     // desired baud rate tolerance (+/- %)


// mplabx library functions
#include <avr/io.h>
#include <avr/wdt.h>
#include <util/delay.h>

#include <stdint.h>
#include <stdio.h>
#include <avr/interrupt.h>  // ISR macro
#include <util/setbaud.h>   // Baud rate calculation macro helpers


/*** LOCAL FUNCTION PROTOTYPES ************************************************/
void TIMER1_Init(void);             // Timer/Counter1 initialization
void USART0_Init(void);             // USART0 initialization
void USART0_Put(uint8_t data);      // Transmit a byte
void USART0_PutString(char *ptr);   // Transmit a string
char USART0_GetChar(void);          // Receive a character (if available)    
uint8_t USART0_CheckChar(void);     // check if a char is available
void UpdateDisplay(void);           // Update the display
uint8_t GetBitNum(uint8_t);

/*** globbals ******************************************************************/
char g_OutString[80];               // output buffer used with sprintf
uint8_t dispchar[8]={'-','L','T','6','5','0','2','-'};
int8_t charpos = 0;
uint8_t CAPSLED = 0;            // 0 = ON, 1 = OFF
volatile uint8_t ColCount = 0;
volatile uint8_t KeyPress = 0xFF;
volatile uint8_t KeyCol = 0;
volatile uint8_t Sent = 1;
volatile uint8_t olddataout = 255;
volatile uint16_t debouncecount = 0;
volatile uint8_t ColInc = 1;

uint8_t ShiftStatus = 0;
uint8_t CtrlStatus = 0;
uint8_t CapsLock = 1;

uint8_t chartable[64]= {'A','B','C','D','E','F','G','H',
                        'I','J','K','L','M','N','O','P',
                        'Q','R','S','T','U','V','W','X',
                        'Y','Z','0','1','2','3','4','5',
                        '6','7','8','9', 45, 61, 91, 93,
                         59, 39, 35, 44, 46, 47, 92, 32,
                         17, 18, 19, 20,  8,  3, 13,255,
                          9,200,201,255,255,255,255,255
};
uint8_t shiftchartable[64]={'a','b','c','d','e','f','g','h',
                            'i','j','k','l','m','n','o','p',
                            'q','r','s','t','u','v','w','x',
                            'y','z', 41, 33, 34,'�', 36, 37,
                             94, 38, 42, 40, 95, 43,123,125,
                             58, 64,126, 60, 62, 63,124, 32,
                             17, 18, 19, 20,  8,  3, 13,255,
                              9,200,240,255,255,255,255,255
};



/*** main() *******************************************************************/
int main(int argc, char** argv) 
{
    // MUST disable WDT before doing ANYTHING!!!
    wdt_reset();
    wdt_disable();

    TIMER1_Init();
    USART0_Init();

    sei(); 

    
    // port configuration
    //  out = 1, in = 0
    DDRA = 0b11111111;              // MSB = Display reset, bit 6 - 0 = Display data
    DDRB = 0b00000000;              // switch inputs
    DDRC = 0b11000011;              // Bit 7 = RX LED, bit 6 = CAPS LED, bit 1 = DISP_nWR, bit 0 = DISP_nEN
    DDRD = 0b11111110;              // bit 7,6,5 = KEYSCAN code, bit 4,3,2 = Display Character
   
    PORTA = 0b11111111;
    PORTC = 0b10000011;             // bottom right LED on
    PORTD = 0b00000000;
        
    //USART0_PutString("\r\nPC6502 Keybed alive!\r\n");
    
    
    PORTA = 0x00;           // reset on board display
    _delay_ms(100);  
    PORTA = 0xD0;

    _delay_ms(100);  
    UpdateDisplay();

    for(uint8_t t = 0; t<8; t++)    // fill display with spaces
    {
        dispchar[t] = ' ';
    }
    
    _delay_ms(1000);

    UpdateDisplay();

    
    //**** Stay a while, stay forever *****
    while(1)
    {
        // update caps LED
        if(CapsLock)
        {
            CAPSLED = 0;
        }
        else
        {
            CAPSLED = 1;
        }
            
            
        // key pressed?             
        if(KeyPress< 0xFF)
        {
            cli();
                
            uint8_t dataout = 255;

            // Need to remember that we use the AVR to selectr the column
            //      and then we read the data from the row.
            uint8_t temp = GetBitNum(KeyPress);             // sort which row we've read
            
            dataout = chartable[(8*temp)+KeyCol];      // fetch character from table
            
            // special keys these are refreshed every complete matrix read
            switch(dataout)
            {
                case(200):              // shift keys
                {
                    ShiftStatus = 1;
                    break;
                }
                case(201):
                {
                    CtrlStatus = 1;
                    break;
                }
                case(240):              // shift + CTRL
                {
                    if(CapsLock)
                    {
                        CapsLock = 0;
                    }
                    else
                    {
                        CapsLock = 1;
                        break;
                    }
                    break;
                }
                default:
                {
                    break;
                }
            }
            
            if(dataout < 128)
            {
                if(ShiftStatus && CapsLock)    // SHIFTED keyset
                {
                    dataout = shiftchartable[(8*temp)+KeyCol];      // fetch character from table
                    
//                    ShiftStatus = 0;
//                    CtrlStatus = 0;
    //                debouncecount = 0;                            // repeat breaks if you put this in
                }
                if(dataout != olddataout)  // Send Normal ASCII Characters
                {
                    USART0_Put(dataout);
                    olddataout = dataout;
                    debouncecount = 0;
                    if(dataout == 13)       // carriage return
                    {
                        USART0_Put(10);     // also send line feed
                    }
                }  
                if(dataout == '£')      // pound sign!
                {
                    USART0_Put(dataout);
                    olddataout = dataout;
                    debouncecount = 0;
                }
            }
            KeyPress = 0xFF;
            Sent = 0x01;

            sei();
        }
        // End of send data code
            
        
        // Data in?
        if(USART0_CheckChar())
        {   
            cli();
            uint8_t datain = USART0_GetChar();
            if((charpos > 7) && (datain !=0x08))    // check we didn't reach the end (ignore if it's delete key))
            {
                charpos = 7;
                dispchar[0] = dispchar[1];      // ok, it's ugly, but for now it works!
                dispchar[1] = dispchar[2];
                dispchar[2] = dispchar[3];
                dispchar[3] = dispchar[4];
                dispchar[4] = dispchar[5];
                dispchar[5] = dispchar[6];
                dispchar[6] = dispchar[7];
            }
            if((datain == 0x0A) || (datain == 0x0D))     // LF or CR
            {
                for(uint8_t t = 0; t<8; t++)
                {
                    dispchar[t] = ' ';
                }
                charpos = 0;
            }
            else if(datain == 0x08)         // Delete
            {
                charpos--;
                if(charpos <0)
                    charpos = 0;
                dispchar[charpos] = ' ';
            }
            else
            {
                dispchar[charpos] = datain;
                charpos++;                
            }
            UpdateDisplay();
            sei();
        }
        //      end of update display code    
        

    }       // end of while(1)
    return (0);
}





/*** Count the bit position ****************************************************/
uint8_t GetBitNum(uint8_t value)
{
    
    uint8_t lresult = 255;
    
    uint8_t lmask = 0b00000001;
    
    uint8_t lcount = 0;

    
    while(lcount < 8)
    {
        if(~value & lmask)            // bitwise compare of value and mask, do they match? i.e. is that bit set?
        {
            lresult = lcount;           // remember which bit is set
            lcount = 99;                // exit while
            break;                      // break if
        }
        else
        {
            lmask <<=1;
            lcount++;
        }
    }
    
    return lresult;
}


/*** Update Display ************************************************************/
void UpdateDisplay(void)
{
    cli();
    uint8_t t = 0;
    while(t <8)
    {
        PORTA = dispchar[t] | 0x80;
        PORTD = t << 2;
        _delay_ms(1);
        PORTC = 0b00000000 | (CAPSLED <<6);    // changed MSB from 1 to 0 to stop keyLEDs flickering
        _delay_ms(1);
        PORTC = 0b00000011 | (CAPSLED <<6);
        t++;
    }
    sei();
}


/*** USART0_Init() *************************************************************/
void USART0_Init(void)
{
 // Set the BAUD rate
 UBRR0H = UBRRH_VALUE;
 UBRR0L = UBRRL_VALUE;
 #if USE_2X     // USE_2X defined by setbaud.h based on inputs
 UCSR0A |= (1 << U2X0);
 #else
 UCSR0A &= ~(1 << U2X0);
 #endif

 // Set the Mode & Frame Parameters
 // Asynchronous, 8-data, No parity, 1 stop
 UCSR0C = (1<<USBS0)|(3<<UCSZ00);
 
 // Enable USART0 Transmitter and Receiver
 UCSR0B = (1 << TXEN0) | (1 << RXEN0);
}


/*** USART0_Put() **************************************************************/
void USART0_Put(uint8_t data)
{ 
 //Checking to see if USART TX buffer is empty for new data
 while(!(UCSR0A & (1<<UDRE0)));
 
 //Initiating transfer
 UDR0 = data;
}


/*** USART0_PutString() ********************************************************/
void USART0_PutString(char *ptr)
{ 
 while(*ptr)
 {   // Loop until end of string (*s = '\0')
  USART0_Put(*ptr++); // Send the character and point to the next one
 }
}


/*** USART0_CheckChar() ********************************************************/
uint8_t USART0_CheckChar(void)
{
   if(UCSR0A & (1<<RXC0))   // checking if USART RX data is available
   {  
       return 1;
   }
   else
   {
       return 0;
   }
}


/*** USART0_GetChar() **********************************************************/
char USART0_GetChar(void)
{ 
 char rxdata;
 
 if(UCSR0A & (1<<RXC0)){  // checking if USART RX data is available
  rxdata = UDR0;   // reading the received byte (clears RXC0)
  return rxdata;   // return the data
 }
 
 return 0x00;    // return NUL char ('/0') if no data available
}

/*** TIMER1_Init() *************************************************************/
void TIMER1_Init(void)
{ 
 // Set up Timer/Counter1
 TCCR1B |= (1 << WGM12);    // Configure timer 1 for CTC mode
 OCR1A = 250;               // 
                            
 TIMSK1 |= (1 << OCIE1A);   // Enable CTC interrupt
 TCCR1B |= ((1 << CS10) | (1 << CS11)); // Start Timer/Counter1 at F_CPU/64
}

/*** Interrupt Handler for TIMER1_COMPA Interrupt (Nesting Disabled) ***********/

ISR(TIMER1_COMPA_vect, ISR_BLOCK)
{
    if((PINB < 0xFF) && (Sent))
    {
        KeyPress = PINB;
        KeyCol = ColCount;
        ColInc = 0;             
    }
    else if(PINB == 0xFF)
    {
        ColInc = 1;
    }
    
    ColCount++;
    //ColCount += ColInc;       // this stops adjacent characters from going nuts, BUT also stops Shift from working
    
    if(ColCount > 7)
    {
        ColCount = 0;
    }

    debouncecount++;
    if(debouncecount > (30*8))          // sets repeat time.
    {
        olddataout = 255;  
        debouncecount = 0;
        ShiftStatus = 0;
        CtrlStatus = 0;
    }



    PORTD = ColCount << 5;
    
    // Timer1 CTC flag auto-cleared by hardware
}
