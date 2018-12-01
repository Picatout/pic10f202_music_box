    
    
    include p10f322.inc

    radix dec
    
    __config _FOSC_INTOSC & _BOREN_OFF & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   constantes
;;;;;;;;;;;;;;;;;;;;;;;;;;;

; nom des notes
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
PAUSE EQU .15

; durée des notes
WHOLE EQU .0
WHOLE_DOT EQU .1
HALF EQU .2
HALF_DOT EQU .3
QUARTER EQU .4
QUARTER_DOT EQU .5
HEIGTH EQU .6
HEIGTH_DOT EQU .7
SIXTHEENTH EQU .8
SIXTHEENTH_DOT EQU .9
; modification du prhasé
NORMAL EQU .12
STACCATO EQU .13
LEGATO EQU .14
 
; sélection du phrasé 
PHRASE_NORMAL EQU 0 ;  note soutenu au 3/4 de la durée
PHRASE_STACCATO EQU 1;  note soutenu 1/2 de la durée
PHRASE_LEGATO EQU 2 ;  les notes sont attachées
PHRASE_MASK EQU 0xC0 ; utilisé dans le décodage de la mélodie
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;
#define AUDIO_P RA0
#define AUDIO GPIO, AUDIO_P
#define ENV_P RA1
#define ENV LATA, ENV_P
#define LED_P RA2
#define LED LATA, LED_P 
#define BTN_P RA3
#define BTN LATA, BTN_P
    
 ; met la broche ENV_P en mode entreée haute impédance
 ; la broche AUDIO_P demeure en mode sortie
disable_env macro
    bsf TRISA, ENV_P
    bsf LED ; éteint
    endm

; met la broache ENV_P à hi.    
enable_env macro
    bcf TRISA, ENV_P
    bsf ENV
    bcf LED ; allume
    endm
    
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;    variables 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    udata
phrase_mode res 1 ; mode du phrasé {PHRASE_NORMAL,PHRASE_STACCATO,PHRASE_LEGATO}    
note_idx res 1 ; index de la note dans la table melody
play res 1; quel mélodie est jouée, index dans table play_list 
temp res 2 ; registres de travail temporaire
; accumulateur 24 bits
accL res 1 ; bits 0-7
accH res 1 ; bits 8-15
accU res 1 ; bit 16-23
 
    org 0
    goto init
    
    org 4
interupt
    
    retfie
    
    
    
    
    
init
    ; met la broche LED en mode sortie
    bcf TRISA, LED_P
    bsf LED ; led éteint
    ; met la broche audio en mode sortie
    bcf TRISA, AUDIO_P
    ; configure PWM1 pour sortie audio
    
main
    enable_env
    nop
    nop
    disable_env
    goto main

    sleep
    
    
    end