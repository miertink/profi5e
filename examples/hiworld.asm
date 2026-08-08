; ============================================================
; hiworld.asm -- static "hi-world" message on the display
;
; Loads into RAM via the serial loader (tools/profi5e_load.py). Writes
; the message once, then loops forever so it stays on screen (no RST 3
; -- returning to the monitor would let its own UI overwrite the
; display).
;
; "hi-world" is exactly 8 characters -- fills the whole display,
; no blank padding needed.
;
; Assembled for 8000h by default. This is NOT position-independent code
; -- if you need it resident at a different address (e.g. to keep it
; loaded alongside another example), rebuild with:
;   python tools/profi5e_build.py examples/hiworld.asm --addr 8200
; and pass the SAME --addr to profi5e_load.py -- the build and load
; addresses must match, or the program reads/jumps to the wrong places.
;
; Typical use:
;   python tools/profi5e_build.py examples/hiworld.asm --addr 8000
;   python tools/profi5e_load.py examples/hiworld.bin --port COM4 --addr 8000
; ============================================================

        IFNDEF LOADADDR
LOADADDR EQU  8000h
        ENDIF
        ORG   LOADADDR

DISPSTR   EQU  0360h    ; BC=ptr to 8 segment bytes -> 87F8h

START:
        LXI   B,MSG
        CALL  DISPSTR

HANG:
        JMP   HANG

; ============================================================
; Segment patterns: bit0=a bit1=b bit2=c bit3=d bit4=e bit5=f bit6=g
; Cross-checked against the ra1fh/profi-5e-ihex display defs (same
; source used elsewhere in this project). 'w' has no standard
; 7-segment glyph -- approximated with the same pattern as 'u'/'v'.
; ============================================================
SEG_h        EQU  74h    ; h
SEG_i        EQU  10h    ; i (segment e only -- a single vertical stroke;
                          ; the reference table's 0x19 looked like a
                          ; truncated 'C' on real hardware)
SEG_DASH     EQU  40h    ; -
SEG_w        EQU  1Ch    ; w (approximation, see note above)
SEG_o        EQU  5Ch    ; o
SEG_r        EQU  50h    ; r
SEG_l        EQU  38h    ; l
SEG_d        EQU  5Eh    ; d

MSG:
        DB    SEG_h,SEG_i,SEG_DASH,SEG_w,SEG_o,SEG_r,SEG_l,SEG_d

        END   START
