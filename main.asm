; constant decleration
;--------------------
regH equ 0x04 
regL equ 0x05 
sector equ 0x06 
regHmax equ 0xa2; for 10Hz 0x51; for 20Hz ; 0x20 for 50Hz 
regLmax equ 0xc2; 0x61; 0x8d 
regHmin equ 0x15 ; for 75Hz 
regLmin equ 0xb3 

     ORG 0x0000 
	 goto Main ;go to start of main code 
	 ORG 0x0008 ;High priority interrupt routine 
	 
	 incf sector, f, ACCESS
	 
	 movlw .1 
	 cpfseq sector,ACCESS 
	 bra sec2 
   bcf PORTB,0,ACCESS ; S4=0 
    call deadtime movlw b'00010110' ; 561 
	movwf PORTB, ACCESS 
	bra outCCP 
	
sec2
    movlw .2 
	cpfseq sector,ACCESS
	bra sec3 
   bcf PORTB,4,ACCESS ; S5=0 
   call deadtime 
   movlw b'00100110' ; 612
   movwf PORTB, ACCESS
   bra outCCP 
   
sec3 
   movlw .3 
   cpfseq sector,ACCESS 
   bra sec4 
  bcf PORTB,2,ACCESS ; S6=0 
   call deadtime 
   movlw b'00101010' ; 123 
   movwf PORTB, ACCESS
   bra outCCP 
   
sec4 
   movlw .4 
   cpfseq sector,ACCESS
   bra sec5
  bcf PORTB,1,ACCESS ; S1=0
   call deadtime movlw b'00101001' ; 234 
   movwf PORTB, ACCESS 
   bra outCCP
   
sec5 
   movlw .5 
   cpfseq sector,ACCESS
   bra sec6
  bcf PORTB,5,ACCESS ; S2=0
   call deadtime 
   movlw b'00011001' ; 345
   movwf PORTB, ACCESS
   bra outCCP 
   
sec6 
   clrf sector,ACCESS
   bcf PORTB,3,ACCESS ; S3=0
   call deadtime
   movlw b'00010101' ; 456
   movwf PORTB, ACCESS
   
outCCP
   bcf PIR1, 2, ACCESS ; CCP1IF =0
   retfie FAST 
deadtime 
   clrf TMR2, ACCESS
   bsf T2CON,2,ACCESS; Start T0
str   movlw .13 ; 10 us (I added the 12 machine cycles of the code between bcf (bit =0)
and movwf, where the bit is set )
wat cpfsgt TMR2, ACCESS
   bra wat 
   
   bcf T2CON,2,ACCESS; Stop T2
   return   
   
;---------------------- 
;Start of main program
Main: 
; Initization 
;-------------
       movlb 0x0f ; 
	   clrf INTCON ; disable interrupts
	   clrf INTCON3
	   movlw 0x93
	   movwf RCON ; Enable Priority Levels on Interrupts/ clear the flags of Reset and 
brown-out 
       clrf PIR1 ; clear flags
	   clrf PIR2
       clrf PIR3
       clrf STKPTR ; reset stack pointer  
	   
; I/O ports 
;---------- 
       CLRF T1CON, ACCESS; shut down Timer 1 Oscilator
	   clrf RCSTA, ACCESS ; disable serial port
	   
	   CLRF PORTB, ACCESS ; Initialize PORTC by clearing output data latches
	   CLRF LATB, ACCESS ; Alternate method to clear output data latches
	   CLRF TRISB, ACCESS ; PortB is set output for 180 gating gating signals
	   
	   CLRF PORTD, ACCESS ; Initialize PORTC by clearing output data latches
	   CLRF LATD, ACCESS ; Alternate method to clear output data latches
	   SETF TRISD, ACCESS ; PortD is set input for 180 gating gating signals	

; variables initialization 
;-------------------------- 
       clrf sector,ACCESS
	   movlw regLmax
	   movwf regL, ACCESS
	   movlw regHmax
	   movwf regH, ACCESS

	   
; T0 & T2 initialization
;------------------------ 
       movlw 0x08 ; 16 bit, prescale=1, stop T0 ; delay of 16 ms, at 10MHZ clock, for one sector
to get 10.41 Hz
       movwf T0CON, ACCESS
	   clrf T2CON,ACCESS; Stop T2, no scales 

;-------------------------------------------------------------------- 
; T1 Initialization for Capture mode
       movlw 0x01
	   movwf T1CON, ACCESS ; Prescale =1, run T1, read 2 separate 8bit
	   clrf TMR1L, ACCESS
	   clrf TMR1H, ACCESS 
;in 18F452 clrf T3CON, ACCESS ; select T1 for CCP1 and CCP2 modules 

; CCP1 Initialization 
       clrf CCP1CON, ACCESS ; Reset CCP1 module
	   clrf CCPR1H, ACCESS
	   clrf CCPR1L, ACCESS
	   movlw 0x0b
	   movwf CCP1CON, ACCESS ; Compare Mode: Trigger special event (CCPIF 
bit is set) and TMR1 is reset 

; Interrupt Initialization
       bsf PIE1, CCP1IE, ACCESS ; CCPIE = 1 to enable CCP interrupt
	   movlw 0xC0
	   movwf INTCON, ACCESS ; enable General and Peripheral interrupts	

MainLoop 
;============================
  
        movff regL, CCPR1L
		movff regH, CCPR1H

		btfsc PORTD, 4, ACCESS ; RC0 for increase T/6 (decrease frequency)
		bra negkey
		movlw regHmax
		cpfslt regH, ACCESS
		bra uplmt
		incf regL,f, ACCESS
		movlw 0XFF ; to avoid Regl = FF because it will never catched in the Delay 
subroutine. 
        cpfseq regL, ACCESS
		bra otpos
		incf regL,f, ACCESS 
		incf regH,f, ACCESS
		bra otpos
uplmt 
        movlw regLmax ;  avoid making regLmax =FF beacuse it will not be 
captured by the Delay code 
        cpfslt regL, ACCESS
		bra negkey
		incf regL,f, ACCESS
otpos 
        call keydelay

negkey 
        btfsc PORTD, 5, ACCESS ; RC1 for decrease T/6 (increase frequency)
		bra MainLoop
		movlw regHmin
		cpfsgt regH, ACCESS
		bra lwrlmt
		decf regL,f, ACCESS
		movlw 0XFF ; to avoid Regl = FF because it will never catched in the Delay 
subroutine. 
        cpfseq regL, ACCESS
		bra outneg
		decf regL,f, ACCESS
		decf regH,f, ACCESS
		bra outneg
lwrlmt 
        movlw regLmin ; avoid making regLmax =FF beacuse it will not be 
captured by the Delay code 
        cpfsgt regL, ACCESS
		bra MainLoop
		decf regL,f, ACCESS
outneg
       call keydelay
	   bra MainLoop
;============================	

keydelay; 1ms 
        clrf TMR0H, ACCESS ; the high must be cleared first
        clrf TMR0L, ACCESS
	    bsf T0CON,7,ACCESS;
		Start T0
bgn     movlw 0xc4 ; 0X09c4 = 1ms 
wlw     cpfsgt TMR0L, ACCESS
        bra wlw
		movlw 0x09
		cpfseq TMR0H, ACCESS
		bra bgn
		bcf T0CON,7,ACCESS; Stop T0
		return 
;End of program
 