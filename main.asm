BITS 64
DEFAULT REL

%macro LOAD_SSE 2
    movdqu %1, [%2]
%endmacro

section .data

align 16
data_block:
    db 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE
    db 0xF0, 0x0D, 0xFE, 0xED, 0xAA, 0xBB, 0xCC, 0xDD

section .bss
    resb 16

section .text
global _start

_start:
    LOAD_SSE xmm0, data_block
    pshufd xmm0, xmm0, 0xB1
    lea rbx, [rip + next_insn]
    mov byte [rbx + 1], 0x00
    clflush [rbx]
    mfence

next_insn:
    inc rax                             
    mov rax, 0x123456789ABCDEF0
    rol rax, 17
    mov rax, 60
    xor rdi, rdi
    syscall
