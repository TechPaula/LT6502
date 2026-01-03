#!/bin/bash

echo "building/linking"

ca65 min_mon.asm -o basic.o -l basic.lst

ld65 -C basic.cfg basic.o -o basic.bin

