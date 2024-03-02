//********************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: María Andrade
// Proyecto: Reloj
// Archivo: Proyecto1.asm
// Hardware: ATMEGA328P
// Created: 21/02/2024 8:06:46
//********************************************
// Encabezado -------------------------------------------------------
.include "M328PDEF.inc"

.dseg
.org SRAM_START
	settings_hours:		.byte 1
	settings_minutes:	.byte 1
	settings_seconds:	.byte 1
	settings_days:		.byte 1
	settings_month:		.byte 1
	settings_years:		.byte 1

.cseg 
// Interrupt Vectors ------------------------------------------------
.org 0x00					;Reset
	JMP START
.org 0x001C					;Compare Match A
	JMP START
	//JMP TIMER0_COMPA

// Reset --------------------------------------------------------- //
START:
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

//Functional Registers ----------------------------------------------
.def hours	= R18
.def minutes= R19
.def seconds= R20
.def ten_ms	= R21
.def day	= R22
.def month	= R23
.def year	= R24

//General Settings --------------------------------------------------
Setup:
	LDI R16, 0x05
	OUT TCCR0B, R16				;Clock selected >> Prescaler at 1024
	LDI R16, 0x02	
	OUT TCCR0A, R16				;Timer mode >> CTC Mode
	STS TIMSK0, R16				;Enable Interrupt Mask for Compare Match A
	LDI R16, 0x9C
	OUT OCR0A, R16				;Max for CTC Mode >> Generates interrrupt
	SEI							;Enable all interruptions

	//Setting initial values
	LDI ten_ms, 99
	LDI seconds, 59
	LDI minutes, 59
	LDI hours, 23
	LDI day, 1
	LDI month, 2
	LDI year, 24

//Main loop ---------------------------------------------------------
Loop:
// CTC ----------------------------------------------------------- //
//TIMER0_COMPA:	
	INC ten_ms
	CPI ten_ms, 100				;ten_ms equals 1s
	BRNE completeinterrupt
	CLR ten_ms					;restart ten_ms
	INC seconds
	CPI seconds, 60				;seconds equals 1m
	BRNE completeinterrupt
	CLR seconds					;restart seconds
	INC minutes
	CPI minutes, 60				;minutes equals 1h
	BRNE completeinterrupt
	CLR minutes					;restart minutes
	INC hours
	CPI hours, 24				;day complete
	BRNE completeinterrupt
	CLR hours					;restart hours
	LDI ZH, HIGH(days_month<<1)	;redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	ADD ZL, month				;correct to the actual month
	LD R16, Z					;max day of month
	CPI month, 2
	BRNE checkmaxofmonth
	MOV R17, year
	CBR R17, 0xFC				;conserve less 2 significant bits
	CPI R17, 0					;check if the number is multiple of four
	BRNE checkmaxofmonth
	LDI R16, 29					;max of february/leap_year
checkmaxofmonth:
	CP R16, day
	BREQ incrementmonth
	INC day
	JMP completeinterrupt

completeinterrupt:
	SBRC ten_ms, PB0
	JMP Loop
	//Display
	JMP Loop
	//RETI
.org 0x100
    days_month:			.DB 0,31,28,31,30,31,30,31,31,30,31,30,31,0			;14 bytes
	//ncode_numbers:		.DB 252,96,218,242,102,182,190,224,254,246			;10 bytes
	//ucode_numbers:		.DB 252,12,218,158,46,246,28,254,190				;10 bytes