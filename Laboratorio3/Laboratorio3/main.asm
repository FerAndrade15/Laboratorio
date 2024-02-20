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
	LDI R16, (1 << CS02) | (1 << CS00)
	OUT TCCR0B, R16						;Prescaler at 1024
	LDI R16, 178
	OUT TCNT0, R16						;Start Value
	LDI R16, (1 << TOIE0)
	STS TIMSK0, R16						;Enable Overflow Interruption
	LDI R16, 7
	OUT DDRB, R16						;Leds (2) inferiores
	LDI R16, 1
	STS PCICR, R16						;Pin Change Interrupt Control Register
	LDI R16, 24	
	STS PCMSK0, R16						;Pin Change Mask Register * PB3 & PB4
	LDI R16, 0x0F
	OUT DDRC, R16						;Display segmentos superiores
	LDI R16, 0xFC	
	OUT DDRD, R16						;Display segmentos inferiores y leds (2) superiores 
	LDI R16, 24
	OUT PORTB, R16						;Pull-up settings
	LDI ZH, HIGH(DISPLAY_C<<1)			;High byte from program memory
	LDI ZL, LOW(DISPLAY_C<<1)
	LPM output_display, Z
	OUT PORTC, output_display
	ADIW ZH:ZL, 16
	LPM output_display, Z
	OUT PORTD, output_display
	CLR binary_counter
	CLR seconds_counter
	CLR dec_sec_counter
//Main loop ---------------------------------------------------------
Loop:
	BRBS 2, change_display
counters:
	CPI fivems_counter, 100
	BRNE Loop
	LDI R16, 1
	STS PCICR, R16						;Pin Change Interrupt Control Register
	CLR fivems_counter
	INC halfminute
	CPI halfminute, 2
	BRNE counters
	CLR fivems_counter
	CLR halfminute
	CPI seconds_counter, 0x09
	BREQ reset1
	INC seconds_counter
assign_display1:
	SBI PORTB, PB1
	CBI PORTB, PB2
	LDI ZL, LOW(DISPLAY_C<<1)		;Low byte from program memory table start
	ADD ZL, seconds_counter
	LPM output_display, Z
	OUT PORTC, output_display
	ADIW ZH:ZL, 0x10
	LPM output_display, Z
	OUT PORTD, output_display
	JMP counters
assign_display2:
	CBI PORTB, PB1
	SBI PORTB, PB2
	LDI ZL, LOW(DISPLAY_C<<1)		;Low byte from program memory table start
	ADD ZL, dec_sec_counter
	LPM output_display, Z
	OUT PORTC, output_display
	ADIW ZH:ZL, 0x10
	LPM output_display, Z
	OUT PORTD, output_display
	LDI R16, 1
	STS PCICR, R16						;Pin Change Interrupt Control Register
	JMP counters
reset1:
	CLR seconds_counter
	INC dec_sec_counter
	CPI dec_sec_counter, 0x06
	BREQ reset2
	JMP Loop
reset2:
	CLR dec_sec_counter
	JMP Loop
change_display:	
	CLN
	SBRC fivems_counter, 1
	JMP assign_display1
	JMP assign_display2
//Pin Change Interruption Subroutine --------------------------------
INT_PINB:
	IN R24, PINB
	SBRS R24, PB4
	JMP incrementar
	SBRS R24, PB3
	JMP decrementar
incrementar:
	CPI binary_counter, 0x0F

	INC binary_counter
decrementar
	DEC binary_counter
	LDI R16, 0
	STS PCICR, R16						;Pin Change Interrupt Control Register
	STS SREG, R16
	RETI
//Timer Interruption Subroutine -------------------------------------
INT_TIM0_OVF:
	SEN
	LDS R16, SREG
	INC fivems_counter
	LDI R16, 178
	OUT TCNT0, R16
	STS SREG, R16
	RETI
//Display codification  ---------------------------------------------
.org 0x100
	DISPLAY_C:	.DB 7,1,11,11,13,14,14,3,15,15,15,12,6,9,14,14 
	DISPLAY_D:	.DB 28,4,24,12,4,12,28,4,28,12,20,28,24,28,24,16