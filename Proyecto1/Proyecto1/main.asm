//*******************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: María Andrade
// Proyecto: Reloj
// Archivo: Proyecto1.asm
// Hardware: ATMEGA328P
// Created: 21/02/2024 8:06:46
//*******************************************************************
// Encabezado -------------------------------------------------------
.include "M328PDEF.inc"
.dseg
//Settings registers ------------------------------------------------
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
	JMP TIMER0_COMPA
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
.def five_ms= R21
.def day	= R22
.def month	= R23
.def year	= R24
.def delmode= R25
.def btn_del= R26
//General Settings --------------------------------------------------
Setup:
	//Timer0 Settings
	LDI R16, 0x05
	OUT TCCR0B, R16				;Clock selected >> Prescaler at 1024
	LDI R16, 0x02	
	OUT TCCR0A, R16				;Timer mode >> CTC Mode
	STS TIMSK0, R16				;Enable Interrupt Mask for Compare Match A
	LDI R16, 0x4E
	OUT OCR0A, R16				;Max for CTC Mode >> Generates interrrupt
	//Pinchange Settings
	LDI R16, 1
	STS PCICR, R16				;Enable Pin Change Interrupt on PINB 
	LDI R16, 28	
	STS PCMSK0, R16				;Enable PB2, PB3 & PB4 on Pin Change Mask Register
	//Setting initial values
	LDI five_ms, 199
	LDI seconds, 59
	LDI minutes, 59
	LDI hours, 23
	LDI day, 30
	LDI month, 4
	LDI year, 24
	CLR mode
	//Enable all interruptions
	SEI
//Main loop ---------------------------------------------------------
Loop:
	//5ms starter
	SBRS delmode, 7				;confirms 5ms delay to change display
	JMP Loop
continue_diplay:					
	MOV R16, delmode			;copy register display selector
	SWAP R16
	CBR R16, 0xF8				;3 bits of display selector				
complete_loop:
	JMP Loop
// CTC ----------------------------------------------------------- //
TIMER0_COMPA:	
	PUSH R16					;save registers and sreg from main loop
	PUSH R17
	IN R16, SREG
	PUSH R16
	INC five_ms
	STS R16, PCMSK0				;PCMSK0 clear after pressing buttons
	CPI R16, 0
	BRNE continue_timer
	INC btn_del					;20ms counter
	CPI btn_del, 3
	BRNE continue_timer
	CLR btn_del					;reset buttons delay
	LDI R16, 28	
	STS PCMSK0, R16				;Enable PB2, PB3 & PB4 on Pin Change Mask Register
continue_timer:
	SBR delmode, 0x80			;b1xxx_xxxx to show displays
	CPI five_ms, 200			;five_ms equals 1s
	BRNE completeinterrupt
	CLR five_ms					;restart five_ms
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
	LPM R16, Z					;max day of month
	CPI month, 2
	BRNE checkmaxofmonth
	MOV R17, year
	CBR R17, 0xFC				;conserve less 2 significant bits	
	CPI R17, 0					;check if the number is multiple of four
	BRNE checkmaxofmonth
	LDI R16, 29					;max of february/leap_year
checkmaxofmonth:
	CP R16, day					;check if the actual day is the max of the month
	BREQ incrementmonth			;change of month
	INC day		
	JMP completeinterrupt
incrementmonth:
	LDI day, 1					;start of month
	INC month
	CPI month, 13				;restart of the year
	BRNE completeinterrupt
	LDI month, 1
	INC year					;increment years
completeinterrupt:
	POP R16						;restore registers and sreg from main loop
	OUT SREG, R16
	POP R17
	POP R16
	RETI
//Info Tables -------------------------------------------------------
.org 0x100
    days_month:			.DB 0,31,28,31,30,31,30,31,31,30,31,30,31,0			;14 bytes