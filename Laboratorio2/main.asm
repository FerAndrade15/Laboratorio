//*******************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: María Andrade
// Proyecto: Laboratorio 2
// Archivo: Laboratorio2.asm
// Hardware: ATMEGA328P
// Created: 05/02/2024 21:09:31
//*******************************************************************;
// Encabezado -------------------------------------------------------
.include "M328PDEF.inc"
.cseg 
.org 0x00
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
//General Settings --------------------------------------------------
Setup:
	LDI R16, 0x0F				
	OUT DDRC, R16				;Display high nibble
	LDI R16, 0xFC	
	OUT DDRD, R16				;Display low nibble and 3bit counter
	LDI R16, 0x21				
	OUT DDRB, R16				;1bit counter and alarm**Equal counters
	LDI R16, 0x18				
	OUT PORTB, R16				;Pull-up settings
	CALL begin_timer
	LDI R21, 0x10				;DISPLAY_C and DISPLAY_D constant difference
	LDI ZH, HIGH(DISPLAY_C<<1)	;High byte from program memory table start
	LDI ZL, LOW(DISPLAY_C<<1)	;Low byte from program memory table start
	LPM R22, Z					;First value lecture
	OUT PORTC, R22				;Half of the display settings at 0
	ADD ZL, R21
	LPM R22, Z
	OUT PORTD, R22				;Half of the display settings at 0
	;Start the counters at 0
	CLR R18						
	CLR R20
//Main loop ---------------------------------------------------------
Loop:
	IN R19, PINB
	SBRS R19, PB4				;Increment button
	JMP greater
	SBRS R19, PB3				;Decrement button
	JMP lower
	IN R16, TIFR0		
	CPI R16, (1<<TOV0)			;Checking flag
	BRNE Loop
	LDI R16, 100				;Timer counter starting number
	OUT TCNT0, R16				;Timer edge counter
	SBI	TIFR0, TOV0				;Flag-off
	INC R17						;Cycle counter
	CPI R17, 100				;Max repetition count
	BRNE Loop
	CLR R17						;Clear 1s counter
	CPI R24, 1					;Check alarm's last cycle state
	BRNE completeloop
	CBI PORTB, PB5				;Alarm off
	CLR R24
completeloop:
	CALL binarycounter			
	JMP Loop
//Hex Counter  ------------------------------------------------------
display:
	LDI ZL, LOW(DISPLAY_C<<1)	;Low byte from program memory table start
	ADD ZL, R20					;Add direction of the number by the counter	
	LPM R22, Z						
	OUT PORTC, R22				;Display upper half output
	ADD ZL, R21
	LPM R22, Z					;Display lower half output
	CALL bitsettings			;Bits distribution on the ports 
final_display:
	JMP Loop					;Return to main loop
greater:
	delay:
		IN R16, TIFR0		
		CPI R16, (1<<TOV0)		;Checking flag
		BRNE delay
		LDI R16, 100			;Timer counter starting number
		OUT TCNT0, R16			;Timer edge counter
		SBI	TIFR0, TOV0			;Flag-off
		INC R17					;Cycle counter
		CPI R17, 100			;Max repetition count
		BRNE continue
		CLR R17					;In case R17 is equal to 100 during debounce
		CALL binarycounter		;Update binary counter
continue:
	SBIS PINB, PB4				;Skip if PB4 is high
	JMP greater					;Debounce loop
	CPI R20, 0x0F				;Max valid value for de counter
	BREQ final_display			;Return to main loop
	INC R20						;Increment hex counter
	JMP display					;All display settings
lower:
	delayL:
		IN R16, TIFR0		
		CPI R16, (1<<TOV0)		;Checking flag
		BRNE delayL
		LDI R16, 100			;Timer counter starting number
		OUT TCNT0, R16			;Timer edge counter
		SBI	TIFR0, TOV0			;Flag-off
		INC R17					;Cycle counter
		CPI R17, 100			;Max repetition count
		BRNE continueL			
		CLR R17					;In case R17 is equal to 100 during debounce
		CALL binarycounter		;Update binary counter
continueL:
	SBIS PINB, PB3				;Skip if PB3 is high
	JMP lower					;Debounce loop
	CPI R20, 0					;Min valid value for de counter
	BREQ final_display			;Return to main loop
	DEC R20						;Decrement hex counter
	JMP display					;All display settings
//Binary counter  ---------------------------------------------------
restart:
	CLR R18
	JMP bitsettings
binarycounter:					;Subroutine start
	CP R18, R20					;Compare binary and hex counters
	BREQ alarm					;If counters are equal
	CPI R18, 0x0F				;If Binary counter is the max valid value
	BREQ restart				;Subroutine to reset the seconds counter
	INC R18						;Increment the value if there's no need to reset
bitsettings:
	MOV R23, R18				;Generate a copy of binary counter
	SWAP R23					;Swap nibbles of the register
	LSL R23						;Load Shifter to the left * 1 bit
	ANDI R23, 0xE0				;R23 can only affect PD7, PD6 and PD5
	ADD R23, R22				;To keep display settings
	OUT PORTD, R23				;Output of the display and leds of the PORTD
	CPI R18, 0x08				;Most significant bit evaluation
	BRLO lastbitoff				
	SBI PORTB, PB0				;In case it must be on
	RET
lastbitoff:
	CBI PORTB, PB0				;In case it must be off
	RET
alarm:
	CLR R17						;Reset the cycle (timer counter)
	CLR R18						;Reset seconds counter
	SBR R24, 1					;Confirms the change for the main loop
	SBI PORTB, PB5				;Alarm on
	JMP bitsettings				;Ports' outputs settings
//Start Timer0  -----------------------------------------------------
begin_timer:
	LDI R16, 0x05				;Prescaler at 1024
	OUT TCCR0B, R16				;Register settings
	LDI R16, 100				;Timer counter starting number
	OUT TCNT0, R16				;Timer edge counter
	RET
//Display codification  ---------------------------------------------
.org 0x100
	DISPLAY_C:	.DB 7,1,11,11,13,14,14,3,15,15,15,12,6,9,14,14 
	DISPLAY_D:	.DB 28,4,24,12,4,12,28,4,28,12,20,28,24,28,24,16