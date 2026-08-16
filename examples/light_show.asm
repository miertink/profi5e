; ============================================================
; light_show.asm -- demo reel: cycles through several display +
; LED effects forever, using everything the board can visibly do.
;
; The display effects run standalone (only the base board). The
; LED effects also drive the same external 8-LED board as
; switch_leds.asm, via Kanal C of I/O-Baustein 1 (port 02h) --
; see Hardware Reference SS3 "External I/O board". Without that
; board attached, the LED writes are simply invisible/harmless;
; everything on the display still works.
;
; Effects, looped forever:
;   1. Spin    -- a single lit segment sweeps a->b->c->d->e->f->e...
;                 on every digit at once, echoed on the LEDs
;   2. Count   -- 8-bit binary counter on the LEDs; display shows a
;                 hex countdown on the left, a dash divider in the
;                 middle, and the matching hex count-up on the right
;   3. Chase   -- a single lit digit/LED bounces end to end
;                 (Knight Rider style)
;   4. Sparkle -- pseudo-random flicker across display and LEDs
;                 (8-bit Galois LFSR)
;   5. Flash   -- full-brightness strobe finale
;
; Loaded via the serial loader (tools/profi5e_load.py). Assembled
; for 8000h by default -- see hiworld.asm for the LOADADDR/--addr
; rebuild instructions if you need it at a different address.
; ============================================================

        IFNDEF LOADADDR
LOADADDR EQU  8000h
        ENDIF
        ORG   LOADADDR

DISP0   EQU  87F8h    ; display memory, 8 bytes (Hardware Reference SS2)
CTRL1   EQU  03h       ; I/O-Baustein 1 (8255 #1) control register
LEDPORT EQU  02h       ; Kanal C -- 8 LEDs (output)
HEXTAB  EQU  02CCh    ; ROM hex-to-7-segment lookup table (16 bytes)

SEED    EQU  8795h    ; (byte) LFSR state -- free RAM below the loader/
CNT     EQU  8796h    ; (byte) FX_COUNT counter -- monitor's own working area

; Segment bits: bit0=a bit1=b bit2=c bit3=d bit4=e bit5=f bit6=g
SEG_BLANK EQU 00h
SEG_ALL   EQU 7Fh      ; all 7 segments, no decimal point
SEG_DASH  EQU 40h      ; g only ("-")

; ------------------------------------------------------------
START:
        MVI   A,80h          ; Kanal A/B/C all output (only Kanal C is wired
        OUT   CTRL1          ; to LEDs on the E-A-8 board, per switch_leds.asm)
        MVI   A,01h
        STA   SEED           ; non-zero LFSR seed

MAIN:
        CALL  FX_SPIN
        CALL  FX_COUNT
        CALL  FX_CHASE
        CALL  FX_SPARKLE
        CALL  FX_FLASH
        JMP   MAIN

; ------------------------------------------------------------
; Effect 1: a single lit segment sweeps back and forth across
; a->f on every digit at once, mirrored on the LEDs.
; ------------------------------------------------------------
FX_SPIN:
        MVI   C,18            ; total steps (~2 back-and-forth sweeps)
        MVI   B,0             ; table index (0..SPIN_LEN-1)
FX_SPIN_LOOP:
        LXI   H,SPIN_SEGS
        MVI   D,0
        MOV   E,B
        DAD   D
        MOV   A,M
        CALL  FILL_DISPLAY
        OUT   LEDPORT

        PUSH  B
        MVI   B,10
        CALL  DELAY
        POP   B

        INR   B
        MOV   A,B
        CPI   SPIN_LEN
        JC    FX_SPIN_SKIP
        MVI   B,0
FX_SPIN_SKIP:
        DCR   C
        JNZ   FX_SPIN_LOOP
        RET

; ------------------------------------------------------------
; Effect 2: 8-bit binary counter on the LEDs. Display: countdown
; (left pair) -- dash divider (middle 4) -- count-up (right pair).
; ------------------------------------------------------------
FX_COUNT:
        XRA   A
        STA   CNT
        MVI   C,64
FX_COUNT_LOOP:
        LDA   CNT
        OUT   LEDPORT

        LXI   H,DISP0

        ; --- left pair: countdown, straight from C (already ticks down
        ; once per step -- no separate variable needed) ---
        PUSH  H
        MOV   A,C
        RRC
        RRC
        RRC
        RRC
        ANI   0Fh               ; high nibble
        CALL  NIBBLE_SEG
        POP   H
        MOV   M,A
        INX   H
        PUSH  H
        MOV   A,C
        ANI   0Fh               ; low nibble
        CALL  NIBBLE_SEG
        POP   H
        MOV   M,A
        INX   H

        ; --- middle: dash separator, 4 digits ("time" divider between
        ; the two counters) ---
        MVI   M,SEG_DASH
        INX   H
        MVI   M,SEG_DASH
        INX   H
        MVI   M,SEG_DASH
        INX   H
        MVI   M,SEG_DASH
        INX   H
        ; HL = DISP0+6 (7th digit)

        ; --- right pair: count-up, from CNT ---
        PUSH  H
        LDA   CNT
        RRC
        RRC
        RRC
        RRC
        ANI   0Fh               ; high nibble
        CALL  NIBBLE_SEG
        POP   H
        MOV   M,A
        INX   H
        PUSH  H
        LDA   CNT
        ANI   0Fh               ; low nibble
        CALL  NIBBLE_SEG
        POP   H
        MOV   M,A

        PUSH  B
        MVI   B,8
        CALL  DELAY
        POP   B

        LDA   CNT
        INR   A
        STA   CNT
        DCR   C
        JNZ   FX_COUNT_LOOP
        RET

; ------------------------------------------------------------
; Effect 3: Knight-Rider-style bounce -- one lit digit/LED
; sweeps 0->7->0.
; ------------------------------------------------------------
FX_CHASE:
        MVI   C,2              ; 2 full back-and-forth passes
FX_CHASE_PASS:
        MVI   B,0
FX_CHASE_FWD:
        CALL  FX_CHASE_STEP
        INR   B
        MOV   A,B
        CPI   8
        JC    FX_CHASE_FWD
        MVI   B,7
FX_CHASE_BACK:
        CALL  FX_CHASE_STEP
        DCR   B
        MOV   A,B
        CPI   0FFh
        JNZ   FX_CHASE_BACK
        DCR   C
        JNZ   FX_CHASE_PASS
        RET

; in: B = position (0-7); preserves B; clobbers A,D,H,L
FX_CHASE_STEP:
        LXI   H,DISP0
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK
        INX   H
        MVI   M,SEG_BLANK

        LXI   H,DISP0
        MVI   D,0
        MOV   E,B
        DAD   D
        MVI   M,SEG_ALL

        CALL  POS_TO_LED       ; preserves B; A = 1 shl B
        OUT   LEDPORT

        PUSH  B
        MVI   B,10
        CALL  DELAY
        POP   B
        RET

; ------------------------------------------------------------
; Effect 4: pseudo-random flicker on every digit and the LEDs.
; ------------------------------------------------------------
FX_SPARKLE:
        MVI   C,40
FX_SPARKLE_LOOP:
        CALL  RAND
        OUT   LEDPORT

        LXI   H,DISP0
        MVI   B,8
FX_SPARKLE_FILL:
        CALL  RAND
        ANI   7Fh               ; keep to the 7 real segments (no stray dp)
        MOV   M,A
        INX   H
        DCR   B
        JNZ   FX_SPARKLE_FILL

        PUSH  B
        MVI   B,6
        CALL  DELAY
        POP   B

        DCR   C
        JNZ   FX_SPARKLE_LOOP
        RET

; ------------------------------------------------------------
; Effect 5: full-brightness strobe finale.
; ------------------------------------------------------------
FX_FLASH:
        MVI   C,6               ; 6 flashes (3 on/off cycles)
FX_FLASH_LOOP:
        MVI   A,SEG_ALL
        CALL  FILL_DISPLAY
        MVI   A,0FFh
        OUT   LEDPORT
        PUSH  B
        MVI   B,10
        CALL  DELAY
        POP   B

        XRA   A
        CALL  FILL_DISPLAY
        OUT   LEDPORT
        PUSH  B
        MVI   B,10
        CALL  DELAY
        POP   B

        DCR   C
        JNZ   FX_FLASH_LOOP
        RET

; ============================================================
; Helpers
; ============================================================

; in: B = outer count (destroyed); clobbers A,B,H,L
DELAY:
DELAY_OUTER:
        LXI   H,0700h
DELAY_INNER:
        DCX   H
        MOV   A,H
        ORA   L
        JNZ   DELAY_INNER
        DCR   B
        JNZ   DELAY_OUTER
        RET

; in: A = segment pattern for all 8 digits; preserves A,B,C,D,E; clobbers H,L
FILL_DISPLAY:
        LXI   H,DISP0
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        INX   H
        MOV   M,A
        RET

; in: A = nibble (0-15); out: A = 7-seg pattern; preserves B,C; clobbers D,E,H,L
NIBBLE_SEG:
        MVI   D,0
        MOV   E,A
        LXI   H,HEXTAB
        DAD   D
        MOV   A,M
        RET

; in: B = position (0-7); out: A = 1 shl B; preserves B,C; clobbers D
POS_TO_LED:
        PUSH  B
        MVI   D,1
        MOV   A,B
        ORA   A
        JZ    POS_TO_LED_DONE
POS_TO_LED_LOOP:
        MOV   A,D
        ADD   A
        MOV   D,A
        DCR   B
        JNZ   POS_TO_LED_LOOP
POS_TO_LED_DONE:
        MOV   A,D
        POP   B
        RET

; 8-bit Galois LFSR (taps: x^8+x^4+x^3+x^2+1). Not true randomness,
; just chaotic-looking. out: A = new byte (also stored to SEED).
RAND:
        LDA   SEED
        ORA   A
        RAL
        JNC   RAND_NOXOR
        XRI   1Dh
RAND_NOXOR:
        STA   SEED
        RET

; ============================================================
; Data
; ============================================================
SPIN_SEGS: DB 01h,02h,04h,08h,10h,20h,10h,08h,04h,02h  ; a,b,c,d,e,f,e,d,c,b
SPIN_LEN EQU 10

        END   START
