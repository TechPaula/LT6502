#!/bin/bash

echo "-----clean old files"
rm main.o
rm keyb.elf

echo "-----compile"
avr-gcc -w -Os -DF_CPU=20000000UL -mmcu=atmega644p -c -o main.o main.c

echo "-----make elf"
avr-gcc -g -mmcu=atmega644p -o keyb.elf main.o

echo "-----make hex (intel format)"
avr-objcopy -j .text -j .data -O ihex keyb.elf keyb.hex
