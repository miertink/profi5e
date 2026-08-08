; ============================================================
; PROFI-5E -- Serial loader (expansion EPROM, ORG 2000h)
; ============================================================
; v2: calls the serial routines already present in the monitor ROM
; (BAUD/RXCHAR/TXCHAR) instead of bit-banging its own UART. See
; docs/Profi5E_Hardware_Reference.md for the full monitor API and
; how these routines were found and cross-validated.
;
; Auto-boot: port 21h bit6=1 on reset -> monitor jumps to 2000h.
; Already done by the monitor before we get here: SP=87ACh, 8255 #1
; and #3 configured (ctrl 92h), interrupt vectors copied to RAM.
; Still to do here: 8255 #2 (ctrl 91h -> port 13h), display.
;
; *** HARDWARE PREREQUISITES (physical switches on port 21h) ***
; Port 21h is read-only -- it reflects the board's physical DIL
; switches, not something this code programs. See Hardware
; Reference doc, section 6, for the full switch table:
;   bits 2-3 : baud rate used by BAUD/RXCHAR/TXCHAR
;              (00=300, 04h=600, 08h=1200, else=2400)
;   bit 4    : MUST be 1 (serial). At 0, TXCHAR sends over
;              Centronics instead of SOD.
;   bit 5    : MUST be 1 (no handshake). At 0, TXCHAR hangs waiting
;              for a "ready" signal on port 11h bit0 that doesn't
;              exist on this wiring (plain USB-TTL, no handshake).
;   bit 6    : auto-boot (optional -- 2000h can also be reached with
;              a manual GO from the monitor keyboard without this).
; Without bit4=1 and bit5=1 set correctly, the loader transmits nothing.
;
; Protocol v1 (PC -> board), one block per loader session:
;   [55h sync] [AAh cmd] [flags] [addr_lo] [addr_hi] [len_lo] [len_hi]
;   [payload... len bytes] [chk]
;   chk = sum modulo 256 of the payload bytes
;   ACK = 06h / NAK = 15h, sent over SOD after checking the checksum
;   flags bit0 = GO: if 1, jumps to addr after the ACK (PCHL);
;                    if 0, returns to the monitor (JMP 00FAh)
; ============================================================

        ORG   2000h

; ---- EQUs: monitor routines ----
BAUD         EQU  056Bh    ; reads port 21h bits2-3, sets up 87C6h/87C8h
RXCHAR       EQU  04F1h    ; receives 1 byte over SID (ROM's own bit-bang) -> A
TXCHAR       EQU  0EC3h    ; sends the byte in A over SOD (or Centronics, see bit4)
MON_REENTRY  EQU  00FAh    ; clean re-entry into the monitor
DISPSTR      EQU  0360h    ; BC=ptr to 8 segment bytes -> 87F8h
STR_ENDE     EQU  0EBBh    ; "EndE"
STR_FEHLER   EQU  03E7h    ; "FEHLEr"

; ---- EQUs: I/O ----
PPI2_CTRL    EQU  13h
PPI2_CTRL_V  EQU  91h       ; 8255 #2, normal Centronics mode

; ---- loader variables (free RAM 8700h-87ABh; do not touch 87ACh+) ----
V_FLAGS      EQU  8784h     ; (byte) header flags (bit0 = GO)
V_ADDR       EQU  8785h     ; (word) destination address
V_LEN        EQU  8787h     ; (word) payload size
V_PTR        EQU  8789h     ; (word) current write pointer
; -- 878Bh-87ABh free for the loader's stack --

; ============================================================
; INIT
; ============================================================
START:
        LXI   SP,87ABh          ; loader's own stack, below the monitor's area

        MVI   A,PPI2_CTRL_V
        OUT   PPI2_CTRL          ; 8255 #2: normal Centronics (91h)

        CALL  BAUD                ; set bit timing from the physical switch

        LXI   B,MSG_LOAD
        CALL  DISPSTR             ; show "LoAd" on the display

; ============================================================
; MAIN: wait for the sync byte (55h) and the header
; ============================================================
WAIT_SYNC:
        CALL  RXCHAR
        CPI   55h
        JNZ   WAIT_SYNC             ; not the sync byte -> try again

        CALL  RXCHAR
        CPI   0AAh
        JNZ   WAIT_SYNC              ; unknown command -> resync

        CALL  RXCHAR
        STA   V_FLAGS

        CALL  RXCHAR
        STA   V_ADDR
        CALL  RXCHAR
        STA   V_ADDR+1

        CALL  RXCHAR
        STA   V_LEN
        CALL  RXCHAR
        STA   V_LEN+1

        LHLD  V_ADDR
        SHLD  V_PTR               ; write pointer = destination address

        LHLD  V_LEN
        MOV   B,H
        MOV   C,L                  ; BC = remaining byte count
        MVI   D,00h                 ; D = running checksum

        MOV   A,B
        ORA   C
        JZ    RX_DONE                ; len=0 -> no payload

RX_LOOP:
        CALL  RXCHAR
        MOV   E,A
        LHLD  V_PTR

        ; Safety check: never write at or past 87ACh (the monitor's own
        ; stack/variables). A garbled length field (e.g. from a baud
        ; mismatch) could otherwise smear incoming noise across the
        ; monitor's RAM. The byte is still "received" (pointer, checksum,
        ; and protocol stay in sync) -- it's just not written once the
        ; destination runs past the safe range.
        MOV   A,H
        CPI   87h
        JC    DO_WRITE
        JNZ   SKIP_WRITE
        MOV   A,L
        CPI   0ACh
        JNC   SKIP_WRITE
DO_WRITE:
        MOV   M,E                    ; store the byte at the destination
SKIP_WRITE:
        INX   H
        SHLD  V_PTR
        MOV   A,D
        ADD   E
        MOV   D,A                    ; checksum += byte
        DCX   B
        MOV   A,B
        ORA   C
        JNZ   RX_LOOP

RX_DONE:
        CALL  RXCHAR                  ; receive the checksum byte
        CMP   D
        JNZ   LOAD_FAIL

; ---- success ----
        MVI   A,06h
        CALL  TXCHAR                    ; ACK
        LXI   B,STR_ENDE
        CALL  DISPSTR

        LDA   V_FLAGS
        ANI   01h
        JZ    LOAD_RETURN

        LHLD  V_ADDR
        PCHL                              ; GO: jump into the loaded program

LOAD_RETURN:
        JMP   MON_REENTRY

LOAD_FAIL:
        MVI   A,15h
        CALL  TXCHAR                       ; NAK
        LXI   B,STR_FEHLER
        CALL  DISPSTR
        JMP   MON_REENTRY

; ============================================================
; Display strings (8 bytes = 8 digits, segment patterns)
; bit0=a bit1=b bit2=c bit3=d bit4=e bit5=f bit6=g
; ============================================================
SEG_BLANK    EQU  00h
SEG_L        EQU  38h        ; L
SEG_o        EQU  5Ch        ; lowercase o
SEG_A        EQU  77h        ; A
SEG_d        EQU  5Eh        ; d

MSG_LOAD:
        DB    SEG_BLANK,SEG_BLANK,SEG_BLANK,SEG_BLANK
        DB    SEG_L,SEG_o,SEG_A,SEG_d

        END   START
