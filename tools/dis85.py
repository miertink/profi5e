#!/usr/bin/env python3
# 8085 disassembler with listing output
import sys

MNEM = {}
def add(op, txt, ln): MNEM[op] = (txt, ln)

regs = ['B','C','D','E','H','L','M','A']
rp   = ['B','D','H','SP']
rpp  = ['B','D','H','PSW']

for i,r in enumerate(regs):
    add(0x04+8*i, f'INR {r}',1); add(0x05+8*i, f'DCR {r}',1)
    add(0x06+8*i, f'MVI {r},#',2)
for d,rd in enumerate(regs):
    for s,rs in enumerate(regs):
        op=0x40+8*d+s
        if op==0x76: MNEM[op]=('HLT',1)
        else: add(op, f'MOV {rd},{rs}',1)
for i,(m) in enumerate(['ADD','ADC','SUB','SBB','ANA','XRA','ORA','CMP']):
    for s,rs in enumerate(regs): add(0x80+8*i+s, f'{m} {rs}',1)
for i,p in enumerate(rp):
    add(0x01+16*i, f'LXI {p},@',3); add(0x03+16*i, f'INX {p}',1)
    add(0x09+16*i, f'DAD {p}',1);  add(0x0B+16*i, f'DCX {p}',1)
add(0x00,'NOP',1); add(0x02,'STAX B',1); add(0x0A,'LDAX B',1)
add(0x12,'STAX D',1); add(0x1A,'LDAX D',1)
add(0x07,'RLC',1); add(0x0F,'RRC',1); add(0x17,'RAL',1); add(0x1F,'RAR',1)
add(0x22,'SHLD @',3); add(0x2A,'LHLD @',3); add(0x27,'DAA',1); add(0x2F,'CMA',1)
add(0x32,'STA @',3); add(0x3A,'LDA @',3); add(0x37,'STC',1); add(0x3F,'CMC',1)
add(0x20,'RIM',1); add(0x30,'SIM',1)
cc=['NZ','Z','NC','C','PO','PE','P','M']
for i,c in enumerate(cc):
    add(0xC0+8*i, f'R{c}',1); add(0xC2+8*i, f'J{c} @',3); add(0xC4+8*i, f'C{c} @',3)
for i,p in enumerate(rpp):
    add(0xC1+16*i, f'POP {p}',1); add(0xC5+16*i, f'PUSH {p}',1)
add(0xC3,'JMP @',3); add(0xC9,'RET',1); add(0xCD,'CALL @',3)
for i,m in enumerate(['ADI','ACI','SUI','SBI','ANI','XRI','ORI','CPI']):
    add(0xC6+8*i, f'{m} #',2)
for i in range(8): add(0xC7+8*i, f'RST {i}',1)
add(0xD3,'OUT #',2); add(0xDB,'IN #',2)
add(0xE3,'XTHL',1); add(0xE9,'PCHL',1); add(0xEB,'XCHG',1)
add(0xF3,'DI',1); add(0xFB,'EI',1); add(0xF9,'SPHL',1)

data = open(sys.argv[1],'rb').read()
org = 0
pc = 0
out = []
while pc < len(data):
    op = data[pc]
    if op not in MNEM:
        out.append((org+pc, data[pc:pc+1], f'DB {op:02X}h'))
        pc += 1; continue
    txt, ln = MNEM[op]
    raw = data[pc:pc+ln]
    if ln==2:
        txt = txt.replace('#', f'{raw[1]:02X}h') if len(raw)>1 else txt
    elif ln==3:
        if len(raw)>2:
            addr = raw[1] | (raw[2]<<8)
            txt = txt.replace('@', f'{addr:04X}h')
    out.append((org+pc, raw, txt))
    pc += ln

for a, raw, txt in out:
    hexs = ' '.join(f'{b:02X}' for b in raw)
    print(f'{a:04X}  {hexs:<9} {txt}')
