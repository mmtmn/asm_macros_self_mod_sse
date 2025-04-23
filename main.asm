BITS 64
default rel               ; Let NASM use RIP-relative by default

%define SYS_mprotect 10   ; On x86_64 Linux, syscall #10 is mprotect
%define PROT_READ   1
%define PROT_WRITE  2
%define PROT_EXEC   4

section .data
    align 4096
    ; -----------------------------------------------------------------------
    ; We'll store code here that we want to modify at runtime. The page
    ; is initially marked R/W but not X. We'll make it executable via mprotect.
    ; -----------------------------------------------------------------------
code_block:
    inc rax                        ; (3 bytes: 48 FF C0)
    mov rax, 0x123456789ABCDEF0
    rol rax, 17
    mov rax, 60                    ; syscall number for exit
    xor rdi, rdi
    syscall
code_block_end:

%define CODE_SIZE (code_block_end - code_block)

    ; Some 16-byte-aligned data for SSE
    align 16
data_block:
    db 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE
    db 0xF0, 0x0D, 0xFE, 0xED, 0xAA, 0xBB, 0xCC, 0xDD


section .text
global _start

%macro LOAD_SSE 2
    movdqu %1, [%2]
%endmacro

_start:
    ; -----------------------------------------------------------------------
    ; 1) SSE demo: load and shuffle the data_block
    ; -----------------------------------------------------------------------
    LOAD_SSE xmm0, data_block
    pshufd xmm0, xmm0, 0xB1

    ; -----------------------------------------------------------------------
    ; 2) mprotect the code_block region: set Read+Write+Exec
    ; -----------------------------------------------------------------------
    ; Linux syscall mprotect(addr, length, prot)
    ;   rax = syscall#
    ;   rdi = address
    ;   rsi = length
    ;   rdx = prot flags
    mov rax, SYS_mprotect
    mov rdi, code_block            ; start address
    mov rsi, CODE_SIZE             ; region size
    mov rdx, (PROT_READ | PROT_WRITE | PROT_EXEC)
    syscall

    ; -----------------------------------------------------------------------
    ; 3) Self-modify the first 3 bytes of code_block
    ;    Original: inc rax  => 0x48 0xFF 0xC0
    ;    Patch to: 3-byte NOP => 0x0F 0x1F 0x00
    ; -----------------------------------------------------------------------
    lea rbx, [rel code_block]
    mov byte [rbx],   0x0F
    mov byte [rbx+1], 0x1F
    mov byte [rbx+2], 0x00

    ; -----------------------------------------------------------------------
    ; 4) Flush instruction cache lines & fence
    ; -----------------------------------------------------------------------
    clflush [rbx]
    clflush [rbx+1]
    clflush [rbx+2]
    mfence

    ; -----------------------------------------------------------------------
    ; 5) Jump into the modified code_block
    ; -----------------------------------------------------------------------
    jmp code_block
