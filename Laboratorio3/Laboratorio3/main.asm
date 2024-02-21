//*******************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: María Andrade
// Proyecto: Laboratorio 3
// Archivo: Laboratorio3.asm
// Hardware: ATMEGA328P
// Created: 12/02/2024 10:30:35
//*******************************************************************
// Encabezado -------------------------------------------------------
.include "M328PDEF.inc"
.cseg 
.org 0x00
	JMP START			//Reset Vector
.org 0x0006
	JMP INT_PINB		//Pin Change Direction
.org 0x0020
	JMP INT_TIM0_OVF	//Timer0 Subroutine
START:
	.def binary_counter  =	R17
	.def fivems_counter  =	R18
	.def halfminute		 =	R19
	.def output_display  =	R20
	.def seconds_counter =	R21
	.def dec_sec_counter =	R22

// Stack Pointer ----------------------------------------------------
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R18, HIGH(RAMEND)
	OUT SPH, R18

//General Settings ----------------------------------------------------
Setup:
	SEI									;Enable Global Interruptions
	//TIMER0 SETTINGS
		LDI R16, (1 << CS02) | (1 << CS00)
		OUT TCCR0B, R16						;Prescaler at 1024
		LDI R16, 178
		OUT TCNT0, R16						;Start Counter Value
		LDI R16, (1 << TOIE0)
		STS TIMSK0, R16						;Enable Overflow Interruption
	//PINCHANGE SETTINGS
		LDI R16, 1
		STS PCICR, R16						;Pin Change Interrupt Control Register
		LDI R16, 24	
		STS PCMSK0, R16						;Pin Change Mask Register * PB3 & PB4
	//OUTPUT SETTINGS
		LDI R16, 7
		OUT DDRB, R16						;Leds (2) inferiores
		LDI R16, 0x0F
		OUT DDRC, R16						;Display segmentos superiores
		LDI R16, 0xFC	
		OUT DDRD, R16						;Display segmentos inferiores y leds (2) superiores 
		LDI R16, 24
		OUT PORTB, R16						;Pull-up settings
	//START DISPLAYS AT 0
		LDI ZH, HIGH(DISPLAY_C<<1)			;High byte from program memory
		LDI ZL, LOW(DISPLAY_C<<1)			;Low byte from program memory
		LPM output_display, Z				;Table information
		OUT PORTC, output_display			;Display table code
		ADIW ZH:ZL, 16						;Change display code (Second line)
		LPM output_display, Z				;Table information
		OUT PORTD, output_display			;Display table code
	//Reset counters
		CLR binary_counter
		CLR seconds_counter
		CLR dec_sec_counter
		CLR R23

//Main loop ---------------------------------------------------------
Loop:
	BRBS 2, change_display			;Checks Nbit on SREG to confirm 5ms has pass
	counters:				
		CPI fivems_counter, 100			;Half-minute check
		BRNE Loop
		CLR fivems_counter				;Reset half-minute
		INC halfminute					;Count half-minute
		CPI halfminute, 2				
		BRNE counters					
		CLR fivems_counter				;Reset both counters
		CLR halfminute
		CPI seconds_counter, 0x09		;Seconds (units) max
		BREQ reset1						;Reset of seconds units
		INC seconds_counter				
		LDI R16, 24						
		STS PCMSK0, R16					;Enable Pin Change Mask Register on PB3 & PB4

	assign_display1:
	//Select display - Multiplexer
		SBI PORTB, PB1					
		CBI PORTB, PB2
	//Assign display output
		LDI ZL, LOW(DISPLAY_C<<1)		;Low byte from program memory table start
		ADD ZL, seconds_counter			;Position of the counter
		LPM output_display, Z
		OUT PORTC, output_display		;Display value
		ADIW ZH:ZL, 0x10				;Distance between lines
		LPM output_display, Z			;Table value
		ADD output_display, R23			;Considering the binary counter on the same port
		OUT PORTD, output_display		;Rewrite all port
		JMP counters

	assign_display2:	
	//Select display - Multiplexer
		CBI PORTB, PB1
		SBI PORTB, PB2
	//Assign display output
		LDI ZL, LOW(DISPLAY_C<<1)		;Low byte from program memory table start
		ADD ZL, dec_sec_counter			;Position of the counter
		LPM output_display, Z
		OUT PORTC, output_display		;Display value
		ADIW ZH:ZL, 0x10				;Distance between lines
		LPM output_display, Z			;Table value
		ADD output_display, R23			;Considering the binary counter on the same port
		OUT PORTD, output_display		;Rewrite all port
		JMP counters

	//Reset the counters when they are at max values
	reset1:
		CLR seconds_counter				;Set the units of seconds 0
		INC dec_sec_counter				;Start counting tens of seconds
		CPI dec_sec_counter, 0x06
		BREQ reset2						;Reset at max
		JMP Loop
	reset2:
		CLR dec_sec_counter				;Set the tens of seconds 0
		JMP Loop

	//SREG Nbit enables the change of displays
	change_display:	
		CLN								;Clear SREG Nbit
		SBRC fivems_counter, 1			
		JMP assign_display1				;5ms counter last bit clear (0)
		JMP assign_display2				;5ms counter last bit set	(1)

//Pin Change Interruption Subroutine --------------------------------
INT_PINB:
	CLR R16
	STS PCMSK0, R16						;Disable Pin Change Mask Register: PB3 & PB4
	LDS R16, SREG						;Save SREG
	IN R24, PINB
	SBRS R24, PB4
	JMP incrementar						;Botton1
	SBRS R24, PB3
	JMP decrementar						;Botton2
	incrementar:
		CPI binary_counter, 0x0F		;Max value
		BREQ close			
		INC binary_counter				;Increment by botton1
		JMP close
	decrementar:
		CPI binary_counter, 0			;Min value
		BREQ close
		DEC binary_counter				;Decremet by botton2
	close:
		CPI binary_counter, 8			;Detect state of high bit of the nibble
		BRSH onlastbit
		CBI PORTB, PB0					;Clear high bit (b4)
		JMP final
	onlastbit:
		SBI PORTB, PB0					;Set high bit (b4)
	final:
		MOV R23, binary_counter			;Generate a copy of binary counter
		SWAP R23						;Swap nibbles of the register
		LSL R23							;Load Shifter to the left * 1 bit
		ANDI R23, 0xE0					;Eliminate aditional bits to prevent errors
		SBI PCIFR, PD0					;Reset flag manually
		STS SREG, R16					;Rewrite the SREG from before the interrupt
	RETI

//Timer Interruption Subroutine -------------------------------------
INT_TIM0_OVF:
	SEN									;Set SREG Nbit
	LDS R16, SREG						;Save SREG
	INC fivems_counter					;Timer counter
	LDI R16, 178
	OUT TCNT0, R16						;Start value of timer0 counter
	STS SREG, R16						;Return original SREG
	RETI
//Display codification  ---------------------------------------------
.org 0x100	
	;PORTC[B=PC0|A=PC1|F=PC2|G=PC3]			PORTD[C=PD2|D=PD3|E=PD4]
	DISPLAY_C:	.DB 7,1,11,11,13,14,14,3,15,15,15,12,6,9,14,14 
	DISPLAY_D:	.DB 28,4,24,12,4,12,28,4,28,12,20,28,24,28,24,16