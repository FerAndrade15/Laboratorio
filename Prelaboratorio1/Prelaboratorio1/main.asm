//*******************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: María Andrade
// Proyecto: Laboratorio 1
// Archivo: Laboratorio1.asm
// Hardware: ATMEGA328P
// Created: 26/01/2024 23:30:32
//*******************************************************************
// Encabezado -------------------------------------------------------
.include "M328PDEF.inc"
.cseg 
.org 0x00
// Stack Pointer ----------------------------------------------------
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
// Configuración ----------------------------------------------------
Setup:
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16			;Habilitación del prescaler
	LDI R16, 0b0000_0110
	STS CLKPR, R16			;Prescaler de 8 fcpu -> CLK 2MHz
	LDI R16, 0x0F
	OUT DDRB, R16
	LDI R16, 0x2F
	OUT DDRC, R16			;Output settings (0000_1111)
	LDI R16, 0xF0
	OUT DDRD, R16			;Output settings (1111_0000)
	LDI R16, 0x0C
	OUT PORTD, R16			;Pull-up buttons (+/-)
	LDI R16, 0x10			
	OUT PORTB, R16			;Pull-up button (sum)
//Registros en Cero * POR ERRORES
	LDI R19, 0
	LDI R20, 0
	LDI R21, 0
Loop:
	IN R17, PIND		
	IN R18, PINC		
	SBRS R18, PC4
	JMP Counter1
	JMP Counter2	
Counter1:
	SBRS R17, PD2
	JMP PlusCounter1
	SBRS R17, PD3
	JMP MinusCounter1
end:
	IN R22, PINB
	SBRS R22, PB4
	JMP Adder
	JMP Loop
PlusCounter1:
	LDI R16, 200			;Delay de revisión
	delayP1:
		DEC R16
		BRNE delayP1
	SBIS PIND, PD2			;Jumps if PC5 is high
	JMP PlusCounter1
	CPI R19, 0x0F
	BREQ end
	INC R19
	OUT PORTC, R19
	JMP end
MinusCounter1:
	LDI R16, 250			;Delay de revisión
	delayM1:
		DEC R16
		BRNE delayM1
	SBIS PIND, PD3			;Jumps if PC5 is high
	JMP MinusCounter1
	CPI R19, 0
	BREQ end
	DEC R19
	OUT PORTC, R19
	JMP end
Counter2:
	SBRS R17, PD2
	JMP PlusCounter2
	SBRS R17, PD3
	JMP MinusCounter2
	JMP end
PlusCounter2:
	LDI R16, 250			;Delay de revisión
	delayP2:
		DEC R16
		BRNE delayP2
	SBIS PIND, PD2			;Jumps if PC5 is high
	JMP PlusCounter2
	CPI R20, 0x0F
	BREQ end
	INC R20
	OUT PORTB, R20
	JMP end
MinusCounter2:
	LDI R16, 250			;Delay de revisión
	delayM2:
		DEC R16
		BRNE delayM2
	SBIS PIND, PD3			;Jumps if PC5 is high
	JMP MinusCounter2
	CPI R20, 0
	BREQ end
	DEC R20
	OUT PORTB, R20
	JMP end
Adder:
/*	LDI R16, 250			;Delay de revisión
	delayA:
		DEC R16
		BRNE delayA
	SBIS PINB, PB4			;Jumps if PC5 is high
	RJMP Adder
	*/
	MOV R21, R20
	ADD R21, R19
	CPI R21, 0x0F
	BREQ no
	BRLO no
	SBI PORTC, PC5
	end_sum:
		ANDI R21, 0x0F
		SWAP R21
		OUT PORTD, R21
		JMP Loop
	no:
		CBI PORTC, PC5
		JMP end_sum