;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Lab 2 Project Assembly Code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m328Pdef.inc"
.def mode=R29
.def state=R18
.def leftDisp=R30
.def rightDisp=R31

.def btAOnes=R20
.def btAZeros=R21
.def btBOnes=R22
.def btBZeros=R23

.def btAState=R27
.def btBState=R28

.equ dpConstant=0b00001000
.equ PAUSED=0
.equ COUNTING=1
.equ STOPPED=2

.cseg
.org 0

	sbi DDRB, 1;	PB1 is now output SER
	sbi DDRB, 2;	PB2 is now output SRCLK
	sbi DDRB, 3;	PB3 is now output RCLK

	cbi DDRB, 4;	PB4 is now input BUTTON 1
	sbi PINB, 4;	Internal pullup resistor for PB4
	
	cbi DDRB, 5;	PB5 is now input BUTTON 2
	sbi PINB, 5;	Internal pullup resistor for PB5
	
; On start of program, initial mode
	ldi mode, 1;		MODE 1A, before counting begins
	ldi state, PAUSED;
	rcall initTimer;
;----------------------------------------------------------------------
; Main loop
;----------------------------------------------------------------------

main:
	rcall display;		Displays R16 to 7seg
	rcall delay;

	cpi btBState, 1;
	breq btBPressAction;

	cpi btAState, 1;
	brge btAPressAction;

	cpi btBState, 2;
	breq btBReleaseAction;

	cpi state, COUNTING;
	brne mainNoUpdate;
	rcall incrementTimer;

	mainNoUpdate:
		rjmp main;

	btBPressAction:
		ldi state, PAUSED;
		rjmp main;

	btAPressAction:
		cpi state, PAUSED;
		breq startCounting;
		cpi state, COUNTING;
		breq pauseCounting;
		rjmp main;

	startCounting:
		ldi state, COUNTING;
		rjmp main;

	pauseCounting:
		ldi state, PAUSED;
		rjmp main;
			
	btBReleaseAction:
		rcall initTimer;
		rjmp main;

	endmain:
	rjmp main; Jumps to top of main, infinite loop

; END OF MAIN LOOP


; Helper function to set displays to show 0s
initTimer:
	ldi leftDisp,  0;	Initial left display is 0
	ldi rightDisp, 0;	Initial right display is 0
	ldi state, PAUSED;
	ret;

; Helper function to increase timer by 1
incrementTimer:
	inc rightDisp;
	cpi rightDisp, 0x0A;
	brpl incrementLeft;
	ret;

	incrementLeft:
	inc leftDisp;
	cpi leftDisp, 0x0A;
	breq timeoutReached;
	ldi rightDisp, 0;
	ret;
	
	timeoutReached:
	ldi leftDisp,  9;
	ldi rightDisp, 9;
	ldi state, STOPPED;		STATE C, stopped counting
	ret;

;----------------------------------------------------------------------
; Switch - maps a 0-9 value to a binary pattern for 7seg display
;----------------------------------------------------------------------

switch: ; Turns R19 val into R16 binary for 7seg
	;caseR19is0:
		cpi R19, 0x00;
		brne caseR19is1;
		ldi R16, 0b01110111; load pattern to display 0
		ret;
	caseR19is1:
		cpi R19, 0x01;
		brne caseR19is2;
		ldi R16, 0b00010100; load pattern to display 1
		ret;
	caseR19is2:
		cpi R19, 0x02;
		brne caseR19is3;
		ldi R16, 0b11010011; load pattern to display 2
		ret;
	caseR19is3:
		cpi R19, 0x03;
		brne caseR19is4;
		ldi R16, 0b11010110; load pattern to display 3
		ret;
	caseR19is4:
		cpi R19, 0x04;
		brne caseR19is5;
		ldi R16, 0b10110100; load pattern to display 4
		ret;
	caseR19is5:
		cpi R19, 0x05;
		brne caseR19is6;
		ldi R16, 0b11100110; load pattern to display 5
		ret;
	caseR19is6:
		cpi R19, 0x06;
		brne caseR19is7;
		ldi R16, 0b11100111; load pattern to display 6
		ret;
	caseR19is7:
		cpi R19, 0x07;
		brne caseR19is8;
		ldi R16, 0b01010100; load pattern to display 7
		ret;
	caseR19is8:
		cpi R19, 0x08;
		brne caseR19is9;
		ldi R16, 0b11110111; load pattern to display 8
		ret;
	caseR19is9:
		cpi R19, 0x09;
		brne caseDefault;
		ldi R16, 0b11110110; load pattern to display 9
		ret;
	caseDefault:
		ldi R16, 0b00000000; load empty pattern, display is off
		ret;

;----------------------------------------------------------------------
; Display - shows a digit on the 7seg display
;----------------------------------------------------------------------

display:	
	mov R19, leftDisp;		Move left digit to be displayed into temp register R19
	rcall switch;			Convert number in R19 into the binary pattern for display

	cpi mode, 2;			If mode is 2,
	breq noDecPoint;		then don't add a decimal point
	ldi R19, dpConstant;	Else add a decimal point
	add R16, R19;
	
	noDecPoint:
	; Loop through binary pattern in R16
	rcall displayHelper;

	mov R19, rightDisp;		Move right digit to be displayed into temp register R19
	rcall switch;			Convert number in R19 into the binary pattern for display
	rcall displayHelper;
	
	; RCLK pulse
	sbi PORTB,2;
	nop;
	cbi PORTB,2;

	ret; 

displayHelper:
	; Save register contents to stack
	push R16;
	push R17;
	in R17, SREG;
	push R17;

	ldi R17, 8;
	displayLoop1:
		rol R16;			rotate R16 left trough Carry
		brcs set_ser_in_1;	if bit is 1, output 1 in SER
		cbi PORTB,1;		else output 0 in SER
		rjmp displayLoop1End

		set_ser_in_1:
		sbi PORTB,1;
		
		displayLoop1End:
		; SRCLK pulse
		sbi PORTB,3;
		nop;
		cbi PORTB,3;

		dec R17;
	brne displayLoop1;
	
	; Restore registers from stack
	pop R17;
	out SREG, R17;
	pop R17;
	pop R16;
	ret;


;----------------------------------------------------------------------
; Delay - does nothing for a period of time
;----------------------------------------------------------------------

delay:
	cpi mode, 1;		
	brmi delay1;	If mode 1, branch to short delay
	cpi mode, 2;
	brpl delay2;	If mode 2, branch to long delay

	delay1:
		rcall delayMode1;
		ret;
	delay2:
		rcall delayMode1;
		ret;


delayMode1:
	; loop 1 {
	ldi r24, 10;
	delayLoop1: 
		; loop 2 {
		ldi r25, 100;
		delayLoop2: 
			; loop 3 {
			ldi btAOnes, 0;
			ldi btAZeros, 0;
			ldi btBOnes, 0;
			ldi btBZeros, 0;
			ldi r26, 100;
			delayLoop3:
				SBIS PINB, 4; 
				inc btAOnes;
				SBIC PINB, 4; 
				inc btAZeros;
				SBIS PINB, 5; 
				inc btBOnes;
				SBIC PINB, 5; 
				inc btBZeros;
			dec r26;
			brne delayLoop3; 
			; } end loop 3

			cp btAOnes, btAZeros; Compares ones and zeros
			brpl buttonApressed; Branch if positive

			cp btBOnes, btBZeros; Compares ones and zeros
			brpl buttonBpressed; Branch if negative

			cpi btAState, 1;
			breq buttonAReleased;

			cpi btBState, 1;
			breq buttonBReleased;
		
		dec r25;
		brne delayLoop2; 
		; } end loop 2
		
		ldi btAState, 0;
		ldi btBState, 0;

	dec r24;
	brne delayLoop1; 
	; } end loop 1
	ret;

	buttonApressed:
		ldi btAState, 1;
		rcall resetLoopCounters;
		ret;
	buttonBpressed:
		ldi btBState, 1;
		rcall resetLoopCounters;
		ret;
	buttonAreleased:
		ldi btAState, 2;
		rcall resetLoopCounters;
		ret;
	buttonBreleased:
		ldi btBState, 2;
		rcall resetLoopCounters;
		ret;


; Helper function to reset loop counters to 0
resetLoopCounters:
	ldi r26, 0;
	ldi r25, 0;
	ldi r24, 0;
	ret;

.exit
