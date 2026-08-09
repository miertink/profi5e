# PROJECT.md — PROFI-5E: Serial Loader + Development Toolchain

**Language policy:** everything in this repository — this file, other docs,
code comments — is written in English from this point on, regardless of the
language used in conversation.

## Goal

Build a complete development chain for the PROFI-5E single-board trainer
(IED Kammerer, Germany — Intel 8085A, 6.144 MHz):

1. **Serial loader in the expansion EPROM (2000h)**, auto-boot capable: the
   board powers up ready to receive programs from a PC over USB-serial.
2. **PC-side tool in Python** (`tools/profi5e_load.py`) that sends a `.bin`
   with a header and checksum, and runs it automatically (`--no-go` to skip).
3. **Phase 2:** a BIN→WAV encoder for the monitor's cassette tape format, as
   a hardware-free alternative loading path.

All hardware facts (memory map, I/O, keyboard, DIL switches, jumpers,
monitor ROM API, serial framing, etc.) live in
**`docs/Profi5E_Hardware_Reference.md` — read that before touching any
assembly code.**

## Current status

**Working end to end on real hardware:** `profi5e_load.py` sends a file over
USB-serial (adapter on SID/SOD) → `loader.asm` (burned to an EPROM in the
expansion socket) receives and checksums it → runs it automatically.

- `loader/loader.asm` — 171 bytes, 0 errors/warnings. Calls the monitor
  ROM's own serial routines (`BAUD`/`RXCHAR`/`TXCHAR`) rather than
  bit-banging its own UART. Write loop never touches 87ACh+ (the monitor's
  own RAM), regardless of what the header claims, so a corrupt/garbled
  transfer can't smash monitor state.
- `tools/profi5e_load.py` — sends sync/header/payload/checksum, waits for
  ACK/NAK, `--port --baud --addr --no-go` flags, runs the program
  automatically by default (`--no-go` to just load and return to the
  monitor).
- `tools/profi5e_build.py` — assembles a `.asm` for a given RAM `--addr`;
  its output must be loaded with the same `--addr` on `profi5e_load.py`
  (see Repository structure below).
- `examples/hiworld.asm`, `examples/scroll_text.asm` — display-only demo
  programs. `examples/switch_leds.asm` — mirrors an external I/O board's 8
  switches onto its 8 LEDs via the 64-pin connector (8255 #1, Hardware
  Reference §3 "External I/O board").
- Prebuilt `.bin`s committed for both the loader (both chip variants) and
  all three examples, so burning the EPROM and loading the examples needs
  no assembler at all — only Python (see README.md "Just want to use it?").
  `asl`/`p2bin` are only needed to modify the loader or write new programs.
- Local `asl`/`p2bin` toolchain built from source, installed at
  `C:\tools\asl\bin` (see Toolchain section).

**Required DIL switch positions — see Hardware Reference §6.** Physical
switch positions have repeatedly not matched what they were believed to be
set to; if serial communication misbehaves, verify the actual bits with a
live `IN 21h` display before suspecting anything else.
- Switch 5 = OFF (no handshake)
- Switch 6 = OFF (V.24 serial, not Centronics)
- Switch 7/8 = desired baud rate, must match `--baud`

## Repository structure

```
profi5e/
├── PROJECT.md
├── .gitignore                      # ignores generated *.bin/*.lst/*.p in loader/ and examples/
├── docs/
│   ├── Profi5E_Hardware_Reference.md   # all hardware facts — read first
│   ├── Profi5E_disassembly.lst         # full ROM disassembly
│   ├── Profi-5E_1.jpeg / Profi-5E_2.jpeg          # this board's USB-TTL/SID/SOD wiring, shown in README
│   ├── Profi-5E_SW.pdf / Profi-5E_COL.pdf         # official schematic (SW processed, COL redundant)
│   ├── Profi-5E Bedienungsanleitung.pdf           # official manual (processed)
│   ├── Profi-5E Training.pdf                      # exercise workbook (processed)
│   └── Profi-5E Bauanleitung.pdf                  # construction manual (not processed)
├── rom/
│   └── Profi5E.BIN                 # monitor ROM dump read from this board's own EPROM — reference, do not modify
├── loader/
│   ├── loader.asm                  # serial loader, ORG 2000h — done, validated on hardware
│   ├── loader_2764.bin             # prebuilt, 8 KB, for a 2764 (committed, no assembler needed)
│   ├── loader_27128.bin            # prebuilt, 16 KB, for a 27128 (committed, no assembler needed)
│   └── build.sh                    # asl → p2bin → 8 KB EPROM image (2764, default) or 16 KB (27128, `./build.sh 27128`)
├── tools/
│   ├── dis85.py                    # 8085 disassembler used to produce the .lst
│   ├── asm_build.sh                # generic asl/p2bin wrapper — used by loader/build.sh
│   │                                 (EPROM padding); examples/ use profi5e_build.py instead
│   ├── profi5e_build.py            # PC-side compiler: .asm + --addr -> .bin for a RAM address
│   ├── profi5e_load.py             # PC-side serial client: sends a .bin to a RAM --addr
│   └── bin2wav.py                  # cassette encoder — phase 2, not started
└── examples/
    ├── hiworld.asm                 # "hi-world" on the display, default ORG 8000h, loaded via the serial loader
    ├── hiworld.bin                 # prebuilt, for --addr 8000 (committed, no assembler needed)
    ├── scroll_text.asm             # scrolls "NOTHING IS CERTAIN" across the display, default ORG 8000h
    ├── scroll_text.bin             # prebuilt, for --addr 8000 (committed, no assembler needed)
    ├── switch_leds.asm             # mirrors an external I/O board's switches onto its LEDs, default ORG 8000h
    └── switch_leds.bin             # prebuilt, for --addr 8000 (committed, no assembler needed)
```

Both examples default to `ORG 8000h` via a `LOADADDR` EQU, not a hardcoded `ORG`.
8085 code isn't position-independent — a binary assembled for one address
won't run correctly if loaded at another.

**The build `--addr` and the load `--addr` are two separate flags on two
separate tools, and they must be given the same value by hand — nothing
enforces this automatically.** `profi5e_build.py --addr` only controls what
address the code is *assembled* for (baked into internal jumps/calls/data
pointers); `profi5e_load.py --addr` only controls where the board *writes*
the incoming bytes in RAM. Giving them different values produces a binary
that loads and even ACKs successfully, but jumps to the wrong places the
moment it runs — there is no error at build or load time to catch this.

To build and load an example:
```
python tools/profi5e_build.py examples/hiworld.asm --addr 8000
python tools/profi5e_load.py examples/hiworld.bin --port COM4 --addr 8000
```
To keep more than one example resident in RAM at once, rebuild the others at
a different address and load them there with the matching `--addr`:
```
python tools/profi5e_build.py examples/scroll_text.asm --addr 8200
python tools/profi5e_load.py examples/scroll_text.bin --port COM4 --addr 8200
```
`profi5e_build.py` prints the exact matching `profi5e_load.py` command after
every successful build, as a reminder.

## Toolchain

- **Assembler:** Macro Assembler AS (`asl`) + `p2bin`, built from source
  (github.com/Macroassembler-AS/asl-releases, `upstream` branch) via
  MSYS2/gcc, installed at `C:\tools\asl\bin` (on the user's PATH). Used
  directly by `loader/build.sh` (via `tools/asm_build.sh`) and by
  `tools/profi5e_build.py` for `examples/`. Alternatives: asm80.com (online;
  RIM/SIM support on that specific platform not confirmed), GNUSim8085
  (simulate/step before burning).
- **EPROM image:** binary assembled with `ORG 2000h`. Byte 0 of the output
  file = bus address 2000h; if the programmer wants Intel HEX, apply a
  −2000h offset (not needed loading the raw `.bin`, e.g. via XGPro).
  `loader/build.sh` defaults to an 8 KB image (chip **2764**, the officially
  documented option, jumper B1 pins 3-4) with the code at offset 0. Pass
  `27128` (`./build.sh 27128`) for a 16 KB image instead, with the code at
  offset 2000h — **not** offset 0 — since that chip's A13 pin is tied to
  VCC on this socket, making only its upper half addressable (Hardware
  Reference §7).
- **Programming:** TL866 programmer + **XGPro**. This project's own board
  uses a 27128 out of convenience (see Hardware Reference §7); 2764 is the
  officially documented and default-built option.
- **PC:** Python 3 + pyserial.
- **PDF processing:** `poppler` (`pdftoppm`/`pdftotext`), installed via
  MSYS2/pacman at `C:\msys64\mingw64\bin` (on PATH) — needed for scanned
  PDFs with no text layer.

## Roadmap

**Phase 1 (serial loader) is complete and validated on hardware:**
`loader/loader.asm` (protocol:
`[55h sync][AAh][flags][addr_lo][addr_hi][len_lo][len_hi][payload…][chk]`,
`chk` = sum mod 256 of the payload, ACK=06h/NAK=15h, `flags` bit0 = GO),
`tools/profi5e_load.py`, and all three example programs.

**Phase 2:** `tools/bin2wav.py`, a BIN→WAV encoder for the monitor's
cassette format, deriving exact timings from routines 0B80h/0C60h (already
disassembled).

## Assembly code conventions

- Classic Intel 8080/8085 syntax (MOV/MVI/LXI…). Comments in English.
- `ORG 2000h` for the loader; its own working RAM sits in unused space below
  87ACh (currently 8784h–878Ah, stack above that up to 87ABh), never touching
  87ACh+ (monitor state) or 87F8h+ (display) except intentionally.
- Monitor routines are always referenced through a named `EQU`
  (e.g. `RXCHAR EQU 04F1h`), never as bare addresses in the code body.
