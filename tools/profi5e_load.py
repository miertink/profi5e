#!/usr/bin/env python3
"""Serial client for the PROFI-5E loader (loader/loader.asm, ORG 2000h).

Sends a binary file to the board over the serial port, following the
loader's v1 protocol:

    [55h sync] [AAh cmd] [flags] [addr_lo] [addr_hi] [len_lo] [len_hi]
    [payload...] [chk]

chk = sum modulo 256 of the payload bytes. flags bit0 = GO (run via PCHL
after loading; otherwise the board returns to the monitor) -- set by
default, pass --no-go to skip it. Waits for ACK (06h) or NAK (15h) over
SOD after the checksum.

--addr only tells the board where to *write* the incoming bytes -- it does
not relocate the code. 8085 binaries are not position-independent, so
--addr must match the address the .bin was actually assembled for (see
LOADADDR in examples/*.asm and tools/asm_build.sh) or the program will
read/jump to the wrong places once it runs.

Requires: pip install pyserial
"""
import argparse
import sys
import time

import serial

SYNC = 0x55
CMD = 0xAA
ACK = 0x06
NAK = 0x15

# The loader is bit-banged and has no receive buffer: each byte must be
# fully processed (RX + write to RAM) before the next one arrives. This
# gap between bytes avoids missing a start bit. Adjust/remove if the
# loader ever gains a buffer/FIFO.
INTER_BYTE_GAP_S = 0.002


def send_byte(ser: serial.Serial, value: int) -> None:
    ser.write(bytes([value & 0xFF]))
    time.sleep(INTER_BYTE_GAP_S)


def load_file(port: str, baud: int, addr: int, data: bytes, go: bool, timeout: float) -> bool:
    if len(data) > 0xFFFF:
        raise ValueError(f"file larger than 64 KB ({len(data)} bytes)")

    flags = 0x01 if go else 0x00
    checksum = sum(data) & 0xFF

    # stopbits=2: confirmed in the manual (Bedienungsanleitung, 11.2) that
    # the PROFI-5E's V.24 uses 2 stop bits. Not critical (the board only
    # detects the edge of the next start bit), but keeps the host faithful
    # to what the hardware actually uses.
    with serial.Serial(port, baud, bytesize=8, parity="N", stopbits=2, timeout=timeout) as ser:
        # Discard anything already sitting in the OS receive buffer (e.g. a
        # stray ACK left over from a previous run) so the ACK/NAK we read
        # below is guaranteed to be a fresh reply to *this* transfer, not a
        # stale byte misread as success.
        ser.reset_input_buffer()

        header = [
            SYNC,
            CMD,
            flags,
            addr & 0xFF,
            (addr >> 8) & 0xFF,
            len(data) & 0xFF,
            (len(data) >> 8) & 0xFF,
        ]
        for b in header:
            send_byte(ser, b)
        for b in data:
            send_byte(ser, b)
        send_byte(ser, checksum)

        reply = ser.read(1)
        if not reply:
            print("Error: no response from the board (timeout).", file=sys.stderr)
            return False
        if reply[0] == ACK:
            suffix = " (GO)" if go else "."
            print(f"OK: {len(data)} bytes loaded at {addr:04X}h{suffix}")
            return True
        if reply[0] == NAK:
            print("Error: NAK -- invalid checksum on the board.", file=sys.stderr)
            return False
        print(f"Error: unexpected reply ({reply[0]:02X}h).", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Send a .bin to the PROFI-5E serial loader")
    parser.add_argument("file", help=".bin file to send")
    parser.add_argument("--port", required=True, help="serial port (e.g. COM4, /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=2400, help="baud rate (default: 2400)")
    parser.add_argument(
        "--addr", default="8000",
        help="destination address in hex, no prefix (default: 8000) -- must match the "
             "address the .bin was actually assembled for (its ORG/LOADADDR); this only "
             "tells the board where to write the bytes, it does not relocate the code",
    )
    parser.add_argument(
        "--no-go", dest="go", action="store_false",
        help="don't run the program after loading -- just leave it in RAM and return to the monitor "
             "(by default the board runs it via PCHL right after loading)",
    )
    parser.set_defaults(go=True)
    parser.add_argument("--timeout", type=float, default=5.0, help="ACK/NAK wait timeout, in seconds")
    args = parser.parse_args()

    addr = int(args.addr, 16)
    with open(args.file, "rb") as f:
        data = f.read()

    ok = load_file(args.port, args.baud, addr, data, args.go, args.timeout)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
