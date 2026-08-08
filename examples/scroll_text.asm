; ============================================================
; scroll_text.asm -- scrolls "NOTHING IS CERTAIN" across the display
;
; A classic skeptical position (echoed from Pyrrhonism to Cartesian
; doubt). Chosen because every letter in it (N,O,T,H,I,G,S,C,E,R,A)
; has a clean, confirmed 7-segment pattern -- unlike a good chunk of
; the alphabet (J,K,M,Q,V,W,X,Y,Z have no decent 7-segment glyph at
; all, which rules out a lot of otherwise natural English phrasing).
;
; The message is padded with 3 blank digits on each side so it
; scrolls in and out of view smoothly, then loops forever.
;
; Loaded via the serial loader (tools/profi5e_load.py). Assembled for
; 8000h by default. This is NOT position-independent code -- if you
; need it resident at a different address (e.g. to keep it loaded
; alongside another example), rebuild with:
;   python tools/profi5e_build.py examples/scroll_text.asm --addr 8200
; and pass the SAME --addr to profi5e_load.py -- the build and load
; addresses must match, or the program reads/jumps to the wrong places.
; ============================================================

        IFNDEF LOADADDR
LOADADDR EQU  8000h
        ENDIF
        ORG   LOADADDR

DISPSTR   EQU  0360h    ; BC=ptr to 8 segment bytes -> 87F8h
ZSECD     EQU  0300h    ; delay = A(decimal) x 0.1s

WIN       EQU  8              ; display width, in digits
TEXT_LEN  EQU  MSG_END-MSG    ; padded message length, in bytes
LAST_OFF  EQU  TEXT_LEN-WIN   ; highest valid scroll offset

OFFSET    EQU  8790h    ; (byte) current scroll offset -- free RAM,
                         ; below the loader/monitor's own working area

START:
        XRA   A
        STA   OFFSET

SCROLL:
        LDA   OFFSET
        MOV   L,A
        MVI   H,00h
        LXI   D,MSG
        DAD   D              ; HL = MSG + offset
        MOV   B,H
        MOV   C,L             ; BC = window pointer
        CALL  DISPSTR

        MVI   A,03h            ; 0.3s per step
        CALL  ZSECD

        LDA   OFFSET
        INR   A
        CPI   LAST_OFF+1
        JC    STORE_OFFSET
        XRA   A                 ; past the end -- wrap back to the start
STORE_OFFSET:
        STA   OFFSET
        JMP   SCROLL

; ============================================================
; Segment patterns: bit0=a bit1=b bit2=c bit3=d bit4=e bit5=f bit6=g
; ============================================================
SEG_BLANK    EQU  00h
SEG_A        EQU  77h
SEG_C        EQU  39h
SEG_E        EQU  79h
SEG_G        EQU  3Dh
SEG_H        EQU  74h
SEG_I        EQU  10h    ; segment e only -- see note in hiworld.asm
SEG_N        EQU  54h
SEG_O        EQU  5Ch
SEG_R        EQU  50h
SEG_S        EQU  6Dh
SEG_T        EQU  78h

MSG:
        DB    SEG_BLANK,SEG_BLANK,SEG_BLANK
        DB    SEG_N,SEG_O,SEG_T,SEG_H,SEG_I,SEG_N,SEG_G
        DB    SEG_BLANK
        DB    SEG_I,SEG_S
        DB    SEG_BLANK
        DB    SEG_C,SEG_E,SEG_R,SEG_T,SEG_A,SEG_I,SEG_N
        DB    SEG_BLANK,SEG_BLANK,SEG_BLANK
MSG_END:

        END   START
