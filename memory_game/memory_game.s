DDRA = $6003
DDRB = $6002
PORTA = $6001
PORTB = $6000
PCR = $600C ; Peripheral Control Register from VIA 6622
IFR = $600D ; Interrupt Flag Register from VIA 6622
IER = $600E ; Interrupt Enable Register from VIA 6622

counter = $0204 ; 2 bytes for the interrupt testing

; Data for the minuend and sustraend 
minuend = $1000 ; 2 bytes (left side)
sustraend = $1002 ; bytes (right side)

message = $0350 ; memory allocated for the message to be sent to the screen


SELECT_BUTTON = %00000001
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00010000
UP_BUTTON = %00000100
DOWN_BUTTON = %00001000 ; This is the physical address flag where the button signal will arrive in the 65C22 VIA at PORTA

LEFT_ARROW = $7F
RIGHT_ARROW = $7E
PLUS_CHAR = $2B
MINUS_CHAR = $2D

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

  lda #$00
  sta $3000
  
wait_interrupt:
  lda $3000
  cmp #$00
  beq wait_interrupt
  jsr send_character
  lda #$00
  sta $3000

  jmp wait_interrupt








; ################## START OF LOOP FOR PRINTING IN A LOOP THE DECIMAL NUMBER IN THE LCD ##################
  
  lda #0          
  sta counter     ; Start the counter at value 0
  sta counter + 1 ; Start the counter at value 0

decimal_loop:
  lda #%00000010 ; Home position for cursor
  jsr lcd_instruction

  lda #0
  sta message ; So that message is null terminated always

; set up the variables to divide in memory (RAM) 
  lda counter
  sta sustraend
  lda counter + 1 
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
  beq decimal_loop
  jsr send_character
  inx
  jmp print

  jmp decimal_loop

; ################## END OF LOOP FOR PRINTING IN A LOOP THE DECIMAL NUMBER IN THE LCD ##################






; #################### START OF SUBROUTINES ########################


; START OF PUSH CHARACTER FUNCTION FOR THE DECIMAL PRINT

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

 ; END OF PUSH CHARACTER FUNCTION FOR THE DECIMAL PRINT 


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
  ;jsr send_character
  sta $3000
  jmp exit_irq

check_right_button:
  cmp #RIGHT_BUTTON
  bne check_up_button
  lda #RIGHT_ARROW
  ;jsr send_character
  sta $3000
  jmp exit_irq

check_up_button:
  cmp #UP_BUTTON
  bne check_down_button
  lda #PLUS_CHAR
  ;jsr send_character
  sta $3000
  jmp exit_irq

check_down_button:
  cmp #DOWN_BUTTON
  bne check_select_button
  lda #MINUS_CHAR
  ;jsr send_character
  sta $3000
  jmp exit_irq

check_select_button:
  cmp #SELECT_BUTTON
  bne exit_irq
  lda #"1"
  ;jsr send_character
  sta $3000

exit_irq:
  ldy #$f0
  ldx #$ff
delay:
  dex
  bne delay
  dey 
  bne delay ; Add delay to debounce the button by software

  lda PORTB ; Read port A to clear the interrupt, telling the VIA that the interrupt was already handled

  pla
  tay
  pla
  tax
  pla ; Restore the values of the a, x and y register from the stack to the CPU registers
  plp
  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq