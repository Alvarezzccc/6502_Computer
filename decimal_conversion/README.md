# 6502_Computer

This is an assembly program designed for use with a 6502 microprocessor-based computer. You can find information about the computer's architecture at https://eater.net/, and additional details about the assembly process are available in my LinkedIn post at https://www.linkedin.com/feed/update/urn:li:activity:6988200375514222592/.

# Binary to Decimal Algorithm 

The program begins with a number in binary, which is stored in memory labeled as "number" (1 byte reserved ). The algorithm divides the number by 10d (1010b) and pushes the minuend to the "message" memory area to store it. Since the natural order of the binary number division by 1010b results in the digits being reversed (i.e., 1980 becomes "0," then "8," then "9," and finally "1"), we need to store the characters in the correct order. To achieve this, I utilize the "push_char" subroutine. This subroutine allocates space in the message memory area for the incoming character and shifts the already written characters to the right.


# How to compile 

vasm -Fbin -dotdir decimal_conversion.s

# How to write into EEPROM

minipro -u -p AT28C256 -w a.out