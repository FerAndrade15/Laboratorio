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
.org (SRAM_START)
	settings_hours:		.byte 1
	settings_minutes:	.byte 1
	settings_seconds:	.byte 1
	settings_days:		.byte 1
	settings_month:		.byte 1
	settings_years:		.byte 1
.cseg 
// Interrupt Vectors ------------------------------------------------
.org 0x00						;Reset
	JMP START
.org 0x001C						;Compare Match A
	JMP TIMER0_COMPA
// Reset --------------------------------------------------------- //
START:
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
//Functional Registers ----------------------------------------------
.def display= R13
.def sel_dis= R14
.def hours	= R18
.def minutes= R19
.def seconds= R20
.def five_ms= R21
.def day	= R22
.def month	= R23
.def year	= R24
.def delmode= R25
//General Settings --------------------------------------------------
Setup:
	LDI R16, 0x05
	OUT TCCR0B, R16				;Clock selected >> Prescaler at 1024
	LDI R16, 0x02	
	OUT TCCR0A, R16				;Timer mode >> CTC Mode
	STS TIMSK0, R16				;Enable Interrupt Mask for Compare Match A
	LDI R16, 0x4E
	OUT OCR0A, R16				;Max for CTC Mode >> Generates interrrupt
	SEI							;Enable all interruptions
	//Inputs and outputs
	CLR R16
	STS	UCSR0B, R16				;Unable RX y TX for communication
	LDI R16, 0x3F
	OUT DDRC, R16				;Set all available PortC as output
	LDI R16, 0xFF
	OUT DDRD, R16				;Set all PortD as output
	//Setting initial values
	LDI five_ms, 199
	LDI seconds, 0x59
	LDI minutes, 0x59
	LDI hours, 0x23
	LDI day, 0x28
	LDI month, 2
	LDI year, 0x99
	LDI delmode, 0x80
//Main loop ---------------------------------------------------------
Loop:
//Settings of Mode
	SBRS delmode, 7				;Check change of display
	JMP Loop
	MOV R16, delmode
	CBR R16, 0xF0				;Mode code
	MOV R17, delmode
	SWAP R17
	CBR R17, 0xF8				;Display selector
	LDI ZH, HIGH(modejumps<<1)	;Redirect to mode jump's table
	LDI ZL, LOW(modejumps<<1)
	ADD ZL, R16
	LPM R30, Z
	CLR R31
	IJMP
//Display assign of selector and value
display_settings:
	LDI ZH, HIGH(selector<<1)	;Redirect to selector's values table
	LDI ZL, LOW(selector<<1)
	ADD ZL, R17
	LPM sel_dis, Z
	OUT PORTC, sel_dis
	OUT PORTD, display
	MOV R16, delmode
	CBR R16, 0xF0				;Mode code
	CPI R17, 5
	BREQ reset
	INC R17
	SWAP R17
	JMP delay_display_mode
reset:
	CLR R17
delay_display_mode:
	ADD R16, R17
	MOV delmode, R16
	JMP Loop
//Modes
MST:							;Mode >> Show Time
	CPI R17, 2
	BRLO hours_settings
	BREQ minutes1
	CPI R17, 3
	BREQ minutes0
	MOV R16, seconds
	SBRS R17, 0
	JMP seconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D2
	JMP display_settings
	hours_settings:
		MOV R16, hours
		SBRS R17, 0
		SWAP R16
		CBR R16, 0xF0
		CALL D0_D1
		JMP display_settings
	minutes1:
		MOV R16, minutes
		SWAP R16
		CBR R16, 0xF0
		CALL D2
		JMP display_settings
	minutes0:
		MOV R16, minutes
		CBR R16, 0xF0
		CALL D3
		JMP display_settings	
	seconds0:
		CBR R16, 0xF0
		CALL D3
		JMP display_settings
SDM:
	JMP Loop
ATM:
	JMP Loop
ADM:
	JMP Loop
TS:
	JMP Loop
DSM:
	JMP Loop
ATSM:
	JMP Loop
ADSM:
	JMP Loop
AAM:
	JMP Loop
//Subroutines
D0_D1:
	LDI ZH, HIGH(show2nm<<1)	;Redirect to displayed value
	LDI ZL, LOW(show2nm<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D2:
	LDI ZH, HIGH(showupdown<<1)	;Redirect to displayed value
	LDI ZL, LOW(showupdown<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D3:
	LDI ZH, HIGH(shownormal<<1)	;Redirect to displayed value
	LDI ZL, LOW(shownormal<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D4_D5:
	LDI ZH, HIGH(show2updown<<1)	;Redirect to displayed value
	LDI ZL, LOW(show2updown<<1)
	ADD ZL, R16
	LPM display, Z
	RET	
//CTC ------------------------------------------------------------ //
TIMER0_COMPA:	
	PUSH R16					;Save initial conditions
	PUSH R17
	LDS R16, SREG
	PUSH R16
	INC five_ms					;Time counter increment
	SBR delmode, 0x80			;5ms delay
	CPI five_ms, 200			;Five_ms equals 1s
	BRNE completeinterrupt
	CLR five_ms					;Restart five_ms
	MOV R16, seconds
	CALL time_inc
	MOV seconds, R16
	CPI seconds, 0x60			;Seconds completes 1 min
	BRNE completeinterrupt
	CLR seconds					;Restart seconds
	MOV R16, minutes
	CALL time_inc
	MOV minutes, R16
	CPI minutes, 0x60			;Seconds completes 1 hour
	BRNE completeinterrupt
	CLR minutes					;Restart minutes
	MOV R16, hours
	CALL time_inc
	MOV hours, R16
	CPI hours, 0x24				;Day complete
	BRNE completeinterrupt
	CLR hours					;Restart hours
	LDI ZH, HIGH(days_month<<1)	;Redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	ADD ZL, month				;Correct to the actual month
	LPM R16, Z					;Max day of month
	CPI month, 2
	BRNE checkmaxofmonth
	MOV R17, year
	CBR R17, 0xFC				;Conserve less 2 significant bits
	CPI R17, 0					;Check if the number is multiple of four
	BRNE checkmaxofmonth
	LDI R16, 41					;Max of february/leap_year * 0x29
checkmaxofmonth:
	CP R16, day					;Compare day to max of each month
	BREQ incrementmonth
	MOV R16, day
	CALL time_inc
	MOV day, R16				;Day increment
	JMP completeinterrupt
incrementmonth:
	LDI day, 1					;Start of month
	CPI month, 12
	BREQ incrementyear
	INC month
	JMP completeinterrupt
incrementyear:
	LDI month, 1				;Start of the year
	MOV R16, year
	CALL time_inc
	MOV year, R16
	CPI year, 0xA0				;Max of 2 digits years shown
	BRNE completeinterrupt
	CLR year
completeinterrupt:
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
	RETI
//Timer incrementers
time_inc:
	MOV R17, R16
	CBR R17, 0xF0
	CPI R17, 9
	BRNE normal_increment
	SWAP R16
	CBR R16, 0xF0
	INC R16
	SWAP R16
	RET
normal_increment:
	INC R16
	RET
// Data Tables --------------------------------------------------- //
.org 0x100
	days_month:	.DB 0,49,40,49,48,49,48,49,49,48,49,48,49,0
	modejumps:	.DB MST,SDM,ATM,ADM,TS,DSM,ATSM,ADSM,AAM,0
	selector:	.DB 1,2,4,8,16,32
	show2nm:	.DB 235,129,218,217,177,121,123,193,251,249
	showupdown:	.DB 238,40,205,109,43,103,231,44,239,111
	shownormal:	.DB 238,130,220,214,178,118,126,194,254,246
	show2updown:.DB 190,24,173,157,27,151,183,28,191,159
