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

; Data for the minuend and sustraend
minuend   = $2030 ; 2 bytes (left side) ; Decimal conversion in RAM layout here to print 1..32 correctly
sustraend = $2032 ; bytes (right side)
message   = $2034 ; memory allocated for the message to be sent to the screen

MESSAGE_POINTER = $00    ; 2 bytes: position of message to print with subroutine

; VARIABLES FOR THE LCD SCREEN CONFIGURATION

E = %10000000
RW = %01000000
RS = %00100000


  .org $8000

reset:
  sei    ; disable interrupts until the initialization is done
  ldx #$ff
  txs		 ; Initializing the stack pointer at the top of the stack

  sei    ; setting the interrupt disable bit to prevent a misconfiguration when initializing

  lda #$10
  sta PCR ; Write a 1 in the CB1 flag so that the raising edge is the one receiving the interrupt in the VIA

  lda PORTB ; Read port B for the VIA to reset it

  lda #$90
  sta IER ; Setting the Interrupt Enable Register to receive interrupts from CA1 (in the Versatile Interface Adapter) and the Set/Clear flag

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

  lda #<start_message ; Print first message
  sta MESSAGE_POINTER
  lda #>start_message
  sta MESSAGE_POINTER+1
  jsr print_message

  jsr long_delay ; leave time for the user to read the message

  lda #<instructions_message ; Print second message
  sta MESSAGE_POINTER
  lda #>instructions_message
  sta MESSAGE_POINTER+1
  jsr print_message

  jsr long_delay ; leave time for the user to read the message

  lda #<input_message ; Print third message
  sta MESSAGE_POINTER
  lda #>input_message
  sta MESSAGE_POINTER+1
  jsr print_message

  jsr clear_lcd_display

  ; Start of the main algorithm of the game

  ; Init to zero all the variables
  lda #$00
  sta ID_ROUND
  sta CURRENT_ROUND_POS
  sta message ; So that message is null terminated always ;
  lda #$ff
  sta LAST_INPUT ; Set this to $FF so the first real input is never ignored by the "no repeats" rule
  tax
reset_rounds_array:
  lda #$00
  sta ROUNDS_ARRAY,x
  inx
  cpx #$20
  bne reset_rounds_array

  cli ; clear the interrupt disable bit to allow interruptions

main_loop:
  jmp main_loop


; DEFINITION OF THE MESSAGES TO PRINT TO THE USER

; 16 chars (line 1)        ; 16 chars (line 2)
start_message:        .asciiz " Welcome to the   Memory Game   "
instructions_message: .asciiz "    Remember       sequences    "
input_message:        .asciiz " Input commands    with buttons "
error_message:        .asciiz "Error, you didn't  remember well"
correct_next_round:   .asciiz "   Correct!!       Next round: "
win_message:          .asciiz "   You won all     32 rounds!    "


; #################### START OF SUBROUTINES ########################


; START OF SUBROUTINE FOR MANAGING THE INPUT
manage_input_sequence:
  cmp LAST_INPUT
  bne continue_manage_input_sequence ; If last input != new input -> considered for the game
  jmp exit_input_sequence            ; JMP because the label can be too far for a branch
continue_manage_input_sequence:
  sta LAST_INPUT          ; If last input != new input -> considered for the game

  tax ; store input in x
  lda ID_ROUND ; compare ID_ROUND and CURRENT_POS
  cmp CURRENT_ROUND_POS
  bne check_input
  ; ID_ROUND = CURRENT_POS -> Check if the game ends here with ID_ROUND == 31
  cmp #31 ; if yes -> user wins. If not -> store new input in ROUNDS_ARRAY[CURRENT_ROUND_POS], increment ID_ROUND, reset CURRENT_ROUND_POS and LAST_INPUT
  beq user_wins
  ldy CURRENT_ROUND_POS
  txa
  sta ROUNDS_ARRAY,y ; ROUNDS_ARRAY[CURRENT_ROUND_POS] = new input

  ; Echo the new input on screen in this same press (this fixes "first button not printed")
  lda #$10
  cmp CURRENT_ROUND_POS
  bne continue_append_echo
  lda #$40
  jsr set_lcd_cursor_position
continue_append_echo:
  txa
  jsr send_character

  inc ID_ROUND
  lda #$00
  sta CURRENT_ROUND_POS
  lda #$ff
  sta LAST_INPUT

  jsr long_delay

  lda #<correct_next_round
  sta MESSAGE_POINTER
  lda #>correct_next_round
  sta MESSAGE_POINTER+1
  jsr print_message

  ; Print next round number as (ID_ROUND + 1), using my multi-digit decimal algorithm (works for 10..32 too)
  lda ID_ROUND
  clc
  adc #$01
  jsr print_decimal_using_my_algorithm

  jsr long_delay ; leave time for the user to read the message

  jsr clear_lcd_display
  jmp exit_input_sequence


user_wins:
  lda #<win_message
  sta MESSAGE_POINTER
  lda #>win_message
  sta MESSAGE_POINTER+1
  jsr print_message

winner_loop:
  jmp winner_loop


check_input:
  ldy CURRENT_ROUND_POS
  txa
  cmp ROUNDS_ARRAY,y        ; compare actual input vs expected
  bne manage_input_error
  jmp exit_correct_input_sequence


manage_input_error:
  lda #<error_message ;
  sta MESSAGE_POINTER
  lda #>error_message
  sta MESSAGE_POINTER+1
  jsr print_message

error_loop:
  jmp error_loop


exit_correct_input_sequence:
  ; Jump to 2nd line BEFORE printing when CURRENT_ROUND_POS == $10, otherwise the 16th char lands in the wrong line
  lda #$10
  cmp CURRENT_ROUND_POS
  bne continue_exit_correct_input_sequence
  lda #$40
  jsr set_lcd_cursor_position

continue_exit_correct_input_sequence:
  txa
  jsr send_character
  inc CURRENT_ROUND_POS

exit_input_sequence:
  rts

; END OF SUBROUTINE FOR MANAGING THE INPUT


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

  jsr clear_lcd_display ; First make sure that the display is cleared

  ldy #$00
print_message_loop:
  lda (MESSAGE_POINTER),y
  beq exit_print_message
  jsr send_character
  iny
  tya
  cmp #$10
  bne print_message_loop
  lda #$40
  jsr set_lcd_cursor_position
  jmp print_message_loop ; continue printing next character if not yet finished
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
  ; Inner delay block
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


; START OF SENDING A CHARACTER STORED IN REGISTER A TO THE LCD SCREEN

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

; END OF SENDING A CHARACTER STORED IN REGISTER A TO THE LCD SCREEN


; START OF WAITING FOR THE REPLY FROM THE LCD SCREEN

lcd_wait:
  pha		 ; Pushing the accumulator into the stack to save the original instruction
  lda #%00000000 ; Set all the pins of PORTB to inputs
  sta DDRB
lcd_busy:
  lda #RW	 ; Setting the read BF instruction to send to the LCD module
  sta PORTA
  lda #(RW | E)	 ; Toggling the Enable bit of the LCD to loadd the instruction
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

; START OF WAITING FOR THE REPLY FROM THE LCD SCREEN


; START OF SENDING AN INSTRUCTION TO THE LCD DISPLAY

lcd_instruction:
  sta PORTB
  lda #0	; Clear RS/RW/E bits
  sta PORTA
  lda #E	; After saying that it is an instruction, enabling the chip
  sta PORTA
  lda #0	; Clear RS/RW/E bits
  sta PORTA
  rts

; END OF SENDING AN INSTRUCTION TO THE LCD DISPLAY


; START OF SENDING AN INSTRUCTION TO THE LCD DISPLAY

set_lcd_cursor_position:
  ora #$80 ; set bit 7 for set DDRAM instruction erasing the one from the subroutine call
  jsr lcd_instruction
  rts

; END OF SENDING AN INSTRUCTION TO THE LCD DISPLAY


; START OF MY DECIMAL CONVERSION ALGORITHM REUSED HERE
print_decimal_using_my_algorithm:
  pha

  lda #0
  sta message ; So that message is null terminated always

  pla
  sta sustraend
  lda #0
  sta sustraend + 1

divisions:
  lda #0
  sta minuend
  sta minuend + 1
  clc

  ldx #16 ; x cpu register will store the counter for each division problem

divide:
  ; It is rotated left the first memory position (not the "+ 1") because Big Endian architecture
  rol sustraend
  rol sustraend + 1
  rol minuend
  rol minuend  + 1

  sec ; set the carry for the checking if it was modifyed

  lda minuend
  sbc #10 ; decimal 10 stored in accumulator
  tay ; y register is storing the result
  lda minuend + 1
  sbc #0 ; substracting with carry so that we can check if it was modifyed (subs 0 is equal to nothing)
  bcc ignore_result

; store the result in minuend
  sty minuend ; low byte of minuend was in y register
  sta minuend + 1 ; high byte of minuend was in accumulator

ignore_result:
  dex
  bne divide ; if we have already finished the 16 iterations loop
  rol sustraend; rotate left in the last iteration of this division problem
  rol sustraend + 1

  lda minuend ; The rest or minuend we want is stored in memory
  clc
  adc #"0" ; pass from binary number to ASCII number
  jsr push_character ; Push the character in the correct order into the queue

; if sustraend != 0, we continue dividing
  lda sustraend
  ora sustraend + 1
  bne divisions

; Here is the code for printing the message in the screen
  ldx #0
print:
  lda message,x
  beq exit_print_decimal
  jsr send_character
  inx
  jmp print

exit_print_decimal:
  rts


push_character:
  ldy #0 ; y register will be the index for the memory position we are working with
  pha ; we want to have the char to be inserted in next position in the stack pointer pos
char_loop:
  lda message,y ; store y pos in accumulator
  tax ; then transfer it to the x register

;store the char in the y message position
  pla ; get the char from the stack
  sta message,y

;increment the index
  iny

;store the value in stack
  txa
  pha ; push the char that was moved to place the new one to the stack (modifying z flag)

;check if the end of the string is reached, if not -> store it in the correct position (back to char_loop)
  bne char_loop

;if the end is achieved, we have in message,x NULL and we have to store it at the end
;store the char in the y message position
  pla ; get the char from the stack
  sta message,y

  rts
; END OF MY DECIMAL CONVERSION ALGORITHM REUSED HERE


; START OF NON-MASKABLE INRRUPTS AND NORMAL INTERRUPTS (ONLY USING NORMAL INTERRUPTS)
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
  jmp send_detected_character

check_right_button:
  cmp #RIGHT_BUTTON
  bne check_up_button
  lda #RIGHT_ARROW
  jmp send_detected_character

check_up_button:
  cmp #UP_BUTTON
  bne check_down_button
  lda #PLUS_CHAR
  jmp send_detected_character

check_down_button:
  cmp #DOWN_BUTTON
  bne check_select_button
  lda #MINUS_CHAR
  jmp send_detected_character

check_select_button:
  cmp #SELECT_BUTTON
  bne exit_irq
  lda #"1"
  jmp send_detected_character

send_detected_character:
  jsr manage_input_sequence

exit_irq:
  jsr short_delay

  lda PORTA ; Read port A to clear the interrupt, telling the VIA that the interrupt was already handled ; Read PORTA here because the buttons are on PORTA

  pla
  tay
  pla
  tax
  pla ; Restore the values of the a, x and y register from the stack to the CPU registers
  plp
  cli
  rti

  ; END OF NON-MASKABLE INRRUPTS AND NORMAL INTERRUPTS (ONLY USING NORMAL INTERRUPTS)

  .org $fffa
  .word nmi
  .word reset
  .word irq