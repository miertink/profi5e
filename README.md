# PROFI-5E Serial Loader + Development Toolchain

A development chain for the **PROFI-5E**, an Intel 8085A single-board
trainer computer built by Ingenieur-Büro Kammerer (Germany, 1984–2011): a
serial loader that runs from the board's expansion EPROM socket, and a
Python client that sends programs to it over USB-serial from a PC.

Full project rationale, current status, and repository layout: **[PROJECT.md](PROJECT.md)**.
All hardware facts (memory map, I/O, keyboard, DIL switches, monitor ROM API,
serial framing): **[docs/Profi5E_Hardware_Reference.md](docs/Profi5E_Hardware_Reference.md)**.

## What it does

1. **`loader/loader.asm`** — burned to an EPROM in the expansion socket
   (2000h). On boot, listens on the serial line (SID/SOD, via the monitor
   ROM's own `RXCHAR`/`TXCHAR` routines) for a framed binary, writes it to
   RAM, checksums it, and runs it.
2. **`tools/profi5e_load.py`** — PC-side client. Sends a `.bin` with a
   sync/header/checksum frame over a serial port, waits for ACK/NAK, and
   (by default) tells the board to run it immediately.
3. **`tools/profi5e_build.py`** — assembles an `examples/*.asm` source for a
   chosen RAM address, so its output lines up with the `--addr` given to
   `profi5e_load.py`.
4. **`examples/`** — small demo programs (7-segment display output) that
   exercise the loader end to end.

Not yet started: a BIN→WAV encoder for the monitor's cassette-tape format,
as a hardware-free alternative loading path (see PROJECT.md Roadmap).

## Requirements

- **Assembler:** [Macro Assembler AS](https://github.com/Macroassembler-AS/asl-releases)
  (`asl` + `p2bin`) on `PATH`.
- **Python 3** with [`pyserial`](https://pypi.org/project/pyserial/)
  (`pip install pyserial`).
- A PROFI-5E board with the expansion EPROM socket populated, and a 5V
  USB-TTL serial adapter wired to SID/SOD (see Hardware Reference §9).

New to the command line, or don't have `asl`/`p2bin`/Python installed yet?
**[docs/Setup_Tutorial.md](docs/Setup_Tutorial.md)** is a from-scratch,
no-experience-assumed walkthrough for installing all of the above on
Windows.

## Quickstart

Build the loader and burn it to an EPROM in the expansion socket:

```sh
cd loader
./build.sh          # -> loader.bin, 8 KB, for a 2764 (the documented chip for this socket)
./build.sh 27128    # -> loader.bin, 16 KB, for a 27128 instead (see Hardware Reference §7)
```

Set the board's DIL switches (see Hardware Reference §6 for the full table):

- **Switch 5 = OFF** (no serial handshake)
- **Switch 6 = OFF** (V.24/serial output, not Centronics)
- **Switch 7/8** = desired baud rate, must match `--baud` below
- **Switch 4 = OFF** for auto-boot into the loader on power-up (otherwise
  start it manually — Hardware Reference §5.3)

Build and load an example program:

```sh
python tools/profi5e_build.py examples/hiworld.asm --addr 8000
python tools/profi5e_load.py examples/hiworld.bin --port COM4 --addr 8000
```

**The `--addr` passed at build time and at load time must be the same
value.** 8085 code is not position-independent: `profi5e_build.py --addr`
controls what address the code is assembled for (baked into internal
jumps/calls), while `profi5e_load.py --addr` only controls where the board
writes the incoming bytes. A mismatch loads and ACKs successfully, but the
program jumps to the wrong places the moment it runs. `profi5e_build.py`
prints the matching load command after every build as a reminder.

## Third-party material

The code and documentation authored in this repository are MIT-licensed
(see [LICENSE](LICENSE)).

`rom/Profi5E.BIN` (a dump of this board's own monitor ROM) and the scanned
manuals/schematics under `docs/*.pdf` are copyrighted material from
Ingenieur-Büro Kammerer, not authored by this project. They're included here
for personal reference, interoperability, and preservation of an otherwise
hard-to-find piece of retrocomputing hardware documentation — not licensed
for redistribution or reproduction elsewhere.
