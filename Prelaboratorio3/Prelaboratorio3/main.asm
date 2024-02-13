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
	JMP Start		//Reset Vector
.org 0x0006
	JMP INT_PINB
Start:
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R18, HIGH(RAMEND)
OUT SPH, R18
//General Settings ----------------------------------------------------
Setup:
	SEI							;Enable Global Interruptions
	LDI R16, 0x04
	STS CLKPR, R16				;Prescaler clk --> 1MHz
	LDI R16, 1
	OUT DDRB, R16				;Input settings and led output
	LDI R16, 0xE0	
	OUT DDRD, R16				;Output 3bit counter
	LDI R16, 0x18				
	OUT PORTB, R16				;Pull-up settings
	LDI R16, 1
	STS PCICR, R16				;Pin Change Interrupt Control Register
	LDI R16, 0x18	
	STS PCMSK0, R16				;Pin Change Mask Register * PB4 & PB5
	CLR R18						;Binary Counter
//Main loop ---------------------------------------------------------
Loop:
	CPI R17, 0
	BRNE bitsettings
	RJMP Loop
//Binary counter ----------------------------------------------------
bitsettings:
	MOV R18, R17				;Generate a copy of binary counter
	SWAP R18					;Swap nibbles of the register
	LSL R18						;Load Shifter to the left * 1 bit
	ANDI R18, 0xE0				;R23 can only affect PD7, PD6 and PD5
	OUT PORTD, R18				;Leds of the PORTD
	CPI R17, 0x08				;Most significant bit evaluation
	BRLO lastbitoff				
	SBI PORTB, PB0				;In case it must be on
	JMP Loop
lastbitoff:
	CBI PORTB, PB0				;In case it must be off
	JMP Loop
//Pin Change Interruption Subroutine --------------------------------
INT_PINB:
	IN R16, SREG
	PUSH R16	
	IN R20, PINB
	SBRS R20, PB4
	INC R17	
	SBRS R20, PB3
	DEC R17
	ANDI R17, 0x0F
CHECK:
	IN R20, PINB
	SBRS R20, PB4
	RJMP CHECK
	SBRS R20, PB3
	RJMP CHECK
	SBI PCIFR, 0 
	POP R16
	STS SREG, R16
	RETI