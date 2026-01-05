#!/bin/bash

echo "----- Programming"

avrdude -c atmelice -p m644p -U flash:w:keyb.hex -U lfuse:w:0xFF:m -U hfuse:w:0x99:m -U efuse:w:0xFF:m
