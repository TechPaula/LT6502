#!/bin/bash

echo "uploading and flashing to picorom flash!"

picorom upload paula_rom basic.bin -s 1MBit
picorom commit paula_rom

