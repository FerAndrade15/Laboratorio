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
.def timeal	= R0
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
	CPI mode, 4					;Table with 2bytes directions of 2 bytes
	BRGE doublebyte
	CLR R31
	IJMP
doublebyte:
	LDI R31, 1
	IJMP
//Enable buttons
enablebtns:
	IN R16, PINB							;Checks if buttons stabilized after 15ms
	CBR R16, 0xE3
	CPI R16, 0x1C
	BRNE continuedisplayset					;If the stabilized it lets buttons react
	LDI R16, (1<<PCINT4)|(1<<PCINT3)|(1<<PCINT2)
	STS PCMSK0, R16
	JMP continuedisplayset
//Display assign of selector and value
display_settings:
	CPI dissel, 5
	BREQ enablebtns							;Debouncing
continuedisplayset:
	LDI ZH, HIGH(selector<<1)				;Redirect to selector's values table
	LDI ZL, LOW(selector<<1)
	ADD ZL, dissel
	LPM R16, Z
	OUT PORTC, R16							;Select display
	CPI dissel, 0
	BREQ noblink							;Checks if the point must be on
	CPI dissel, 5
	BREQ noblink							;Checks if the point must be on
	MOV R16, btndel
	CBR R16, 0xFE
	ADD display, R16						;Adds the point to the value of the port
	OUT PORTD, display						;Show on displays
	JMP completedisplay
noblink:
	OUT PORTD, display						;Show on displays without the point
	JMP completedisplay
completedisplay:
	CPI dissel, 5
	BREQ reset								;Increment of selector (0>>5)
	INC dissel
	JMP Loop
reset:
	CLR dissel								;Loop of selector (5>>0)
	JMP Loop
//Mode >> Show Time ----------------------------------------------------
MST:							
	SBI PORTB, PB0							;Identifier (Blue)
	CPI dissel, 2
	BRLO hours_settings						;Checks the value that must show
	BREQ minutes1							
	CPI dissel, 3						
	BREQ minutes0
	MOV R16, seconds
	SBRC dissel, 0							;5Seconds' decades
	JMP seconds0
	//seconds1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	hours_settings:							;0>Hours'decades 1>Hours' units
		MOV R16, hours
		CALL D0_D1							;Returns the value that will be shown on the display
		JMP display_settings
	minutes1:								;2>Minutes'decades 3>Minutes' units
		MOV R16, minutes
		CALL D2								;Returns the value that will be shown on the display
		JMP display_settings
	minutes0:								;2>Minutes'decades 3>Minutes' units
		MOV R16, minutes
		CALL D3								;Returns the value that will be shown on the display
		JMP display_settings	
	seconds0:								;4Seconds' units
		CBR R16, 0xF0
		CALL D4_D5							;Returns the value that will be shown on the display
		JMP display_settings
//Mode >> Show Date --------------------------------------------------
SDM:						
	SBI PORTB, PB1							;Show mode indicator (Green)
	CPI dissel, 2
	BRLO days_settings						;Display selector start comparation
	BREQ month1
	CPI dissel, 3
	BREQ month0
	MOV R16, year							
	SBRC dissel, 0
	JMP year0
	//year1									;Year msnibble shown
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	days_settings:							;Show day units
		MOV R16, day
		CALL D0_D1
		JMP display_settings
	month1:									;Show month decades
		MOV R16, month
		CALL D2
		JMP display_settings
	month0:									;Show month units
		MOV R16, month
		CALL D3
		JMP display_settings	
	year0:									;Show years units
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
//Mode >> Show Alarm Time  -------------------------------------------
ATM:
	SBI PORTB, PB0							;Show identifier >> Purple
	SBI PORTB, PB1
	CPI dissel, 2							;Select display to send info
	BRLO ahours_settings
	BREQ amins1
	CPI dissel, 3
	BREQ amins0
	MOV R16, asecs
	SBRC dissel, 0
	JMP aseconds0
	//seconds1								;Set alarm seconds decades
	SWAP R16	
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	ahours_settings:						;Set alarm hours 
		MOV R16, ahours
		CALL D0_D1
		JMP display_settings
	amins1:									;Set alarm's minutes decades
		MOV R16, amins
		CALL D2
		JMP display_settings
	amins0:									;Set alarm's minutes units
		MOV R16, amins
		CALL D3
		JMP display_settings	
	aseconds0:								;Set alarm's seconds units
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
//Mode >> Show Alarm Date ------------------------------------------ 
//(ADDED Function >> not implemented)
ADM:							
	SBI PORTB, PB0							;Show identifier >> Purple
	SBI PORTB, PB1
	CPI dissel, 2
	BRLO adays_settings						;Display selector and filter to colect info
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
	adays_settings:							;Select days info
		MOV R16, aday
		CALL D0_D1
		JMP display_settings
	amonth1:								;Select months' alarm decades info
		MOV R16, amonth
		CALL D2
		JMP display_settings
	amonth0:								;Select months' alarm units info
		MOV R16, amonth
		CALL D3
		JMP display_settings	
	ayear0:									;Select alarm's years decades info
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
//Mode >> Time or Alarm Time Settings -------------------------------------
TA_S:
	SBRS btndel, 0							;Blink of identifier of date settings in general >> Blue blink
	CBI PORTB, PB0
	SBRC btndel, 0
	SBI PORTB, PB0
	MOV R17, btndel							;Check changes on btndel, used to save the state of the buttons
	SBRC R17, PB3
	JMP DEC_LEFTm							;Decrement values, time mode
	SBRC R17, PB4
	JMP INC_RIGHTm							;Increment values, time mode
showdsptimeset:								;Selection of info for the displays
	CPI dissel, 2	
	BRLO shours_settings					;Show hours
	BREQ sminutes1							;Show minutes' decades
	CPI dissel, 3
	BREQ sminutes0							;Show minutes' units
	MOV R16, ssecs							
	SBRC dissel, 0
	JMP sseconds0							;Show seconds' units
	//seconds1							
	SWAP R16								
	CBR R16, 0xF0
	CALL D4_D5								;Show seconds' decades
	JMP display_settings					
	shours_settings:						;Show hours
		MOV R16, shours
		CALL D0_D1
		JMP display_settings
	sminutes1:								;Show minutes' decades
		MOV R16, smins
		CALL D2
		JMP display_settings			
	sminutes0:								;Show minutes' units
		MOV R16, smins
		CALL D3
		JMP display_settings	
	sseconds0:								;Show seconds' units
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings
INC_RIGHTm:									;Incremet values selected
	SBRC R17, PB2							;Just if the are no changes on the main button proceed to change shown info
	JMP showdsptimeset
	MOV R16, movdsl							;movdsl stablished the selection of info that is going to change
	CPI R16, 0
	BREQ incrementShours					;increment hours at settings
	CPI R16, 1
	BREQ incrementSminutes					;increment hours at minutes
	CPI R16, 2
	BREQ incrementSseconds					;increment hours at seconds
	JMP showdsptimeset
confirminctm:								;Returns the value of the btndel to default
	MOV R17, btndel
	CBR R17, 0x10
	MOV btndel, R17
	JMP showdsptimeset						;Jumps to the selecter of info
incrementShours:						
	MOV R16, shours							;Copy shown hours
	CALL time_inc							;Inc hours
	CPI R16, 0x24							;Checks max
	BRNE offbuttoninch
	CLR R16									;Reset of values
offbuttoninch:
	MOV shours, R16							;Set the settings register of hours
	JMP confirminctm
incrementSminutes:
	MOV R16, smins							;Copy shown minutes
	CALL time_inc							;Inc minutes
	CPI R16, 0x60							;Compare to max
	BRNE offbuttonincm						
	CLR R16									;Reset of value
offbuttonincm:
	MOV smins, R16							;Set changes executed
	JMP confirminctm
incrementSseconds:							
	MOV R16, ssecs							;Copy of shown seconds
	CALL time_inc							;Increment of seconds
	CPI R16, 0x60							;Compare to max
	BRNE offbuttonincs
	CLR R16									;Reset value
offbuttonincs:
	MOV ssecs, R16							;Save change
	JMP confirminctm
DEC_LEFTm:									;Decrement of selected info
	SBRC R17, PB2							;After the button is disabled
	JMP showdsptimeset
	MOV R16, movdsl							;Selection of info that's going to change
	CPI R16, 0
	BREQ decrementShours					;Decrement hours
	CPI R16, 1
	BREQ decrementSminutes					;Decrement minutes
	CPI R16, 2
	BREQ decrementSseconds					;Decrement seconds
	JMP showdsptimeset
confirmdectm:		
	MOV R17, btndel							;Reset value of filter (register)
	CBR R17, 0x08
	MOV btndel, R17
	JMP showdsptimeset						;Select displays info
decrementShours:
	MOV R16, shours							;Copy of hours
	CPI R16, 0
	BREQ underflowh							;Compare to min
	CALL time_dec
	JMP finaldech							;Jmp to set changes 
underflowh:
	LDI R16, 0x23							;Mov to max
finaldech:
	MOV shours, R16							;Set changes
	JMP confirmdectm
decrementSminutes:
	MOV R16, smins							;Copy minutes
	CPI R16, 0
	BREQ underflowm							;Compare to min
	CALL time_dec
	JMP finaldecm							;Jmp to set changes 
underflowm:
	LDI R16, 0x59							;Mov to max
finaldecm:
	MOV smins, R16							;Set changes
	JMP confirmdectm
decrementSseconds:
	MOV R16, ssecs							;Copy seconds
	CPI R16, 0
	BREQ underflows							;Compare to min
	CALL time_dec
	JMP finaldecs							;Jmp to set changes 
underflows:
	LDI R16, 0x59							;Mov to max
finaldecs:
	MOV ssecs, R16
	JMP confirmdectm						;Set changes
//Mode >> Date or Alarm Date Settings -------------------------------------
DASM:							
	SBRS btndel, 0					;Blink state >> Green
	CBI PORTB, PB1
	SBRC btndel, 0
	SBI PORTB, PB1
	MOV R17, btndel					;Saves info of buttons changes
	SBRC R17, PB3
	JMP DEC_LEFTd					;Decrement dates
	SBRC R17, PB4
	JMP INC_RIGHTd					;Increment dates
showdspdateset:
	CPI dissel, 2
	BRLO sdays_settings				;Days settings jump
	BREQ smonth1					;Month firstbit jump
	CPI dissel, 3
	BREQ smonth0					;Month lsbit jump		
	MOV R16, syear
	SBRC dissel, 0
	JMP syears0						;Year lsbit jump
	//year1
	SWAP R16
	CBR R16, 0xF0
	CALL D4_D5
	JMP display_settings
	sdays_settings:					;Days settings
		MOV R16, sdays
		CALL D0_D1
		JMP display_settings
	smonth1:						;Month firstbit
		MOV R16, smonth
		CALL D2
		JMP display_settings
	smonth0:						;Month lsbit
		MOV R16, smonth
		CALL D3
		JMP display_settings	
	syears0:						;Year lsbit
		CBR R16, 0xF0
		CALL D4_D5
		JMP display_settings		;Show on display
INC_RIGHTd:
	SBRC R17, PB2					;Checks that the is no change on mode
	JMP showdspdateset
	MOV R16, movdsl					;Selection of info
	CPI R16, 0
	BREQ incrementSyears			;Increment years
	CPI R16, 1
	BREQ incrementSmonths			;Increment months
	CPI R16, 2
	BREQ incrementSdays				;Increment days
	JMP showdspdateset
confirmincdt:
	MOV R17, btndel					;Reset state of buttons lecture
	CBR R17, 0x10
	MOV btndel, R17
	JMP showdspdateset
incrementSyears:
	MOV R16, syear					;Copy year
	CPI R16, 0x99					
	BRNE incrementyear				;Compare to max
	CLR R16							;Reset
	JMP setnewyeari
incrementyear:
	CALL time_inc					;Increment year
setnewyeari:						;Set values
	MOV syear, R16
	JMP confirmincdt
incrementSdays:
	MOV R16, sdays					;Copy days
	LDI ZH, HIGH(days_month<<1)		;Redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	ADD ZL, smonth					;Correct to the actual month
	LPM R17, Z						;Max day of month
	CP R16, R17						;Compare to max
	BRNE incrementday				;Normal increment
	LDI R16, 1						;Reset
	JMP setnewday					
incrementday:
	CALL time_inc					;Normal increment
setnewday:
	MOV sdays, R16					;Set changes
	JMP confirmincdt
incrementSmonths:
	MOV R16, smonth					;Copy month
	CPI R16, 12						
	BRNE incrementmonth				;Compare to max
	LDI R16, 1						;Reset
	JMP setnewmonth					;Jmp to set values
incrementmonth:
	INC R16							;Normal increment
setnewmonth:
	MOV smonth, R16					;Set changes
	JMP confirmincdt
DEC_LEFTd:
	SBRC R17, PB2					;Checks that the is no change on mode
	JMP showdspdateset
	MOV R16, movdsl					;Selection of info
	CPI R16, 0
	BREQ decrementSyears			;Decrement years
	CPI R16, 1
	BREQ decrementSmonths			;Decrement months
	CPI R16, 2
	BREQ decrementSdays				;Decrement days
	JMP showdspdateset
confirmdecdt:
	MOV R17, btndel					;Reset state of buttons lecture
	CBR R17, 0x08
	MOV btndel, R17
	JMP showdspdateset
decrementSdays:
	MOV R16, sdays					;Copy days
	LDI ZH, HIGH(days_month<<1)		;Redirect to days of month table
	LDI ZL, LOW(days_month<<1)
	ADD ZL, smonth					;Correct to the actual month
	LPM R17, Z						;Max day of month
	CPI R16, 0
	BRNE decrementday				;Normal decrement
	MOV R16, R17					;Max
	JMP setnewdayd					;Jmp set value
decrementday:
	CALL time_dec					;Decrement
setnewdayd:
	MOV sdays, R16					;Set changes
	JMP confirmdecdt
decrementSyears:
	MOV R16, syear					;Copy years
	CPI R16, 0						
	BRNE decrementyear				;Compare min
	LDI R16, 0x99					;Change to max
	JMP setnewyeard					;Jmp set value
decrementyear:
	CALL time_dec					;Normal decrement
setnewyeard:
	MOV syear, R16					;Set changes
	JMP confirmdecdt
decrementSmonths:
	MOV R16, smonth					;Copy month
	CPI R16, 0
	BRNE decrementmonth				;Compare to min
	LDI R16, 0x99					;Change to max
	JMP setnewmonthd
decrementmonth:
	CALL time_dec					;Normal decrement
setnewmonthd:
	MOV smonth, R16				;Set changes
	JMP confirmdecdt
//Subroutines
D0_D1:
	SBRS dissel, 0					;Decades or units
	SWAP R16
	CBR R16, 0xF0
	LDI ZH, HIGH(show2nm<<1)		;Redirect to displayed value
	LDI ZL, LOW(show2nm<<1)
	ADD ZL, R16
	LPM display, Z					;Register to write portD
	RET
D2:
	SWAP R16						;Decades
	CBR R16, 0xF0
	LDI ZH, HIGH(showupdown<<1)		;Redirect to displayed value
	LDI ZL, LOW(showupdown<<1)
	ADD ZL, R16
	LPM display, Z					;Register to write portD
	RET
D3:
	CBR R16, 0xF0					;Units
	LDI ZH, HIGH(shownormal<<1)		;Redirect to displayed value
	LDI ZL, LOW(shownormal<<1)
	ADD ZL, R16
	LPM display, Z					;Register to write portD
	RET
D4_D5:
	LDI ZH, HIGH(show2updown<<1)	;Redirect to displayed value
	LDI ZL, LOW(show2updown<<1)
	ADD ZL, R16
	LPM display, Z					;Register to write portD
	RET	
//Time automatic incrementers
time_inc:
	MOV R17, R16					;Save value
	CBR R17, 0xF0					
	CPI R17, 9						;Overflow
	BRNE normal_increment			;No overflow detected
	SWAP R16
	CBR R16, 0xF0
	INC R16							;Increment decades
	SWAP R16
	RET
normal_increment:
	INC R16							;Increment units
	RET
//Time automatic decrementers
time_dec:
	MOV R17, R16					;Save value
	CBR R17, 0xF0
	CPI R17, 0						;Underflow
	BRNE normal_decrement			;No underflow detected
	SWAP R16
	CBR R16, 0xF0					
	DEC R16							;Decrement decades
	SWAP R16
	LDI R17, 0x09					;Set units at 9
	ADD R16, R17
	RET
normal_decrement:
	DEC R16							;Decrement units
	RET
//BUTTONS PIN CHANGE ---------------------------------------------- //
PCINT0_INT:
	PUSH R16						;Save initial conditions
	PUSH R17
	LDS R16, SREG
	PUSH R16
	IN R16, PINB					;Pin Change detection
	CBR R16, 0xE3
	CPI R16, 0x1C
	BREQ jmpcompletepcint			;No changes, pressing buttons
	CPI mode, 4
	BRLO changemodes				
	BRGE jmpsetnewvalues
jmpsetnewvalues:
	JMP setnewvalues
jmpcompletepcint:
	JMP completepcint
changemodes:
	SBRS R16, PB4					;Don't care
	JMP completepcint
	SBRS R16, PB3
	JMP changeshownmode				;Change mode (Time>>Date>>AlarmTime>>AlarmDate)
	SBRS R16, PB2
	JMP intosettings				;Start settings of any mode
changeshownmode:
	CBI PORTB, PB0					;Clear all leds
	CBI PORTB, PB1
	CBI PORTB, PB5
	CLR dissel
	CPI mode, 3						;Changes just into the first four modes >> Show
	BREQ resetmode
	INC mode
	JMP completepcint
resetmode:
	CLR mode						;Reset
	JMP completepcint
intosettings:
	CBI PORTB, PB0					;Clear all leds
	CBI PORTB, PB1
	CBI PORTB, PB5
	LDI R17, 4						;Get into settings
	ADD mode, R17
	CBR mode, 0xF0
	CPI mode, 4
	BREQ copytime					;Copy register into settings register
	CPI mode, 5
	BREQ copydate					;Copy register into settings register
	CPI mode, 6
	BREQ copyatime					;Copy register into settings register
	CPI mode, 7
	BREQ copyadate					;Copy register into settings register
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
copyatime:
	MOV shours, ahours
	MOV smins, amins
	MOV ssecs, asecs
	JMP completepcint
copyadate:
	MOV sdays, aday
	MOV smonth, amonth
	MOV syear, ayear
	JMP completepcint
setnewvalues:
	MOV R17, btndel					;Buttons recognizers
	CBR R17, 0xFE
	SBRS R16, PB4					;Button press Inc
	SBR R17, 0x10
	SBRS R16, PB3					;Button press Dec
	SBR R17, 0x08
	MOV btndel, R17					;Save buttons changes
	SBRS R16, PB2
	JMP exitsettings				;Set values changes on settings and change info selected to change
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
	INC R16						;Three states of changes
	MOV movdsl, R16	
	CPI R16, 3
	BRLO completepcint			;At 3(fourth state) clear all and reset settings
	CLR movdsl
	CPI mode, 4
	BREQ scopytime				;Set info changed
	CPI mode, 5
	BREQ scopydate				;Set info changed
	CPI mode, 6
	BREQ scopyatime				;Set info changed
	CPI mode, 7
	BREQ scopyadate				;Set info changed
	JMP completepcint
scopytime:
	MOV hours, shours
	MOV minutes, smins
	MOV seconds, ssecs
	SUBI mode, 4
	JMP completepcint
scopydate:
	MOV day, sdays
	MOV month, smonth
	MOV year, syear
	SUBI mode, 4
	JMP completepcint
scopyatime:
	MOV ahours, shours
	MOV amins, smins
	MOV asecs, ssecs
	SUBI mode, 4
	JMP completepcint
scopyadate:
	MOV aday, sdays
	MOV amonth, smonth
	MOV ayear, syear
	SUBI mode, 4
	JMP completepcint
//CTC TIMER0 ----------------------------------------------------- //
TIMER0_COMPA:
	SBR dissel, 0x08			;2.5ms delay
	SBRC btndel, 7
	JMP alarm_time
	RETI
alarm_time:
	PUSH R16					;Save initial conditions
	PUSH R17
	LDS R16, SREG
	PUSH R16
	INC timeal
	SBI PORTB, PB5
	MOV R16, timeal
	CPI R16, 0xFE
	BRNE endalint
	CBI PORTB,PB5
	MOV R16, btndel
	CBR R16, 0x80
	MOV btndel, R16
endalint:
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
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
	CP ahours, hours
	BRNE endint
	CP amins, minutes
	BRNE endint
	CP asecs, seconds
	BRNE endint
	MOV R16, btndel
	SBR R16, 0x80
	MOV btndel, R16
endint:
	POP R16
	STS SREG, R16
	POP R17
	POP R16	
	RETI
// Data Tables --------------------------------------------------- //
.org 0x600
	days_month:	.DB 0,49,40,49,48,49,48,49,49,48,49,48,49,0
	modejumps:	.DB MST,SDM,ATM,ADM,TA_S,DASM,TA_S,DASM
	selector:	.DB 1,2,4,8,16,32
	show2nm:	.DB 222,136,230,236,184,124,126,200,254,252
	showupdown: .DB 250,66,220,214,102,182,190,82,254,246
	shownormal:	.DB 222,66,124,122,226,186,190,82,254,250
	show2updown:.DB 252,144,62,182,210,230,238,176,254,246