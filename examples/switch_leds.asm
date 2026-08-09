; ============================================================
; switch_leds.asm -- mirrors 8 switches onto 8 LEDs, live
;
; Needs an external I/O board (e.g. the "E-A-8" unit from
; Training.pdf SS4) connected via the 64-pin SMP-Bus expansion
; connector (populated only on full builds -- Hardware Reference
; SS11). On that board's fixed wiring, the 8 switches are on
; Kanal B and the 8 LEDs are on Kanal C of I/O-Baustein 1 (the
; first 8255, ports 00h-03h -- Hardware Reference SS3), matching
; Training.pdf SS4.1/4.2.
;
; Control word 82h (Training.pdf SS4.2 table): Kanal A=out,
; Kanal B=in, Kanal C=out. Only Kanal B (in) and Kanal C (out)
; are actually used here; Kanal A is set to out but left idle.
;
; Loaded via the serial loader (tools/profi5e_load.py). Assembled
; for 8000h by default -- see hiworld.asm for the LOADADDR/--addr
; rebuild instructions if you need it at a different address.
; ============================================================

        IFNDEF LOADADDR
LOADADDR EQU  8000h
        ENDIF
        ORG   LOADADDR

CTRL1 EQU  03h    ; I/O-Baustein 1 (8255 #1, I12) control register
PB1   EQU  01h    ; Kanal B -- 8 switches (input)
PC1   EQU  02h    ; Kanal C -- 8 LEDs (output)

START:
        MVI   A,82h        ; Kanal A=out, Kanal B=in, Kanal C=out
        OUT   CTRL1

LOOP:
        IN    PB1          ; read the 8 switches
        OUT   PC1          ; mirror them onto the 8 LEDs
        JMP   LOOP

        END   START
