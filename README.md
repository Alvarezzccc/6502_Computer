# 6502_Computer

This repository contains three 6502 assembly programs for a 65C22 VIA and an HD44780-compatible LCD.

Programs
- `decimal_conversion`: initializes the HD44780 in 8-bit mode, converts a 16-bit constant (`number`) to ASCII using a shift-and-subtract divide-by-10 routine with a remainder buffer, and prints it.
- `interrupts`: configures VIA CA1 interrupts; the IRQ handler increments a 16-bit counter with debounce delay, and the main loop converts the counter to decimal and prints it on the LCD.
- `memory_game`: polls five buttons on PORTA and prints arrow glyphs on the LCD (includes a binary-to-decimal routine).

Common build steps
- Build (run inside each program folder): `vasm -Fbin -dotdir <program>.s`
- Program EEPROM: `minipro -u -p AT28C256 -w a.out`
