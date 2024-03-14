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
.cseg 
// Interrupt Vectors ------------------------------------------------
.org 0x00						;Reset
	JMP START
.org 0x0006						;Pin Change Interrupt Request 0
	JMP PCINT0_INT
.org 0x0016						;Compare Match A Timer1
	JMP TIMER1_COMPA
.org 0x001C						;Compare Match A Timer0
	JMP TIMER0_COMPA
// Reset --------------------------------------------------------- //
START:
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
//Functional Registers ----------------------------------------------
.def ahours	= R1
.def amins	= R2
.def asecs	= R3
.def aday	= R4
.def amonth	= R5
.def ayear	= R6
.def shours	= R7
.def smins	= R8
.def ssecs	= R9
.def sdays	= R10
.def smonth	= R11
.def syear	= R12
.def delay	= R13
.def display= R14
.def movdsl = R15
.def hours	= R18
.def minutes= R19
.def seconds= R20
.def day	= R21
.def month	= R22
.def year	= R23
.def mode	= R24
.def dissel = R25
//General Settings --------------------------------------------------
Setup:
	//PinChange
	LDI R16, (1<<PCIE0)
	STS PCICR, R16				;Enable Pin Change Interrupt for PORTB
	LDI R16, (1<<PCINT4)|(1<<PCINT3)|(1<<PCINT2)
	STS PCMSK0, R16				;Enable Pin Change on PB4, PB3 and PB2
	//Timer0
	LDI R16, (1<<OCIE0A)	
	STS TIMSK0, R16				;Enable Interrupt Mask for Compare Match A Timer0
	OUT TCCR0A, R16				;Timer0 mode >> CTC Mode
	LDI R16, 0x27
	OUT OCR0A, R16				;Max for CTC Mode Timer0 >> Generates interrrupt0
	LDI R16, (1<<CS02)|(1<<CS00)
	OUT TCCR0B, R16				;Timer0 clock selected >> Prescaler at 1024
	//Timer1
	LDI R16, (1<<OCIE1A)	
	STS TIMSK1, R16				;Enable Interrupt Mask for Compare Match A Timer1
	LDI R16, 0x3D
	STS OCR1AH, R16				;Max for CTC Mode Low Timer1 >> Generates interrrupt1
	LDI R16, 0x09 
	STS OCR1AL, R16				;Max for CTC Mode High Timer1 >> Generates interrrupt1
	CLR R16
	STS TCCR1A, R16				;Timer1 mode >> CTC Mode
	LDI R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
	STS TCCR1B, R16				;Timer1 Prescaler at 1024 and CTC Settings
	SEI							;Enable all interruptions
	//Inputs and outputs
	CLR R16
	STS	UCSR0B, R16				;Unable RX y TX for communication
	LDI R16, 0x3F
	OUT DDRC, R16				;Set all available PortC as output
	LDI R16, 0xFF
	OUT DDRD, R16				;Set all PortD as output
	LDI R16, 0x23
	OUT DDRB, R16				;Set as outputs PB0&PB1&PB5 for led mode
	LDI R16, 0x1C					
	OUT PORTB, R16				;Buttons pull-ups			
	//Setting initial values
	LDI seconds, 0x50
	LDI minutes, 0x59
	LDI hours, 0x23
	LDI day, 0x28
	LDI month, 2
	LDI year, 0x24
	LDI dissel, 0x08
	CLR R16
	MOV ahours, R16
	MOV amins, R16
	MOV asecs, R16
	LDI R16, 0x29
	MOV aday, R16
	LDI R16, 5
	MOV amonth, R16
	LDI R16, 24
	MOV ayear, R16
	LDI R16, 1
	MOV movdsl, R16
//Main loop ---------------------------------------------------------
Loop:
//Settings of Mode
	SBRS dissel, 3				;Check change of display
	JMP Loop
	CBR dissel, 0xF8			;Display selector
	LDI ZH, HIGH(modejumps<<1)	;Redirect to mode jump's table
	LDI ZL, LOW(modejumps<<1)
	ADD ZL, mode
	LPM R30, Z
	CPI mode, 4
	BRGE doublebyte
	CLR R31
	IJMP
doublebyte:
	LDI R31, 1
	IJMP
//Display assign of selector and value
display_settings:
	LDI ZH, HIGH(selector<<1)	;Redirect to selector's values table
	LDI ZL, LOW(selector<<1)
	ADD ZL, dissel
	LPM R16, Z
	OUT PORTC, R16
	OUT PORTD, display		
	JMP completedisplay
completedisplay:
	CPI dissel, 5
	BREQ reset
	INC dissel
	JMP Loop
reset:
	CLR dissel
	JMP Loop
//Modes
MST:							;Mode >> Show Time
	SBI PORTB, PB0
	CPI dissel, 2
	BRLO hours_settings
	BREQ minutes1
	CPI dissel, 3
	BREQ minutes0
	MOV R16, seconds
	SBRC dissel, 0
	JMP seconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	hours_settings:
		MOV R16, hours
		CALL D0_D1
		JMP display_settings
	minutes1:
		MOV R16, seconds
		CALL D3
		JMP display_settings
	minutes0:
		MOV R16, seconds
		CALL D2
		JMP display_settings	
	seconds0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
SDM:							;Mode >> Show Date
	SBI PORTB, PB1
	CPI dissel, 2
	BRLO days_settings
	BREQ month1
	CPI dissel, 3
	BREQ month0
	MOV R16, year
	SBRC dissel, 0
	JMP year0
	//year1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	days_settings:
		MOV R16, day
		CALL D0_D1
		JMP display_settings
	month1:
		MOV R16, month
		CALL D2
		JMP display_settings
	month0:
		MOV R16, month
		CALL D3
		JMP display_settings	
	year0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
ATM:							;Mode >> Show Alarm Time
	SBI PORTB, PB5
	CPI dissel, 2
	BRLO ahours_settings
	BREQ amins1
	CPI dissel, 3
	BREQ amins0
	MOV R16, asecs
	SBRC dissel, 0
	JMP aseconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	ahours_settings:
		MOV R16, ahours
		CALL D0_D1
		JMP display_settings
	amins1:
		MOV R16, amins
		CALL D2
		JMP display_settings
	amins0:
		MOV R16, amins
		CALL D3
		JMP display_settings	
	aseconds0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
ADM:							;Mode >> Show Alarm Date
	SBI PORTB, PB5
	CPI dissel, 2
	BRLO adays_settings
	BREQ amonth1
	CPI dissel, 3
	BREQ amonth0
	MOV R16, ayear
	SBRC dissel, 0
	JMP ayear0
	//year1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	adays_settings:
		MOV R16, aday
		CALL D0_D1
		JMP display_settings
	amonth1:
		MOV R16, amonth
		CALL D2
		JMP display_settings
	amonth0:
		MOV R16, amonth
		CALL D3
		JMP display_settings	
	ayear0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
TS:								;Mode >> Time Settings
	CPI dissel, 2
	BRLO shours_settings
	BREQ sminutes1
	CPI dissel, 3
	BREQ sminutes0
	MOV R16, ssecs
	SBRC dissel, 0
	JMP sseconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	shours_settings:
		MOV R16, shours
		CALL D0_D1
		JMP display_settings
	sminutes1:
		MOV R16, smins
		CALL D2
		JMP display_settings
	sminutes0:
		MOV R16, smins
		CALL D3
		JMP display_settings	
	sseconds0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
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
	SBRS dissel, 0
	SWAP R16
	CBR R16, 0xF0
	LDI ZH, HIGH(show2nm<<1)	;Redirect to displayed value
	LDI ZL, LOW(show2nm<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D2:
	SWAP R16
	CBR R16, 0xF0
	LDI ZH, HIGH(showupdown<<1)	;Redirect to displayed value
	LDI ZL, LOW(showupdown<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D3:
	CBR R16, 0xF0
	LDI ZH, HIGH(shownormal<<1)	;Redirect to displayed value
	LDI ZL, LOW(shownormal<<1)
	ADD ZL, R16
	LPM display, Z
	RET
D4_D5:
	LDI ZH, HIGH(show2updown<<1);Redirect to displayed value
	LDI ZL, LOW(show2updown<<1)
	ADD ZL, R16
	LPM display, Z
	RET	
//BUTTONS PIN CHANGE ---------------------------------------------- //
PCINT0_INT:
	PUSH R16					;Save initial conditions
	PUSH R17
	LDS R16, SREG
	PUSH R16
	IN R16, PINB				
	CBR R16, 0xE3
	CPI R16, 0x1C
	BREQ completepcint
	CPI mode, 4
	BRLO changemodes
	BRGE setnewvalues
changemodes:
	SBRS R16, PB4
	JMP completepcint
	SBRS R16, PB3
	JMP changeshownmode
	SBRS R16, PB2
	JMP intosettings
changeshownmode:
	CBI PORTB, PB0
	CBI PORTB, PB1
	CBI PORTB, PB5
	CPI mode, 3
	BREQ resetmode
	INC mode
	LDI R16, 0x80
	MOV delay, R16
	JMP completepcint
resetmode:
	CLR mode
	JMP completepcint
intosettings:
	CBI PORTB, PB0
	CBI PORTB, PB1
	CBI PORTB, PB5
	LDI R17, 4 
	ADD mode, R17
	CBR mode, 0xF0
	CPI mode, 4
	BREQ copytime
	CPI mode, 5
	BREQ copydate
	JMP completepcint
copytime:
	MOV shours, hours
	MOV smins, minutes
	MOV ssecs, seconds
	JMP completepcint
copydate:
	MOV sdays, day
	MOV smonth, month
	MOV syear, year
	JMP completepcint
setnewvalues:
	SBRS R16, PB4
	JMP exitsettings
	;SBRS R16, PB3
	;JMP increment_right
completepcint:
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
	RETI	
exitsettings:
	SUBI mode, 4
	JMP completepcint
//CTC TIMER0 ----------------------------------------------------- //
TIMER0_COMPA:
	SBR dissel, 0x08			;2.5ms delay
	RETI
TIMER1_COMPA:
	PUSH R16					;Save initial conditions
	PUSH R17
	LDS R16, SREG
	PUSH R16
	MOV R16, seconds
	CALL time_inc
	MOV seconds, R16
	CPI seconds, 0x60			;Seconds completes 1 min
	BRNE completetimer1int
	CLR seconds					;Restart seconds
	MOV R16, minutes
	CALL time_inc
	MOV minutes, R16
	CPI minutes, 0x60			;Seconds completes 1 hour
	BRNE completetimer1int
	CLR minutes					;Restart minutes
	MOV R16, hours
	CALL time_inc
	MOV hours, R16
	CPI hours, 0x24				;Day complete
	BRNE completetimer1int
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
	JMP completetimer1int
incrementmonth:
	LDI day, 1					;Start of month
	CPI month, 12
	BREQ incrementyear
	INC month
	JMP completetimer1int
incrementyear:
	LDI month, 1				;Start of the year
	MOV R16, year
	CALL time_inc
	MOV year, R16
	CPI year, 0xA0				;Max of 2 digits years shown
	BRNE completetimer1int
	CLR year
completetimer1int:
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
	RETI
//Time incrementers
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
.org 0x600
	days_month:	.DB 0,49,40,49,48,49,48,49,49,48,49,48,49,0
	modejumps:	.DB MST,SDM,ATM,ADM,TS,DSM,ATSM,ADSM,AAM,0
	selector:	.DB 1,2,4,8,16,32
	show2nm:	.DB 222,136,230,236,184,124,126,200,254,252
	showupdown: .DB 250,40,220,188,46,182,246,168,254,190
	shownormal:	.DB 222,132,124,188,166,186,250,140,254,190
	show2updown:.DB 252,144,62,182,210,230,238,176,254,246