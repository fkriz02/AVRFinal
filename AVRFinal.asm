; definice pro nas typ procesoru
.include "m169def.inc"
; podprogramy pro praci s displejem
.org 0x1000
.include "print.inc"
; countery
.dseg
.org 0x100
counter: .BYTE 1
counter2: .BYTE 1
minuty: .BYTE 1
sekundy: .BYTE 1
sekpred: .BYTE 1
des_sek: .BYTE 1

.cseg

; Zacatek programu - po resetu
.org 0x0
 jmp start

 .org 0xA
 jmp preruseni_timer

.org 0x100
start:
	; Inicializace zasobniku
	ldi r16, 0xFF
	out SPL, r16
	ldi r16, 0x04
	out SPH, r16
    
	; Inicializace displeje
	call init_disp

    ; Inicializace casovace
    call init_int

    ; Inicializace joysticku
    call init_joy

    ; vynulovani counteru
    call vynulovani

loop:
    call joystick_control
    call refresh_screen
    jmp loop   

init_joy:
    ; Inicializace Joysticku na PORTB
	in r17, DDRB
	andi r17, 0b00101111
	in r16, PORTB
	ori r16, 0b11010000
	out DDRB, r17
	out PORTB, r16
    ret

joystick_control:
    
	; nacti joystick
	in r16, PINE
	in r17, PINB
	andi r16, 0b00001100 ; vymaskuj
	andi r17, 0b11010000 ; vymaskuj
	or r16, r17 ; dej dohromady

	; chvili pockej
	ldi r18, 254
	cek: dec r18
	nop
	brne cek

	; nacti joystick znovu
	in r17, PINE
	in r18, PINB
	andi r17, 0b00001100 ; vymaskuj
	andi r18, 0b11010000 ; vymaskuj
	or r17, r18 ; dej dohromady
	cp r16, r17
	brne joystick_control

	; je zmacknuty nahoru? = povol globalni preruseni
	cpi r16, 0x9C
	brne neq
	sei
	ret 	; return to main loop

neq: 
	; je zmacknuty dolu? = zakaz globalni preruseni 
	cpi r16, 0x5C
	brne neq2
	cli
	ret 	; return to main loop

neq2:
	; je zmacknuty enter? = vynuluj countery
	cpi r16, 0xCC
	brne neq3
	
	push r16 
	in r16, SREG 
	push r16 
	push r17
	push r18
	push r19
	push r20
	push r21
	; nacti
	lds r16, counter
	lds r17, counter2
	lds r18, des_sek 
	lds r19, sekundy
	lds r20, minuty
	lds r21, sekpred
	; vynuluj
	ldi r16, 0
	ldi r17, 0
	ldi r18, 0 
	ldi r19, 0
	ldi r20, 0
	ldi r21, 0
	; uloz	
	sts counter, r16
	sts counter2, r17
	sts des_sek, r18
	sts sekundy, r19
	sts minuty, r20
	sts sekpred, r21
	; vse ze "vyber" ze zasobniku
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16


neq3:
	ret 	; return to main loop


refresh_screen:
    disp_rfrsh:	; resfresh the display
	ldi r22, 0x30		; 48 (pro ziskani ASCII kodu cisla)

	lds r20, minuty
	add r20, r22
	mov	r16, r20		; ASCII kod do zobrozovaciho registru
	ldi r17, 2      	; pozice
	call show_char  	
	
	lds r20, sekpred
	add r20, r22
	mov r16, r20		
	ldi r17, 4     	 
	call show_char 	 

	lds r20, sekundy
	add r20, r22
	mov r16, r20		
	ldi r17, 5      
	call show_char  


	lds r20, des_sek
	add r20, r22
	mov r16, r20	
	ldi r17, 7      	
	call show_char  
ret



init_int:            ; 1
    cli              ; globalni zakazani preruseni
    ldi r16, 0b00001000
    sts ASSR, r16    ; vyber hodin od externiho krystaloveho oscilátoru 32768 Hz
    ldi r16, 0b00000001
    sts TIMSK2, r16  ; povoleni preruseni od casovace 2 2
    ldi r16, 0b00000001
    sts TCCR2A, r16  ; nastaveni deliciho pomeru 1024
    clr r16
    out EIMSK, r16   ; zakazani preruseni od joysticku
    sei              ; globalni povoleni preruseni
ret

vynulovani:
    ldi r16, 0
	sts counter, r16
	sts des_sek, r16
	sts sekundy, r16
	sts sekpred, r16
	sts minuty, r16

preruseni_timer:
    cli

	; nacpi vse do zasobniku
	push r16 
	in r16, SREG 
	push r16 
	push r17
	push r18
	push r19
	push r20
	push r21

	lds r16, counter
	lds r17, counter2
	lds r18, des_sek 
	lds r19, sekundy
	lds r20, minuty
	lds r21, sekpred

	inc r16		; inkrementujeme counter preruseni
	cpi r17, 10	; chceme pricist desetiny po desate?
	brne desetiny	; desetiny chceme inkrementovat po 13 prerusenich

	cpi r16, 11	; desetiny chceme inkrementovat po 11 prerusenich
	brne save_val
	ldi r16, 0	; nastavime counter preruseni na 0
	ldi r17, 0	; nastavime counter pricitani desetin na nulu
	ldi r18, 0	; nastav desetiny na nulu a ->
	inc r19		; inkrementuj sekundy

desetiny:
	cpi r16, 13 ; 9x jednou za 13 preruseni inkrementuju desetiny
	brne save_val
	ldi r16, 0	; nastavime counter preruseni na 0
	inc r17		; increment counter2
	inc r18		; pridame desetinu

save_val:
	cpi r18, 10
	brne sek
	ldi r18, 0
	inc r19

sek:
	cpi r19, 10
	brne min
	ldi r19, 0
	inc r21

min:
	cpi r21, 6	; pricti minuty, pokud na vyssim radu sekund je 6
	brne save
	ldi r21, 0
	inc r20

save:	
	sts counter, r16
	sts counter2, r17
	sts des_sek, r18
	sts sekundy, r19
	sts minuty, r20
	sts sekpred, r21

	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16

	sei		; povol preruseni

reti


endloop:
    jmp endloop