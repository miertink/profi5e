#!/usr/bin/env python3
"""Builds a single EPROM image containing the loader plus three demo
programs, each at a fixed address, so they can be run directly from
ROM -- no serial loading needed. Start any of them from the monitor
with the manual B / [address] / S / G sequence (Hardware Reference
§5.3): e.g. B, 2 2 0 0, S, G runs hi-world.

    2000h  loader.asm       -- the serial loader (unchanged)
    2200h  hiworld.asm      -- "hi-world" on the display
    2400h  scroll_text.asm  -- "NOTHING IS CERTAIN" scrolling
    2600h  light_show.asm   -- the display+LED demo reel

Usage: python loader/build_demo_rom.py [27128]
  Default target is 2764 (8 KB, officially documented -- see
  loader/build.sh and Hardware Reference §7). Pass 27128 for the
  16 KB variant instead.

Requires asl + p2bin on PATH.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXAMPLES = HERE.parent / "examples"

# (source file, bus address, needs LOADADDR override)
PROGRAMS = [
    (HERE / "loader.asm", 0x2000, False),          # fixed ORG 2000h in the source itself
    (EXAMPLES / "hiworld.asm", 0x2200, True),
    (EXAMPLES / "scroll_text.asm", 0x2400, True),
    (EXAMPLES / "light_show.asm", 0x2600, True),
]


def assemble(src: Path, addr: int, use_loadaddr: bool, tmpdir: Path) -> bytes:
    # Builds into tmpdir, never next to the source -- examples/*.bin and
    # loader/loader.bin are shared, committed-elsewhere artifacts built
    # for RAM (--addr 8000) or for the standalone EPROM (2000h); this
    # script must not silently overwrite them with ROM-address builds.
    out_p = tmpdir / (src.stem + ".p")
    out_bin = tmpdir / (src.stem + ".bin")
    cmd = ["asl", "-cpu", "8085"]
    if use_loadaddr:
        cmd += ["-D", f"LOADADDR={addr:04X}h"]
    cmd += ["-L", str(src), "-o", str(out_p)]
    subprocess.run(cmd, check=True)
    subprocess.run(["p2bin", str(out_p)], check=True)
    return out_bin.read_bytes()


def main() -> int:
    chip = sys.argv[1] if len(sys.argv) > 1 else "2764"
    if chip == "27128":
        total, base, out = 0x4000, 0x2000, HERE / "loader_demo_27128.bin"
    elif chip == "2764":
        total, base, out = 0x2000, 0x0000, HERE / "loader_demo_2764.bin"
    else:
        print(f"error: unknown chip '{chip}', expected 2764 or 27128", file=sys.stderr)
        return 1

    buf = bytearray(b"\xFF" * total)
    starts = [addr for _, addr, _ in PROGRAMS] + [0x2000 + total - base]
    with tempfile.TemporaryDirectory(prefix="profi5e_demo_rom_") as tmp:
        tmpdir = Path(tmp)
        for i, (src, addr, use_loadaddr) in enumerate(PROGRAMS):
            code = assemble(src, addr, use_loadaddr, tmpdir)
            off = base + (addr - 0x2000)
            next_addr = starts[i + 1]
            if addr + len(code) > next_addr:
                print(
                    f"error: {src.name} ({len(code)} bytes at {addr:04X}h) runs past "
                    f"the next program's start ({next_addr:04X}h)",
                    file=sys.stderr,
                )
                return 1
            buf[off:off + len(code)] = code
            print(f"{src.name}: {len(code)} bytes at bus {addr:04X}h (file offset {off:#06x})")

    out.write_bytes(buf)
    print(f"{out}: {total} bytes total")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
