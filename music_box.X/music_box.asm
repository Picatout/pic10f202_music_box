; NOM: music_box.asm
; DESCRIPTION: une boite à musique basée sur le PIC10F202
;AUTEUR: Jacqes Deschênes
;DATE: 2018-11-29
;REF: gamme tempérée: http://davbucci.chez-alice.fr/index.php?argument=musica/scala/scala.inc
;REF: happy birthday: http://en.wikipedia.org/wiki/File:GoodMorningToAll.svg

#include p10f202.inc

    __config  _WDTE_OFF & _MCLRE_OFF

    radix dec
   
;;;;;;;;;;;; constantes ;;;;;;;;;;
 
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
 
    
; indicateur booléen pour phase soutenue de la note
F_SUSTAIN EQU 0 ; position du bit dans flags
 
; sélection du phrasé 
PHRASE_NORMAL EQU 0 ;  note soutenu au 3/4 de la durée
PHRASE_STACCATO EQU 1;  note soutenu 1/2 de la durée
PHRASE_LEGATO EQU 2 ;  les notes sont attachées
PHRASE_MASK EQU 0xC0 ; utilisé dans le décodage de la mélodie
 
;;;;;;;;;;;; macros ;;;;;;;;;;;;;;
#define AUDIO_P GP0
#define AUDIO GPIO, AUDIO_P
#define ENV_P GP1
#define ENV GPIO, ENV_P
#define LED_P GP2
#define LED GPIO, LED_P 
#define BTN_P GP3
#define BTN GPIO, BTN_P
 
 ; met la broche ENV_P en mode entreée haute impédance
 ; la broche AUDIO_P demeure en mode sortie
disable_env macro
    movlw  ~(1<<AUDIO_P)
    tris GPIO
    endm

 ; met la  broche audio au niveau 1    
audio_hi macro
    bsf AUDIO
    endm

; met la broche audio au niveau 0    
audio_lo macro 
    bcf AUDIO
    endm
    
; met les broches AUDIO_P et ENV_P en mode sortie
enable_audio macro  
    movlw  ~((1<<AUDIO_P) | (1<<ENV_P) | (1<<LED_P))
    tris GPIO
    bcf LED
    bsf ENV
    endm

; met la broche audio en haute impédance (mode entrée)    
;3 instructions    
disable_audio macro  
    bcf ENV
    movlw ~(1<<ENV_P)
    tris GPIO
    endm

; délais demi-cycle pour générer une note
; 3 instructions    
delay_half_cycle macro 
    movfw TMR0
    skpz
    goto $-2
    endm


; macro pour aider l'écriture d'une table de mélodie
; paramètres:
;   nom de la note selon les définitions plus bas
;   duree de la note selon les définitions plus bas
NOTE macro nom, duree
    retlw (duree*.16)+nom
    endm
    
; modification du phrasé peut-être inséré n'importe où dans une table mélodie.
; p est une des valeur suivante 0,1,2
; 0 -> phrasé normal
; 1 -> phrasé staccato
; 2-> phrasé légato    
PMODE macro p
    retlw (0xC+(p&3))<<4
    endm
    
; instructions entête d'une mélodie
MELODY macro nom
nom 
    movfw tone_idx
    addwf PCL,F
    endm

; fin de la mélodie
MELODY_END macro
    retlw H'FF'
    endm

;;;;;;;;;;;; variables ;;;;;;;;;;;;
    udata
duration_cntr res 3 ; compteur pour délais durée notes
sustain_cntr res 3 ; durée maintenue de la note
freq_dly res 1 ; délais demi-cycle pour produire la fréquence x
phrase_mode res 1 ; mode du phrasé {PHRASE_NORMAL,PHRASE_STACCATO,PHRASE_LEGATO} 
tone_idx res 1 ; index de la note dans la table melody
flags res 1 ; indicateurs booléens
play res 1; quel mélodie est jouée, index dans table play_list 
temp res 2 ; registres de travail temporaire
; accumulateur 24 bits
accL res 1 ; bits 0-7
accH res 1 ; bits 8-15
accU res 1 ; bit 16-23
 
rst_vector org 0
    clrf OSCCAL
    nop
    goto init
; lien indirect aux sous-routine situées après 0xff
query_timeout
    goto query_timeout_upper
calc_sustain
    goto calc_sustain_upper
decay
    goto decay_upper
play_tone
    goto play_tone_upper
    
    

scale
; table des notes échelle tempérée
    addwf PCL, F
    dt .239  ;do4
    dt .225  ;do#4
    dt .212  ;ré4
    dt .201  ;ré#4
    dt .189  ;mi4
    dt .179  ;fa4
    dt .169  ;fa#4
    dt .159  ;sol4
    dt .150  ;sol#4
    dt .142  ;la4
    dt .134  ;la#4
    dt .126  ;si4
    dt .119  ;do5
    dt .112  ;do#5
    dt .106  ;ré5
    dt H'FE' ; pause

duration
; table des durées en multiple de 8 microsecondes
; tempo 120 noires (QUARTER_NOTE) / minutes 
; pour varier le tempo il faut recalculer les valeurs de
; cette table v= durée_note/8e-6
    addwf PCL, F
    dt low .250000, high .250000, upper .250000  ; WHOLE_NOTE
    dt low .375000, high .375000, upper .375000; WHOLE_NOTE.
    dt low .125000, high .125000, upper .125000    ; HALF_NOTE
    dt low .187500, high .187500, upper .187500  ; HALF_NOTE.
    dt low .62500, high .62500, 0   ; QUARTER_NOTE
    dt low .93750, high .93750, upper .93750 ; QUARTER_NOTE.
    dt low .31250, high .31250,0    ; HIEGTH_NOTE
    dt low .46875, high .46875, 0 ; HEIGTH_NOTE.
    dt low .15625, high .15625, 0 ; SIXTHEENTH_NOTE.
    dt low .23437, high .23437, 0 ; SXTHEENTH_NOTE.

    
play_list
    addwf PCL,F
    goto bon_tabac
    goto ode_joie
    goto beau_sapin
    goto claire_fontaine
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
;    MELODY joyeux_anniv
;    NOTE DO4,HEIGTH_DOT
;    NOTE DO4,SIXTEENTH
;    NOTE RE4,QUARTER
;    NOTE DO4,QUARTER
;    NOTE FA4,QUARTER
;    NOTE MI4,HALF
;    NOTE DO4,HEIGTH_DOT
;    NOTE DO4,SIXTEENTH
;    NOTE RE4,QUARTER
;    NOTE DO4,QUARTER
;    NOTE SOL4,QUARTER
;    NOTE FA4,HALF
;    NOTE DO4,HEIGTH_DOT
;    NOTE DO4,SIXTEENTH
;    NOTE DO5,QUARTER
;    NOTE LA4,QUARTER
;    NOTE FA4,QUARTER
;    NOTE MI4,QUARTER
;    NOTE RE4,QUARTER
;    NOTE SI4B,HEIGTH_DOT
;    NOTE SI4B,SIXTEENTH
;    NOTE LA4,QUARTER
;    NOTE FA4,QUARTER
;    NOTE SOL4,QUARTER
;    NOTE FA4,HALF
;    MELODY_END
;   
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
    NOTE .15,HEIGTH
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

    org 0x100
init
    ; timer clk=Fosc/4, diviseur=4
    ; fréquence timer=250Khz
    movlw ~((1<<T0CS) | (1<<PSA) | (1<<PS1) | (1<<PS2) | (1<<NOT_GPWU))
    option
    btfsc STATUS, GPWUF
    goto main
reset_list    
    clrf play
    comf play
main
    incf play
    clrf tone_idx
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
    incf tone_idx,F
    goto main01
main03
    movfw temp
    call play_tone
    incf tone_idx, F
    goto main01
main02
    sleep   ; terminé met le MCU en mode sleep pour ménager la pile.
    goto main

; décrémente duration_cntr
; à la sortie carry==0 si timeout    
query_timeout_upper
    movfw freq_dly
    subwf duration_cntr, F
    skpnc
    retlw 0
    movlw 1
    subwf duration_cntr+1, F
    skpnc
    retlw 0
    subwf duration_cntr+2, F
    retlw 0
    
; initialise la variable sustain_cntr
;  en fonction du mode phrasé
calc_sustain_upper
    movfw phrase_mode
    skpnz
    goto case_normal
    xorlw PHRASE_STACCATO
    skpnz
    goto case_staccato
case_legato ; note soutenue sur sa durée complète
    movfw duration_cntr+2
    movwf sustain_cntr+2
    movfw duration_cntr+1
    movwf sustain_cntr+1
    movfw duration_cntr
    movwf sustain_cntr
    goto set_flag
case_staccato ; note soutenu sur la moitié de sa durée    
    clrc
    rrf duration_cntr+2,W
    movwf sustain_cntr+2
    rrf duration_cntr+1,W
    movwf sustain_cntr+1
    rrf duration_cntr,W
    movwf sustain_cntr
    goto set_flag
case_normal ; la note est soutenue sur 3/4 de sa durée.    
    clrc
    rrf duration_cntr+2,W
    movwf sustain_cntr+2
    rrf duration_cntr+1,W
    movwf sustain_cntr+1
    rrf duration_cntr,W
    movwf sustain_cntr
    ;sustain_cntr=soustain_cntr+sustain_cntr/2
    clrc
    rrf sustain_cntr+2,W
    movwf accU
    rrf sustain_cntr+1,W
    movwf accH
    rrf sustain_cntr,W
    addwf sustain_cntr
    movlw 1
    skpnc
    addwf sustain_cntr+1
    skpnc
    addwf sustain_cntr+2
    movfw accH
    addwf sustain_cntr+1
    skpnc
    incf sustain_cntr+2
    movfw accU
    addwf sustain_cntr+2
set_flag    
    bsf flags, F_SUSTAIN
    retlw 0
    
; décrémente la variable sustain_cntr
; lorsque sustain_cntr<=0 met ENV_P en haute impédance    
decay_upper  
    btfss flags, F_SUSTAIN
    retlw 0
    movfw freq_dly
    subwf sustain_cntr,F
    skpnc
    retlw 0
    movlw 1
    subwf sustain_cntr+1,F
    skpnc
    retlw 0
    subwf sustain_cntr+2
    skpnc
    retlw 0
    disable_env ; 2 instructions
    bcf flags, F_SUSTAIN
    retlw 0
    
play_tone_upper
; joue une note
; note dans W
; bits 0-3 index de la note dans la table 'scale', 15=pause
; bits 4-6 index de la durée de la note dans la table 'duration'
    movwf temp
    movwf temp+1
    swapf temp, F ; durée dans le low nibble
    movlw H'F'
    andwf temp, F ; ne garde que le low nibble
    bcf STATUS, C ; multiplication par 3
    rlf temp, W
    addwf temp, F
    movfw temp
    call duration
    movwf duration_cntr  ; octet faible
    incf temp,F
    movfw temp
    call duration
    movwf duration_cntr+1 ;octet intermédiaire
    incf temp, W
    call duration
    movwf duration_cntr+2  ; octet fort
    enable_audio
    movlw H'F'
    andwf temp+1, F
    xorwf temp+1, W
    skpz
    goto play_tone01
    disable_audio  ; c'est une pause
play_tone01
    call calc_sustain ; initialise la variable sustain_cntr
    movfw temp+1
    call scale
    movwf freq_dly  ; délais en multiple de 4usec.
play_tone02
    audio_hi
    comf freq_dly, W
    addwf TMR0
    call decay ; décrémente sustain_cntr
    delay_half_cycle
    audio_lo
    comf freq_dly, W
    addwf TMR0
    call query_timeout
    skpc
    retlw 0
    delay_half_cycle
    goto play_tone02
    
    
    end
