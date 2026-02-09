# memory_game

## Overview
This program runs a memory/sequence game on a 6502 system with a 65C22 VIA and an HD44780-compatible LCD. I built this memory game because, while working through Ben Eater’s computer, I felt like I was following a very guided path. I wanted to go a bit deeper and create something original on my own, something I could enjoy with family and friends, learn from along the way, and hopefully reuse in the future, both professionally and personally (and if not, at least I’d have had a good time building it). The game is basically a turn-based “Simon Says” memory challenge. You can play it solo, but it’s much better with two people competing. Each round belongs to one player: they must repeat the full sequence accumulated so far and then add one new button press at the end. In round one, player 1 creates the first element; next round, player 2 repeats it and adds another; and so on. The sequence can grow up to 32 steps, matching the usable capacity of the LCD. The first player to make a mistake loses, and the winner is the one who can best remember both their own and their opponent’s past sequences.

I also created a simulator of this computer hardware prepared to run this game in my website so thay you can copy paste the whole memory_game.s and run it: https://alcdaniel.com/memory-game-6502/  

## Game Rules (for testing)
1. Round 1: The sequence is empty. Press any button (left, right, plus, minus, or select). The button is stored as the first sequence element and shown on the LCD. The round ends immediately and the message "Correct!! Next round:" appears with the next round number. The display is cleared to start the next round.
2. Round N (N >= 2): First repeat the full sequence from previous rounds in the same order. Each correct press is shown on the LCD (left to right, line 2 after 16 characters). After the sequence is correctly repeated, press one additional button to append the new element for this round. That new input is stored at the end of the sequence, shown on the LCD, and the round ends with "Correct!! Next round:". The display is cleared for the next round.
3. No repeats rule: If you press the same button twice in a row, the second press is ignored to avoid repeats from bounce or holding the button.
4. Error: If you press the wrong button during the repeat phase, the LCD shows "Error, you didn't remember well" and the program loops forever.
5. Victory: After completing 32 rounds, the LCD shows "You won all 32 rounds!" and the program loops forever.

Quick test example: R1 press right. R2 repeat right, then add minus. R3 repeat right, minus, then add plus. R4 repeat right, minus, plus, then add left.

## Hardware Map

### CPU role and memory map assumptions
- 6502-compatible CPU running from ROM/EPROM mapped at $8000-$FFFF.
- RAM mapped in low memory including zero page and stack.
- I/O mapped to a 65C22 VIA at $6000-$600E.

### 65C22 VIA role
- PORTA: button inputs on PA0..PA4 and LCD control on PA5..PA7.
- PORTB: LCD 8-bit data bus on PB0..PB7.

### LCD interface signals
- Control lines on PORTA:
  - RS = PA5
  - RW = PA6
  - E  = PA7
- Data lines on PORTB:
  - D0..D7 = PB0..PB7

![Breadboard computer interrupts for memory game](/assets/memory-game-init.jpg)

### Address space (system-level view)
```
Address space of the 65C02

FFFF ┌───────────────────────────────────────────────┐
     │                 ROM (EPROM)                   │
8000 └───────────────────────────────────────────────┘

7FFF

600F ┌──────────────────────── I/O (VIA 65C22) ────────────────────────┐
600E │  IER  ($600E)  Interrupt Enable Register                         │
600D │  IFR  ($600D)  Interrupt Flag Register                           │
600C │  PCR  ($600C)  Peripheral Control Register                       │
6003 │  DDRA ($6003)  Data Direction Register A                         │
6002 │  DDRB ($6002)  Data Direction Register B                         │
6001 │  PORTA($6001)  Port A                                            │
6000 │  PORTB($6000)  Port B                                            │
6000 └─────────────────────────────────────────────────────────────────┘

5FFF

3FFF ┌───────────────────────────────────────────────┐
     │                     RAM                       │
0000 └───────────────────────────────────────────────┘
0100-01FF  Stack

FFFD ┌───────────────┐
FFFC │ Reset Vector   │  ($FFFC-$FFFD)
     └───────────────┘
```

## Memory Organization

### Zero page usage
- MESSAGE_POINTER at $0000-$0001: indirect pointer used by `print_message` to output ROM strings.

### Stack
- Stack pointer initialized to $01FF via TXS, stack grows downward.
- IRQ handler pushes P, A, X, Y to the stack and restores them before RTI.

### RAM variables layout

| Address range | Size | Name | Purpose |
|---|---:|---|---|
| $0000-$0001 | 2 bytes | MESSAGE_POINTER | Indirect pointer for `print_message` |
| $0100-$01FF | 256 bytes | Stack | CPU stack for subroutines and IRQ |
| $2000-$201F | 32 bytes | ROUNDS_ARRAY | Sequence the player must reproduce |
| $2020 | 1 byte | ID_ROUND | Current last index (round length - 1) |
| $2021 | 1 byte | CURRENT_ROUND_POS | Progress index within the current round |
| $2022 | 1 byte | LAST_INPUT | Last accepted input (no-repeat rule) |
| $2030-$2031 | 2 bytes | minuend | Decimal conversion remainder workspace |
| $2032-$2033 | 2 bytes | sustraend | Decimal conversion dividend/quotient |
| $2034-... | buffer | message | Null-terminated ASCII buffer for decimal printing |

### ROM/EPROM layout
- Program assembled at `.org $8000` (code and strings).
- Interrupt vectors at `.org $FFFA`: NMI, RESET, IRQ addresses.

### VIA I/O mapped registers (usage)
- PORTB $6000: LCD data bus (D0..D7)
- PORTA $6001: buttons (PA0..PA4) and LCD control (PA5..PA7)
- DDRB  $6002: direction for LCD data bus
- DDRA  $6003: direction for LCD control and buttons
- PCR   $600C: edge/handshake control for the IRQ line
- IFR   $600D: interrupt flags (read/clear status)
- IER   $600E: interrupt enable (set/clear bit + source bit)

## VIA Configuration and Interrupts

### Reset-time initialization
- PCR is written with $10 to select edge behavior on the control-line interrupt input.
- IER is written with $90 to enable the CB1 interrupt source and set the enable bit (bit7=1 means "set").
- DDRB is set to outputs for LCD data; DDRA configures PA5..PA7 as outputs for LCD control.

### IRQ handler flow
- Save CPU state: P, A, X, Y.
- Read PORTA and mask with `%00011111` to isolate button bits.
- Compare against button masks and translate into a character code:
  - LEFT -> LEFT_ARROW ($7F)
  - RIGHT -> RIGHT_ARROW ($7E)
  - UP -> PLUS_CHAR ($2B)
  - DOWN -> MINUS_CHAR ($2D)
  - SELECT -> ASCII "1"
- Call `manage_input_sequence` with A holding the character.
- Debounce using `short_delay`.
- Read PORTA to clear the interrupt.
- Restore state and `RTI`.

### Why masking is necessary
- PA5..PA7 are used for LCD control (RS/RW/E), so only PA0..PA4 should be compared for buttons.

## LCD Driver Routines
- `lcd_instruction`: sends instruction byte in A to the LCD by writing PORTB and toggling E with RS=0.
- `send_character`: waits until not busy, then sends a data byte with RS=1.
- `lcd_wait`: sets DDRB to input, polls busy flag on PORTB bit7, then restores DDRB to output.
- `set_lcd_cursor_position`: ORA #$80 and calls `lcd_instruction` to set DDRAM address.
- `print_message`: uses MESSAGE_POINTER and `(ptr),Y` to print a null-terminated string; moves to line 2 at 16 chars by setting cursor to $40.
- `clear_lcd_display`: sends instruction 0x01.

## Game Logic (manage_input_sequence)
- No-repeat rule: if the new input equals `LAST_INPUT`, it is ignored to avoid repeats from button bounce/hold.
- Input handling by position:
  - If `CURRENT_ROUND_POS != ID_ROUND` (validation step): compare input to `ROUNDS_ARRAY[CURRENT_ROUND_POS]`. On success, echo to LCD and increment `CURRENT_ROUND_POS`. On failure, show the error message and loop forever.
  - If `CURRENT_ROUND_POS == ID_ROUND` (append step): store input into `ROUNDS_ARRAY[CURRENT_ROUND_POS]`, echo it, increment `ID_ROUND`, reset `CURRENT_ROUND_POS` and `LAST_INPUT`, then print "Correct!! Next round:" and the next round number.
- Win condition: when `ID_ROUND == 31` (32 rounds), show the win message and loop forever.
- Error condition: show the error message and loop forever.


### Pseudocode for manage_input_sequence
```text
FUNC manage_input_sequence(input_char):

  # 0) “No repeats” rule (ignore identical consecutive presses)
  IF input_char == LAST_INPUT:
      RETURN
  LAST_INPUT = input_char

  # 1) Append step happens when CURRENT_ROUND_POS == ID_ROUND
  IF CURRENT_ROUND_POS == ID_ROUND:

      # 1.1) Win condition (32 rounds)
      IF ID_ROUND == 31:
          show WIN_MESSAGE and loop forever
          RETURN

      # 1.2) Store new element at current position
      ROUNDS_ARRAY[CURRENT_ROUND_POS] = input_char

      # 1.3) Echo input on LCD (jump to line 2 at pos 16)
      IF CURRENT_ROUND_POS == 16:
          set_cursor_to_line_2
      lcd_print(input_char)

      # 1.4) Prepare next round state
      ID_ROUND = ID_ROUND + 1
      CURRENT_ROUND_POS = 0
      LAST_INPUT = 0xFF

      # 1.5) Round-complete feedback
      wait(long_delay)
      show CORRECT_NEXT_ROUND
      lcd_print_decimal(ID_ROUND + 1)
      wait(long_delay)

      clear_lcd()
      RETURN

  # 2) Validation step: compare against expected sequence value
  expected = ROUNDS_ARRAY[CURRENT_ROUND_POS]

  IF input_char != expected:
      show ERROR_MESSAGE and loop forever
      RETURN

  # 2.1) Correct input: echo and advance
  IF CURRENT_ROUND_POS == 16:
      set_cursor_to_line_2
  lcd_print(input_char)
  CURRENT_ROUND_POS = CURRENT_ROUND_POS + 1
  RETURN

## Decimal Printing (multi-digit) Routine
`print_decimal_using_my_algorithm` converts a small binary value (1..32) into ASCII digits:
- `sustraend` holds the working dividend (quotient).
- `minuend` accumulates the remainder during the shift/subtract divide-by-10 routine.
- After 16 iterations, the remainder (0..9) is converted to ASCII by adding "0".
- `push_character` inserts each new digit at the front of the null-terminated `message` buffer, so digits print in correct order.
- The message buffer is kept null-terminated before and after building digits, then printed until the terminator.

## Timing / Delays
- `short_delay`: software debounce after each IRQ; saves/restores X and Y.
- `long_delay`: used between intro messages and after completing a round before showing the next round text.

```


