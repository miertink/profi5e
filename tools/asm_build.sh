#!/bin/sh
# Assembles a .asm with the Macro Assembler AS (asl) and produces the
# matching .bin.
#
# Usage: asm_build.sh file.asm [chip_total_size] [chip_offset]
#   With no extra arguments, produces just the .bin at the code's real
#   size (typical for examples, loaded into RAM by the loader).
#
#   With a total size, produces a buffer of that size filled with FFh
#   and copies the assembled code into it at the given chip_offset
#   (default 0 if omitted).
#
#   loader/build.sh uses this to produce the expansion-EPROM image:
#   an 8 KB image at offset 0 by default (chip: 2764, the officially
#   documented option for this socket), or a 16 KB image with the code
#   at offset 8192 (2000h) if built for a 27128 instead -- on this
#   socket, a 27128's A13 pin is tied to VCC, so only its upper half
#   (offset 2000h-3FFFh) is reachable by the CPU. See loader/build.sh
#   and Hardware Reference #7 for the full explanation.
#
# Set LOADADDR (env var) to override where the code is assembled to run
# from, for sources that declare their ORG via a LOADADDR EQU (see
# examples/hiworld.asm). Lets the same source be rebuilt to live at a
# different RAM address -- e.g. to keep two examples resident at once:
#   LOADADDR=8200 ../tools/asm_build.sh scroll_text.asm
# 8085 code is not position-independent: a binary assembled for one
# address will not run correctly if loaded at another.
#
# Requires asl + p2bin on the PATH (https://github.com/Macroassembler-AS/asl-releases)
# and Python 3 (via "python3", or on Windows the "py" launcher).
set -e

# On Windows, "python3" is often a Microsoft Store alias-stub that
# doesn't work even with Python installed -- so "py" (the official
# launcher) is tried first here.
if command -v py >/dev/null 2>&1; then
    PYTHON=py
elif command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
else
    echo "error: neither py nor python3 found on PATH" >&2
    exit 1
fi

if [ -z "$1" ]; then
    echo "usage: $0 file.asm [chip_total_size] [chip_offset]" >&2
    exit 1
fi

SRC="$1"
TOTAL="$2"
OFFSET="${3:-0}"
BASE="${SRC%.asm}"
OUT="$BASE.p"
BIN="$BASE.bin"

if [ -n "$LOADADDR" ]; then
    asl -cpu 8085 -D "LOADADDR=$LOADADDR" -L "$SRC" -o "$OUT"
else
    asl -cpu 8085 -L "$SRC" -o "$OUT"
fi
p2bin "$OUT" "$BIN"

if [ -n "$TOTAL" ]; then
    "$PYTHON" - "$BIN" "$TOTAL" "$OFFSET" << 'EOF'
import sys

path, total, offset = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with open(path, "rb") as f:
    code = f.read()

if offset + len(code) > total:
    raise SystemExit(
        f"code ({len(code)} bytes) at offset {offset} doesn't fit in a {total}-byte buffer"
    )

buf = bytearray(b"\xff" * total)
buf[offset:offset + len(code)] = code

with open(path, "wb") as f:
    f.write(buf)

print(
    f"{path}: {len(code)} bytes of code at offset {offset:#06x}, "
    f"total buffer {total} bytes (rest FFh)"
)
EOF
else
    size=$(wc -c < "$BIN")
    echo "$BIN: $size bytes (no padding)"
fi
