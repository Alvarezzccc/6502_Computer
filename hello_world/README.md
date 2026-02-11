# Hello World (6502 + LCD)

This example initializes a 6502 system and prints "Hello, world!" to an HD44780‑style character LCD using memory‑mapped I/O ports.

## Files
- `hello_world.s` — 6502 assembly that configures the LCD and prints the message.

## What It Does
- Sets the stack pointer.
- Configures Port B as LCD data (output) and the top 3 bits of Port A as LCD control lines (E, RW, RS).
- Initializes the LCD in 8‑bit, 2‑line mode.
- Sends characters from the `message` string to the LCD.
- Loops forever after printing.

## Memory Map / Signals
- `PORTB = $6000` — LCD data bus (D0–D7)
- `PORTA = $6001` — LCD control lines
- `DDRB  = $6002` — Data direction for Port B
- `DDRA  = $6003` — Data direction for Port A

Control bit masks:
- `E  = %10000000`
- `RW = %01000000`
- `RS = %00100000`

## Key Routines
- `lcd_wait` — Polls the LCD busy flag before writes.
- `lcd_instruction` — Sends a command to the LCD.
- `print_char` — Sends one character to the LCD.

## Notes
- The program is assembled to start at `$8000` and sets the reset vector at `$FFFC`.
- The `message` is defined with `.asciiz` and ends with a zero byte.

## Quick Assembly/Run
Use the assembler and emulator you use elsewhere in this repo. If you want this README to include exact build commands, tell me which tools you prefer and I’ll add them.
