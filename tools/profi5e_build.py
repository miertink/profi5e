#!/usr/bin/env python3
"""Assembles a PROFI-5E RAM program (examples/*.asm) for a specific address.

8085 code is not position-independent: the .bin only runs correctly if
loaded at the exact address it was assembled for (its LOADADDR/ORG).
This wraps asl + p2bin, sets that address at assembly time via asl's
-D flag, and prints the matching tools/profi5e_load.py command so the
build address and the load --addr can't drift apart by accident.

Requires: asl + p2bin on PATH (see PROJECT.md "Toolchain").
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def build(src: Path, addr: int) -> Path:
    out_p = src.with_suffix(".p")
    out_bin = src.with_suffix(".bin")

    subprocess.run(
        ["asl", "-cpu", "8085", "-D", f"LOADADDR={addr:04X}h", "-L", str(src), "-o", str(out_p)],
        check=True,
    )
    subprocess.run(["p2bin", str(out_p)], check=True)
    return out_bin


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Assemble a PROFI-5E example for a specific RAM address"
    )
    parser.add_argument("file", type=Path, help=".asm source file")
    parser.add_argument(
        "--addr", default="8000",
        help="RAM address to assemble for, in hex, no prefix (default: 8000). "
             "The source must declare its ORG via a LOADADDR EQU (see "
             "examples/hiworld.asm) for this to have any effect.",
    )
    parser.add_argument("--port", help="if given, also print a ready-to-run load command for this port")
    args = parser.parse_args()

    for tool in ("asl", "p2bin"):
        if shutil.which(tool) is None:
            print(f"error: '{tool}' not found on PATH (see PROJECT.md Toolchain section)", file=sys.stderr)
            return 1

    if not args.file.is_file():
        print(f"error: {args.file} not found", file=sys.stderr)
        return 1

    addr = int(args.addr, 16)

    try:
        out_bin = build(args.file, addr)
    except subprocess.CalledProcessError:
        print("error: assembly failed, see asl output above", file=sys.stderr)
        return 1

    size = out_bin.stat().st_size
    print(f"{out_bin}: {size} bytes, assembled for {addr:04X}h")
    print()
    print("Load with the SAME --addr, or the program will read/jump to the wrong")
    print("places once it runs (the .bin is not position-independent):")
    port = args.port or "COMx"
    print(f"  python tools/profi5e_load.py {out_bin} --port {port} --addr {addr:04X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
