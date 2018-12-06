;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATE:  2018-12-05
; AUTHOR: Jacques Deschenes, Copyright 2018
; DESCRIPTION:    
;   musix box built using a PIC12F1572
;   Can play 3 simultanuous tones.
;    
; LICENCE: GPLv3    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
    
    include p12f1572.inc
    
	__config _CONFIG1, _FOSC_ECH&_WDTE_OFF&_PWRTE_ON&_MCLRE_ON
	
	;__config _CONFIG2, _PLLEN_ON
	
	radix dec
	
;;;;;;;;;;;;;	
; constants	
;;;;;;;;;;;;;	

FOSC EQU 32000000  ; CPU oscillator frequency, PLLON
FCYCLE EQU 8000000  ; instruction cycle frequency
CPER EQU 125 ; intruction cycle in nanoseconds
; tone channels
CHN0 EQU 0
CHN1 EQU 1
CHN2 EQU 2
 
 
; tempered scale 4th octave
C4 EQU .0
C4s EQU .1
D4f EQU .1
D4 EQU .2
D4s EQU .3
E4f EQU .3 
E4 EQU .4
F4 EQU .5
F4s EQU .6
G4f EQU .6
G4 EQU .7
G4s EQU .8
A4f EQU .8 
A4 EQU .9
A4s EQU .10
B4f EQU .10 
B4  EQU .11

; duration
WHOLE EQU 0
DOTTED_WHOLE EQU 1
HALF EQU 2
DOTTED_HALF EQU 3
QUARTER EQU 4
DOTTED_QUARTER EQU 5
HEIGTH EQU 6
DOTTED_HEIGTH EQU 7
SIXTEENTH EQU 8
DOTTED_SIXTEENTH EQU 9

; octaves
O4 EQU 0
O5 EQU 1
 
; boolean flags
; bit position 
F_OCTAVE EQU 0  
F_SUSTAIN EQU 1
F_DONE EQU 2
 
;;;;;;;;;;;;;;;;;;;;;;;;
;   assembler macros 
;;;;;;;;;;;;;;;;;;;;;;;;

; create table entry for pwm period count 
PR_CNT macro n
    dt low n, high n
    endm
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; arguments stack manipulation macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; pop top stack in W    
pop macro 
    moviw --FSR0
    endm
    
; push W on stack    
push macro
    movwi FSR0++
    endm

; interchange  W and top of stack    
xchg macro
    xorwf INDF0,F
    xorwf INDF0,W
    xorwf INDF0,F
    endm

; get nth element of stack
pick macro n
    moviw  (~n&0x1f)[FSR0]
    endm

; insert element on stack at postion n    
store  macro n
   movwi (~n&0x1f)[FSR0]
   endm
   
;;;;;;;;;;;;;;;
;  variables
;;;;;;;;;;;;;;;
stack_seg    udata 0x20 
stack res 16 ; arguments stack
 
var_seg  udata_shr 0x70
flags res 1 ; boolean flags  
score_idx res 1 ; position in music score
play res 1 ; index of melody in play
durationL res 1; low duration counter
durationH res 1; high duration counter
sustainL res 1; low sustain counter
sustainH res 1; high sustain counter 
tempL res 1 ; low temporary storage
tempH res 1; high temporary storage
accL res 1 ; low accumulator 
accH res 1 ; high accumulator
 
;;;;;;;;;;;;;;;;
;   code
;;;;;;;;;;;;;;;;	
	org 0
	goto init

	org 4
isr
	retfie
	
; PWM period count
; This 16 bits resolution values
; values computed for 8Mhz PWM_clk	
scale
	addwf PCL,F
	PR_CNT 15287  ; C4
	PR_CNT 14429  ; C4s
	PR_CNT 13621  ; D4
	PR_CNT 12855  ; D4s
	PR_CNT 12133  ; E4
	PR_CNT 11452  ; F4
	PR_CNT 10810  ; F4s
	PR_CNT 10203  ; G4
	PR_CNT 9631   ; G4s
	PR_CNT 9090   ; A4
	PR_CNT 8580   ; A4s
	PR_CNT 8098   ; B4
	
init
	banksel OSCCON
	;movlw (1<<SPLLEN)|(0xE<<3)
	;movwf OSCCON
	bsf OSCCON, SPLLEN
	; initialize stack pointer
	; use FSR0 comme stack pointer
	clrf FSR0H
	movlw 0x20
	movwf FSR0L
	banksel ANSELA
	clrf ANSELA
	; limit slew rate
	banksel SLRCONA
	movlw 0xff
	movwf SLRCONA
	; configure PWM pin as output
	banksel TRISA
	movlw ~((1<<RA0)|(1<<RA1)|(1<<RA2))
	movwf TRISA
	; clear PWMxDC, PWMxOF, PWMxPH, PWMxPR
	; PWM1
	movlw high PWM1PH
	movwf FSR1H
	movlw low PWM1PH
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf PWM1LDCON,LDA
	; PWM2
	movlw high PWM2PH
	movwf FSR1H
	movlw low PWM2PH
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf PWM2LDCON,LDA
	;PWM3
	movlw high PWM3PH
	movwf FSR1H
	movlw low PWM3PH
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf PWM3LDCON,LDA
	; active les 3 canaux pwm
	banksel PWM1CON
	movlw 0xC0
	movwf PWM1CON
	movwf PWM2CON
	movwf PWM3CON
	movlw 2<<PWM1PS0
	movwf PWM1CLKCON
	movwf PWM2CLKCON
	movwf PWM3CLKCON
main	
	bcf flags, F_OCTAVE
	movlw 0
	push
	movlw C4
	push
	call set_pwm_period
	movlw 1
	push
	movlw E4
	push
	call set_pwm_period
	movlw 2
	push
	movlw G4s
	push
	call set_pwm_period
	banksel TRISA
	bcf TRISA,RA4
	bcf TRISA,RA5
	banksel LATA
	bsf LATA,RA4
	bcf LATA,RA5
	goto $

	
	
;configure PWM channel to generate tone 50% duty cycle
; stack  ( idx chn -- )
; idx is scale table index
; chn is pwm channel {0,1,2}
set_pwm_period
	; tone period value in acc
	pop
	movwf tempL
	clrc
	rlf tempL,F
	movfw tempL
	call scale
	movwf accL
	incf tempL,W
	call scale
	movwf accH
	btfss flags, F_OCTAVE
	goto octave0
octave1
	clrc
	rrf accH,F
	rrf accL,F
octave0	
	banksel PWMEN
	pop
	xorlw CHN2
	skpnz
	goto pwm3
	xorlw CHN2
	xorlw CHN1
	skpnz
	goto pwm2
pwm1
	movfw accL
	movwf PWM1PRL
	movfw accH
	movwf PWM1PRH
	clrc
	rrf accH,W
	movwf PWM1DCH
	rrf accL,W
	movwf PWM1DCL
	bsf PWM1LDCON,LDA
	return
pwm2
	movfw accL
	movwf PWM2PRL
	movfw accH
	movwf PWM2PRH
	clrc
	rrf accH,W
	movwf PWM2DCH
	rrf accL,W
	movwf PWM2DCL
	bsf PWM2LDCON,LDA
	return
pwm3
	movfw accL
	movwf PWM3PRL
	movfw accH
	movwf PWM3PRH
	clrc
	rrf accH,W
	movwf PWM3DCH
	rrf accL,W
	movwf PWM3DCL
	bsf PWM3LDCON,LDA
	return
		
	
	
	
	
	
	
	
	
	
	movlw 0xd
	movwf FSR1H
	movlw 0x91
	movwf FSR1L
	pop
	movwf tempL
	pop
	movwf tempH
	clrc
	rlf tempH,F
	addwf tempH,W
	addwf PCL,F
channel0
	goto load_period
	nop
	nop
channel1
	movlw 0x10
	addwf FSR1L,F
	goto load_period
channel2
	movlw 0x20
	addwf FSR1L,F
load_period
	clrc
	rlf tempL,F
	movfw tempL
	call scale
	movwi 2[FSR1]
	incf tempL,W
	call scale 
	movwi 3[FSR1]
set_duty_cycle
	movwf tempL
	clrc 
	rrf tempL,W
	movwi 1[FSR1]
	moviw 2[FSR1]
	movwf tempL
	rrf tempL,W
	movwi 0[FSR1]
	banksel PWMLD
	movfw tempH
	addwf PCL,F
chn0_load
	bsf PWMLD,0
	return
chn1_load
	bsf PWMLD,1
	return
chn2_load	
	bsf PWMLD,2
	return
	
	end 
    
    
    


