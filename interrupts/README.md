# interrupts

Requirements
- 6502-compatible CPU with program ROM starting at $8000.
- 65C22 VIA mapped at $6000 (PORTB=$6000, PORTA=$6001, DDRB=$6002, DDRA=$6003, PCR=$600C, IFR=$600D, IER=$600E).
- IRQ source connected to VIA CA1 (program enables CA1 interrupts).
- HD44780-compatible LCD in 8-bit mode: data bus on PORTB, control lines on PORTA (RS=PA5, RW=PA6, E=PA7).
- RAM usage: `counter` at $0204-$0205, `message` at $0350+, `minuend`/`sustraend` at $1000-$1003.

Technical description
- Configures the VIA for CA1 edge interrupts, enables CA1 in IER, and enables CPU interrupts with `cli`.
- IRQ handler saves registers, increments a 16-bit `counter` with carry, applies a short software debounce delay, clears the interrupt by reading PORTA, and returns with `rti`.
- The main loop homes the LCD cursor, converts `counter` to decimal using the same 16-bit divide-by-10 routine as `decimal_conversion`, and prints the resulting ASCII string.
- LCD writes are synchronized via the busy-flag read on PORTB D7.
