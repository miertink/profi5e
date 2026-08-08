#!/bin/sh
# Assembles loader.asm and produces the image to burn on the expansion
# EPROM (socket I14).
#
# Usage: ./build.sh [27128]
#
# Default target: EPROM 2764 (8 KB) -- the chip family the manual and
# schematic actually document for this socket (jumper B1 pins 3-4).
# ORG 2000h maps directly to file offset 0, no padding trick needed.
#
# Pass "27128" to build for a 16 KB 27128 instead -- not officially
# documented for this socket, but empirically confirmed to work (see
# Hardware Reference #7); mainly useful if, like this project's own
# board, you have 27128s on hand and few/no 2764s. On this socket the
# A13 pin is tied to VCC, so only the chip's UPPER half
# (offset 2000h-3FFFh) is visible to the CPU -- the code (ORG 2000h)
# must go at file offset 8192 (2000h), not offset 0.
set -e
cd "$(dirname "$0")"

if [ "$1" = "27128" ]; then
    ../tools/asm_build.sh loader.asm 16384 8192
else
    ../tools/asm_build.sh loader.asm 8192 0
fi
