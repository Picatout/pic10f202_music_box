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
    
	__config _CONFIG1, _FOSC_INTOSC&_WDTE_OFF&_PWRTE_OFF&_BOREN_OFF&_MCLRE_ON
	
	__config _CONFIG2, _PLLEN_ON&_STVREN_OFF&_LPBOREN_OFF&_LVP_OFF
	
	radix dec
	
;;;;;;;;;;;;;	
; constants	
;;;;;;;;;;;;;	
ENV_CLK EQU 15500 ; clock after prescale for ENV pwm
FOSC EQU 32000000  ; CPU oscillator frequency, PLLON
FCYCLE EQU 8000000  ; instruction cycle frequency
CPER EQU 125 ; intruction cycle in nanoseconds
; tone pwm
TONE EQU PWM1PH
TONE_RA EQU RA0 
; enveloppe pwm 
ENV EQU  PWM2PH
; offset pwm registers
PWMPHL EQU 0
PWMPHH EQU 1 
PWMDCL EQU 2 
PWMDCH EQU 3
PWMPRL EQU 4
PWMPRH EQU 5
PWMOFL EQU 6
PWMOFH EQU 7
PWMTMRL EQU 8
PWMTMRH EQU 9
PWMCON EQU 10
PWMINTE EQU 11
PWMINTF EQU 12
PWMCLKCON EQU 13 
PWMLDCON EQU 14
PWMOFCON EQU 15
; PWMCLKCON register 
PWMPS EQU 4 ; prescale select
PWMCS EQU 0 ; clock source select
 
 
ENV_PIR EQU PIR3
ENV_INTF EQU PWM2IF
ENV_PIE EQU PIE3
ENV_INTE EQU PWM2IE 
ENV_RA EQU RA1
 
; tempered scale 4th octave
C4 EQU 0
C4s EQU 1
D4f EQU 1
D4 EQU 2
D4s EQU 3
E4f EQU 3 
E4 EQU 4
F4 EQU 5
F4s EQU 6
G4f EQU 6
G4 EQU 7
G4s EQU 8
A4f EQU 8 
A4 EQU 9
A4s EQU 10
B4f EQU 10 
B4  EQU 11
C5  EQU 12
C5s EQU 13
D5f EQU 13
D5  EQU 14
PAUSE EQU 15
; note names in french
DO4 EQU .0
DO4D EQU .1
RE4B EQU .1
RE4 EQU .2
RE4D EQU .3
MI4B EQU .3 
MI4 EQU .4
FA4 EQU .5
FA4D EQU .6
SOL4B EQU .6
SOL4 EQU .7
SOL4D EQU .8
LA4B EQU .8 
LA4 EQU .9
LA4D EQU .10
SI4B EQU .10 
SI4  EQU .11
DO5 EQU .12
DO5D EQU .13
RE5B EQU .13 
RE5 EQU .14
 
 
; duration
WHOLE EQU 0
WHOLE_DOT EQU 1
HALF EQU 2
HALF_DOT EQU 3
QUARTER EQU 4
QUARTER_DOT EQU 5
HEIGTH EQU 6
HEIGTH_DOT EQU 7
SIXTEENTH EQU 8
SIXTEENTH_DOT EQU 9
; code 0xC to 0xF are commands
; stroke switch
STROKE_SWITCH EQU 0xE0
; octave switch
OCT_SWITCH EQU 0xF0   ; octave {O4,O5}
; commands mask
CMD_MASK EQU 0xC0
; end of staff
STAFF_END EQU 0xFF

; stroke type
NORMAL EQU 0
STACCATO EQU 1
LEGATO EQU 2
 
; octaves
O4 EQU 0
O5 EQU 1
 
; boolean flags
; bit position 
F_DONE EQU 0
F_OCTAVE EQU 1  ; set for O5, cleared for O4

 
;;;;;;;;;;;;;;;;;;;;;;;;
;   assembler macros 
;;;;;;;;;;;;;;;;;;;;;;;;

; and enable ENV pwm
env_enable macro
    banksel ENV
    clrf (ENV+PWMINTF)
    movlw 0xC0
    movwf (ENV+PWMCON)
    bcf flags,F_DONE
    endm
    
env_disable macro
    banksel ENV
    bcf (ENV+PWMCON),EN
    endm
 
;enable TONE pwm
tone_enable macro
    banksel TONE
    movlw 0xC0
    movwf (TONE+PWMCON)
    endm
    
;disable TONE pwm
tone_disable macro
    banksel TONE
    bcf (TONE+PWMCON),EN
    endm
    
    
; create an entry in scale table
; 'n' is given pwm period count    
PR_CNT macro n
    dt low n, high n
    endm
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   macros to assist melody table creation 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; insert melody table multiplexer code (begin a table)
MELODY macro name
name 
    movlw high (name+7)
    movwf PCLATH
    movlw low (name+7)
    addwf note_idx,W
    skpnc
    incf PCLATH
    movwf PCL
    endm

; compute duration value from tempo 
; This macro must be the first entry in melody table after MELODY
; Insert 16 bits data in low, high order
; arguments:    
;   'tempo' is  QUARTER/minute
TEMPO macro tempo    
    dt  low (ENV_CLK*60*4/tempo-1), high (ENV_CLK*60*4/tempo-1)
    endm
    
; insert end of table code (mark end of table)
MELODY_END macro
    retlw STAFF_END
    endm

    
; add staff note entry to melody table, one entry by staff note.
; arguments:
;   'name', note name {C4,C4s,D4f,....} 
;   'time', duration {WHOLE, WHOLE_DOT, HALF,...} 
NOTE macro name, time
    retlw ((time<<4)|name)
    endm
    
; set note stroke,  added as required by staff
; s, stroke type {NORMAL,STACCATO,LEGATO} 
STROKE macro s
    retlw STROKE_SWITCH|(s&0x3)
    endm
    
; switching octave
;  o, {O4, O5}
OCTAVE macro o    
    dt OCT_SWITCH|(o&1)
    endm
    
;;;;;;;;;;;;;;;
;  variables
;;;;;;;;;;;;;;;
stack_seg    udata 0x20 
stack res 16 ; arguments stack
 
var_seg  udata_shr 0x70
flags res 1 ; boolean flags  
note_idx res 1 ; current position staff
play res 1 ; current position in play_list table
stroke res 1 ; staff note stroke {NORMAL,STACCATO,LEGATO} 
; 16 bits working storgage
tempL res 1 ; low byte
tempH res 1; high byte
; working storage 3
temp3 res 1  
; 16 bits arithmetic accumulator
accL res 1 ; low byte
accH res 1 ; high byte
; note duration counter 16 bits value
; extracted from TEMPO entry in melody table 
durationL res 1 ; low byte
durationH res 1 ; high byte
led_dc_inc res 1 ; 
 
;;;;;;;;;;;;;;;;
;   code
;;;;;;;;;;;;;;;;	
	org 0
	goto init

	org 4
isr
led_ctrl_isr
	banksel PWM3INTF
	btfss PWM3INTF,PRIF
	goto env_isr
	bcf PWM3INTF,PRIF
	banksel PWM3DCL
	btfss led_dc_inc,7
	goto positive_slope
negative_slope	
	movlw 4
	subwf PWM3DCL,W
	skpnc
	goto change_dc
	goto invert_slope
positive_slope
	movlw 151
	subwf PWM3DCL,W
	skpc
	goto change_dc
invert_slope ; two's complement
	comf led_dc_inc,F
	incf led_dc_inc,F
change_dc
	movfw led_dc_inc
	addwf PWM3DCL,F
	bsf PWM3LDCON,LDA
	banksel PIR3
	bcf PIR3,PWM3IF
env_isr	
	btfsc flags,F_DONE
	goto isr_exit
	banksel ENV
	btfss (ENV+PWMINTF),PRIF
	goto isr_exit
	clrf (ENV+PWMINTF)
	bsf flags,F_DONE
isr_exit	
	banksel ENV_PIR
	bcf ENV_PIR,ENV_INTF
	retfie

	
; PWM period count
; This 16 bits resolution values
; values computed for 8Mhz PWM_clk	
scale
	clrf PCLATH
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
	PR_CNT 7644   ; C5
	PR_CNT 7215   ; C5s
	PR_CNT 6809   ; D5
	
; melodies play list
play_list
	clrf PCLATH
	addwf PCL,F
	goto o_canada
	goto concerto_3_m1_beethoven
	goto a_bytown
	goto ah_que_l_hiver
	goto go_down_moses
	goto amazin_grace
	goto greensleeves
	goto complainte_phoque
	goto god_save_the_queen
	goto melodia
	goto roi_dagobert
	goto frere_jacques
	goto ode_joy
	goto korobeiniki
	goto bon_tabac
	goto joyeux_anniv
	goto beau_sapin
	goto claire_fontaine
	goto reset_list

; PWM3 and CWG are used to
; control RED/GREEN LEDs
; PWM -> 200Hz period
; use interrupt on PRIF to 
; modify DC
; LED pulses in complementary	
config_led_control
	movlw 1
	movwf led_dc_inc
	; map CWGA -> RA5 and CWGB on RA4
	banksel APFCON
	movlw (1<<CWGASEL)|(1<<CWGBSEL)
	movwf APFCON
	; configure PWM3
	banksel PWM3PH
	clrf PWM3PHL
	clrf PWM3PHH
	clrf PWM3OFL
	clrf PWM3OFH
	bsf PWM3CLKCON,1 ; use LFINTOSC as source clock
	movlw 155
	movwf PWM3PRL
	clrf PWM3PRH
	movlw 77
	movwf PWM3DCL
	clrf PWM3DCH
	bsf PWM3LDCON,LDA
	; set interrupt on PR to modify DC
	bcf PWM3INTF,PRIF
	bsf PWM3INTE,PRIE
	bsf PWM3CON,EN
	bsf PWM3CON,OE
	; configure CWG
	banksel CWG1DBR
	bsf CWG1CON1,2; source is PWM3
	clrf CWG1DBR
	clrf CWG1DBF
	movlw (1<<G1EN)|(1<<G1OEA)|(1<<G1OEB)
	movwf CWG1CON0
	; enable interrupt in PIE3
	banksel PIE3
	bsf PIE3,PWM3IE
	return
	
init
	banksel OSCCON
	movlw (0xE<<IRCF0)
	movwf OSCCON
	banksel ANSELA
	clrf ANSELA
	; limit slew rate
	banksel SLRCONA
	movlw 0xff
	movwf SLRCONA
	; ensure ENV_RA==0 and TONE_RA=0
	banksel LATA
	bcf LATA,ENV_RA
	bcf LATA,TONE_RA
	; output pins: RA0,RA1,R2,RA4,RA5
	banksel TRISA
	clrf TRISA
	; power LED ON
	banksel LATA
	bcf LATA, RA2
	; bicolor led show
	call config_led_control
	; clear TONE PH, DC, PR, OF
	banksel TONE
	movlw high TONE
	movwf FSR1H
	movlw low TONE
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf (TONE+PWMLDCON),LDA
	; clear ENV PH, DC, PR, OF
	movlw high ENV
	movwf FSR1H
	movlw low ENV
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf (ENV+PWMLDCON),LDA
	; configure TONE pwm
	movlw 2<<PWMPS
	movwf (TONE+PWMCLKCON)
	movlw 0xC0
	movwf (TONE+PWMCON)
	; configure ENV pwm
	movwf (ENV+PWMCON)
	movlw (2<<PWMCS)|(1<<PWMPS)
	movwf (ENV+PWMCLKCON)
	; enable_interrupt for ENV DC and PR
	clrf (ENV+PWMINTF)
	bsf (ENV+PWMINTE),PRIE
	banksel ENV_PIE
	bsf ENV_PIE,ENV_INTE
	banksel INTCON
	movlw (1<<GIE)|(1<<PEIE)
	movwf INTCON
	btfss STATUS,NOT_PD
	goto main
reset_list
	clrf play
main
	clrf note_idx
	clrf stroke
	clrf flags
	movfw play
	call play_list
	movwf durationL
	incf note_idx,F
	movfw play
	call play_list
	movwf durationH
staff_loop
	incf note_idx
	movfw play
	call play_list
	movwf tempL
	xorlw STAFF_END
	skpnz
	goto melody_done
	movfw tempL
	andlw 0xF0
	xorlw OCT_SWITCH
	skpnz
	goto cmd_octave
	xorlw OCT_SWITCH
	xorlw STROKE_SWITCH
	skpnz
	goto cmd_stroke
	xorlw STROKE_SWITCH
	movlw 0xF
	andwf tempL,W
	xorlw PAUSE
	skpz
	goto tone
	swapf tempL,W
	andlw 0xF
	call pause
	goto staff_loop
tone
	movfw tempL
	call play_note
	goto staff_loop
cmd_octave
	bcf flags, F_OCTAVE
	btfsc tempL,0
	bsf flags, F_OCTAVE
	goto staff_loop
cmd_stroke
	movlw 3
	andwf tempL,W
	movwf stroke
	goto staff_loop
melody_done
	incf play,F
	;goto main
	call low_power
	sleep
	goto init

; configure �C for lowest current draw
; during sleep	
low_power
	banksel INTCON
	bcf INTCON, GIE
	banksel PWM3CON
	bcf PWM3CON,EN
	bcf PWM3CON,OE
	bcf PWM3INTE,PRIF
	bcf PWM3INTF,PRIF
	banksel CWG1CON0
	bcf CWG1CON0,G1OEA
	bcf CWG1CON0,G1OEB
	banksel LATA
	bcf LATA,RA4
	bcf LATA,RA5
	bsf LATA,RA2
	return

; disable any tone
; wait duration	
; arguemnents:
;   W  duration value extracted from melody table
;	value in low nibble	
pause
	call set_envelope
	env_enable
	btfss flags, F_DONE
	goto $-1
	env_disable
	return
	
; play staff note
; arguments:
;   W  note data extracted from melody table
;	low nibble note_idx
;	high nibble duration
play_note
	movwf temp3
	andlw 0xF
	call set_tone_freq
	swapf temp3,W
	andlw 0xF
	call set_envelope
	tone_enable
	env_enable
	btfss flags, F_DONE
	goto $-1
	tone_disable
	env_disable
	return
	
; set tone duration
; argument W duration value {WHOLE,DOTTED_WHOLE,...}	
set_envelope 
	movwf tempL
	banksel ENV
	; duration variable contain value for WHOLE
	movfw durationL
	movwf accL
	movfw durationH
	movwf accH
	clrc
	rrf tempL,W
	movwf tempH
; repeat devision by 2 until tempH==0
div2_loop	
	movfw tempH
	skpnz
	goto div_done
	clrc
	rrf accH,F
	rrf accL,F
	decf tempH,F
	goto div2_loop
div_done
; if it is dotted increase duration by 50%
	btfss tempL,0
	goto set_duration
	clrc
	rrf accH,W
	movwf tempH
	rrf accL,W
	addwf accL,F
	skpnc
	incf tempH,F
	movfw tempH
	addwf accH,F
set_duration	
	movfw accL
	movwf (ENV+PWMPRL)
	movfw accH
	movwf (ENV+PWMPRH)
	movlw LEGATO
	xorwf stroke,W
	skpnz
	goto legato_mode
	movlw STACCATO
	xorwf stroke,W
	skpnz
	goto staccato_mode
normal_mode ; 3/4 duration
	clrc
	rrf accH,F
	rrf accL,F
	clrc
	rrf accH,F
	rrf accL,W
	subwf (ENV+PWMPRL),W
	movwf accL
	skpc
	incf accH,F
	movfw accH
	subwf (ENV+PWMPRH),W
	movwf accH
	goto update_dc
staccato_mode ; 1/2 duration
	clrc
	rrf accH,F
	rrf accL,F 
	goto update_dc
legato_mode ; 7/8 duration
	movlw 3
	movwf tempL
div8
	movfw tempL
	skpnz
	goto div8_done
	clrc
	rrf accH,F
	rrf accL,F
	decf tempL,F
	goto div8
div8_done	
	movfw accL
	subwf (ENV+PWMPRL),W
	movwf accL
	skpc
	incf accH,F
	movfw accH
	subwf (ENV+PWMPRH),W
	movwf accH
update_dc
	movfw accL
	movwf (ENV+PWMDCL)
	movfw accH
	movwf (ENV+PWMDCH)
update_env
	clrf (ENV+PWMTMRL)
	clrf (ENV+PWMTMRH)
	bsf (ENV+PWMLDCON), LDA
	return
	
;configure PWM channel to generate tone 50% duty cycle
; argument W tone index for 'scale' table
set_tone_freq
	movwf tempL
	banksel TONE
	; set period
	clrc
	rlf tempL,F
	movfw tempL
	call scale
	movwf (TONE+PWMPRL)
	incf tempL,W
	call scale
	movwf (TONE+PWMPRH)
	btfss flags, F_OCTAVE
	goto octave0
octave1
	; shift octave over
	clrc
	rrf (TONE+PWMPRH),F
	rrf (TONE+PWMPRL),F
octave0	
	; set duty cycle
	clrc
	rrf (TONE+PWMPRH),W
	movwf (TONE+PWMDCH)
	rrf (TONE+PWMPRL),W
	movwf (TONE+PWMDCL)
	bsf (TONE+PWMLDCON),LDA
	return

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   melodies tables to end of memory	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; hymne national du Canada
	MELODY o_canada
	TEMPO 100
	OCTAVE O4
	;1
	NOTE LA4,HALF
	NOTE DO5, QUARTER_DOT
	NOTE DO5, HEIGTH
	;2
	NOTE FA4, HALF_DOT
	NOTE SOL4, QUARTER
	;3
	NOTE LA4, QUARTER
	NOTE SI4B, QUARTER
	NOTE DO5, QUARTER
	NOTE RE5, QUARTER
	;4
	NOTE SOL4, HALF_DOT
	NOTE PAUSE, QUARTER
	;5
	NOTE LA4, HALF
	NOTE SI4, QUARTER_DOT
	NOTE SI4, HEIGTH
	;6
	NOTE DO5, HALF_DOT
	NOTE RE5, QUARTER
	;7
	OCTAVE O5
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	OCTAVE O4
	NOTE RE5, QUARTER
	NOTE RE5, QUARTER
	;8
	NOTE DO5, HALF_DOT
	NOTE SOL4, HEIGTH_DOT
	NOTE LA4, SIXTEENTH
	;9
	NOTE SI4B, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SOL4,QUARTER
	NOTE LA4, HEIGTH_DOT
	NOTE SI4B, SIXTEENTH
	;10
	NOTE DO5,QUARTER_DOT
	NOTE SI4B,HEIGTH
	NOTE LA4,QUARTER
	NOTE SI4B,QUARTER_DOT
	NOTE DO5, SIXTEENTH
	;11
	NOTE RE5, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4B,QUARTER
	NOTE LA4, QUARTER
	;12
	NOTE SOL4, HALF_DOT
	NOTE SOL4, HEIGTH_DOT
	NOTE LA4, SIXTEENTH
	;13
	NOTE SI4B, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SOL4, QUARTER
	NOTE LA4, HEIGTH_DOT
	NOTE SI4B, SIXTEENTH
	;14
	NOTE DO5, QUARTER_DOT
	NOTE SI4B, HEIGTH
	NOTE LA4, QUARTER
	NOTE LA4, QUARTER
	;15
	NOTE SOL4, QUARTER
	NOTE DO5, QUARTER
	NOTE DO5, HEIGTH
	NOTE SI4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE SI4B, HEIGTH
	;16
	NOTE DO5, HALF_DOT
	NOTE PAUSE, QUARTER
	;17
	NOTE LA4, HALF
	NOTE DO5, QUARTER_DOT
	NOTE DO5, HEIGTH
	;18
	NOTE FA4, HALF_DOT
	NOTE PAUSE, QUARTER
	;19
	NOTE SI4B, HALF
	NOTE RE5, QUARTER_DOT
	NOTE RE5, HEIGTH
	;20
	NOTE SOL4, HALF_DOT
	NOTE PAUSE, QUARTER
	;21
	NOTE DO5, HALF
	NOTE DO5D, QUARTER_DOT
	NOTE DO5, HEIGTH
	;22
	NOTE RE5, QUARTER
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	;23
	NOTE FA4, HALF
	NOTE SOL4, HALF
	;24
	NOTE LA4, HALF_DOT
	NOTE PAUSE, QUARTER
	;25
	NOTE DO5, HALF
	OCTAVE O5
	NOTE FA4, QUARTER_DOT
	NOTE FA4, HEIGTH
	;26
	OCTAVE O4
	NOTE RE5, QUARTER
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	;27
	NOTE DO5, HALF
	NOTE MI4, HALF
	;28
	NOTE FA4, HALF_DOT
	NOTE PAUSE, QUARTER
	
	MELODY_END
	
; concerto pour piano no. 3 mouvement 1, Beetoven
	MELODY concerto_3_m1_beethoven
	TEMPO 120
	OCTAVE 4
	;1
	NOTE LA4, HALF
	NOTE SOL4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE SI4B, HEIGTH
	NOTE SOL4, HEIGTH
	;2
	NOTE FA4, HALF
	NOTE DO4, QUARTER_DOT
	NOTE FA4, HEIGTH
	;3
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	NOTE SOL4D, QUARTER
	;4
	NOTE SOL4D, HALF
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;5
	NOTE SI4B, HALF
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;6
	NOTE RE5, HALF
	NOTE DO5, QUARTER
	NOTE DO5, QUARTER
	;7
	NOTE SI4, QUARTER
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	NOTE RE5, QUARTER
	;8
	NOTE FA4, HALF
	NOTE MI4, HEIGTH
	NOTE RE5, HEIGTH
	NOTE DO5, HEIGTH
	NOTE SI4B, HEIGTH
	;9
	NOTE LA4, HALF
	NOTE SOL4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE SI4B, HEIGTH
	NOTE SOL4, HEIGTH
	;10
	NOTE FA4, HALF
	NOTE DO4, QUARTER_DOT
	NOTE FA4, HEIGTH
	;11
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	NOTE SOL4D, QUARTER
	;12
	NOTE SOL4D, HALF
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;13
	NOTE SI4B, HALF
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;14
	NOTE RE5, HALF
	NOTE DO5, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE SI4B, HEIGTH
	;15
	NOTE LA4, QUARTER
	NOTE LA4, QUARTER
	NOTE LA4, HEIGTH
	NOTE SOL4, HEIGTH
	NOTE FA4, HEIGTH
	NOTE SOL4, HEIGTH
	;16
	NOTE SOL4, QUARTER_DOT
	NOTE SOL4D, HEIGTH
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;17
	NOTE SI4B,HALF
	NOTE LA4, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE FA4, HEIGTH
	;18
	NOTE RE5, HALF
	NOTE DO5, QUARTER
	NOTE PAUSE, HEIGTH
	NOTE SI4B, HEIGTH
	;19
	NOTE LA4, QUARTER
	NOTE LA4, QUARTER
	NOTE LA4, HEIGTH
	NOTE SOL4, HEIGTH
	NOTE FA4, HEIGTH
	NOTE SOL4, HEIGTH
	;20
	NOTE SOL4, HALF
	NOTE FA4, QUARTER
	NOTE PAUSE, QUARTER
	
	MELODY_END
	
; A Bytown, c'est un' Joli' Place
	MELODY a_bytown
	TEMPO 120
	OCTAVE O4
	;1
	NOTE RE4, QUARTER
	NOTE SOL4, QUARTER
	;2
	STROKE LEGATO
	NOTE SOL4, QUARTER
	NOTE SOL4, HEIGTH
	STROKE NORMAL
	NOTE SI4, SIXTEENTH
	NOTE SI4, SIXTEENTH
	;3
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	;4
	NOTE MI4, HALF
	;5
	NOTE RE4, QUARTER
	NOTE FA4, QUARTER
	;6
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	;7
	NOTE SI4, QUARTER
	NOTE RE5, QUARTER
	;8
	NOTE SOL4, HALF
	;9
	NOTE PAUSE, QUARTER
	NOTE DO5, QUARTER
	;10
	NOTE SI4, QUARTER_DOT
	NOTE LA4, HEIGTH
	;11
	NOTE SI4, QUARTER
	NOTE RE5, QUARTER
	;12
	STROKE LEGATO
	NOTE SOL4, HALF
	;13
	NOTE SOL4, QUARTER
	STROKE NORMAL
	NOTE PAUSE, QUARTER
	;14
	NOTE RE4, QUARTER
	NOTE SOL4, QUARTER
	;15
	NOTE SOL4, QUARTER
	NOTE FA4, HEIGTH
	NOTE MI4, HEIGTH
	;16
	NOTE FA4, QUARTER_DOT
	NOTE SOL4, HEIGTH
	;17
	NOTE LA4, QUARTER_DOT
	NOTE FA4, HEIGTH
	;18
	NOTE SOL4, QUARTER
	NOTE RE5, QUARTER
	;19
	STROKE LEGATO
	NOTE RE5, QUARTER
	NOTE RE5, HEIGTH
	STROKE NORMAL
	NOTE DO5, HEIGTH
	NOTE DO5, HEIGTH
	;20
	NOTE SI4, QUARTER_DOT
	NOTE LA4, HEIGTH
	;21
	NOTE SOL4, QUARTER
	NOTE PAUSE, QUARTER
	MELODY_END
	
; ah! que l'hiver de Gilles Vigneault
	MELODY ah_que_l_hiver
	TEMPO 120
	OCTAVE O4
	;1
	NOTE LA4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE SOL4, HEIGTH
	;2
	NOTE FA4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE SOL4, HEIGTH
	NOTE FA4, HEIGTH
	;3
	NOTE RE4, QUARTER_DOT
	NOTE RE4, HEIGTH
	NOTE MI4, HEIGTH
	NOTE FA4, HEIGTH
	;4
	NOTE MI4, QUARTER_DOT
	NOTE MI4, HEIGTH
	NOTE FA4, HEIGTH
	NOTE SOL4, HEIGTH
	;5
	NOTE FA4, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE SOL4, HEIGTH
	;6
	NOTE FA4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE LA4, HEIGTH
	NOTE FA4, HEIGTH
	;7
	NOTE RE4, QUARTER_DOT
	NOTE MI4, HEIGTH
	NOTE MI4, HEIGTH
	NOTE MI4, HEIGTH
	;8
	NOTE LA4, QUARTER
	NOTE SOL4,HEIGTH
	NOTE FA4, QUARTER
	NOTE MI4, HEIGTH
	;9
	NOTE RE4, QUARTER
	
	MELODY_END
	
; go down moses
	MELODY go_down_moses
	TEMPO 120
	OCTAVE O4
	;1
	NOTE PAUSE, QUARTER
	NOTE PAUSE, QUARTER
	NOTE PAUSE, QUARTER
	NOTE MI4, QUARTER
	;2
	NOTE DO5, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4, QUARTER
	NOTE SI4, QUARTER
	;3
	NOTE DO5, HEIGTH
	NOTE DO5, QUARTER
	STROKE LEGATO
	NOTE LA4, HEIGTH
	NOTE LA4, QUARTER_DOT
	STROKE NORMAL
	NOTE PAUSE, HEIGTH
	;4
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	NOTE SOL4D, HEIGTH
	NOTE SOL4D, QUARTER_DOT
	;5
	NOTE LA4, HALF
	NOTE PAUSE, QUARTER
	NOTE MI4, QUARTER
	;6
	NOTE DO5, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4, QUARTER
	NOTE SI4, QUARTER
	;7
	NOTE DO5, HEIGTH
	NOTE DO5, QUARTER
	STROKE LEGATO
	NOTE LA4, HEIGTH
	NOTE LA4, QUARTER_DOT
	STROKE NORMAL
	NOTE PAUSE, HEIGTH
	;8
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	NOTE SOL4D, HEIGTH
	NOTE SOL4D, QUARTER_DOT
	;9
	NOTE LA4, WHOLE
	;10
	NOTE LA4, HEIGTH
	STROKE LEGATO
	NOTE LA4, QUARTER_DOT
	NOTE LA4, HALF
	STROKE NORMAL
	;11
	NOTE RE5, HEIGTH
	STROKE LEGATO
	NOTE RE5, QUARTER_DOT
	NOTE RE5, HALF
	STROKE NORMAL
	;12
	OCTAVE O5
	NOTE MI4, HALF
	NOTE MI4, QUARTER_DOT
	NOTE RE4, HEIGTH
	;13
	NOTE MI4, HEIGTH
	NOTE MI4, QUARTER
	OCTAVE O4
	NOTE RE5, HEIGTH
	NOTE DO5, HEIGTH
	NOTE LA4, QUARTER_DOT
	;14
	NOTE DO5, HEIGTH
	STROKE LEGATO
	NOTE LA4, QUARTER_DOT
	NOTE LA4, QUARTER
	STROKE NORMAL
	NOTE PAUSE, QUARTER
	;15
	NOTE DO5, HEIGTH
	STROKE LEGATO
	NOTE LA4, QUARTER_DOT
	NOTE LA4, QUARTER_DOT
	STROKE NORMAL
	NOTE MI4, HEIGTH
	;16
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	NOTE SOL4D, HEIGTH
	NOTE SOL4D, QUARTER_DOT
	;17
	NOTE LA4, HALF_DOT
	NOTE PAUSE, QUARTER
	MELODY_END
	
; amazing grace
; REF: https://www.apprendrelaflute.com/amazing-grace-a-la-flute-a-bec	
	MELODY amazin_grace
	TEMPO 120
	OCTAVE O4
	;1
	NOTE SOL4, QUARTER
	;2
	NOTE DO5, HALF
	OCTAVE O5
	NOTE MI4, HEIGTH
	NOTE DO4, HEIGTH
	;3
	NOTE MI4, HALF
	NOTE RE4, QUARTER
	;4
	NOTE DO4, HALF
	OCTAVE O4
	NOTE LA4, QUARTER
	;5
	NOTE SOL4, HALF
	NOTE SOL4, QUARTER
	;6
	NOTE DO5, HALF
	OCTAVE O5
	NOTE MI4, HEIGTH
	NOTE DO4, HEIGTH
	;7
	NOTE MI4, HALF
	NOTE RE4, QUARTER
	;8
	STROKE LEGATO
	NOTE SOL4, HALF_DOT
	;9
	STROKE NORMAL
	NOTE SOL4, HALF
	NOTE MI4, QUARTER
	;10
	NOTE SOL4, QUARTER_DOT
	NOTE MI4, HEIGTH
	NOTE SOL4, HEIGTH
	NOTE MI4, HEIGTH
	;11
	OCTAVE O4
	NOTE DO5, HALF
	NOTE SOL4, QUARTER
	;12
	NOTE LA4, QUARTER_DOT
	NOTE DO5, HEIGTH
	NOTE DO5, HEIGTH
	NOTE LA4, HEIGTH
	;13
	NOTE SOL4, HALF
	NOTE SOL4, QUARTER
	;14
	NOTE DO5, HALF
	OCTAVE O5
	NOTE MI4, HEIGTH
	NOTE DO4, HEIGTH
	;15
	NOTE MI4, HALF
	NOTE RE4, QUARTER
	STROKE LEGATO
	OCTAVE O4
	NOTE DO5, HALF_DOT
	;16
	NOTE DO5, HALF_DOT
	STROKE NORMAL
	MELODY_END
	
; greensleeves
; REF: https://www.apprendrelaflute.com/greensleeves-a-la-flute-a-bec
	MELODY greensleeves
	TEMPO 120
	OCTAVE O4
	;1
	NOTE PAUSE, QUARTER
	NOTE PAUSE, QUARTER
	NOTE LA4, QUARTER
	;2
	STROKE LEGATO
	NOTE DO5, HALF
	STROKE NORMAL
	NOTE RE5, QUARTER
	;3
	OCTAVE O5
	NOTE MI4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE MI4, QUARTER
	;4
	STROKE LEGATO
	NOTE RE4, HALF
	STROKE NORMAL
	OCTAVE O4
	NOTE SI4, QUARTER
	;5
	NOTE SOL4, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SI4, QUARTER
	;6
	STROKE LEGATO
	NOTE DO5, HALF
	STROKE NORMAL
	NOTE LA4, QUARTER
	;7
	NOTE LA4, QUARTER_DOT
	NOTE SOL4D, HEIGTH
	NOTE LA4, QUARTER
	;8
	NOTE SI4, HALF
	NOTE SOL4D, QUARTER
	;9
	NOTE MI4, HALF
	NOTE LA4, QUARTER
	;10
	NOTE DO5, HALF
	NOTE RE5, QUARTER
	;11
	OCTAVE O5
	NOTE MI4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE MI4, QUARTER
	;12
	OCTAVE O4
	NOTE RE5, HALF
	NOTE SI4, QUARTER
	;13
	NOTE SOL4, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SI4, QUARTER
	;14
	NOTE DO5, QUARTER_DOT
	NOTE SI4, HEIGTH
	NOTE LA4, QUARTER
	;15
	NOTE SOL4D, QUARTER_DOT
	NOTE FA4D, HEIGTH
	NOTE SOL4D, HEIGTH
	;16
	NOTE LA4, HALF
	NOTE LA4, QUARTER
	;17
	NOTE LA4, HALF_DOT
	;18
	OCTAVE O5
	NOTE SOL4, HALF_DOT
	;19
	NOTE SOL4, QUARTER_DOT
	NOTE FA4D, HEIGTH
	NOTE MI4, QUARTER
	;20
	OCTAVE O4
	NOTE RE5, HALF
	NOTE SI4, QUARTER
	;21
	NOTE SOL4, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SI4, QUARTER
	;22
	NOTE DO5, HALF
	NOTE LA4, QUARTER
	;23
	NOTE LA4, QUARTER_DOT
	NOTE SOL4D, HEIGTH
	NOTE LA4, QUARTER
	;24
	NOTE SI4, HALF
	NOTE SOL4D, QUARTER
	;25
	NOTE MI4, HALF_DOT
	;26
	OCTAVE O5
	NOTE SOL4, HALF_DOT
	;27
	NOTE SOL4, QUARTER_DOT
	NOTE FA4D, HEIGTH
	NOTE MI4, QUARTER
	;28
	OCTAVE O4
	NOTE RE5, HALF
	NOTE SI4, QUARTER
	;29
	NOTE SOL4, QUARTER_DOT
	NOTE LA4, HEIGTH
	NOTE SI4, QUARTER
	;30
	NOTE DO5, QUARTER_DOT
	NOTE SI4, HEIGTH
	NOTE LA4, QUARTER
	;31
	NOTE SOL4D, QUARTER_DOT
	NOTE FA4D, HEIGTH
	NOTE SOL4D, QUARTER
	;32
	STROKE LEGATO
	NOTE LA4, HALF_DOT
	;33
	NOTE LA4, HALF
	STROKE NORMAL
	NOTE PAUSE, QUARTER
	MELODY_END
	
; La complainte du phoque en alaska (chorus)
	MELODY complainte_phoque
	TEMPO 120
	OCTAVE O4
	;1
	NOTE SOL4, HALF_DOT
	;2
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;3
	NOTE MI4, HALF
	NOTE RE4, HEIGTH
	NOTE MI4, HEIGTH
	;4
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;5
	NOTE MI4, HALF
	NOTE RE4, HEIGTH
	NOTE MI4, HEIGTH
	;6
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;7
	NOTE DO4, HALF
	NOTE DO4, HEIGTH
	NOTE DO4, HEIGTH
	;8
	NOTE DO4, QUARTER
	NOTE RE4, QUARTER
	NOTE MI4, QUARTER
	;9
	NOTE RE4, QUARTER
	NOTE MI4, QUARTER
	NOTE FA4, QUARTER
	;10
	NOTE SOL4, HALF
	NOTE PAUSE, HEIGTH
	NOTE SOL4, HEIGTH
	;11
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;12
	NOTE MI4, HALF
	NOTE MI4, HEIGTH
	NOTE FA4, HEIGTH
	;13
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;14
	NOTE MI4, HALF
	NOTE RE4, HEIGTH
	NOTE MI4, HEIGTH
	;15
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;16
	NOTE DO4, HALF
	NOTE DO4, HEIGTH
	NOTE DO4, HEIGTH
	;17
	NOTE DO4, QUARTER
	NOTE RE4, QUARTER
	NOTE FA4, QUARTER
	;18
	NOTE RE4, HALF
	MELODY_END
	
; god save de the queen
	MELODY god_save_the_queen
	TEMPO 120
	OCTAVE O5
	;1
	NOTE DO4, QUARTER
	NOTE DO4, QUARTER
	NOTE RE4, QUARTER
	;2
	OCTAVE O4
	NOTE SI4, QUARTER_DOT
	NOTE DO5, HEIGTH
	NOTE RE5, QUARTER
	;3
	OCTAVE O5
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	NOTE FA4, QUARTER
	;4
	NOTE MI4, QUARTER_DOT
	NOTE RE4, HEIGTH
	NOTE DO4, QUARTER
	;5
	OCTAVE O4
	NOTE RE5, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4, QUARTER
	;6
	NOTE DO5, HALF_DOT
	;7
	OCTAVE O5
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	NOTE SOL4, QUARTER
	;8
	NOTE SOL4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE MI4, QUARTER
	;9
	NOTE FA4, QUARTER
	NOTE FA4, QUARTER
	NOTE FA4, QUARTER
	;10
	NOTE FA4, QUARTER_DOT
	NOTE MI4, HEIGTH
	NOTE RE4, QUARTER
	;11
	NOTE MI4, QUARTER
	NOTE FA4, HEIGTH
	NOTE MI4, HEIGTH
	NOTE RE4, HEIGTH
	NOTE DO4, HEIGTH
	;12
	NOTE MI4, QUARTER_DOT
	NOTE FA4, HEIGTH
	NOTE SOL4, QUARTER
	;13
	NOTE LA4, HEIGTH
	NOTE FA4, HEIGTH
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;13
	NOTE DO4, HALF_DOT
	
	MELODY_END
	
; melodia
; REF: https://www.apprendrelaflute.com/melodia-musique-du-film-jeux-interdits-flute-a-bec
	MELODY melodia
	TEMPO 120
	OCTAVE O4
	;1
	NOTE LA4, QUARTER
	NOTE LA4, QUARTER
	NOTE LA4, QUARTER
	;2
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE FA4, QUARTER
	;3
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;4
	NOTE RE4, QUARTER
	NOTE FA4, QUARTER
	NOTE LA4, QUARTER
	;5
	NOTE RE5, QUARTER
	NOTE RE5, QUARTER
	NOTE RE5, QUARTER
	;6
	NOTE RE5, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4B, QUARTER
	;7
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	;8
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	NOTE SI4B, QUARTER
	;9
	NOTE LA4, QUARTER
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	;10
	NOTE DO5D, QUARTER
	NOTE SI4B, QUARTER
	NOTE LA4, QUARTER
	;11
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE FA4, QUARTER
	;12
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	NOTE RE4, QUARTER
	;13
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	NOTE MI4, QUARTER
	;14
	NOTE MI4, QUARTER
	NOTE FA4, QUARTER
	NOTE MI4, QUARTER
	;15
	NOTE RE4, HALF_DOT
	MELODY_END
	
	
; Le bon roi Dagobert
; REF: https://www.apprendrelaflute.com/le-bon-roi-dagobert-a-la-flute-a-bec
	MELODY roi_dagobert
	TEMPO 140
	OCTAVE O4
	;1
	NOTE PAUSE, QUARTER
	NOTE PAUSE, QUARTER
	NOTE SI4, QUARTER
	;2
	NOTE SI4, HALF
	NOTE LA4, QUARTER
	;3
	NOTE LA4, HALF
	NOTE SOL4, QUARTER
	;4
	NOTE SOL4, QUARTER_DOT
	;5
	NOTE LA4, QUARTER_DOT
	;6
	NOTE SI4, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4, QUARTER
	;7
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	;8
	NOTE SOL4, QUARTER_DOT
	;9
	NOTE PAUSE, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	;10
	NOTE SI4, HALF
	NOTE SI4, QUARTER
	;11
	NOTE SI4, QUARTER
	NOTE DO5, QUARTER
	NOTE RE5, QUARTER
	;12
	NOTE LA4, HALF
	NOTE LA4, QUARTER
	;13
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	;14
	NOTE SI4, HALF
	NOTE SI4, QUARTER
	;15
	NOTE SI4, QUARTER
	NOTE DO5, QUARTER
	NOTE RE5, QUARTER
	;16
	NOTE LA4, HALF
	NOTE LA4, QUARTER
	;17
	NOTE LA4, HALF
	NOTE LA4, QUARTER
	;18
	NOTE SI4, HALF
	NOTE LA4, QUARTER
	;19
	NOTE LA4, HALF
	NOTE SOL4, QUARTER
	;20
	NOTE SOL4, QUARTER_DOT
	;21
	NOTE LA4, QUARTER_DOT
	;22
	NOTE SI4, QUARTER
	NOTE DO5, QUARTER
	NOTE SI4, QUARTER
	;23
	NOTE LA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	;24
	NOTE SOL4, HALF_DOT
	MELODY_END
	
; fr�re Jacques
; ref: https://www.apprendrelaflute.com/lecon-5-frere-jacques
	MELODY frere_jacques
	TEMPO 120
	OCTAVE O4
	;1
	NOTE FA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	NOTE FA4, QUARTER
	;2
	NOTE FA4, QUARTER
	NOTE SOL4, QUARTER
	NOTE LA4, QUARTER
	NOTE FA4, QUARTER
	;3
	NOTE LA4, QUARTER
	NOTE SI4B, QUARTER
	NOTE DO5, HALF
	;4
	NOTE LA4, QUARTER
	NOTE SI4B, QUARTER
	NOTE DO5, HALF
	;5
	NOTE DO5,HEIGTH_DOT
	NOTE RE5,SIXTEENTH
	NOTE DO5, HEIGTH
	NOTE SI4B, HEIGTH
	NOTE LA4, QUARTER
	NOTE FA4, QUARTER
	;6
	NOTE DO5,HEIGTH_DOT
	NOTE RE5,SIXTEENTH
	NOTE DO5, HEIGTH
	NOTE SI4B, HEIGTH
	NOTE LA4, QUARTER
	NOTE FA4, QUARTER
	;7
	NOTE FA4, QUARTER
	NOTE DO4, QUARTER
	NOTE FA4, HALF
	;8
	NOTE FA4, QUARTER
	NOTE DO4, QUARTER
	NOTE FA4, HALF
	MELODY_END
	
; ode to joy , Beethoven
; REF: https://www.apprendrelaflute.com/lecon-6-ode-a-la-joie	
    MELODY ode_joy
    TEMPO 140
    OCTAVE O4
    ;1
    NOTE A4,QUARTER
    NOTE A4,QUARTER
    NOTE B4f,QUARTER
    OCTAVE O5
    NOTE C4, QUARTER
    ;2
    NOTE C4, QUARTER
    OCTAVE O4
    NOTE B4f, QUARTER
    NOTE A4, QUARTER
    NOTE G4, QUARTER
    ;3
    NOTE F4, QUARTER
    NOTE F4, QUARTER
    NOTE G4, QUARTER
    NOTE A4, QUARTER
    ;4
    NOTE A4, QUARTER_DOT
    NOTE G4, HEIGTH
    NOTE G4, HALF
    ;5
    NOTE A4, QUARTER
    NOTE A4, QUARTER
    NOTE B4f, QUARTER
    OCTAVE O5
    NOTE C4, QUARTER
    ;6
    NOTE C4, QUARTER
    OCTAVE O4
    NOTE B4f, QUARTER
    NOTE A4, QUARTER
    NOTE G4, QUARTER
    ;7
    NOTE F4, QUARTER
    NOTE F4,QUARTER
    NOTE G4,QUARTER
    NOTE A4,QUARTER
    ;8
    NOTE G4,QUARTER_DOT
    NOTE F4,HEIGTH
    NOTE F4,HALF
    ;9
    NOTE G4,QUARTER
    NOTE G4,QUARTER
    NOTE A4,QUARTER
    NOTE F4,QUARTER
    ;10
    NOTE G4,QUARTER
    STROKE LEGATO
    NOTE A4,HEIGTH
    NOTE B4f,HEIGTH
    STROKE NORMAL
    NOTE A4,QUARTER
    NOTE F4,QUARTER
    ;11
    NOTE G4,QUARTER
    STROKE LEGATO
    NOTE A4,HEIGTH
    NOTE B4f,HEIGTH
    STROKE NORMAL
    NOTE A4,QUARTER
    NOTE G4,QUARTER
    ;12
    NOTE F4,QUARTER
    NOTE G4,QUARTER
    NOTE C4,HALF
    ;13
    NOTE A4, QUARTER
    NOTE A4, QUARTER
    NOTE B4f, QUARTER
    OCTAVE O5
    NOTE C4, QUARTER
    ;14
    NOTE C4, QUARTER
    OCTAVE O4
    NOTE B4f, QUARTER
    NOTE A4, QUARTER
    NOTE G4, QUARTER
    ;15
    NOTE F4, QUARTER
    NOTE F4, QUARTER
    NOTE G4, QUARTER
    NOTE A4, QUARTER
    ;16
    NOTE G4, QUARTER_DOT
    NOTE F4,HEIGTH
    NOTE F4, HALF
    MELODY_END

    ; tetris game theme
    ;REF: https://en.wikipedia.org/wiki/Korobeiniki
    MELODY korobeiniki
    TEMPO 90
    ;1
    OCTAVE O4
    NOTE E4,QUARTER_DOT
    NOTE G4s,HEIGTH
    NOTE B4,QUARTER
    NOTE G4,HEIGTH
    NOTE E4,HEIGTH
    ;2
    NOTE A4,QUARTER_DOT
    NOTE C5,HEIGTH
    OCTAVE O5
    NOTE E4,QUARTER
    OCTAVE O4
    NOTE D5,HEIGTH
    NOTE C5,HEIGTH
    ;3
    NOTE B4,QUARTER_DOT
    NOTE C5,HEIGTH
    NOTE D5,QUARTER
    OCTAVE O5
    NOTE E4,QUARTER
    ;4
    OCTAVE O4
    NOTE C5,QUARTER
    NOTE A4,QUARTER
    NOTE A4,HALF
    ;5
    OCTAVE O5
    NOTE F4,QUARTER_DOT
    NOTE G4, HEIGTH
    NOTE A4,QUARTER
    NOTE G4,HEIGTH
    NOTE F4,HEIGTH
    ;6
    NOTE E4,QUARTER_DOT
    NOTE F4,HEIGTH
    NOTE E4,QUARTER
    OCTAVE O4
    NOTE D5,HEIGTH
    NOTE C5,HEIGTH
    ;7
    NOTE B4,QUARTER_DOT
    NOTE C5,HEIGTH
    NOTE D5,QUARTER
    OCTAVE O5
    NOTE E4,QUARTER
    ;8
    OCTAVE O4
    NOTE C5,QUARTER
    NOTE A4,QUARTER
    NOTE A4,HALF
    MELODY_END

; J'ai du bon tabac dans ma tabati�re
    MELODY bon_tabac
    TEMPO 120
    NOTE SOL4,QUARTER
    NOTE LA4,QUARTER
    NOTE SI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4, HALF
    NOTE LA4, QUARTER
    NOTE SI4, QUARTER
    NOTE DO5, HALF
    NOTE DO5, HALF
    NOTE SI4, HALF
    NOTE SI4, HALF
    NOTE SOL4, QUARTER
    NOTE LA4, QUARTER
    NOTE SI4, QUARTER
    NOTE SOL4, QUARTER
    NOTE LA4, HALF
    NOTE LA4, QUARTER
    NOTE SI4, QUARTER
    NOTE DO5, HALF
    NOTE RE5, HALF
    NOTE SOL4, WHOLE
    NOTE RE5, HALF
    NOTE RE5, QUARTER
    NOTE DO5, QUARTER
    NOTE SI4,HALF
    NOTE LA4,QUARTER
    NOTE SI4,QUARTER
    NOTE DO5, HALF
    NOTE RE5, HALF
    NOTE LA4, WHOLE
    MELODY_END
    
; joyeux aniversaire    
    MELODY joyeux_anniv
    TEMPO 120
    NOTE DO4,HEIGTH_DOT
    NOTE DO4,SIXTEENTH
    NOTE RE4,QUARTER
    NOTE DO4,QUARTER
    NOTE FA4,QUARTER
    NOTE MI4,HALF
    NOTE DO4,HEIGTH_DOT
    NOTE DO4,SIXTEENTH
    NOTE RE4,QUARTER
    NOTE DO4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,HALF
    NOTE DO4,HEIGTH_DOT
    NOTE DO4,SIXTEENTH
    NOTE DO5,QUARTER
    NOTE LA4,QUARTER
    NOTE FA4,QUARTER
    NOTE MI4,QUARTER
    NOTE RE4,QUARTER
    NOTE SI4B,HEIGTH_DOT
    NOTE SI4B,SIXTEENTH
    NOTE LA4,QUARTER
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,HALF
    MELODY_END
 
; mon beau sapin
    MELODY beau_sapin
    TEMPO 100
    NOTE DO4,QUARTER
    NOTE FA4,HEIGTH_DOT
    NOTE FA4, SIXTEENTH
    NOTE FA4, QUARTER
    NOTE SOL4, QUARTER
    NOTE LA4, HEIGTH_DOT
    NOTE LA4,SIXTEENTH
    NOTE LA4,QUARTER_DOT
    NOTE LA4,HEIGTH
    NOTE SOL4,HEIGTH
    NOTE LA4,HEIGTH
    NOTE SI4B,QUARTER
    NOTE MI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,QUARTER
    NOTE PAUSE,HEIGTH
    NOTE DO5,HEIGTH
    NOTE DO5,HEIGTH
    NOTE LA4,HEIGTH
    NOTE RE5,QUARTER_DOT
    NOTE DO5,QUARTER
    NOTE DO5,QUARTER
    NOTE SI4B,HEIGTH
    NOTE SI4B,QUARTER_DOT
    NOTE SI4B,HEIGTH
    NOTE SI4B,HEIGTH
    NOTE SOL4,HEIGTH
    NOTE DO5,QUARTER_DOT
    NOTE SI4B,HEIGTH
    NOTE SI4B,HEIGTH
    NOTE LA4, HEIGTH
    NOTE LA4, QUARTER
    NOTE DO4, QUARTER
    NOTE FA4,HEIGTH_DOT
    NOTE FA4,SIXTEENTH
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4,HEIGTH_DOT
    NOTE LA4,SIXTEENTH
    NOTE LA4,QUARTER_DOT
    NOTE LA4,HEIGTH
    NOTE SOL4,HEIGTH
    NOTE LA4,HEIGTH
    NOTE SI4B,QUARTER
    NOTE MI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,HALF
    MELODY_END

    MELODY claire_fontaine
    TEMPO 100
    NOTE SOL4,HALF
    NOTE SOL4,QUARTER
    NOTE SI4,QUARTER
    NOTE SI4,QUARTER
    NOTE LA4,QUARTER
    NOTE SI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE SOL4,HALF
    NOTE SOL4,QUARTER
    NOTE SI4,QUARTER
    NOTE SI4,QUARTER
    NOTE LA4,QUARTER
    NOTE SI4,HALF
    NOTE SI4,HALF
    NOTE SI4,QUARTER
    NOTE LA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE SI4,QUARTER
    NOTE RE5,QUARTER
    NOTE SI4,QUARTER
    NOTE RE5,HALF
    NOTE RE5,QUARTER
    NOTE SI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE SI4,QUARTER
    NOTE LA4,HALF
    NOTE SOL4,HALF
    NOTE SOL4,QUARTER
    NOTE SI4,QUARTER
    NOTE SI4,QUARTER
    NOTE LA4,HEIGTH
    NOTE SOL4,HEIGTH
    NOTE SI4,QUARTER
    NOTE SOL4,QUARTER
    NOTE SI4, HALF
    NOTE SI4,QUARTER
    NOTE LA4,HEIGTH
    NOTE SOL4,HEIGTH
    NOTE SI4,QUARTER
    NOTE LA4,QUARTER
    NOTE SOL4,HALF
    MELODY_END 
    
	end 
    
    
    


