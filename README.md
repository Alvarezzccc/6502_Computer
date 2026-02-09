# 6502_Computer

This repository contains three 6502 assembly programs for a 65C22 VIA and an HD44780-compatible LCD.

Programs
- `decimal_conversion`: initializes the HD44780 in 8-bit mode, converts a 16-bit constant (`number`) to ASCII using a shift-and-subtract divide-by-10 routine with a remainder buffer, and prints it.
- `interrupts`: configures VIA CA1 interrupts; the IRQ handler increments a 16-bit counter with debounce delay, and the main loop converts the counter to decimal and prints it on the LCD.
- `memory_game`: polls five buttons on PORTA and prints arrow glyphs on the LCD (includes a binary-to-decimal routine).

Game Rules (for testing)
1. Round 1: The sequence is empty. Press any button (left, right, plus, minus, or select). The button is stored as the first sequence element and shown on the LCD. The round ends immediately and the message "Correct!! Next round:" appears with the next round number. The display is cleared to start the next round.
2. Round N (N >= 2): First repeat the full sequence from previous rounds in the same order. Each correct press is shown on the LCD (left to right, line 2 after 16 characters). After the sequence is correctly repeated, press one additional button to append the new element for this round. That new input is stored at the end of the sequence, shown on the LCD, and the round ends with "Correct!! Next round:". The display is cleared for the next round.
3. No repeats rule: If you press the same button twice in a row, the second press is ignored to avoid repeats from bounce or holding the button.
4. Error: If you press the wrong button during the repeat phase, the LCD shows "Error, you didn't remember well" and the program loops forever.
5. Victory: After completing 32 rounds, the LCD shows "You won all 32 rounds!" and the program loops forever.

Quick test example: R1 press right. R2 repeat right, then add minus. R3 repeat right, minus, then add plus. R4 repeat right, minus, plus, then add left.

Common build steps
- Build (run inside each program folder): `vasm -Fbin -dotdir <program>.s`
- Program EEPROM: `minipro -u -p AT28C256 -w a.out`
