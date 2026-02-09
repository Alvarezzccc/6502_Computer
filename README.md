# 6502_Computer

This repository contains 6502 assembly programs for a 65C22 VIA and an HD44780-compatible LCD I am currently running while learning electronics and following Ben Eaters's videos and projects (more info: https://eater.net/6502)

Programs
- `decimal_conversion`: follows Ben Eater's videos. It initializes the HD44780 in 8-bit mode, converts a 16-bit constant (`number`) to ASCII using a shift-and-subtract divide-by-10 routine with a remainder buffer, and prints it.
- `interrupts`: follows Ben Eater's videos. It configures VIA CA1 interrupts; the IRQ handler increments a 16-bit counter with debounce delay, and the main loop converts the counter to decimal and prints it on the LCD.
- `memory_game`: I built this memory game because, while working through Ben Eater’s computer, I felt like I was following a very guided path. I wanted to go a bit deeper and create something original on my own—something I could enjoy with family and friends, learn from along the way, and hopefully reuse in the future, both professionally and personally (and if not, at least I’d have had a good time building it). The game is basically a turn-based “Simon Says” memory challenge. You can play it solo, but it’s much better with two people competing. Each round belongs to one player: they must repeat the full sequence accumulated so far and then add one new button press at the end. In round one, player 1 creates the first element; next round, player 2 repeats it and adds another; and so on. The sequence can grow up to 32 steps, matching the usable capacity of the LCD. The first player to make a mistake loses, and the winner is the one who can best remember both their own and their opponent’s past sequences.

