#!/bin/sh
# Assembles loader.asm and produces the 16 KB image to burn on the
# expansion EPROM (chip: 27128, 16 KB).
#
# IMPORTANT: on this board, the expansion socket's A13 pin is tied to
# VCC, so only the UPPER half of the chip (offset 2000h-3FFFh) is
# visible to the CPU at 2000h-3FFFh -- the lower half (0000h-1FFFh)
# is physically unreachable. That's why the code (assembled with
# ORG 2000h) goes at offset 8192 (2000h) of the 16 KB file, not
# offset 0.
set -e
cd "$(dirname "$0")"
../tools/asm_build.sh loader.asm 16384 8192
