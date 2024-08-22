DDRA = $6003
DDRB = $6002
PORTA = $6001
PORTB = $6000

counter = $0204 ; 2 bytes for the interrupt testing

; Data for the minuend and sustraend 
minuend = $1000 ; 2 bytes (left side)
sustraend = $1002 ; bytes (right side)

message = $0350 ; memory allocated for the message to be sent to the screen

E = %10000000
RW = %01000000
RS = %00100000

  .org $8000
 
reset:
  ldx #$ff
  txs		 ; Initializing the stack pointer at the top of the stack 
 
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

  lda #0
  sta counter
  sta counter + 1  
  

loop:
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
  beq loop
  jsr send_character
  inx
  jmp print

  jmp loop

number: .word 1980

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

nmi:
irq:
  inc counter
  bne exit_irq
  inc counter + 1
exit_irq:
  rti

  .org $fffa
  .word nmi
  .word reset
  .word irq
