; Ocho secuencias de LEDs seleccionadas con un dato de 3 bits
; PIC16F887 - oscilador interno, TIMER0 como base de tiempo
; Entradas: RA2:RA0 (selector)    Salidas: RB7:RB0 (LEDs)
; Universidad del Cauca - 22-09-2026

LIST	P=16f887
#include "p16f887.inc"

; CONFIG1
 __CONFIG _CONFIG1, _FOSC_INTRC_CLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
 
; CONFIG2
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; Declaracion de variables
selector    equ 20h	; combinacion leida en RA2:RA0
sel_ant     equ 21h	; combinacion de la lectura anterior
paso        equ 22h	; paso actual dentro de la secuencia (0 a 7)
indice      equ 23h	; posicion dentro de la tabla de patrones
ticks       equ 24h	; desbordamientos de TIMER0 que faltan

N_TICKS     equ D'6'	; 6 x 65.5 ms = 393 ms por paso

RES_VECT  CODE    0x0000  ; vector de reset del procesador
    GOTO    START         ; va al inicio del programa

MAIN_PROG CODE            ; permite que el linker ubique el programa principal

START

; ======= **** Configuracion del microcontrolador **** =======

; Configuracion de puertos
    BANKSEL	PORTA
    CLRF	PORTA	    ; Inicializacion de PORTA (en ceros)
    CLRF	PORTB	    ; Inicializacion de PORTB (en ceros)

    BANKSEL	ANSEL
    CLRF	ANSEL	    ; PORTA como I/O digital
    CLRF	ANSELH	    ; PORTB como I/O digital

    BANKSEL	TRISA
    MOVLW	0xFF
    MOVWF	TRISA	    ; PORTA como entrada (selector en RA2:RA0)
    CLRF	TRISB	    ; PORTB como salida (8 LEDs)

    ; Configuracion del oscilador interno
    BANKSEL	OSCCON
    MOVLW	b'01100000' ; IRCF<2:0>=110 fija el oscilador interno a 4 MHz
    MOVWF	OSCCON	    ; SCS=0: el reloj del sistema lo determina FOSC (config bits)
    
; Configuracion del TIMER0
    BANKSEL	TMR0
    CLRF	TMR0	    ; Clarea el TIMER0 y el prescaler
    BANKSEL	OPTION_REG
    MOVLW	b'11010000' ; Mascara para seleccion del TIMER0, reloj interno y bits del prescaler
    ANDWF	OPTION_REG,W
    IORLW	b'00000111' ; Fija el prescaler a 1:256
    MOVWF	OPTION_REG

; Inicializacion de variables
    BANKSEL	PORTA
    CLRF	paso
    CLRF	indice
    CLRF	ticks
    MOVLW	0xFF
    MOVWF	sel_ant	    ; Valor imposible en 3 bits: fuerza el arranque desde el paso 0
    BCF		INTCON,T0IF ; Empieza a contar sin bandera pendiente

; ======= **** Bucle principal **** =======
LOOP
    CALL	LEER_SEL    ; Lee el selector
    CALL	SACAR_PATRON; Saca el patron que toca por PORTB
    CALL	RETARDO	    ; Mantiene el patron un tiempo fijo
    CALL	SIG_PASO    ; Avanza al siguiente paso
    GOTO	LOOP

; Si el selector cambio, la secuencia arranca de nuevo
LEER_SEL
    MOVF	PORTA,W
    ANDLW	b'00000111' ; Solo interesan RA2, RA1 y RA0
    MOVWF	selector
    XORWF	sel_ant,W   ; Compara con la lectura anterior
    BTFSC	STATUS,Z
    RETURN		    ; Misma combinacion: sigue la secuencia
    MOVF	selector,W
    MOVWF	sel_ant
    CLRF	paso
    RETURN

; indice = selector*8 + paso
SACAR_PATRON
    MOVF	selector,W
    MOVWF	indice
    BCF		STATUS,C
    RLF		indice,F
    BCF		STATUS,C
    RLF		indice,F
    BCF		STATUS,C
    RLF		indice,F    ; Tres corrimientos = selector x 8
    MOVF	paso,W
    ADDWF	indice,F
    CALL	TABLA
    MOVWF	PORTB
    RETURN

; Ocho pasos por secuencia, despues vuelve al primero
SIG_PASO
    INCF	paso,F
    MOVLW	b'00000111'
    ANDWF	paso,F
    RETURN

; Espera N_TICKS desbordamientos del TIMER0
RETARDO
    MOVLW	N_TICKS
    MOVWF	ticks
ESPERA
    BTFSS	INTCON,T0IF
    GOTO	ESPERA
    BCF		INTCON,T0IF ; Limpia la bandera para el siguiente conteo
    DECFSZ	ticks,F
    GOTO	ESPERA
    RETURN

; Devuelve en W el patron apuntado por indice
TABLA
    MOVLW	HIGH(PATRONES)
    MOVWF	PCLATH	    ; Pagina donde esta la tabla
    MOVF	indice,W
    ADDLW	LOW(PATRONES)
    BTFSC	STATUS,C
    INCF	PCLATH,F    ; Corrige si el salto cruza de pagina
    MOVWF	PCL

PATRONES
; 000 - un LED corre de RB0 hacia RB7
    RETLW	b'00000001'
    RETLW	b'00000010'
    RETLW	b'00000100'
    RETLW	b'00001000'
    RETLW	b'00010000'
    RETLW	b'00100000'
    RETLW	b'01000000'
    RETLW	b'10000000'
; 001 - un LED corre de RB7 hacia RB0
    RETLW	b'10000000'
    RETLW	b'01000000'
    RETLW	b'00100000'
    RETLW	b'00010000'
    RETLW	b'00001000'
    RETLW	b'00000100'
    RETLW	b'00000010'
    RETLW	b'00000001'
; 010 - se van encendiendo todos, de RB0 a RB7
    RETLW	b'00000001'
    RETLW	b'00000011'
    RETLW	b'00000111'
    RETLW	b'00001111'
    RETLW	b'00011111'
    RETLW	b'00111111'
    RETLW	b'01111111'
    RETLW	b'11111111'
; 011 - se van apagando todos, de RB0 a RB7
    RETLW	b'11111111'
    RETLW	b'11111110'
    RETLW	b'11111100'
    RETLW	b'11111000'
    RETLW	b'11110000'
    RETLW	b'11100000'
    RETLW	b'11000000'
    RETLW	b'10000000'
; 100 - pares e impares alternados
    RETLW	b'10101010'
    RETLW	b'01010101'
    RETLW	b'10101010'
    RETLW	b'01010101'
    RETLW	b'10101010'
    RETLW	b'01010101'
    RETLW	b'10101010'
    RETLW	b'01010101'
; 101 - abre desde el centro y cierra
    RETLW	b'00011000'
    RETLW	b'00111100'
    RETLW	b'01111110'
    RETLW	b'11111111'
    RETLW	b'01111110'
    RETLW	b'00111100'
    RETLW	b'00011000'
    RETLW	b'00000000'
; 110 - dos LEDs van de los extremos al centro y regresan
    RETLW	b'10000001'
    RETLW	b'01000010'
    RETLW	b'00100100'
    RETLW	b'00011000'
    RETLW	b'00100100'
    RETLW	b'01000010'
    RETLW	b'10000001'
    RETLW	b'00000000'
; 111 - los ocho LEDs parpadean juntos
    RETLW	b'11111111'
    RETLW	b'00000000'
    RETLW	b'11111111'
    RETLW	b'00000000'
    RETLW	b'11111111'
    RETLW	b'00000000'
    RETLW	b'11111111'
    RETLW	b'00000000'

    END
