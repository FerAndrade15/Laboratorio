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
.def resmode= R0
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
.def btndel = R13
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
	LDI R16, 0x1E
	STS OCR1AH, R16				;Max for CTC Mode Low Timer1 >> Generates interrrupt1
	LDI R16, 0x85 
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
	CLR movdsl
	CLR btndel
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
//Enable buttons
enablebtns:
	IN R16, PINB
	CBR R16, 0xE3
	CPI R16, 0x1C
	BRNE continuedisplayset
	LDI R16, (1<<PCINT4)|(1<<PCINT3)|(1<<PCINT2)
	STS PCMSK0, R16
	JMP continuedisplayset
//Display assign of selector and value
display_settings:
	CPI dissel, 5
	BREQ enablebtns
continuedisplayset:
	LDI ZH, HIGH(selector<<1)	;Redirect to selector's values table
	LDI ZL, LOW(selector<<1)
	ADD ZL, dissel
	LPM R16, Z
	OUT PORTC, R16
	CPI dissel, 0
	BREQ noblink
	CPI dissel, 5
	BREQ noblink
	MOV R16, btndel
	CBR R16, 0xFE
	ADD display, R16
	OUT PORTD, display		
	JMP completedisplay
noblink:
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
		MOV R16, minutes
		CALL D2
		JMP display_settings
	minutes0:
		MOV R16, minutes
		CALL D3
		JMP display_settings	
	seconds0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
SDM:							;Mode >> Show Date
	SBI PORTB, PB5
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
	SBI PORTB, PB0
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
	SBI PORTB, PB0
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
TA_S:								;Mode >> Time or Alarm Settings
	SBRS btndel, 0
	CBI PORTB, PB0
	SBRC btndel, 0
	SBI PORTB, PB0
	MOV R17, btndel
	SBRC R17, PB3
	JMP DEC_LEFTm
	SBRC R17, PB4
	JMP INC_RIGHTm
showdsptimeset:
	CPI dissel, 2
	BRLO shours_settings
	BREQ sminutes1
	CPI dissel, 3
	BREQ sminutes0
	SBRS mode, 1
	MOV R16, ssecs
	SBRC mode, 1
	MOV R16, asecs
	SBRC dissel, 0
	JMP sseconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	shours_settings:
		SBRS mode, 1
		MOV R16, shours
		SBRC mode, 1
		MOV R16, ahours
		CALL D0_D1
		JMP display_settings
	sminutes1:
		SBRS mode, 1
		MOV R16, smins
		SBRC mode, 1
		MOV R16, amins
		CALL D2
		JMP display_settings
	sminutes0:
		SBRS mode, 1
		MOV R16, smins
		SBRC mode, 1
		MOV R16, amins
		CALL D3
		JMP display_settings	
	sseconds0:
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
INC_RIGHTm:
	SBRC R17, PB2
	JMP showdsptimeset
	MOV R16, movdsl
	CPI R16, 0
	BREQ incrementShours
	CPI R16, 1
	BREQ incrementSminutes
	CPI R16, 2
	BREQ incrementSseconds
	JMP showdsptimeset
confirminctm:
	MOV R17, btndel
	CBR R17, 0x10
	MOV btndel, R17
	JMP showdsptimeset
incrementShours:
	SBRS mode, 1
	MOV R16, shours 
	SBRC mode, 1
	MOV R16, ahours 
	CALL time_inc
	CPI R16, 0x24
	BRNE offbuttoninch
	CLR R16
offbuttoninch:
	SBRS mode, 1
	MOV shours, R16
	SBRC mode, 1
	MOV ahours, R16
	JMP confirminctm
incrementSminutes:
	SBRS mode, 1
	MOV R16, smins 
	SBRC mode, 1
	MOV R16, amins 
	CALL time_inc
	CPI R16, 0x60
	BRNE offbuttonincm
	CLR R16
offbuttonincm:
	SBRS mode, 1
	MOV smins, R16
	SBRC mode, 1
	MOV amins, R16
	JMP confirminctm
incrementSseconds:
	SBRS mode, 1
	MOV R16, ssecs 
	SBRC mode, 1
	MOV R16, asecs 
	CALL time_inc
	CPI R16, 0x60
	BRNE offbuttonincs
	CLR R16
offbuttonincs:
	SBRS mode, 1
	MOV ssecs, R16
	SBRC mode, 1
	MOV asecs, R16
	JMP confirminctm
DEC_LEFTm:
	SBRC R17, PB2
	JMP showdsptimeset
	MOV R16, movdsl
	CPI R16, 0
	BREQ decrementShours
	CPI R16, 1
	BREQ decrementSminutes
	CPI R16, 2
	BREQ decrementSseconds
	JMP showdsptimeset
confirmdectm:
	MOV R17, btndel
	CBR R17, 0x08
	MOV btndel, R17
	JMP showdsptimeset
decrementShours:
	SBRS mode, 1
	MOV R16, shours 
	SBRC mode, 1
	MOV R16, ahours
	CPI R16, 0
	BREQ underflowh
	CALL time_dec
	JMP finaldech
underflowh:
	LDI R16, 0x23
finaldech:
	SBRS mode, 1
	MOV shours, R16
	SBRC mode, 1
	MOV ahours, R16
	JMP confirmdectm
decrementSminutes:
	SBRS mode, 1
	MOV R16, smins 
	SBRC mode, 1
	MOV R16, amins
	CPI R16, 0
	BREQ underflowm
	CALL time_dec
	JMP finaldecm
underflowm:
	LDI R16, 0x59
finaldecm:
	SBRS mode, 1
	MOV smins, R16
	SBRC mode, 1
	MOV amins, R16
	JMP confirmdectm
decrementSseconds:
	SBRS mode, 1
	MOV R16, ssecs 
	SBRC mode, 1
	MOV R16, asecs 
	CPI R16, 0
	BREQ underflows
	CALL time_dec
	JMP finaldecs
underflows:
	LDI R16, 0x23
finaldecs:
	SBRS mode, 1
	MOV ssecs, R16
	SBRC mode, 1
	MOV asecs, R16
	JMP confirmdectm

DASM:							;Mode >> Date or Alarm Date Settings
	SBRS btndel, 0
	CBI PORTB, PB5
	SBRC btndel, 0
	SBI PORTB, PB5
	MOV R17, btndel
	SBRC R17, PB3
	JMP DEC_LEFTd
	SBRC R17, PB4
	JMP INC_RIGHTd
showdspdateset:
	CPI dissel, 2
	BRLO sdays_settings				;Days settings jump
	BREQ smonth1					;Month firstbit jump
	CPI dissel, 3
	BREQ smonth0					;Month lsbit jump		
	SBRS mode, 1
	MOV R16, syear
	SBRC mode, 1
	MOV R16, ayear
	SBRC dissel, 0
	JMP syears0						;Year lsbit jump
	//year1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	sdays_settings:					;Days settings
		SBRS mode, 1
		MOV R16, sdays
		SBRC mode, 1
		MOV R16, aday
		CALL D0_D1
		JMP display_settings
	smonth1:						;Month firstbit
		SBRS mode, 1
		MOV R16, smonth
		SBRC mode, 1
		MOV R16, amonth
		CALL D2
		JMP display_settings
	smonth0:						;Month lsbit
		SBRS mode, 1
		MOV R16, smonth
		SBRC mode, 1
		MOV R16, amonth
		CALL D3
		JMP display_settings	
	syears0:						;Year lsbit
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
INC_RIGHTd:
	SBRC R17, PB2
	JMP showdspdateset
	CPI R16, 0
	BREQ incrementSyears
	CPI R16, 1
	BREQ incrementSmonths
	MOV R16, movdsl
	CPI R16, 2
	BREQ incrementSdays
	JMP showdspdateset
confirmincdt:
	MOV R17, btndel
	CBR R17, 0x10
	MOV btndel, R17
	JMP showdspdateset
incrementSyears:
	SBRS mode, 1
	MOV R16, syear
	SBRC mode, 1
	MOV R16, ayear 
	CPI R16, 0x99
	BRNE incrementyear
	CLR R16
	JMP setnewyeari
incrementyear:
	CALL time_inc
setnewyeari:
	SBRS mode, 1
	MOV syear, R16
	SBRC mode, 1
	MOV ayear, R16
	JMP confirmincdt
incrementSdays:
	SBRS mode, 1
	MOV R16, sdays
	SBRC mode, 1
	MOV R16, aday 
	LDI ZH, HIGH(days_month<<1)	;Redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	SBRS mode, 1
	ADD ZL, smonth				;Correct to the actual month
	SBRC mode, 1
	ADD ZL, amonth				;Correct to the actual month
	LPM R17, Z					;Max day of month
	CP R16, R17
	BRNE incrementday
	SBRS mode, 1
	LDI R16, 1
	SBRC mode, 1
	CLR R16
	JMP setnewday
incrementday:
	CALL time_inc
setnewday:
	SBRS mode, 1
	MOV sdays, R16
	SBRC mode, 1
	MOV aday, R16
	JMP confirmincdt
incrementSmonths:
	SBRS mode, 1
	MOV R16, smonth 
	SBRC mode, 1
	MOV R16, amonth
	CPI R16, 12
	BRNE incrementmonth
	SBRS mode, 1
	LDI R16, 1
	SBRC mode, 1
	CLR R16
	JMP setnewmonth
incrementmonth:
	INC R16
setnewmonth:
	SBRS mode, 1
	MOV smins, R16
	SBRC mode, 1
	MOV amins, R16
	JMP confirmincdt
DEC_LEFTd:
	SBRC R17, PB2
	JMP showdspdateset
	CPI R16, 0
	BREQ decrementSyears
	CPI R16, 1
	BREQ decrementSmonths
	MOV R16, movdsl
	CPI R16, 2
	BREQ decrementSdays
	JMP showdspdateset
confirmdecdt:
	MOV R17, btndel
	CBR R17, 0x08
	MOV btndel, R17
	JMP showdspdateset
decrementSdays:
	SBRS mode, 1
	MOV R16, sdays
	SBRC mode, 1
	MOV R16, aday 
	LDI ZH, HIGH(days_month<<1)	;Redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	SBRS mode, 1
	ADD ZL, smonth				;Correct to the actual month
	SBRC mode, 1
	ADD ZL, amonth				;Correct to the actual month
	LPM R17, Z					;Max day of month
	CPI R16, 0
	BRNE decrementday
	MOV R16, R17
	JMP setnewdayd
decrementday:
	CALL time_dec
setnewdayd:
	SBRS mode, 1
	MOV sdays, R16
	SBRC mode, 1
	MOV aday, R16
	JMP confirmdecdt
decrementSmonths:
	SBRS mode, 1
	MOV R16, smonth 
	SBRC mode, 1
	MOV R16, amonth
	SBRS mode, 1
	CPI R16, 1
	SBRC mode, 1
	CPI R16, 0
	BRNE decrementmonth
	LDI R16, 12
	JMP setnewmonthd
decrementmonth:
	INC R16
setnewmonthd:
	SBRS mode, 1
	MOV smins, R16
	SBRC mode, 1
	MOV amins, R16
	JMP confirmdecdt
decrementSyears:
	SBRS mode, 1
	MOV R16, syear
	SBRC mode, 1
	MOV R16, ayear 
	CPI R16, 0
	BRNE decrementyear
	LDI R16, 0x99
	JMP setnewyeard
decrementyear:
	CALL time_inc
setnewyeard:
	SBRS mode, 1
	MOV syear, R16
	SBRC mode, 1
	MOV ayear, R16
	JMP confirmdecdt

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
//Time automatic incrementers
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
//Time automatic decrementers
time_dec:
	MOV R17, R16
	CBR R17, 0xF0
	CPI R17, 0
	BRNE normal_decrement
	SWAP R16
	CBR R16, 0xF0
	DEC R16
	SWAP R16
	LDI R17, 0x09
	ADD R16, R17
	RET
normal_decrement:
	DEC R16
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
	CLR dissel
	CPI mode, 3
	BREQ resetmode
	INC mode
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
	MOV R17, btndel
	CBR R17, 0xFE
	SBRS R16, PB4
	SBR R17, 0x10
	SBRS R16, PB3
	SBR R17, 0x08
	SBRS R16, PB2
	JMP exitsettings
	MOV btndel, R17
completepcint:
	CLR R16
	STS PCMSK0, R16				;Disable Pin Change on PB4, PB3 and PB2
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
	RETI	
exitsettings:	
	MOV R16, movdsl
	INC R16
	MOV movdsl, R16
	CPI R16, 3
	BRNE completepcint
	CLR movdsl
	SUBI mode, 4
	MOV hours, shours
	MOV minutes, smins
	MOV seconds, ssecs
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
	MOV R16, btndel
	INC R16
	CBR R16, 0xFE
	MOV btndel, R16
	CPI R16, 0
	BRNE completetimer1int
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
	BREQ aincrementmonth
	MOV R16, day
	CALL time_inc
	MOV day, R16				;Day increment
	JMP completetimer1int
aincrementmonth:
	LDI day, 1					;Start of month
	CPI month, 12
	BREQ aincrementyear
	INC month
	JMP completetimer1int
aincrementyear:
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
// Data Tables --------------------------------------------------- //
.org 0x600
	days_month:	.DB 0,49,40,49,48,49,48,49,49,48,49,48,49,0
	modejumps:	.DB MST,SDM,ATM,ADM,TA_S,DASM,TA_S,DASM,AAM,0
	selector:	.DB 1,2,4,8,16,32
	show2nm:	.DB 222,136,230,236,184,124,126,200,254,252
	showupdown: .DB 250,66,220,214,102,182,190,82,254,246
	shownormal:	.DB 222,66,124,122,226,186,190,82,254,250
	show2updown:.DB 252,144,62,182,210,230,238,176,254,246