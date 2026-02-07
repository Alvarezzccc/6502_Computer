# decimal_conversion

Requirements
- 6502-compatible CPU with program ROM starting at $8000.
- 65C22 VIA mapped at $6000 (PORTB=$6000, PORTA=$6001, DDRB=$6002, DDRA=$6003).
- HD44780-compatible LCD in 8-bit mode: data bus on PORTB, control lines on PORTA (RS=PA5, RW=PA6, E=PA7).
- RAM usage: `message` at $0350+, `minuend`/`sustraend` at $1000-$1003.

Technical description
- Initializes the LCD in 8-bit mode and uses the busy-flag read (PORTB D7) to time writes.
- Converts a 16-bit constant at `number` to ASCII by repeated shift-and-subtract division by 10 across 16 iterations, keeping quotient in `sustraend` and remainder in `minuend`.
- Uses `push_character` to insert each remainder digit at the start of `message`, producing correct decimal order before printing to the LCD.
- Prints the null-terminated message and then loops forever.

Pseudocode
```text
init_lcd()
message = ""
quotient = number
do:
    remainder = 0
    repeat 16 times:
        (quotient, remainder) = shift_left_with_carry(quotient, remainder)
        if remainder >= 10:
            remainder -= 10
            set_carry_for_quotient_bit()
    push_front(message, char('0' + remainder))
while quotient != 0
print(message)
loop_forever()
```
