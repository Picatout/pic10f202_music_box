; NOM: music_box.asm
; DESCRIPTION: une boite à musique basée sur le PIC10F202
;AUTEUR: Jacqes Deschênes
;DATE: 2013-01-15
;REF: gamme tempérée: http://davbucci.chez-alice.fr/index.php?argument=musica/scala/scala.inc
;REF: happy birthday: http://en.wikipedia.org/wiki/File:GoodMorningToAll.svg

#include p10f202.inc

    __config  _WDTE_OFF & _MCLRE_OFF

;;;;;;;;;;;; constantes ;;;;;;;;;;

;durées notes
WHOLE_NOTE EQU 0
HALF_NOTE EQU 1
QUARTER_NOTE EQU 2
HEIGHT_NOTE EQU 3
SIXTEENTH EQU 4

PAUSE_BIT EQU 7

;;;;;;;;;;;; macros ;;;;;;;;;;;;;;
#define AUDIO_P GP0
#define AUDIO GPIO, AUDIO_P
#define ENV_P GP1
#define ENV GPIO, ENV_P
 
disable_env macro ; met la broche GP1 en mode entreée haute impédance
    movlw  ~(1<<AUDIO_P)
    endm
    
audio_hi macro ; met la  broche audio au niveau 1
    bsf AUDIO
    endm

audio_lo macro ; met la broche audio au niveau 0
    bcf AUDIO
    endm

enable_audio macro  ; met la broche audio en mode sortie
    movlw  ~((1<<AUDIO_P) | (1<<ENV_P))
    tris GPIO
    bsf ENV
    endm

disable_audio macro  ; met la broche audio en haute impédance (mode entrée)
    movlw H'FF'
    tris GPIO
    endm

delay_half_cycle macro ; délais demi-cycle pour générer une note
    comf freq_dly, W
    addwf TMR0
    movfw TMR0
    skpz
    goto $-2
    endm

skip_timeout macro  ; délais durée de la note
    movfw freq_dly
    subwf delay_cntr, F
    skpnc
    goto $+7
    movlw 1
    subwf delay_cntr+1, F
    skpnc
    goto $+3
    subwf delay_cntr+2, F
    skpnc
    endm

;;;;;;;;;;;; variables ;;;;;;;;;;;;
    udata
delay_cntr res 3 ; compteur pour délais durée notes
freq_dly res 1 ; délais demi-cycle pour produire la fréquence x
note_idx res 1 ; index de la note dans la table melody
temp res 2 ; registres de travail temporaire

rst_vector org 0
    clrf OSCCAL
    nop
    goto init


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
    addwf PCL, F
    dt low .62500, high .62500, 0    ; WHOLE_NOTE
    dt low .93750, high .93750, upper .93750; WHOLE_NOTE.
    dt low .31250, high .31250, 0    ; HALF_NOTE
    dt low .46875, high .46875, 0  ; HALF_NOTE.
    dt low .15625, high .15625,0   ; QUARTER_NOTE
    dt low .23437, high .23437, 0 ; QUARTER_NOTE.
    dt low .7812, high .7812,0    ; HIEGTH_NOTE
    dt low .11718, high .11718, 0 ; HEIGTH_NOTE.
    dt low .3906, high .3906, 0 ; SIXTHEENTH_NOTE.
    dt low .5859, high .5859, 0 ; SXTHEENTH_NOTE.

melody
; table de la mélodie 'happy birthday'
; bits 0-3 index de la note dans la table 'scale', 15=pause
; bits 4-6 index de la durée de la note dans la table 'duration'
    addwf PCL, F
    dt .82
    dt .98
    dt .20
    dt .18
    dt .23
    dt .5
    dt .82
    dt .98
    dt .20
    dt .18
    dt .25
    dt .7
    dt .82
    dt .98
    dt .30
    dt .27
    dt .23
    dt .21
    dt .20
    dt .92
    dt .108
    dt .27
    dt .23
    dt .25
    dt .7
    dt H'FF'


play_note
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
    movwf delay_cntr  ; octet faible
    incf temp,F
    movfw temp
    call duration
    movwf delay_cntr+1 ;octet intermédiaire
    incf temp, W
    call duration
    movwf delay_cntr+2  ; octet fort
    enable_audio
    movlw H'F'
    andwf temp+1, F
    xorwf temp+1, W
    skpz
    goto play_note01
    disable_audio  ; c'est une pause
play_note01
    movfw temp+1
    call scale
    movwf freq_dly  ; délais en multiple de 4usec.
play_note02
    audio_hi
    delay_half_cycle
    audio_lo
    delay_half_cycle
    skip_timeout
    goto play_note02
    retlw 0

init
    ; timer clk=Fosc/4, diviseur=4
    movlw H'FF' -(1<<T0CS) -(1<<PSA) -(1<<PS1) -(1<<PS2)
    option
    clrf note_idx

main
    movfw note_idx
    call melody
    xorlw H'FF' ; marque la fin de la mélodie
    skpnz
    goto main02
    xorlw H'FF'
    call play_note
    incf note_idx, F
    movlw .4*.16+.15
    call play_note ; brève pause entre les notes
    goto main
main02
    sleep   ; terminé met le MCU en mode sleep pour ménager la pile.
    goto $
    end
