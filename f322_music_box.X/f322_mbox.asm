    
    
    include p10f322.inc

    
    __config _FOSC_INTOSC & _BOREN_OFF & _WDTE_OFF & _PWRTE_ON

    radix dec

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   constantes
;;;;;;;;;;;;;;;;;;;;;;;;;;;
; délais pour TMR0
MS_DLY EQU 5
; indicateurs booléens dans la variable 'flags'
F_DONE EQU 0 ; bit 0
F_SUSTAIN EQU 1 ; bit 1
 
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
SIXTEENTH EQU .8
SIXTEENTH_DOT EQU .9
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
    bsf flags, F_SUSTAIN
    endm
    
; configure le PWM pour générer la note 
;  dont la valeur de la table scale est dans W
set_tone macro 
    movwf PR2
    clrf PWM1DCL
    clrc
    rrf PR2,W
    movwf PWM1DCH
    skpnc
    bsf PWM1DCL,7
    bcf flags, F_DONE
    endm
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   macros d'assistance à l'écriture 
;   des tables de mélodies
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; instructions entête d'une mélodie
MELODY macro nom
nom 
    movlw high (nom+7)
    movwf PCLATH
    movlw low (nom+7)
    addwf note_idx,W
    skpnc
    incf PCLATH
    movwf PCL
    endm

; fin de la mélodie
MELODY_END macro
    retlw H'FF'
    endm

; ajout d'une note à la table
; paramètres:
;   nom de la note selon les définitions plus bas
;   duree de la note selon les définitions plus bas
NOTE macro nom, duree
    retlw ((duree<<4)|nom)
    endm
    
; modification du phrasé peut-être inséré n'importe où dans une table mélodie.
; p est une des valeur suivante 0,1,2
; 0 -> phrasé normal
; 1 -> phrasé staccato
; 2-> phrasé légato    
PMODE macro p
    retlw (0xC+(p&3))<<4
    endm
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;    variables 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    udata
duration_cntr res 2; durée de la note, résolution 1msec
sustain_cntr res 2; durée soutenue de la note, résolution 1msec
phrase_mode res 1 ; mode du phrasé {PHRASE_NORMAL,PHRASE_STACCATO,PHRASE_LEGATO}    
note_idx res 1 ; index de la note dans la table melody
play res 1; quel mélodie est jouée, index dans table play_list 
flags res 1; indicateurs booléens
temp res 2 ; registres de travail temporaire
; accumulateur arithmétique 16 bits
accL res 1 ; bits 0-7
accH res 1 ; bits 8-15
 
    org 0
    goto init
    
    org 4
; interruption sur le compteur TMR0    
; décrémente duration_cntr et sustain_cntr    
isr 
    movlw MS_DLY
    addwf TMR0,F
    btfsc flags, F_DONE
    goto isr_exit
decr_duration
    movlw 1
    subwf duration_cntr,F
    skpnc
    goto decr_sustain
    subwf duration_cntr+1,F
    skpnc
    goto decr_sustain
    bsf flags, F_DONE
    bcf INTCON, TMR0IE
    goto isr_exit
decr_sustain
    btfss flags, F_SUSTAIN
    goto isr_exit
    movlw 1
    subwf sustain_cntr,F
    skpnc
    goto isr_exit
    subwf sustain_cntr+1,F
    skpnc
    goto isr_exit
    bcf flags, F_SUSTAIN
    disable_env
isr_exit    
    bcf INTCON, TMR0IF 
    retfie
    
scale
; table des notes échelle tempérée
    clrf PCLATH
    addwf PCL, F
    dt .238  ;do4
    dt .224  ;do#4
    dt .212  ;ré4
    dt .200  ;ré#4
    dt .189  ;mi4
    dt .178  ;fa4
    dt .168  ;fa#4
    dt .158  ;sol4
    dt .149  ;sol#4
    dt .141  ;la4
    dt .133  ;la#4
    dt .126  ;si4
    dt .118  ;do5
    dt .112  ;do#5
    dt .105  ;ré5
    dt H'FE' ; pause
    
duration
; table de durée des notes
; valeurs en millisecondes
; calculées pour un tempo de 120 noires/minute    
    clrf PCLATH
    addwf PCL,F
    dt low 2000, high 2000  ; ronde dure 2 secondes
    dt low 3000, high 3000  ; ronde.  3 secondes
    dt low 1000, high 1000  ; blanche
    dt low 1500, high 1500  ; blanche.
    dt low 500, high 500    ; noire
    dt low 750, high 750    ; noire.
    dt low 250, high 250    ; croche
    dt low 375, high 375    ; croche.
    dt low 125, high 125    ; double-croche
    dt low 62,  high 62     ;doucle-croche.
    
play_list
    addwf PCL,F
    goto claire_fontaine
    goto ode_joie
    goto bon_tabac
    goto beau_sapin
    goto joyeux_anniv
    goto reset_list


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   ajout des tables de mélodies ici
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
    
; J'ai du bon tabac dans ma tabatière
    MELODY bon_tabac
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
   
; ode à la joie de Beethoven
    MELODY ode_joie
    NOTE LA4,QUARTER
    NOTE LA4,QUARTER
    NOTE SI4B,QUARTER
    NOTE DO5, QUARTER
    NOTE DO5, QUARTER
    NOTE SI4B, QUARTER
    NOTE LA4, QUARTER
    NOTE SOL4, QUARTER
    NOTE FA4, QUARTER
    NOTE FA4, QUARTER
    NOTE SOL4, QUARTER
    NOTE LA4, QUARTER
    NOTE LA4, QUARTER_DOT
    NOTE SOL4, HEIGTH
    NOTE SOL4, HALF
    NOTE LA4, QUARTER
    NOTE LA4, QUARTER
    NOTE SI4B, QUARTER
    NOTE DO5,QUARTER
    NOTE DO5,QUARTER
    NOTE SI4B,QUARTER
    NOTE LA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,QUARTER
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4,QUARTER
    NOTE SOL4,QUARTER_DOT
    NOTE FA4,HEIGTH
    NOTE FA4,HALF
    NOTE SOL4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4,QUARTER
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4,HEIGTH
    NOTE SI4B,HEIGTH
    NOTE LA4,QUARTER
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE LA4,HEIGTH
    NOTE SI4B,HEIGTH
    NOTE LA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE FA4,QUARTER
    NOTE SOL4,QUARTER
    NOTE DO4,HALF
    NOTE LA4,QUARTER
    NOTE LA4,QUARTER
    NOTE SI4B,QUARTER
    NOTE DO5, QUARTER
    NOTE DO5, QUARTER
    NOTE SI4B, QUARTER
    NOTE LA4, QUARTER
    NOTE SOL4, QUARTER
    NOTE FA4, QUARTER
    NOTE FA4, QUARTER
    NOTE SOL4, QUARTER
    NOTE LA4, QUARTER
    NOTE SOL4, QUARTER_DOT
    NOTE FA4, HEIGTH
    NOTE FA4, HALF
    MELODY_END
    
; mon beau sapin
    MELODY beau_sapin
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
    
init
    ; met la broche LED en mode sortie
    bcf TRISA, LED_P
    bsf LED ; led éteint
    ; met la broche audio en mode sortie
    bcf TRISA, AUDIO_P
    ; met un weak pull sur RA3
    movlw 1<<BTN_P
    movwf WPUA
    ; configure TMR0 pre-scale pour utiliser COMME compteur de duré de la note
    movlw 2 ; PS=1:8  
    movwf OPTION_REG
    ; configure PWM1 pour sortie audio
    bsf PWM1CON, PWM1OE
    bsf PWM1CON, PWM1EN
    ; active TMR2 pour alimenter PMW1
    movlw (1<<TMR2ON)+2
    movwf T2CON
    movlw 1<<F_DONE
    movwf flags
    movlw (1<<TMR0IE)|(1<<GIE)
    movwf INTCON
    btfss STATUS, NOT_PD
    goto main
    
reset_list    
    clrf play
    comf play
main
    incf play
    clrf note_idx
    clrf phrase_mode
main01
    movfw play
    call play_list
    xorlw H'FF' ; marque la fin de la mélodie
    skpnz
    goto main02
    xorlw H'FF'
    movwf temp
    movlw 0xC0
    andwf temp,W
    xorlw 0xC0
    skpz
    goto main03
    ;changement de phrasé
    swapf temp,W
    andlw 3
    movwf phrase_mode
    incf note_idx,F
    goto main01
main03
    movfw temp
    call play_tone
    incf note_idx, F
    goto main01
main02
    sleep   ; terminé met le MCU en mode sleep pour ménager la pile.
    goto main

    
    

; calcule la durée soutenue de la note    
calc_sustain
    movfw phrase_mode
    skpnz
    goto case_normal
    xorlw PHRASE_STACCATO
    skpnz
    goto case_staccato
case_legato ; note soutenue sur sa durée complète
    movfw duration_cntr+1
    movwf sustain_cntr+1
    movfw duration_cntr
    movwf sustain_cntr
    return
case_staccato ; note soutenu sur la moitié de sa durée    
    clrc
    rrf duration_cntr+1,W
    movwf sustain_cntr+1
    rrf duration_cntr,W
    movwf sustain_cntr
    return
case_normal ; la note est soutenue sur 3/4 de sa durée.    
    clrc
    rrf duration_cntr+1,W
    movwf sustain_cntr+1
    rrf duration_cntr,W
    movwf sustain_cntr
    ;sustain_cntr=soustain_cntr+sustain_cntr/2
    clrc
    rrf sustain_cntr+1,W
    movwf accH
    rrf sustain_cntr,W
    addwf sustain_cntr
    skpnc
    incf sustain_cntr+1
    movfw accH
    addwf sustain_cntr+1,F
    return
    
    
; joue la note qui est dans W    
play_tone
    movwf temp
    swapf temp,W
    andlw 0xF
    movwf temp+1
    clrc
    rlf temp+1,F
    movfw temp+1
    call duration
    movwf duration_cntr
    incf temp+1,W
    call duration
    movwf duration_cntr+1
    call calc_sustain
    movfw temp
    andlw 0xF
    xorlw 0xF
    skpnz
    goto play_tone01
    xorlw 0xF
    call scale
    set_tone
    enable_env
play_tone01 ; pause    
    bsf INTCON,TMR0IE
    btfss flags, F_DONE
    goto $-1
    return
    
    
    end