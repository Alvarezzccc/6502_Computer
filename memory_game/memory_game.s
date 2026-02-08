DDRA = $6003
DDRB = $6002
PORTA = $6001
PORTB = $6000
PCR = $600C ; Peripheral Control Register from VIA 6622
IFR = $600D ; Interrupt Flag Register from VIA 6622
IER = $600E ; Interrupt Enable Register from VIA 6622

SELECT_BUTTON = %00000001
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00010000
UP_BUTTON = %00000100
DOWN_BUTTON = %00001000 ; This is the physical address flag where the button signal will arrive in the 65C22 VIA at PORTA

LEFT_ARROW = $7F
RIGHT_ARROW = $7E
PLUS_CHAR = $2B
MINUS_CHAR = $2D

ROUNDS_ARRAY      = $2000  ; 32 bytes: $2000..$201F (sequence to reproduce)
ID_ROUND          = $2020  ; 0..31  (current round length-1, or “last index”)
CURRENT_ROUND_POS = $2021  ; 0..ID_ROUND (user progress within current round)
LAST_INPUT        = $2022  ; last button in THIS round (for “no repeats” rule)

MESSAGE_POINTER = $00    ; 2 bytes: position of message to print with subroutine


; VARIABLES FOR THE LCD SCREEN CONFIGURATION

E = %10000000
RW = %01000000
RS = %00100000


  .org $8000
 
reset:
  ldx #$ff
  txs		 ; Initializing the stack pointer at the top of the stack 

  sei    ; setting the interrupt disable bit to prevent a misconfiguration when initializing
 
  lda #$10
  sta PCR ; Write a 1 in the CB1 flag so that the raising edge is the one receiving the interrupt in the VIA

  lda PORTB ; Read port B for the VIA to reset it

  lda #$90
  sta IER ; Setting the Interrupt Enable Register to receive interrupts from CA1 (in the Versatile Interface Adapter) and the Set/Clear flag

  cli ; clear the interrupt disable bit to allow interruptions

  
  lda #%11111111 ; Set all the pins of PORTB to outputs
  sta DDRB
  lda #%11100000 ; Initialize DDRA to be outputs for the E R/W and RS 
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font	
  jsr lcd_instruction
  lda #%00001110 ; Display on; Cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display	
  jsr lcd_instruction
  lda #%00000001 ; Clear the display	
  jsr lcd_instruction


main:

start_memory_game:

  lda #<start_message
  sta MESSAGE_POINTER
  lda #>start_message
  sta MESSAGE_POINTER+1
  jsr print_message

  jsr long_delay

  jsr clear_lcd_display
  lda #<instructions_mesasge
  sta MESSAGE_POINTER
  lda #>instructions_mesasge
  sta MESSAGE_POINTER+1
  jsr print_message



start_message: .asciiz "Welcome to Memory Game"
instructions_mesasge: .asciiz "Remember sequences"


; #################### START OF SUBROUTINES ########################


; START OF CLEARING LCD SCREEN
clear_lcd_display:
  pha

  lda #%00000001 ; Clear the display	
  jsr lcd_instruction

  pla
  rts

; END OF CLEARING LCD SCREEN


; START OF PRINTING A WHOLE MESSAGE IN THE LCD SCREEN

print_message:
  pha
  tya
  pha

  ldy #$00
print_message_loop:
  lda (MESSAGE_POINTER),y
  beq exit_print_message
  jsr send_character
  iny
  bne print_message_loop
  rts    
             ; o saltar a exit_print_message si quieres
exit_print_message:

  pla
  tay
  pla
  rts

; END OF PRINTING A WHOLE MESSAGE IN THE LCD SCREEN

short_delay:
  ; save X and Y (6502 style)
  txa
  pha
  tya
  pha

  ldy #$ff
  ldx #$40       ; shorter than $ff/$ff, tweak as you like
short_delay_wait:
  dex
  bne short_delay_wait
  dey
  bne short_delay_wait ; Add delay to debounce the button by software

  pla
  tay
  pla
  tax
  rts

long_delay:
  ; Save X and Y (6502 style) so the caller doesn't lose registers
  txa
  pha
  tya
  pha

  lda #5               ; Number of iterations (adjust to taste)

long_delay_outer:
  ; Inner delay block (same idea as your original wait loops)
  ldy #$ff
  ldx #$ff
long_delay_wait:
  dex
  bne long_delay_wait
  dey
  bne long_delay_wait  ; Software delay loop

  ; Decrement loop counter in A and repeat until it reaches 0
  sec
  sbc #1               ; A = A - 1
  bne long_delay_outer

  ; Restore Y and X (6502 style)
  pla
  tay
  pla
  tax
  rts

; START OF SENDING A CHARANTER ATORED IN A TO THE LCD SCREEN

send_character:
  jsr lcd_wait  ; checking the busy flag
  sta PORTB
  lda #RS	; Set RS and clear RW/E bits
  sta PORTA
  lda #(E | RS)	; After saying that it is an instruction, enabling the chip
  sta PORTA
  lda #RS	; Set RS and clear RW/E bits
  sta PORTA
  rts

lcd_wait:
  pha		 ; Pushing the accumulator into the stack to save the original instruction
  lda #%00000000 ; Set all the pins of PORTB to inputs
  sta DDRB
lcd_busy: 
  lda #RW	 ; Setting the read BF instruction to send to the LCD module 
  sta PORTA
  lda #(RW | E)	 ; Toggling the Enable bit of the LCD to laod the instruction
  sta PORTA
  lda #RW
  sta PORTA
  lda PORTB	; Reading the contents of the Busy flag of the LCD screen      
  and #$80	; This AND is due to we don't care about the Address Counter info of the PORTB0-PORTB6 bits
  bne lcd_busy	; if the BF = 1 (LCD is busy) then check it another time 

  lda #%11111111 ; Set again all the pins of PORTB to outputs
  sta DDRB
  
  pla		; Restoring the content of the original instruction into the accumulator 
  rts

lcd_instruction:
  sta PORTB
  lda #0	; Clear RS/RW/E bits
  sta PORTA
  lda #E	; After saying that it is an instruction, enabling the chip
  sta PORTA
  lda #0	; Clear RS/RW/E bits
  sta PORTA
  rts

nmi:
irq:
  sei
  php
  pha
  txa 
  pha
  tya 
  pha ; Store the value of the a, x and y registers in the stack 

  ; Read PORTA and go through shift the values of the register to see
  lda PORTA

  ; Mask only the 5 button bits (PA0..PA4) before comparing (PA5..PA7 are used for LCD control)
  and #%00011111

  ; Check buttons pressed
  cmp #LEFT_BUTTON
  bne check_right_button
  lda #LEFT_ARROW
  jsr send_character
  jmp exit_irq

check_right_button:
  cmp #RIGHT_BUTTON
  bne check_up_button
  lda #RIGHT_ARROW
  jsr send_character
  jmp exit_irq

check_up_button:
  cmp #UP_BUTTON
  bne check_down_button
  lda #PLUS_CHAR
  jsr send_character
  jmp exit_irq

check_down_button:
  cmp #DOWN_BUTTON
  bne check_select_button
  lda #MINUS_CHAR
  jsr send_character
  jmp exit_irq

check_select_button:
  cmp #SELECT_BUTTON
  bne exit_irq
  lda #"1"
  jsr send_character

exit_irq:
  jsr short_delay

  lda PORTB ; Read port A to clear the interrupt, telling the VIA that the interrupt was already handled

  pla
  tay
  pla
  tax
  pla ; Restore the values of the a, x and y register from the stack to the CPU registers
  plp
  cli
  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq