# PROFI-5E Hardware Reference

Consolidated technical reference for the IED Kammerer PROFI-5E single-board
computer, compiled from the ROM disassembly, the official schematic, and the
official manuals. This is the single source of truth for hardware facts on
this project — read it before touching any assembly code.

**Identity:** Einplatinencomputer PROFI-5E, Ingenieur-Büro Kammerer
(Kirchheim, Germany). Product family PROFI-5, "E" variant produced 1984–2011.
Used as an official training device by the Heinz-Piest-Institut (HPI),
Hannover. Documented in the book *Mikrocomputer-Fachpraxis* (Lamparter); the
ROM's resident disassembler string reads "DISASSEMBLER Stand:19.6.1985".

**Sources:**
- `rom/Profi5E.BIN` — 8 KB monitor ROM dump, read from the user's own physical
  EPROM (the authoritative reference for this specific board; see "ROM
  variants" below for other files that were considered and rejected).
- `docs/Profi5E_disassembly.lst` — full disassembly of the above, produced by
  `tools/dis85.py`.
- `docs/Profi-5E_SW.pdf` — official schematic, KiCad redraw (2024, rev 1.1),
  black-and-white version processed (identical page count/size to the color
  version, cheaper to read).
- `docs/Profi-5E Bedienungsanleitung.pdf` — official operating manual, Josef
  Kammerer, 3rd edition, EPV-Verlag 1999, ISBN 3-924544-72-2. Scanned, no text
  layer; high-value sections processed page-by-page (cover/specs, block
  diagram, keyboard, DIL switches, memory/jumpers, I/O connector, execution
  modes, monitor subroutine summary, V.24 appendix, SMP-Bus appendix, original
  schematic sheets). Sections 5 (manual RAM programming walkthrough), 9.1–9.3
  (per-routine usage examples), 10 (interrupt handling walkthrough) and 11.1
  (Centronics) were not processed in detail — the 9.4 summary table and the
  disassembly cover the same ground for this project's purposes.
- `docs/Profi-5E Training.pdf` — 8085 assembly exercise workbook (has a text
  layer, read in full). Confirms register/port conventions already known;
  no project-specific findings.
- `docs/Profi-5E Bauanleitung.pdf` — construction manual. Not processed.

---

## 1. System overview

| | |
|---|---|
| CPU | Intel 8085A |
| Clock | 6.144 MHz crystal (confirmed on schematic, Q1) → 3.072 MHz T-state clock |
| Monitor ROM | 8 KB, EPROM 2764, address 0000–1FFF |
| Base RAM | 2 KB (I6, UM6116-2), address 8000–87FF |
| Expansion | Up to 22 KB total: +8 KB EPROM (2000–3FFF) + 2×2 KB RAM (7000–77FF, 7800–7FFF) |
| I/O | 3× Intel 8255 PPI (3 ports × 8 bit each) |
| Display | 8-digit 7-segment, driven by an ICM7218E display controller (I5), hardware-refreshed |
| Keyboard | 26 keys: 16 hex (black) + 9 function (orange) + 1 reset (red) |
| Serial | V.24-style interface, baud/mode set by DIL switches |
| Cassette | Kansas-City-style FSK audio on/off port 22h bit 0 / port 21h bit 0 |
| Power | 5 V, ~650 mA typical (750 mA–1 A supply recommended) |
| Expansion bus | 64-pin connector, Siemens SMP-Bus standard for 8080/8085 systems (populated only on full builds) |

---

## 2. Memory map

| Range | Size | Content |
|---|---|---|
| 0000–0FFF | 4 KB | Monitor program |
| 1000–18BF | ~2.2 KB | Self-test / demo program (checksum, RAM/port/display/keyboard/serial/Centronics tests, BCD games) |
| 1C00–1F9B | ~0.9 KB | Resident 8085 disassembler |
| 2000–3FFF | 8 KB | Expansion EPROM socket (I14). Official use: "user programs for extra functions, Assembler P5". **This project's loader lives here.** |
| 7000–77FF | 2 KB | Optional expansion RAM 1 (I8), populated only on full builds |
| 7800–7FFF | 2 KB | Optional expansion RAM 2 (I7), populated only on full builds |
| 8000–87FF | 2 KB | Base RAM (I6). User area 8000–87AB; monitor stack/variables above (see below) |

I/O ports are also memory-mapped, 1:1 with their I/O addresses shifted to 4000h+: Port 1 → 4000–4003h, Port 2 → 4010–4013h*, Port 3 → 4020–4023h (`*` = full builds only).

### Monitor RAM variables (8000–87FF)

| Address | Purpose |
|---|---|
| 8000 | Default user program start (PC preset here on cold start) |
| 8000–87AB | Free user area |
| 8790 | Default user stack pointer (set on cold start) |
| 87AC | Top of the **monitor's own** stack (`LXI SP,87ACh`) — do not confuse with the user SP default above |
| 87B0–87B7 | Breakpoint shadow area (saved original instruction + trampoline `JMP`) |
| 87C0 | Generic pointer (block end in SAVE/MOVE) |
| 87C2/87C3 | Single-step/breakpoint state-machine flags (values 55/75/AB/EE) |
| 87C6 | Serial half-bit delay constant (set by `BAUD`, 056Bh) |
| 87C8 | Serial full-bit delay constant (set by `BAUD`, 056Bh) |
| 87D0–87D2 | RST 7.5 vector → `JMP 080Ah` (default: single-step engine — do not remap) |
| 87D3–87D5 | RST 6.5 vector (free user hook) |
| 87D6–87D8 | RST 5.5 vector (free user hook) |
| 87D9 | Digit-blanking mask (1 bit per display digit) |
| 87DA–87DC | RST 7 / INTR vector (free user hook) |
| 87E0 | Current address shown on display |
| 87E2 | Saved user SP |
| 87E4/87E6/87E8/87EA | Saved user HL / DE / BC / PSW (inspectable via the R key) |
| 87EC | Data value being edited |
| 87EE | Address value being edited |
| 87F3 | Keyboard debounce flag |
| 87F4–87F7 | Hex value being converted to display digits (4 bytes, see `DECOD`) |
| 87F8–87FF | **Display memory: 8 bytes = 8 digits, 1 byte per digit (segment pattern), hardware-refreshed** |

With jumper B2 open (shortened RAM, see §6), the equivalent system-cell block is 83AC–83FF instead of 87AC–87FF (the whole system-variable window shifts down because only 1 KB of RAM is fitted).

### Display encoding

Segment bits: bit0=a, bit1=b, bit2=c, bit3=d, bit4=e, bit5=f, bit6=g, bit7=decimal point.
Hex-to-segment table, ROM address **02CCh**, 16 bytes, digits 0–F:
`3F 06 5B 4F 66 6D 7D 07 7F 6F 77 7C 39 5E 79 71`

Confirmed segment patterns for the letters this project uses (cross-checked
against the independent `ra1fh/profi-5e-ihex` project's display defs — exact
match): `L=38h`, `o=5Ch`, `A=77h`, `d=5Eh`.

Reusable system message strings (8-byte segment patterns) in ROM:
- `"EndE"` at **0EBBh** (the routine at 0EB2h, `ENDE`, loads this and jumps into the monitor loop — does not return; this project loads the string address directly and calls TEXT8/0360h instead, then continues its own flow)
- `"FEHLEr"` at **03E7h** (routine `FEHLN`, 03CCh, loads this exact address and calls TEXT8, then returns)
- `"bU5y"` at 0F27h, `"SuchE"` at 0E28h

---

## 3. I/O map — three 8255 PPIs

| Ports | Chip | Use |
|---|---|---|
| 00h(PA)/01h(PB)/02h(PC)/03h(ctrl) | 8255 #1 (I12) | Free user experimentation port, brought out to the 64-pin connector. Reset control word 92h (A=in, B=in, C=out); self-test uses 80h (all out) |
| 10h(PA)/11h(PB)/12h(PC)/13h(ctrl) | 8255 #2 (I11) | Centronics printer interface: data on port 11h, STROBE = port 12h bit4 (pulse), BUSY = port 12h bit0. Normal ctrl = 91h. Ctrl = 9Bh reconfigures port 11h bit0 as a serial handshake "ready" input |
| 20h(PA)/21h(PB)/22h(PC)/23h(ctrl) | 8255 #3 (I10) | Keyboard, configuration/DIL-switch readback, cassette, speaker. Ctrl = 92h on reset. Not user-available (drives system functions) |

### Port 3 detail (I10)

- **Port 22h (output):**
  - bits 4/5/6 (active-low, patterns EFh/DFh/BFh): keyboard column select
  - bit 0: audio output — speaker and cassette recording (software-toggled tone generator, routine 0B80h)
- **Port 20h (input):** 8 keyboard row lines (active-low). 3 columns × 8 rows = 24 keys: 16 hex (codes 00–0Fh) + 8 function (codes 10h–17h). See §5 for the physical mapping.
- **Port 21h (input) — configuration/status, reflects the physical DIL switches, not writable:**
  - bit 0: cassette input (pulse-width sensing)
  - bit 2/3: baud rate select (DIL switch 8 / 7 — see §6)
  - bit 4: character-output device select (0=Centronics, 1=serial/SOD) — DIL switch 6
  - bit 5: serial handshake mode — DIL switch 5
  - bit 6: cold-start vector (0=0000h, 1=2000h) — DIL switch 4, i.e. "auto-boot into the expansion EPROM"
  - bits 2–7, masked FCh in the self-test menu: test-program selection (64h = self-test menu; 24h/1Ch/58h/54h = variants)

### 64-pin I/O connector (S2), ports 1 & 2 only

Full pin table lives in the manual (§8.1); relevant summary: all 24 8255 #1/#2
lines are broken out, plus +5V (pin a3), 0V (pins a1/a2), and INT (pin b32,
wired to RST 7.5 via the dedicated hardware interrupt button).

---

## 4. Interrupt vectors (8085)

| Vector | Addr. | Destination |
|---|---|---|
| RESET | 0000 | Init 8255s, SP=87ACh, RAM vectors copied, variables cleared, cold-start test (port 21h bit6 → 2000h), `SIM 1Bh` (enables RST 7.5 only), splash display, main loop at 0066h |
| RST 3 (0018) | 0018 | **Re-enter the monitor, saving all registers** (PSW, BC, DE, HL, SP) — the recommended way to end a user program |
| RST 4 (0020) | 0020 | Same, via 003Fh |
| TRAP (0024) | 0024 | `JMP 1000h` → self-test program |
| RST 5.5 (002C) | 002C | `JMP 87D6h` (free user hook in RAM) |
| RST 6 (0030) | 0030 | `JMP 019Ah` (internal) |
| RST 6.5 (0034) | 0034 | `JMP 87D3h` (free user hook in RAM) |
| RST 7 (0038) | 0038 | `JMP 87DAh` (free user hook in RAM) |
| **RST 7.5 (003C)** | 003C | `JMP 87D0h` → default **080Ah**, the single-step/breakpoint engine. **Never remap this if single-step must keep working.** |

Single-stepping is hardware-assisted: a circuit fires RST 7.5 after every user
instruction; the handler at 080Ah saves all registers to 87E0–87EA, updates
the display, and returns control to the monitor. Breakpoints work by
replacing the target instruction with a `JMP` to a trampoline (original opcode
preserved at 87B0+).

The dedicated hardware **Interrupt key ("I")** also drives RST 7.5, with two
behaviors depending on DIL switch 5 (§6): monitor warm-start, or a
user-defined interrupt (if 87D0h were remapped, which is otherwise
discouraged).

---

## 5. Keyboard

Physical layout (5×5 grid of 25 keys + 1 separate reset button = 26 total):

```
 G   E   B   F   I
 C   D   E   F   R
 8   9   A   B   A
 4   5   6   7   D
 0   1   2   3   S
```
16 black hex keys (0–9, A–F) occupy the 4×4 sub-grid (rows 2–5, columns 1–4).
The 9 orange function keys are: the whole top row (G, E, B, F, I) plus column
5 of rows 2–5 (R, A, D, S). `F` is not a function key in this sense — it is a
separate prefix key for numbered system functions (§5.2). Reset is a 10th,
physically separate red button.

### 5.1 Function keys (matrix codes 10h–17h)

All eight cross-checked three ways: physical label (schematic key-generator
table), functional description (manual §3.1), and destination address
(ROM dispatch table at 0098h, decoded directly from the binary).

| Code | Key | ROM target | Function |
|---|---|---|---|
| 10h | **E** | 08F0h | Single-step (Einzelschritt) |
| 11h | **G** | 0927h | Run (Automatikbetrieb / GO) |
| 12h | **R** | 0400h | Show register (Registerinhalt anzeigen); next hex key 5–F picks which: A=Akku, B=RegB, C=RegC, D=RegD, E=RegE, F=Flags(hex), 8=H, 9=L, 7=SP, 6=last PC, 5=Flags(binary) |
| 13h | **D** | 00CDh | Decrement displayed address |
| 14h | **A** | 004Ch | Commit edited value into the address field (Adresse wählen) |
| 15h | **S** | 00A8h | Store edited value into RAM at the current address, advance address (Speichern) |
| 16h | **B** | 0A53h | Set the Program Counter to the edited address (Befehlszähler setzen) |
| 17h | **C** | 0188h | Clear / cold start (same effect as power-on: PC=8000h, user SP=8790h, 8255 #1/#3 ctrl=92h) |

Ninth orange key, **not** in the 10h–17h matrix (dedicated wiring, drives RST 7.5 directly): **I** = Interrupt (see §4).

### 5.2 System functions (F + hex digit)

| Key | Function |
|---|---|
| F0 | unused |
| F1 | Insert a NOP at the current address |
| F2 | Insert a NOP, also fixing up relative jump/call targets within the page (XX00–XXFF) |
| F3 | Delete the current cell, shift the rest of the page up |
| F4 | Save RAM contents to cassette |
| F5 | Load RAM contents from cassette |
| F6 | HEX-DUMP printout |
| F7 | Disassembler printout |
| F8 | ASCII text input (serial/terminal) |
| F9 | ASCII text output (serial/terminal) |
| FA | Fill memory cells with a constant |
| FB | Set a breakpoint |
| FC | Move a memory block |

### 5.3 Confirmed keystroke sequence: run a program at address X

1. Press **B** (orange) — display shows `PC- 8000` (or the last PC value)
2. Enter the address on the hex keypad — display updates as digits are typed
3. Press **A** to commit it into the address field, or **S** if you're
   also confirming/storing a data value — for setting the *program counter*
   specifically, the manual's own worked example uses **B → [hex digits] → S**
   (the dash in `PC-` becomes solid, confirming the PC is now set)
4. Press **G** to run, or **E** to single-step one instruction at a time
5. On HALT, press **I** to show the final register state; press **I** again
   (~1s later) for a warm-start back to the idle `0000` display

This is the manually-driven equivalent of the "auto-boot" DIL switch (§6) —
useful for testing code in the expansion EPROM without relying on that
switch.

---

## 6. DIL switches

8 switches on the lower edge of the board.

> **Required for this project** (plain 3-wire USB-TTL adapter, no hardware
> handshake line): **Switch 5 = OFF**, **Switch 6 = OFF**. Switch 7/8 set the
> baud rate (table below) and must match `--baud` in `tools/profi5e_load.py`.
> Switch 4 = OFF only if auto-boot into 2000h is wanted; otherwise use the
> manual GO sequence (§5.3). This differs from the factory-recommended
> default (all 8 switches "ON") — with Switch 5 = ON there is no handshake
> wire connected, so `TXCHAR` hangs forever after sending; with Switch 6 =
> ON, `TXCHAR` sends over Centronics instead of SOD and nothing reaches the
> PC at all.
>
> **The physical switch position has repeatedly not matched what it was
> believed to be set to.** If serial communication misbehaves, don't trust
> a glance at the switches — write a few lines that `IN 21h` and show the
> raw byte as 2 hex digits on the display, live, to confirm what the CPU
> actually sees.

| Switch | ON | OFF |
|---|---|---|
| 1 | RST 6.5 → PC3 (I11) connected | RST 6.5 → PC3 disconnected |
| 2 | RST 5.5 → PC0 (I11) connected | RST 5.5 → PC0 disconnected |
| 3 | Single-step treats a subroutine call as one instruction | Single-step steps *into* the subroutine |
| 4 | Cold start at 0000h | **Cold start at 2000h** (the "auto-boot into the expansion EPROM" this project relies on) |
| 5 | I-key = monitor warm-start; serial transfer **with** handshake | I-key = user interrupt; serial transfer **without** handshake |
| 6 | Centronics interface enabled | **V.24 (serial) interface enabled** |
| 7+8 | Baud rate, see table below | |

Baud rate (switches 7 and 8), read by the ROM routine `BAUD` (056Bh) from
port 21h bits 3/2:

| Switch 7 | Switch 8 | Baud |
|---|---|---|
| ON | ON | 300 |
| ON | OFF | 600 |
| OFF | ON | 1200 |
| OFF | OFF | 2400 |

Note: `TXCHAR`'s handshake check (bit 5) happens *after* the byte is fully
transmitted, not before — so with Switch 5 = ON and no handshake wire
connected, a byte still goes out cleanly but the routine then hangs forever
afterward. This makes a handshake misconfiguration look, from the PC side,
like the board sent a valid reply and then simply stopped responding —
worth knowing since it's not an obvious "nothing was sent" symptom.

### Handshake is a separate wire, not a data-line protocol

Confirmed in the manual (§11.2): the V.24 interface's handshake uses an
*additional* line, **pin 5** of the V.24 connector. Level 0 (~+4V) = transfer
enabled; level 1 (~-4V) = the PROFI-5E pauses transmission until level 0
returns. This is electrically a busy/ready flag akin to RTS, entirely
separate from the TX/RX data lines. With a plain TXD/RXD/GND USB-TTL cable
there is no such wire, confirming Switch 5 must be OFF.

### Framing

The manual's timing diagram (§11.2) shows **2 stop bits** for V.24 transfers
(`tools/profi5e_load.py` opens the port accordingly). 8 data bits, no parity,
LSB-first, idle-high, start-bit-low — standard, non-inverted UART framing,
identical to what a generic USB-TTL adapter expects (confirmed independently
from the TX routine's disassembly).

---

## 7. Jumpers

| Jumper | Setting | Effect |
|---|---|---|
| B1 | pins 1-2 closed | Expansion socket I14 accepts EPROM **2716** |
| B1 | pins 3-4 closed | Expansion socket I14 accepts EPROM **2732, 2764**, or CMOS-RAM **6264** |
| B2 | closed | Full system RAM range, 8000–87FFh, system cells at 87ACh+ |
| B2 | open | Shortened RAM range, 8000–83FFh, system cells at 83ACh+ (compatible with the older PROFI-5/PROFI-50 boards) |
| BR3 | closed (BR4, BR5 open) | EPROM **2732, 2764** |
| BR5 | closed (BR3, BR4 open) | CMOS-RAM **6264** |
| **BR4** | **must never be closed** | explicit manufacturer warning, on both the manual and the schematic |

**Officially documented / recommended chip: 2764 (8 KB)**, jumper B1 pins
3-4. This is the loader's default build target (`loader/build.sh`, no
arguments): `ORG 2000h` maps directly to file offset 0, the whole 8 KB chip
is addressable, no padding or offset trick needed.

**This project's own board is instead fitted with a 27128 (16 KB)** in
socket I14, using the same jumper positions as the 2764 ("B1 pins 3-4",
"B2 pins 1-2") — purely a convenience choice (many 27128s on hand, only a
couple of 2764s), not a hardware requirement. Neither the manual nor the
schematic documents a 27128 option by name for this socket (both only go up
to 2764/6264). **Empirically confirmed:** socket address line A13 is tied to
VCC, so only the *upper* 8 KB of the 27128 (chip-internal 2000h–3FFFh) is
reachable by the CPU, mapped to bus address 2000h–3FFFh — consistent with the
memory map, which only ever reserved 8 KB for this socket regardless of the
physical chip's capacity. Code assembled with `ORG 2000h` must be placed at
**offset 2000h** within the 16 KB image written to the chip, not offset 0.
Build this variant with `loader/build.sh 27128` (see `tools/asm_build.sh`).

---

## 8. Monitor ROM subroutine reference

All addresses are absolute ROM addresses, callable with a normal `CALL`.

| Name | Addr. | Registers | Description |
|---|---|---|---|
| TASTD | 0216h | A,F,B,D,E | Wait for a key (blocking), debounced. Returns code in A: 00–0Fh=hex, 10h–17h=function |
| TASTM | 0223h | A,F,B,D,E | Poll keyboard, non-blocking. A=FFh if nothing pressed |
| TEXT8 | 0360h | B,C | Show 8 characters (segment patterns) on the display. BC = pointer to 8 consecutive bytes; BC += 8 on return |
| TEXT1 | 03E0h | B,C | Same as TEXT8 for 1 character; BC += 1 on return |
| DECOD | 01C0h | all | Show cells 87F4–87F7 (or 83F4–83F7 with jumper B2 open) as hex digits, respecting the 87D9h blank mask |
| DISRG | 01A1h | all | Show the address/data register pair (87EC–87EF / 83EC–83EF) |
| FEHLN | 03CCh | — | Print "FEHLEr" (internally: `LXI B,03E7h` + call TEXT8), then return |
| ENDE | 0EB2h | — | Print "EndE" (internally: `LXI B,0EBBh` + call TEXT8), then **jumps into the monitor loop — does not return** |
| TEMAS | 07CCh | A,F,B,C | Overlay text/symbols onto the display |
| DUNKL | 0380h | — | Blank the display |
| 02CCh | 02CCh | — | Hex→7-segment lookup table (16 bytes, index by nibble) |
| ZSECD | 0300h | A,F | Delay, N×0.1s, N **decimal** in Akku (0–9.9s) |
| ZSECH | 0303h | — | Delay, N×0.1s, N **hex** in Akku (0–25.5s) |
| SECD | 0310h | A,F | Delay, N×1s, N **decimal** in Akku (0–99s) |
| SECH | 0313h | — | Delay, N×1s, N **hex** in Akku (0–255s) |
| ZADE | 03F0h | — | Delay, N×0.1s, N = Akku×RP_D (up to 6553.5s) |
| TDE | 03F4h | A | Delay, N×0.1s, N in RP_D |
| T45 | 02DDh | D,E,F | Fixed delay, 4.5 ms |
| T90 | 02EAh | D,E,F | Fixed delay, 9 ms |
| T270 | 02EFh | D,E,F | Fixed delay, 27 ms |
| EXAF | 03FAh | A,F | Swap Akku ↔ Flags |
| EXHL | 031Ah | H,L | Swap H ↔ L |
| HLBC | 03C0h | F | Compare BC vs HL: CY=1 if BC>HL |
| HLDE | 06BFh | F | Compare DE vs HL: CY=1 if DE>HL |
| HEXDZ | 0370h | A,F | Hex → decimal (Akku); shows "FEHLER" if decimal result > 99 |
| DEZHX | 0390h | A,F | Decimal → hex (Akku); shows "FEHLER" on invalid BCD |
| **BAUD** | **056Bh** | — | Read port 21h bits 2-3 (DIL switches 7/8) and set the 87C6h/87C8h serial timing constants |
| **RXCHAR** ("ASCII" in some sources) | **04F1h** | — | Receive one byte over SID (internally bit-banged). Blocking, no error/timeout signaling. Returns byte in A |
| **TXCHAR** ("MODE" in some sources) | **0EC3h** | — | Send the byte in A over SOD (or Centronics, per port 21h bit4); if handshake is enabled (port 21h bit5=0) and no ready signal arrives, this hangs |
| 06A7h | 06A7h | B,C | Send 2 characters via TXCHAR |
| 0B80h | 0B80h | H,E,D | Tone generator (speaker/cassette). H=period, D/E=duration |
| 0B9Bh | 0B9Bh | — | Cassette SAVE |
| 0CEDh | 0CEDh | — | Cassette LOAD/seek ("SuchE" while searching, "EndE" when done) |
| 0CB0h | 0CB0h | — | Cassette pulse-width read (threshold 7Fh) |
| 0C60h | 0C60h | — | Cassette bit-out |

The three bold entries (BAUD/RXCHAR/TXCHAR) are what this project's loader
(`loader/loader.asm`) calls directly, instead of bit-banging its own UART.

### Function-key dispatch table

Codes 10h–17h dispatch through a jump table at ROM address **0098h** (16
bytes, 8 little-endian pointers, index = code AND 07h). See §5.1 for the
decoded table.

### Write-pointer bounds check

The receive loop never trusts the header's `len` field to stay in bounds: it
checks the write pointer before every byte and simply stops writing (while
still consuming the byte and updating the checksum, to stay protocol-in-sync)
once the pointer reaches 87ACh — the monitor's own stack/variables. Without
this, a garbled `len` (e.g. from a baud mismatch corrupting whatever
`RXCHAR` samples) could march the write pointer far past the intended
target and smear incoming noise across monitor RAM, regardless of whether
the checksum later fails — by the time a bad checksum triggers "FEHLEr",
the out-of-bounds writes have already happened.

If monitor RAM ever does get corrupted this way (garbled values at
prompts, e.g. a `B`-key address that reads like garbage), a **full power
cycle** (not just the reset button/`C` key) is the reliable fix — cold
start only reinitializes specific variables (SP, PC, 8255 control words),
not necessarily everything that could have been smashed.

---

## 9. Serial interface (V.24 / SID / SOD)

**Electrical:** the board has no real ±12V rail. The physical V.24 DB
connector is driven by I15/I16 (TAA765A comparators) and I9 (LM224 quad
op-amp), powered from a negative rail synthesized by **I17, an
LMC7660/ICL7660 charge pump**, from the 5V supply — a low-swing pseudo-RS232,
not full EIA levels. **SID and SOD connect directly to the 8085's own pins**,
upstream of all that analog conditioning.

**Wiring decision for this project:** bypass the V.24 DB connector entirely.
Connect a standard 5V USB-TTL adapter directly: adapter TXD → SID, adapter
RXD → SOD, GND common. No level shifter needed. Confirmed empirically: VCC=5V,
SOD idle ≈3V (a valid logic-high, reduced by the R24/R31→I9/I16 loading that
stays in parallel — not a fault). See README.md for photos of this project's
own physical connection.

### I9 and the SID contention question

I9 (LM224 quad op-amp) has one section — pin 14, the "D" op-amp of the
package — wired to the same electrical net as SID, as part of converting
the DB9 connector's incoming RS232-level signal down to TTL for the 8085.
With a USB-TTL adapter driving SID directly and I9 still seated, two output
drivers can end up on the same net — not electrically clean, though this
project's own board has run this way in practice without observed issues
(no device plugged into the physical V.24 port at the same time). SOD has
no equivalent problem: the adapter's RXD and I9/I16's inputs are just two
listeners on the 8085's own output pin, not competing drivers (this is the
R24/R31 loading noted above).

Three options, in order of preference, since I9 is socketed (not soldered):

1. **Pull I9 from its socket (recommended).** Costs nothing, instantly
   reversible, eliminates the contention risk on SID entirely. Side effect:
   disables the physical V.24 port completely while I9 is out. No other
   documented function on this board depends on I9 — the cassette interface
   is purely digital, driven straight from 8255 ports (§10), not through any
   op-amp — but this hasn't been independently re-verified pin-by-pin
   against the schematic in this pass, so a quick visual check before
   pulling it is worth doing if in doubt.
2. **Lift only pin 14** (bend it out of the socket, or trim it) instead of
   removing the whole chip. More surgical — disables just the SID-side
   receiver section, leaves the rest of I9 and the V.24 port's transmit
   side (driven by I15/I16, from SOD) untouched. Slightly fiddlier to do
   without stressing the socket contact or the pin itself.
3. **Leave I9 seated.** Works — this is what this project's own board
   currently does — but carries the contention risk above, especially if a
   real RS232 device is ever plugged into the physical V.24 connector at
   the same time as the USB-TTL adapter.

**Framing:** 8N1... actually 8N2 (2 stop bits, see §6), LSB-first, idle-high,
start-bit-low — standard non-inverted UART, matching a generic USB-TTL
adapter with no polarity inversion needed. Confirmed both from the TXCHAR
disassembly and the manual's timing diagram.

**Baud rate:** hardware-selected by DIL switches 7/8 (§6), read by `BAUD`
(056Bh) into RAM constants 87C6h/87C8h, shared by both RXCHAR and TXCHAR.
Cross-check: the factory 2400-baud constant (87C8h=0032h=50 decimal),
evaluated against the actual ROM delay-loop instruction sequence, computes to
~1285 T-states/bit — 0.4% off the 1280 T-state theoretical target at
6.144 MHz, confirming both the assumed crystal frequency and the delay-loop
model. Field note from an independent implementer (`ra1fh/profi-5e-ihex`,
same hardware): 2400 baud is not always reliable in practice even using these
same factory routines; 1200 baud tested reliably on their unit.

---

## 10. Cassette interface

Kansas-City-style FSK: recording toggles port 22h bit 0 (tone generator
0B80h, different periods for bit 0 / bit 1); reading measures half-cycle
pulse width on port 21h bit 0 (routine 0CB0h, threshold 7Fh). SAVE = 0B9Bh,
LOAD/seek = 0CEDh (display shows "SuchE" while searching, "EndE" when done).
Front-panel triggers: F4 = save, F5 = load (§5.2). Not yet implemented on the
PC side (planned: `tools/bin2wav.py`, phase 2 of this project).

---

## 11. SMP-Bus (64-pin expansion connector)

Optional expansion bus, Siemens SMP standard for 8080/8085 systems. Requires
populating I25/I26 (address/control signal generation: MEMR, MEMW, IOR, IOW
derived from the 8085's RD/WR/IO-M) and I22 (GATE signal, with I25). Not used
by this project; documented here only for completeness (full pin table in
the manual, §11.3, and the schematic).

---

## 12. ROM variants

`rom/Profi5E.BIN` is the sole ROM reference for this project: a dump of the
chip actually installed on this board. Other monitor-ROM dumps circulate
online under names like `Profi50E_M2764AFI.bin` / `JK_Monitor_P2_0_T.bin`;
where checked, they differ from this board's dump **only** within
1000h–18BEh (the self-test/demo program), a 6-byte pointer patch at
0296h–029Bh, and a 48-byte code block at 0F70h–0F9Fh (unused filler on this
board, but containing calls to `BAUD`/`RXCHAR` on the other variant — a later
monitor revision's own serial-load entry point in that gap).

**Everything this project's loader depends on — the whole 0000h–0FFFh
monitor core, including BAUD/RXCHAR/TXCHAR/TEXT8/delays — is byte-identical
across all known variants.** No reason to adopt a different variant: it
would not change anything this project uses, and would stop matching the
physical ROM chip in the machine.
