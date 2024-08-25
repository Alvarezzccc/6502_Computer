DDRA = $6003
DDRB = $6002
PORTA = $6001
PORTB = $6000
PCR = $600C ; Peripheral Control Register
IFR = $600D ; Interrupt Flag Register
IER = $600E ; Interrupt Enable Register

number = $0f04 ; 2 bytes for the binary number to be printed in the screen

; Data for the minuend and sustraend 
minuend = $1000 ; 2 bytes (left side)
sustraend = $1002 ; bytes (right side)

message = $0350 ; memory allocated for the message to be sent to the screen

SELECT_BUTTON = %00000001
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00010000
UP_BUTTON = %00000100
DOWN_BUTTON = %00001000 ; This is the phisical address flag where the button signal will arrive in the 65C22 VIA at PORTA

LEFT_ARROW = $7F
RIGHT_ARROW = $7E
UP_ARROW = $5E
DOWN_ARROW = $5F  ; This is the HEX representation of the arrows for the LCD screen (HITACHI HD44780U)

E = %10000000
RW = %01000000
RS = %00100000

  .org $8000
 
reset:
  sei ; interrupts disabled
  ldx #$ff
  txs		 ; Initializing the stack pointer at the top of the stack 
 
  lda #00 ; 00 for the falling edge ; 10 for the rising edge
  sta PCR ; Write a 0 in the CB1 flag so that the falling edge is the one receiving the interrupt in the VIA

  lda #$90
  sta IER ; Setting the Interrupt Enable Register to receive interrupts from CB1 (in the Versatile Interface Adapter) and the Set/Clear flag
  
  lda #%11111111 ; Set all the pins of PORTB to outputs
  sta DDRB
  lda #%11111111 ; Initialize DDRA to be outputs for the E R/W and RS
  ;lda #%11100000 ; Initialize DDRA to be outputs for the E R/W and RS (PA5-PA7) and inputs for the buttons (PA0-PA4)
  sta DDRA

  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font	
  jsr lcd_instruction
  lda #%00001110 ; Display on; Cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display	
  jsr lcd_instruction
  lda #%00000001 ; Clear the display	
  jsr lcd_instruction

  lda #0
  sta number
  sta number + 1 ; Initialize the number to be printed to 0

  cli ; interrupts enabled

  ;lda #%00001010 ; Decimal number 10
  ;sta number  ; stored in number + 1 beacuse of Big Endian architecture
  ;jsr print_binary_number_in_lcd  ; Print the number stored in the accumulator in the screen

infinite_loop:
  jmp infinite_loop
  





print_binary_number_in_lcd:

  pha
  txa 
  pha
  tya 
  pha ; Store the value of the a, x and y registers in the stack 

  lda #0
  sta message ; So that message is null terminated always

; set up the variables to divide in memory (RAM) 
  lda number
  sta sustraend
  lda number + 1 
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
  beq exit_binary_subroutine
  jsr send_character
  inx
  jmp print

  pla
  tay
  pla
  tax
  pla ; Restore the values of the a, x and y register from the stack to the CPU registers

exit_binary_subroutine:
  rts ; binary number printed in the screen

;number: .word 1980

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


  .org $f800
nmi:
irq:
  pha
  txa 
  pha
  tya 
  pha ; Store the value of the a, x and y registers in the stack 

  lda %00000000
  sta DDRA ; Set all the pins of PORTA to inputs
  
  ;lda PORTA
  ;sta number
  ;jsr print_binary_number_in_lcd  ; Print the number read in the buttons

  ; Checking Which button was the one triggering the interrupt
  lda PORTA
  and #LEFT_BUTTON
  beq check_right_button
  jsr left_button_function

check_right_button:
  lda PORTA
  and #RIGHT_BUTTON
  beq check_up_button
  jsr right_button_function

check_up_button:
  lda PORTA
  and #UP_BUTTON
  beq check_down_button
  jsr up_button_function

check_down_button:
  lda PORTA
  and #DOWN_BUTTON
  beq check_select_button
  jsr down_button_function

check_select_button:
  lda PORTA
  and #SELECT_BUTTON
  beq default_case
  ;jsr select_button_function

default_case:
  lda #"?"
  jsr send_character  ; In the case that the signal was not detected by the PORTA, we send a "?" to the screen

  ; jmp force_exit_irq ; Exit the interrupt with no delay
  
  ; Exit the interrupt with a delay

exit_irq:
  ldy #$f5
  ldx #$ff
delay:
  dex
  bne delay
  dey 
  bne delay ; Add delay to debounce the button by software

force_exit_irq:
  bit PORTB ; Read port A to clear the interrupt, telling the VIA that the interrupt was already handled
  lda $ff
  sta IFR
  
  lda %11111111
  sta DDRA ; Set all the pins of PORTA to ouputs again

  pla
  tay
  pla
  tax
  pla ; Restore the values of the a, x and y register from the stack to the CPU registers

  rti

left_button_function:
  pha

  lda #LEFT_ARROW
  jsr send_character

  pla
  rts

right_button_function:
  pha

  lda #RIGHT_ARROW
  jsr send_character

  pla
  rts

up_button_function:
  pha

  lda #UP_ARROW
  jsr send_character

  pla
  rts


down_button_function:
  pha

  lda #DOWN_ARROW
  jsr send_character

  pla
  rts


  .org $fffa
  .word nmi
  .word reset
  .word irq
